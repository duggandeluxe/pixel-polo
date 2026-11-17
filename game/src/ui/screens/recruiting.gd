extends BaseScreen
## RECRUITING MARKET (Coaching's RECRUITING; the Credit Economy & Recruiting Overhaul and the
## Recruiting Player Cards update; the Recruiting Market Visual Overhaul): eight prospects for
## sale in Coaching Credits (Recruiting), four to a row on athlete cards (paint_recruit: big
## portrait, surname, current stars, the price in the footer). The card is one button:
## a tap anywhere on it opens his profile (the player page in recruit mode: everything about him,
## his potential too, and SIGN RECRUIT). Tapping never signs anyone. Two tabs: MARKET (the eight) and INCOMING (who you've
## signed: they join next season). Above them RECRUITS SIGNED: X / 4, REFRESH RECRUITS with its
## cost, and the PROJECTED ROSTER against your cap, warning when it's over (cuts after the season:
## roster_cuts). Your credits are in the header's chip.

const RosterScreen := preload("res://src/ui/screens/roster.gd")
const TABS := ["MARKET", "INCOMING"]
const COLS := 4
const GAP := 8
const ROW_GAP := 6

## Kept while you move around the career screens.
static var tab := "MARKET"
static var sel := -1        # the last prospect opened (his card is outlined)

var from := "hub"
var cards := {}             # pid -> his card

func setup(params: Dictionary) -> void:
	if params.has("tab"):
		tab = String(params.tab)
	if not tab in TABS:
		tab = "MARKET"
	if params.has("sel"):
		sel = int(params.sel)
	from = String(params.get("from", "hub"))   # Coaching opens it too: back goes back there

func _ready() -> void:
	back_target = from
	build("RECRUITING MARKET", true, true)
	if c != null and Recruiting.seen_new(c):
		Game.save_career()   # (NEW RECRUITS AVAILABLE read: the hub's banner and dot go, for good)
	_render()

func _render() -> void:
	for ch in body.get_children():
		body.remove_child(ch)
		ch.queue_free()
	cards = {}
	body.add_theme_constant_override("separation", 4)
	body.add_child(_top())
	body.add_child(_projection())
	var rows: Array = c.market if tab == "MARKET" else c.incoming
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if rows.is_empty():
		var empty := "No recruits signed yet: they join next season." if tab == "INCOMING" else \
			("The market reopens with the new season." if c.phase == "cuts" else "The market is empty: refresh it.")
		center.add_child(UI.label(empty, 8, UI.DIM))
	else:
		var grid := GridContainer.new()
		grid.name = "Cards"
		grid.columns = COLS
		grid.add_theme_constant_override("h_separation", GAP)
		grid.add_theme_constant_override("v_separation", ROW_GAP)
		var size := card_size(self)
		for r in rows:
			grid.add_child(_card(r, size))
		center.add_child(grid)
	body.add_child(center)

## A card's size: four to a row across the page (the safe area's), up to CARD_W, CARD_H tall.
static func card_size(scr: BaseScreen) -> Vector2:
	var ins := scr.safe_insets()
	var w := scr.get_viewport_rect().size.x - 8.0 - ins.x - ins.z
	return Vector2(clampf(floorf((w - GAP * (COLS - 1)) / COLS), 96.0, CARD_W), CARD_H)

# ------------------------------------------------------------------ top: tabs, signings, refresh
func _top() -> Control:
	var h := UI.hbox(3)
	h.name = "Top"
	for t in TABS:
		var tt: String = t
		var n := ""
		if tt == "INCOMING":
			n = "  %d" % c.incoming.size()
		var b := Deck.button(tt + n, func():
			tab = tt
			_render(), "tab_on" if tab == tt else "tab", 74, 18)
		b.name = "Tab_" + tt
		h.add_child(b)
	h.add_child(UI.spacer(0, 0, true))
	var signed := PanelContainer.new()
	signed.add_theme_stylebox_override("panel", UI.chunky(Deck.NAVY, UI.GOLD, false, false, 5, 2))
	signed.name = "Signed"
	signed.add_child(UI.label("RECRUITS SIGNED: %d / %d" % [Recruiting.signed_count(c), Recruiting.SIGN_MAX], 8, UI.GOLD, "caps"))
	signed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(signed)
	var cost := Recruiting.refresh_cost(c)
	var block := Recruiting.refresh_block(c)
	var rb := UI.button("", _ask_refresh, "primary" if block == "" else "normal", 0, 18)
	CreditCoin.set_button(rb, "REFRESH RECRUITS  %s" % ("FREE" if cost == 0 else CreditCoin.tag(cost)))
	rb.name = "Refresh"
	rb.disabled = block != ""
	rb.tooltip_text = CreditCoin.plain(block) if block != "" else "New prospects replace the market's unpinned recruits. Signed recruits stay signed."
	h.add_child(rb)
	return h

## NEXT SEASON: the projected roster against your cap (and the warning when it's over),
## graduating and signed. One compact navy panel.
func _projection() -> Control:
	var over := Recruiting.over_by(c)
	var keepers_over := maxi(0, Recruiting.projected_keepers(c) - c.keeper_cap(c.school))
	var bad := over > 0 or keepers_over > 0
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.chunky(Color("3a0d22") if bad else Deck.NAVY, UI.WARN if bad else UI.BORDER, false, false, 5, 2))
	p.name = "Projection"
	p.set_meta("over", over)
	var pv := UI.vbox(1)
	p.add_child(pv)
	var h := UI.hbox(8)
	pv.add_child(h)
	h.add_child(UI.label("NEXT SEASON", 8, UI.GOLD, "caps"))
	var head := UI.label("PROJECTED ROSTER: %d / %d" % [Recruiting.projected(c), c.roster_max()], 8, UI.WARN if bad else UI.TEXT, "caps")
	head.name = "ProjectedCount"
	h.add_child(head)
	h.add_child(UI.label("GRADUATING: %d" % Recruiting.graduating(c).size(), 8, UI.ACCENT, "caps"))
	# (SIGNED is the gold chip above; the note stays short so the strip fits the 480 px page)
	h.add_child(UI.spacer(0, 0, true))
	var msg := "NO CUTS REQUIRED"
	if over > 0:
		msg = "MUST CUT %d AFTER SEASON" % over
	elif keepers_over > 0:
		msg = "MUST CUT %d GK (MAX %d)" % [keepers_over, c.keeper_cap(c.school)]
	var ml := UI.label(msg, 8, UI.WARN if bad else UI.GOOD, "caps")
	ml.name = "ProjectionNote"
	h.add_child(ml)
	return p

# ------------------------------------------------------------------ the cards
## A recruit's athlete card: his position (top left; a small pin when he's pinned), his portrait
## big (Portrait, twice its pixels, cut at the shoulders), his surname, his stars (one bar: gold
## to CURRENT, hollow up to POTENTIAL and no further), and a footer with his price (the number, then the coin) or,
## signed, JOINS NEXT SEASON. One button: a tap opens his profile (the player page in recruit
## mode, SIGN RECRUIT there). Hover brightens it, the last one opened has a gold border, a press
## sinks it a pixel (not with Reduce Motion).
func _card(r: Dictionary, size: Vector2 = Vector2(CARD_W, CARD_H)) -> Button:
	var p: PoloPlayer = r.p
	var pid := p.id
	var incoming: bool = r in c.incoming
	var pinned := Recruiting.is_pinned(r)
	var team := c.team()
	var b := Deck.card(size, func(ci, _rr, mode):
		paint_recruit(ci, size, p, team, mode, pid == sel, pinned, incoming, bool(r.get("legacy", false)), int(r.get("price", 0))), func():
		sel = pid
		Game.goto("player", {"id": pid, "recruit": true, "from": from}))
	b.name = "Card_%d" % pid
	b.set_meta("price", int(r.price))
	b.set_meta("pid", pid)
	b.set_meta("pinned", pinned)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cards[pid] = b
	if DevArt.is_dev(p):
		# THE DEV RECRUIT GLITCH: on the body (not the drop shadow), sunk a pixel with the card on a press
		DevGlitch.attach(self, b, {"seed": hash([p.dev_recruit, "market"]), "body": func(bt: Control) -> Rect2:
			var down := 1.0 if Juice.enabled() and (bt as BaseButton).get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED] else 0.0
			return Rect2(0, down, bt.size.x - 2, bt.size.y - 2)})
	return b

const CARD_W := 112.0
const CARD_H := 88.0
const PORTRAIT_Y := 3.0       # the portrait's top
const PORTRAIT_SHOW := 40     # its rows shown (2x: his cap to his chin)
const NAME_Y := 52.0
const STARS_Y := 58.0
const FOOT_H := 17.0          # the footer: the price and its 16 px coin, never shrunk
const CARD_BG := Color("0b1d5c")
const PORTRAIT_BG := Color("16308a")
const PIN := [".###.", "#####", ".###.", "..#..", "..#..", "..#.."]

## The market card's star bar width: a half-star ceiling ends on a cut star (half its columns).
static func market_bar_w(fills: Array) -> float:
	var n := fills.size()
	if n == 0:
		return 0.0
	var last := int(Deck.STAR_SHAPE.half) if float(fills[n - 1].pot) < 0.99 else int(Deck.STAR_SHAPE.w)
	return Deck.star_x(n - 1) + last

## One recruit card at `size` (static: the tests paint it too).
static func paint_recruit(ci: CanvasItem, size: Vector2, p: PoloPlayer, team: PoloTeam, mode: String, selected: bool, pinned: bool,
		incoming: bool, legacy: bool, price: int) -> void:
	var down := 1.0 if mode == "down" and Juice.enabled() else 0.0
	var o := Vector2(0, down)
	var w := size.x
	var h := size.y
	var is_dev := DevArt.is_dev(p)   # a DEV RECRUIT: the light-blue card (DevArt), same layout
	# depth: a hard drop shadow (it stays put while the card sinks)
	ci.draw_rect(Rect2(2, 2, w - 2, h - 2), Color(0, 0, 0, 0.35))
	var body := Rect2(o, Vector2(w - 2, h - 2))
	if is_dev:
		DevArt.panel(ci, body, mode == "hover")
	else:
		ci.draw_rect(body, CARD_BG.lightened(0.07) if mode == "hover" else CARD_BG)
	# the portrait panel
	var pan := Rect2(o + Vector2(3, 3), Vector2(w - 8, NAME_Y - 8))
	var pan_col := DevArt.ICE_DEEP if is_dev else (Color("7a1a22") if p.is_keeper() else PORTRAIT_BG)
	ci.draw_rect(pan, pan_col.lightened(0.06 if mode == "hover" else 0.0))
	if is_dev:
		ci.draw_rect(Rect2(pan.position, Vector2(pan.size.x, 1)), DevArt.CYAN)   # its lit top edge
	var col := Portrait.colors_ours(p, team)
	var tex := Portrait.texture(p, col[0], col[1])
	var sz := Vector2(Portrait.SIZE) * 2.0
	var show := minf(float(PORTRAIT_SHOW), pan.size.y - 1.0)
	var at := Vector2(floorf(o.x + w * 0.5 - 1.0 - sz.x * 0.5), o.y + PORTRAIT_Y + 1.0)
	ci.draw_texture_rect_region(tex, Rect2(at, Vector2(sz.x, show)), Rect2(Vector2.ZERO, Vector2(Portrait.SIZE.x, show / 2.0)))
	Deck.text(ci, o.x + 7, o.y + 9, Deck.pos_tag(p), 8, UI.TEXT)
	if pinned:
		Deck.pat(ci, o + Vector2(w - 13, 5), PIN, {"#": UI.GOLD})
	# his name, then his stars
	var name := p.short_name().to_upper()
	var room := w - 12.0
	var big := Deck.text_w(name, 16, "big") <= room
	Deck.ctext(ci, Rect2(o + Vector2(0, NAME_Y - 6), Vector2(w - 2, 10)), Deck.fit(name, room, 16 if big else 8, "big" if big else "caps"), 16 if big else 8,
		DevArt.INK if is_dev else UI.TEXT, "big" if big else "caps")
	# one bar: gold to CURRENT, hollow up to POTENTIAL, ending at his ceiling (never padded to five)
	var cur := PlayerForm.snap_half(p.stars)
	var pot := PlayerForm.snap_half(p.pot_stars)
	var fills := Deck.star_fills(cur, pot)
	var sw := market_bar_w(fills)
	var sx := floorf(o.x + (w - 2 - sw) * 0.5)
	for i in fills.size():
		# a half-star ceiling: the last star is cut down the middle (only its left half drawn)
		var cut := i == fills.size() - 1 and float(fills[i].pot) < 0.99
		Deck.star_place(ci, Vector2(sx + Deck.star_x(i), o.y + STARS_Y), fills[i], Color(DevArt.INK, 0.3) if is_dev else Color(1, 1, 1, 0.14), 0,
			int(Deck.STAR_SHAPE.half) if cut else 99)
	# the footer
	var foot := Rect2(o + Vector2(0, h - 2 - FOOT_H), Vector2(w - 2, FOOT_H))
	ci.draw_rect(foot, Deck.NAVY_HEAD.lightened(0.06) if mode == "hover" else Deck.NAVY_HEAD)
	ci.draw_rect(Rect2(foot.position, Vector2(foot.size.x, 1)), Color(UI.GOLD, 0.55) if not incoming else Color(UI.GOOD, 0.6))
	# (a DEV Recruit's footer is everyone's: no label, the price centred; his card glitches: DevGlitch)
	if incoming:
		Deck.ctext(ci, foot, "COMMITTED" if legacy else "SIGNED: NEXT SEASON", 8, UI.GOOD)
	else:
		CreditCoin.draw_amount(ci, foot.position.x, foot.get_center().y, str(price), 8, UI.GOLD, "caps", 16, 1, foot.size.x)
	# the border last: white; brighter on hover; gold (two pixels) for the one you opened (a DEV
	# Recruit's darker blue, electric on hover)
	var edge := UI.GOLD if selected or mode == "down" else (UI.ACCENT if mode == "hover" else UI.BORDER)
	if is_dev and not selected and mode != "down":
		edge = DevArt.ELECTRIC if mode == "hover" else DevArt.EDGE
	ci.draw_rect(body, edge, false, 1.0)
	if selected:
		ci.draw_rect(body.grow(-1), edge, false, 1.0)

# ------------------------------------------------------------------ signing and refreshing
## SIGN RECRUIT (from his profile): the roster warning when he'd take the projection over the cap
## (SIGN ANYWAY), or a plain confirmation. Nothing is paid until the coach says yes; `done` runs
## after a signing (with "" or why not).
static func ask_sign(c: Career, r: Dictionary, done: Callable) -> void:
	var p: PoloPlayer = r.p
	var price := int(r.price)
	var block := Recruiting.sign_block(c, r)
	if block != "":
		Game.toast(block, UI.WARN)
		Sfx.play("error")
		return
	var who := "%s (%s, %s*)" % [p.short_name(), p.pos_text(), PlayerForm.star_text(p.stars)]
	var sign := func():
		var err := Recruiting.sign(c, r)
		if err == "":
			Sfx.play("coins")
			Game.toast("SIGNED: %s joins next season" % p.short_name(), UI.GOLD)
			Game.save_career()
		done.call(err)
	var over := Recruiting.over_by(c, 1)
	if over > 0:
		Game.dialog("ROSTER LIMIT WARNING", "Signing this recruit will bring your projected roster to %d / %d.\n\nYou will need to cut %d player%s after the season.\n\n%s costs %s." % [
			Recruiting.projected(c, 1), c.roster_max(), over, "" if over == 1 else "s", who, CreditCoin.tag(price)], [
			["SIGN ANYWAY", sign, "primary"],
			["CANCEL", Callable(), "ghost"]])
		return
	Game.dialog("SIGN RECRUIT?", "Sign %s for %s?\n\nHe joins your roster next season. Projected roster: %d / %d." % [who, CreditCoin.tag(price), Recruiting.projected(c, 1), c.roster_max()], [
		["SIGN RECRUIT", sign, "primary"],
		["CANCEL", Callable(), "ghost"]])

func _ask_refresh() -> void:
	var cost := Recruiting.refresh_cost(c)
	var pins := Recruiting.pinned(c).size()
	# an unpinned DEV Recruit rotates out with this refresh (DevRecruits.rotate_out): said up front
	var devs: Array = c.market.filter(func(r): return (r.p as PoloPlayer).dev_recruit != "" and not Recruiting.is_pinned(r)).map(func(r): return r.p)
	var warn := "" if devs.is_empty() else "\n\nUNPINNED DEV RECRUIT%s: %s rotate%s out, with a %d%% chance a CPU program signs %s. Pin to keep." % [
		"" if devs.size() == 1 else "S", " and ".join(devs.map(func(q): return "%s %s" % [q.first, q.last])), "s" if devs.size() == 1 else "",
		roundi(DevRecruits.PICKUP_CHANCE * 100.0), "him" if devs.size() == 1 else "each"]
	Game.dialog("REFRESH RECRUITS?", "New prospects replace everyone on the market%s%s.\n\nRecruits you've signed stay signed, and this season's signings still count (%d / %d).%s" % [
		"" if pins == 0 else " except your %d pinned" % pins, " for free" if cost == 0 else " for %s" % CreditCoin.tag(cost), Recruiting.signed_count(c), Recruiting.SIGN_MAX, warn], [
		["REFRESH" if cost == 0 else "REFRESH  %s" % CreditCoin.tag(cost), func():
			var err := Recruiting.refresh(c)
			if err != "":
				Game.toast(err, UI.WARN)
				Sfx.play("error")
				return
			Sfx.play("card")
			sel = -1
			for q: PoloPlayer in devs:   # (where each rotated DEV Recruit went: his news line)
				var to := DevRecruits.school_of(c, q.dev_recruit)
				Game.toast("DEV RECRUIT SIGNED: %s %s COMMITS TO %s" % [q.first.to_upper(), q.last.to_upper(), Colleges.short_name(c.teams[to]).to_upper()] if to != "" and c.teams.has(to)
					else "%s %s LEFT THE MARKET UNSIGNED" % [q.first.to_upper(), q.last.to_upper()], UI.GOLD)
			Game.save_career()
			_render(), "primary"],
		["CANCEL", Callable(), "ghost"]])
