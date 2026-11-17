extends BaseScreen
## THE DYNASTY HUB (the team card on the home screen; the old MORE): eight cards in two rows of
## four, filling the page. Row one, the program: PROGRAM (program.gd), LEAGUE NEWS (news.gd: scores, news & records),
## TROPHY CASE (trophy_room.gd in team mode: the program's championships), RECORD BOOK (records.gd). Row two, managing and the rest:
## POLO POINTS SHOP, SETTINGS, VISUAL UPGRADES (visual_shop.gd), RECRUITING. Each card: a small pixel icon, its title,
## a line about it and, in gold, where it stands now (your record, your credits...).

const GAP := 6
const COLS := 4
## [title, subtitle, icon, screen]
const CARDS := [
	["PROGRAM", "Your team's legacy", "shield", "program"],
	["LEAGUE NEWS", "Scores, news & records", "paper", "news"],
	["TROPHY CASE", "Your program's championships", "case", "team_trophies"],
	["RECORD BOOK", "Records, awards & history", "trophy", "records"],
	["POLO POINTS SHOP", "Polo Points & Polo +", "coin", "store"],
	["SETTINGS", "Customize your game", "gear", "settings"],
	["VISUAL UPGRADES", "Celebrations, crowds & more", "screen", "visual_shop"],
	["RECRUITING", "Build next year's roster", "player", "recruiting"],
]
## The icons, 10 x 10 pixel patterns drawn at 2x ("#" ink, "o" gold, "w" white).
const ICONS := {
	"shield": ["##########", "#oooooooo#", "#oowwwwoo#", "#oowooooo#", "#oowwwwoo#", "#oooooow#.", ".#oowwwo#.", "..#oooo#..", "...#oo#...", "....##...."],
	"paper": ["##########", "#wwwwwwww#", "#w####ww##", "#w#oo#wwo#", "#w####ww##", "#wwwwwwww#", "#w######w#", "#wwwwwwww#", "#w######w#", "##########"],
	"pool": ["..........", "#........#", "#........#", "#.oooooo.#", "#oowoowoo#", "#oooooooo#", "#woowoowo#", "#oooooooo#", "##########", ".........."],
	"trophy": ["#oooooooo#", "#oooooooo#", ".#oooooo#.", "..#oooo#..", "...#oo#...", "....##....", "....oo....", "...####...", "..#oooo#..", "..######.."],
	"case": ["##########", "#wo....ow#", "#w.oooo.w#", "#w.oooo.w#", "#w..oo..w#", "#w..oo..w#", "#w.oooo.w#", "#wwwwwwww#", "##########", "#oooooooo#"],
	"gear": ["....##....", ".##.oo.##.", ".#oooooo#.", "..oo##oo..", "#oo#..#oo#", "#oo#..#oo#", "..oo##oo..", ".#oooooo#.", ".##.oo.##.", "....##...."],
	"screen": ["##########", "#oooooooo#", "#o......o#", "#o.ww...o#", "#o.w....o#", "#o......o#", "#oooooooo#", "##########", "...####...", ".########."],
	"player": ["...####...", "..#oooo#..", ".#oooooo#.", ".#wwwwww#.", ".#ww##ww#.", "..#wwww#..", "...#ww#...", ".########.", "#wwwwwwww#", "#wwwwwwww#"],
}

func _ready() -> void:
	c = Game.career
	if c == null:
		Game.goto("title")
		return
	back_target = "hub"
	# however the hub was reached, the home screen's first-time hint is gone for good in this save
	if not c.hub_seen:
		c.hub_seen = true
		Game.save_career()
	build("DYNASTY HUB", true, true)
	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var i := 0
	for card in CARDS:
		var tile := _card(card)
		grid.add_child(tile)
		Juice.enter(tile, i)
		i += 1

## Where each section stands now, in gold under its line ("9-3  #2 IN PEC", your credits...).
func _status(screen: String) -> String:
	match screen:
		"program":
			return "%s   #%d IN %s" % [c.record_text(), c.conf_rank(), c.conf_abbr()]
		"news":
			var wk: int = load("res://src/ui/screens/news.gd").board_week(c)
			return "%s SCORES" % ConfAwards.week_label(c, wk) if wk >= 0 else "NO RESULTS YET"
		"team_trophies":
			var n := TeamHonours.of(c, c.school).size()
			return "%d TITLE%s" % [n, "" if n == 1 else "S"] if n > 0 else "NO TITLES YET"
		"records":
			return "%d AWARDS WON" % c.conf_awards.filter(func(a): return String(a.team) == c.school).size()
		"store":
			return CreditCoin.tag(c.wallet())
		"settings":
			return Difficulty.label_for(true)
		"visual_shop":
			return CreditCoin.tag(c.wallet())
		"recruiting":
			return "SIGNED %d / %d" % [Recruiting.signed_count(c), Recruiting.SIGN_MAX]
	return ""

func _card(card: Array) -> Control:
	var title := String(card[0])
	var sub := String(card[1])
	var icon := String(card[2])
	var screen := String(card[3])
	var status := _status(screen)
	var b := Deck.card(Vector2(0, 0), func(ci: Control, r: Rect2, mode: String):
		var down := mode == "down"
		var box := Rect2(r.position + (Vector2(1, 2) if down else Vector2.ZERO), r.size - Vector2(1, 2))
		var fill := Deck.NAVY_HEAD.lightened(0.1) if mode == "hover" else (Deck.NAVY_HEAD if down else Deck.NAVY)
		Deck.frame(ci, box, fill, UI.GOLD if mode != "normal" else UI.BORDER, not down)
		var x := box.position.x + 8.0
		var y := box.position.y
		if icon == "coin":
			CreditCoin.draw(ci, Vector2(x, y + 8), 20)
		else:
			Deck.pat(ci, Vector2(x, y + 8), ICONS[icon], {"#": UI.INK, "o": UI.GOLD, "w": UI.TEXT}, 2.0)
		Deck.shadow_text(ci, x, y + 42, Deck.fit(title, box.size.x - 14, 16, "big"), 16, UI.TEXT, "big")
		var lines := _wrap(sub.to_upper(), box.size.x - 14)
		for li in lines.size():
			Deck.text(ci, x, y + 57 + li * 10, lines[li], 8, UI.ACCENT)
		var sy := box.end.y - 10.0
		if CreditCoin.has_tag(status):
			CreditCoin.draw_text(ci, x, sy - 2, status, 8, UI.GOLD)
		else:
			Deck.text(ci, x, sy, Deck.fit(status, box.size.x - 14), 8, UI.GOLD), func():
		if screen == "team_trophies":
			Game.goto("trophy_room", {"team": c.school, "back_to": "more"})   # (the Trophy Room in team mode)
		else:
			Game.goto(screen))
	b.name = "Card_" + screen
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return b

## `t` in lines of at most `w` px (whole words; two lines at most, the last fitted).
static func _wrap(t: String, w: float) -> Array:
	t = Loc.t(t)   # (the player's LANGUAGE: translated whole, then wrapped)
	var out: Array = []
	var line := ""
	for word: String in Loc.units(t):
		var next := word if line == "" else line + Loc.gap() + word
		if Deck.text_w(next) <= w or line == "":
			line = next
		else:
			out.append(line)
			line = word
	out.append(line)
	if out.size() > 2:
		out = [out[0], Deck.fit(Loc.gap().join(out.slice(1)), w)]
	return out
