extends BaseScreen
## The roster as a deck of cards, straight on the page: the starting seven in a 3-3 offence
## facing the opponent's goal (top), LEFT WING, CENTER FORWARD, RIGHT WING on the 2 m line, LEFT
## FLAT, POINT, RIGHT FLAT out on the perimeter, the keeper on his own below them, and under it
## to their right, a little apart, the three SUBS on the bench, one per row. Who stands where is the team's
## lineup (PoloTeam.lineup, saved): the match lines up just like this, and the bench sits out.
## A career's first visit sets it from the team's own seven (formation(): PoloTeam's
## position-aware seven, each in his place). Every starting place has its name over its card
## (PoloTeam.slot_name: C, 2MD, ATK, WG, GK, the right side ATK/LFTY and WG/LFTY while there's a
## lefty on the roster); the card itself keeps the man's own position (a UT in WG/LFTY is a UT).
## Each card: up top, his position, cap number, HOT or VERY HOT, and the
## player's front-on headshot (Portrait: his cap, face and build, the same everywhere) on a solid panel;
## below, his surname and class year (a small red cross while he's hurt), his five stars (StarFx
## in Deck.STAR_SHAPE, the game's one star: gold for CURRENT, red after it for HOT / VERY HOT,
## nothing for POTENTIAL: the bar ends on his last current star) and a thin XP bar (nothing once
## he's fully developed).
## No OVR or POT numbers: they're on his page.
## The starting keeper's card is red. A place in the seven nobody fills is an OPEN SPOT (tap: recruiting); a bench place
## nobody fills is EMPTY.
##
## Drag a card onto another to swap the two (like a card game's deck): it lifts and follows the
## pointer, its place left as a dashed slot, every place it may go outlined. Only a keeper keeps
## goal and no keeper plays in the field; a starting place is never left empty for the bench. A
## drop anywhere else and the card slides back. Only legal moves (PoloTeam.fits): a centre or
## 2MD at C and 2MD, attackers, wings and utilities on the perimeter, a lefty only on the right
## side's two places. The cards come in quickly, one after another,
## each rising a few pixels. Tap a card (no drag): its border flashes gold and pulses out a
## pixel, then his page opens. A form change since his card was last on show plays once on the
## stars it moves (StarFx), nothing else. With Settings > Developer Mode on, a small DEV picks a
## card and heats, cools or resets it right here: a test form on the card only, gone when you
## leave (the player, his form and the save never change).
##
## SCOUTING (scout.gd, Coaching's SCOUT OPPONENT, extends this: scouted() is the team): the same
## deck for your next opponent, read only. His seven in their places as his own lineup has them
## (never set or saved from here), his bench under SUBS, the same cards (only current stars, and
## no XP bar: its going says he's fully developed), every card tapping through to his page in
## scouting mode (player.gd: no potential anywhere). No dragging, no DEV, no open-spot link. The
## two empty places either side of his keeper hold the team: logo, name, record, rating, home or
## away, and his home pool.

const CARD := Vector2(102, 64)   # (the Portrait Zoom update: 55 -> 64, the room all for the portrait)
const GAP := 6
const ROW_GAP := 11        # (room for the place's name over the next row's cards)
const BENCH_GAP := 14      # between the seven and the bench column
const LABEL_H := 11        # over the first row: the places' names and SUBS
const SPLIT := 39.0        # the divider: the portrait above it, his name and stars below
const STAR_X := 5.0
const STAR_Y := 48.0       # the top of the star bar
const XP_Y := 59.0         # the XP bar, 2 px
const TOP_BG := Color("0b1d5c")   # (Deck.NAVY)
const INFO_BG := Color("101c38")
const GK_TOP := Color("6e2230")
const GK_INFO := Color("341725")
const SUB_TOP := Color("27335a")
const SUB_INFO := Color("202b48")
const DIVIDER := Color("cca832")  # (UI.GOLD darkened)
const INJURY := Color("f23b45")
const CROSS := ["..#..", "..#..", "#####", "..#..", "..#.."]
const SUB_EDGE := Color("ffffff")
const SLOT_BG := Color("081751")    # an open spot
const DEV_W := 26
const IN_TIME := 0.15      # a card coming in
const IN_STAGGER := 0.03
const IN_RISE := 4.0
const PICK_TIME := 0.16    # a tapped card's flash and pulse before his page opens
const DRAG_PX := 7.0       # how far a press moves before it's a drag, not a tap
const LIFT := 2.0          # a dragged card rides this far above the pointer's hold
const SWAP_TIME := 0.18    # cards sliding into their new places (or back)
const BAD_TIME := 0.3      # a refused drop: the card's border flashes red
## After the roster's shape (CollegeGen.ROSTER_POS), anyone left goes in this order.
const POS_ORDER := [PoloPlayer.Pos.GK, PoloPlayer.Pos.CENTER, PoloPlayer.Pos.DEFENDER,
	PoloPlayer.Pos.DRIVER, PoloPlayer.Pos.UTILITY, PoloPlayer.Pos.WING]
const PLUS := ["..#..", "..#..", "#####", "..#..", "..#.."]

## The places, as the screen shows them: the 3-3, the keeper, the bench. Each one's place
## [column, row] (row 0 on the 2 m line, 1 the perimeter, 2 the keeper; column 3 the bench) and its
## name. PoloTeam.LINEUP_SPOTS has the lineup's order, PoloTeam.SLOTS who may play each.
const SPOTS := ["lw", "cf", "rw", "lf", "pt", "rf", "gk"]
const SPOT_AT := {"lw": [0, 0], "cf": [1, 0], "rw": [2, 0], "lf": [0, 1], "pt": [1, 1], "rf": [2, 1], "gk": [1, 2],
	"s1": [3, 0], "s2": [3, 1], "s3": [3, 2]}
const SPOT_NAMES := {"lw": "LEFT WING", "cf": "CENTER FORWARD", "rw": "RIGHT WING", "lf": "LEFT FLAT",
	"pt": "POINT", "rf": "RIGHT FLAT", "gk": "GOALKEEPER", "s1": "SUB", "s2": "SUB", "s3": "SUB"}

var fxs := {}            # pid -> his card's StarFx
var cards := {}          # pid -> his card
var slots: Array = []    # lineup place -> what stands there (his card, or an empty place)
var board: Control       # the cards' table: what's drawn under them while one is dragged
var dev_on := false      # Developer Mode: card taps pick a player to test
var dev_pick := -1
var dev_forms := {}      # pid -> the test form his card shows (never saved)
var bottom: CenterContainer
var picked := -1         # the card flashing on its way to his page
var pick_t := 0.0
var press_pid := -1      # a card under a press, maybe about to be dragged
var press_at := Vector2.ZERO
var drag_pid := -1       # the card being dragged...
var drag_from := -1      # ...from this lineup place...
var grab := Vector2.ZERO # ...held here
var hover := -1          # the place under the dragged card
var dragged := false     # the press became a drag: its release opens nobody's page
var busy := false        # cards sliding: no new drag till they're in
var bad_pid := -1        # a refused drop's card, its border flashing red
var bad_t := 0.0
var scout_team: PoloTeam = null   # scouting: the team on show (read only), null: yours
var scout_lineup: Array = []      # ...its lineup as it stands, read (never written)

## The team on show: an opponent's while scouting (scouted), else yours.
func team() -> PoloTeam:
	return scout_team if scout_team != null else c.team()

## Scouting's team (scout.gd overrides it); null: your roster.
func scouted() -> PoloTeam:
	return null

## The lineup on show: your saved one, or the scouted team's as it stands (its own if it has one,
## else the seven its starters() make, as set_lineup would draw it, but not written anywhere).
func lineup() -> Array:
	return scout_lineup if scout_team != null else team().lineup

func _init() -> void:
	detail = true   # (its team logos: TeamLogo's fine pixels)

func _ready() -> void:
	scout_team = scouted()
	if scout_team != null:
		back_target = "coaching"
		build_compact("SCOUT OPPONENT")
		scout_lineup = scout_team.lineup.duplicate() if scout_team.has_lineup() else _drafted(scout_team)
		_render()
		return
	back_target = "hub"
	build_compact("ROSTER")
	if bool(Game.settings.get("dev_mode", false)):
		# small and quiet, but a full-height target
		var dev := flat_button("DEV", _dev_toggle, Deck.NAVY, Deck.EDGE, UI.DIM2, 20)
		dev.name = "Dev"
		dev.custom_minimum_size.x = DEV_W
		dev.tooltip_text = "Developer Mode: test form on a card"
		header_right.add_child(dev)
		header_right.move_child(dev, 0)
	set_lineup(c.team())
	_render()
	hot_tip()

const HOT_TIP_TITLE := "PLAYERS CAN HEAT UP!"
const HOT_TIP := "Great performances build momentum and can earn a player up to two red Hot stars.\n\nHot stars boost him for a while, but momentum fades.\n\nTap his portrait card on his page to flip it and see how close he is to heating up!"

## The HOT form tip, once a career (Career.hot_tip, saved): the first time the roster opens with one
## of yours heating up (a run above 0) or HOT. Returns whether it showed.
func hot_tip() -> bool:
	if c.hot_tip or not c.team().roster.any(func(q: PoloPlayer): return q.heat > 0 or PlayerForm.run_score(q.form) > 0):
		return false
	c.hot_tip = true
	Game.save_career()
	Game.dialog(HOT_TIP_TITLE, HOT_TIP, [["GOT IT", Callable(), "primary"]])
	return true

## The team's lineup, in step with its roster: the first time (an older save, a new career) set
## from formation(), the seven as they already stood. Saved when it changes.
static func set_lineup(t: PoloTeam) -> void:
	var was := t.lineup.duplicate()
	if not t.has_lineup():
		var f := formation(t)
		for k in PoloTeam.LINEUP_SPOTS:
			var p: PoloPlayer = f.spots.get(k)
			t.lineup.append(p.id if p != null else -1)
		for i in range(PoloTeam.STARTERS, PoloTeam.LINEUP_SPOTS.size()):
			var j := i - PoloTeam.STARTERS
			t.lineup[i] = (f.bench[j] as PoloPlayer).id if j < f.bench.size() else -1
	t.sync_lineup()
	if t.lineup != was and Game.career != null:
		Game.save_career()

## A lineup drawn from the team's own seven and bench (formation), as set_lineup would, kept here.
static func _drafted(t: PoloTeam) -> Array:
	var f := formation(t)
	var out: Array = []
	for k in PoloTeam.LINEUP_SPOTS:
		var p: PoloPlayer = f.spots.get(k)
		out.append(p.id if p != null else -1)
	for i in range(PoloTeam.STARTERS, PoloTeam.LINEUP_SPOTS.size()):
		var j := i - PoloTeam.STARTERS
		out[i] = (f.bench[j] as PoloPlayer).id if j < f.bench.size() else -1
	return out

## Who stands at lineup place `i` (null: nobody).
func at(i: int) -> PoloPlayer:
	var lu := lineup()
	return team().find_id(int(lu[i])) if i >= 0 and i < lu.size() else null

## Is `p` on the bench?
func on_bench(p: PoloPlayer) -> bool:
	return lineup().find(p.id) >= PoloTeam.STARTERS

## Everyone's page in lineup order, anyone past the ten after them.
func page_ids() -> Array:
	var t := team()
	var ids: Array = lineup().filter(func(pid): return t.find_id(int(pid)) != null)
	for p: PoloPlayer in ordered(t.roster):
		if not ids.has(p.id):
			ids.append(p.id)
	return ids

## `enter`: the cards come in one after another (not after a swap).
func _render(enter: bool = true) -> void:
	for ch in body.get_children():
		ch.queue_free()
	var t := team()
	var ids := page_ids()
	fxs.clear()
	cards.clear()
	slots.clear()
	board = UI.canvas(int(board_size().x), int(board_size().y), _paint_board)
	board.name = "Board"
	var order: Array = SPOTS + ["s1", "s2", "s3"]
	slots.resize(PoloTeam.LINEUP_SPOTS.size())
	for n in order.size():
		var k: String = order[n]
		var i := PoloTeam.LINEUP_SPOTS.find(k)
		var p := at(i)
		var cell: Control
		if p != null:
			cell = _player_card(p, ids)
			cell.tooltip_text = ("%s (%s): %s" % [SPOT_NAMES[k], t.slot_name(i), p.short_name()]) if i < PoloTeam.STARTERS else "%s: %s" % [SPOT_NAMES[k], p.short_name()]
			cell.name = ("Spot_" + k) if i < PoloTeam.STARTERS else "Bench_%d" % p.id
		elif i < PoloTeam.STARTERS:
			cell = Deck.card(CARD, func(ci, _r, mode): _paint_open(ci, mode), func():
				if scout_team == null:
					Game.goto("recruiting"))
			cell.tooltip_text = "%s: an open place, fill it in recruiting" % SPOT_NAMES[k]
			cell.name = "Spot_" + k
		else:
			cell = UI.canvas(int(CARD.x), int(CARD.y), _paint_empty)
			cell.name = "Empty_" + k
		cell.position = spot_pos(k)
		cell.size = CARD
		board.add_child(cell)
		slots[i] = cell
		if enter:
			_enter(cell, n)
	if scout_team != null:
		_scout_head(board, t)
	# centred in the page; the seven and the bench all fit, so no scrolling
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(board)
	body.add_child(center)
	bottom = CenterContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(bottom)
	_render_bottom()

func _player_card(p: PoloPlayer, ids: Array) -> Button:
	var pid := p.id
	var fx := StarFx.new()
	var card := Deck.card(CARD, func(ci, _r, mode): _paint_card(ci, mode, p, fx), func():
		if dragged:
			dragged = false
		elif dev_on:
			_dev_select(pid)
		else:
			_open(pid, ids))
	card.add_child(fx)
	fx.watch(StarFx.key_of(p), p.form_state(), String(p.last_game.get("was", "")))
	card.gui_input.connect(_card_input.bind(pid))
	fxs[pid] = fx
	cards[pid] = card
	return card

## Scouting: the team, in the two places either side of his keeper (empty in every lineup): left,
## his logo, name, record, rating and where the game is; right, his SCOUTING REPORT (OFFENSE and
## DEFENSE stars). Navy, a white
## border, cyan labels, the numbers gold. Real data: Career's record, PoloTeam's rating, the
## schedule's game.
func _scout_head(on: Control, t: PoloTeam) -> void:
	var g := c.next_game()
	var y := LABEL_H + 2.0 * (CARD.y + ROW_GAP)
	var where := "HOME" if bool(g.get("home", false)) else "AWAY"
	var team_box := UI.canvas(int(CARD.x), int(CARD.y), func(ci: Control):
		_head_panel(ci)
		TeamLogo.paint(ci, Vector2(4, 4), t, TeamLogo.MEDIUM, 1)
		var words := Colleges.display_name(t.name).to_upper().split(" ")
		var first := " ".join(words.slice(0, maxi(1, words.size() - 1)))
		var last := words[words.size() - 1] if words.size() > 1 else ""
		Deck.text(ci, 36, 9, Deck.fit(first, CARD.x - 40), 8, UI.TEXT)
		Deck.text(ci, 36, 18, Deck.fit(last, CARD.x - 40), 8, UI.TEXT)
		_head_kv(ci, 31, "RECORD", c.record_text(t.id))
		_head_kv(ci, 41, "RATING", str(t.overall_display()))
		_head_kv(ci, 51, "GAME", where))
	team_box.name = "ScoutTeam"
	team_box.position = Vector2(0, y)
	team_box.set_meta("text", "%s RECORD %s RATING %d %s" % [t.name.to_upper(), c.record_text(t.id), t.overall_display(), where])
	on.add_child(team_box)
	# right: the SCOUTING REPORT (the HOME POOL box until the Hot Star & Scouting update): his
	# OFFENSE and DEFENSE overalls as five-place star bars, half stars and all. The real numbers
	# (PoloTeam.offense_display / defense_display, from his seven's permanent attributes) through
	# the one conversion every screen uses (PoloTeam.rating_stars), never a number of their own.
	var off := PoloTeam.rating_stars(t.offense_display())
	var dfn := PoloTeam.rating_stars(t.defense_display())
	var report := UI.canvas(int(CARD.x), int(CARD.y), func(ci: Control): paint_report(ci, off, dfn))
	report.name = "ScoutReport"
	report.position = Vector2(2.0 * (CARD.x + GAP), y)
	report.set_meta("text", "SCOUTING REPORT OFFENSE %s DEFENSE %s" % [PlayerForm.star_text(off), PlayerForm.star_text(dfn)])
	report.set_meta("off", off)
	report.set_meta("def", dfn)
	on.add_child(report)

## The SCOUTING REPORT panel (CARD-sized): navy, white border, a title, then OFFENSE and DEFENSE
## in cyan, each over its gold five-place star bar, the two bars lined up under each other.
static func paint_report(ci: CanvasItem, off: float, dfn: float) -> void:
	_head_panel(ci)
	Deck.ctext(ci, Rect2(0, 3, CARD.x, 10), "SCOUTING REPORT", 8, UI.TEXT)
	ci.draw_rect(Rect2(5, 14, CARD.x - 10, 1), UI.BORDER)
	var w := Deck.star_x(Deck.STAR_PLACES - 1) + float(Deck.STAR_SHAPE.w)   # (a team row: always five places)
	var bx := roundf((CARD.x - w) / 2.0)
	for i in 2:
		var top := 18.0 + i * 23.0
		Deck.text(ci, bx, top + 4, "OFFENSE" if i == 0 else "DEFENSE", 8, UI.ACCENT)
		Deck.star_bar(ci, bx, top + 10, off if i == 0 else dfn, float(Deck.STAR_PLACES))

static func _head_panel(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, CARD), Deck.NAVY)
	_outline(ci, Rect2(Vector2.ZERO, CARD), 1.0, UI.BORDER)

static func _head_kv(ci: CanvasItem, y: float, k: String, v: String) -> void:
	Deck.text(ci, 5, y, k, 8, UI.ACCENT)
	Deck.rtext(ci, CARD.x - 5, y, v, 8, UI.GOLD)

## `text` in lines no wider than `w` (whole words).
static func _wrap(text: String, w: float) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if Deck.text_w(next) <= w or line == "":
			line = next
		else:
			out.append(line)
			line = word
	if line != "":
		out.append(line)
	return out

## The cards' table: three across, the goal-side row, the perimeter, the keeper, then the bench a
## then the bench column a little apart to their right, SUBS over it.
static func board_size() -> Vector2:
	return Vector2(CARD.x * 4.0 + GAP * 2.0 + BENCH_GAP, LABEL_H + CARD.y * 3.0 + ROW_GAP * 2.0)

## Where a place's card stands on the table, its top left.
static func spot_pos(k: String) -> Vector2:
	var a: Array = SPOT_AT[k]
	var col := int(a[0])
	var x := col * (CARD.x + GAP) if col < 3 else 3.0 * CARD.x + GAP * 2.0 + BENCH_GAP
	return Vector2(x, LABEL_H + int(a[1]) * (CARD.y + ROW_GAP))

## Lineup place `i`'s card rect on the table.
static func slot_rect(i: int) -> Rect2:
	return Rect2(spot_pos(PoloTeam.LINEUP_SPOTS[i]), CARD)

## Who plays where: {spots: {spot: player}, bench: [players]}. The starting seven are the team's
## own (PoloTeam.starters: position-aware, already in LINEUP_SPOTS order, a lefty on the right
## side). Spots nobody fills are left out; everyone else on the roster is on the bench. (A
## lineup's first draft: set_lineup.)
static func formation(t: PoloTeam) -> Dictionary:
	var seven := t.starters()
	var spots := {}
	if seven.size() == PoloTeam.STARTERS:
		for i in PoloTeam.STARTERS:
			spots[PoloTeam.LINEUP_SPOTS[i]] = seven[i]
	elif not seven.is_empty():
		spots["gk"] = seven[0]
		for i in range(1, seven.size()):
			spots[PoloTeam.LINEUP_SPOTS[i]] = seven[i]
	var bench: Array = ordered(t.roster.filter(func(p): return not seven.has(p)))
	return {"spots": spots, "bench": bench}

## Under the cards: SUBS beside the bench (and how many more there are past the ten), and while a
## card is dragged, its own place as a dashed slot, every place it may go outlined in cyan, the
## one under it in gold (red when it can't go there).
func _paint_board(ci: Control) -> void:
	var bx := spot_pos("s1").x
	Deck.ctext(ci, Rect2(bx, 0, CARD.x, LABEL_H - 3.0), "SUBS", 8, UI.DIM)
	# each starting place's name over its card (a lefty's places in gold)
	for i in PoloTeam.STARTERS:
		var at_ := spot_pos(PoloTeam.LINEUP_SPOTS[i])
		var nm := team().slot_name(i)
		Deck.ctext(ci, Rect2(at_.x, at_.y - LABEL_H, CARD.x, LABEL_H - 3.0), nm, 8, UI.GOLD if nm.contains("LFTY") else UI.DIM)
	var extra := team().roster.size() - lineup().filter(func(pid): return team().find_id(int(pid)) != null).size()
	if extra > 0:
		Deck.rtext(ci, bx + CARD.x, floorf((LABEL_H - 3.0) * 0.5), "+%d" % extra, 8, UI.DIM2)
	if drag_pid == -1:
		return
	var from := slot_rect(drag_from)
	ci.draw_rect(from, Color(0, 0, 0, 0.18))
	_dashes(ci, from, Color(1, 1, 1, 0.6))
	for i in PoloTeam.LINEUP_SPOTS.size():
		if i != drag_from and i != hover and can_swap(drag_from, i):
			_outline(ci, slot_rect(i).grow(1.0), 1.0, Color(UI.ACCENT, 0.7))
	var under := slot_at(_board_point(get_global_mouse_position()))
	if hover >= 0:
		_outline(ci, slot_rect(hover).grow(2.0), 2.0, UI.GOLD)
	elif under >= 0 and under != drag_from:
		_outline(ci, slot_rect(under).grow(1.0), 1.0, Color(UI.BAD, 0.8))

static func _outline(ci: CanvasItem, r: Rect2, w: float, col: Color) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	ci.draw_rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), col)
	ci.draw_rect(Rect2(r.position.x, r.position.y + w, w, r.size.y - w * 2.0), col)
	ci.draw_rect(Rect2(r.end.x - w, r.position.y + w, w, r.size.y - w * 2.0), col)

## A card coming in: it fades in as its picture rises a few pixels into place (the picture, not
## the card: the card stays on its spot).
func _enter(card: Control, i: int) -> void:
	if not Juice.enabled() or card.get_child_count() == 0:
		return
	var cv: Control = card.get_child(0)
	var delay := i * IN_STAGGER
	card.modulate.a = 0.0
	cv.position.y = IN_RISE
	var tw := card.create_tween().set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, IN_TIME).set_delay(delay)
	tw.tween_property(cv, "position:y", 0.0, IN_TIME).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## His page, after his card flashes gold and pulses (straight there with reduce motion on).
func _open(pid: int, ids: Array) -> void:
	if picked != -1:
		return
	var go := {"id": pid, "list": ids}
	if scout_team != null:
		go["view"] = true    # (another program's player: read only...)
		go["scout"] = true   # (...and nothing of his potential: player.gd's scouting mode)
	if not Juice.enabled():
		Game.goto("player", go)
		return
	picked = pid
	var card: Button = cards[pid]
	var tw := create_tween()
	tw.tween_method(func(v: float):
		pick_t = v
		card.queue_redraw(), 0.0, PICK_TIME, PICK_TIME)
	tw.tween_callback(func(): Game.goto("player", go))

# ------------------------------------------------------------------ dragging cards
## A press on a card, then the pointer moving with it held (a mouse, or a finger: Godot sends a
## finger as the mouse too), then its release. Past DRAG_PX it's a drag, not a tap.
func _card_input(ev: InputEvent, pid: int) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			press_pid = pid
			press_at = ev.global_position
			dragged = false
		elif press_pid == pid:
			press_pid = -1
			if drag_pid == pid:
				var card: Button = cards[pid]
				drop(ev.global_position)
				# the release is the drag's: the button doesn't take it as a tap
				if is_instance_valid(card) and card.is_inside_tree():
					card.accept_event()
	elif ev is InputEventMouseMotion and press_pid == pid and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if drag_pid == -1 and ev.global_position.distance_to(press_at) > DRAG_PX:
			lift(pid, press_at)
		if drag_pid == pid:
			follow(ev.global_position)

## Picks up `pid`'s card, held at `gp` (global): it rises over the others, its border lit.
## Returns whether it could (not while cards slide, a page opens, or a test form is picked).
func lift(pid: int, gp: Vector2) -> bool:
	if busy or picked != -1 or dev_on or scout_team != null or not cards.has(pid):
		return false
	var card: Button = cards[pid]
	drag_pid = pid
	drag_from = c.team().lineup.find(pid)
	dragged = true
	grab = gp - card.global_position
	card.z_index = 10
	follow(gp)
	return true

## The dragged card follows the pointer; the place under it lights up if he can go there.
func follow(gp: Vector2) -> void:
	if drag_pid == -1:
		return
	var card: Button = cards[drag_pid]
	card.global_position = (gp - grab - Vector2(0, LIFT)).round()
	var under := slot_at(_board_point(gp))
	hover = under if can_swap(drag_from, under) else -1
	card.queue_redraw()
	board.queue_redraw()

## Lets go at `gp`: over a place he can go, the two swap (the lineup saved, the cards sliding
## into their places); anywhere else he slides back, his border flashing red if it was a place he
## can't take. Returns whether they swapped.
func drop(gp: Vector2) -> bool:
	if drag_pid == -1:
		return false
	var pid := drag_pid
	var from := drag_from
	var to := slot_at(_board_point(gp))
	drag_pid = -1
	hover = -1
	board.queue_redraw()
	if not can_swap(from, to):
		_slide({pid: slot_rect(from).position}, func(): cards[pid].z_index = 0)
		if to >= 0 and to != from:
			_refused(pid)
		return false
	var t := c.team()
	var other: Control = slots[to]
	var sw: int = t.lineup[to]
	t.lineup[to] = t.lineup[from]
	t.lineup[from] = sw
	Game.save_career()
	Sfx.play("click")
	_slide({pid: slot_rect(to).position, other: slot_rect(from).position}, func(): _render(false))
	return true

## Can the man at place `a` go to place `b`, and whoever's there to `a`? Only where the
## position rules let him (PoloTeam.fits: only a keeper in goal, the posts' men at C and 2MD,
## a lefty only on the right side); a starting place is never left empty
## for an empty bench place. Nobody can be dragged from an empty place.
func can_swap(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a == b:
		return false
	var pa := at(a)
	var pb := at(b)
	# PROVE ME WRONG: the backup you promised the start stays in his place until that game
	var lock := CoachEvents.locked(c) if c != null and scout_team == null else -1
	if lock >= 0 and ((pa != null and pa.id == lock) or (pb != null and pb.id == lock)):
		return false
	if pa == null or not PoloTeam.fits(pa, b):
		return false
	if pb != null:
		return PoloTeam.fits(pb, a)
	return not (a < PoloTeam.STARTERS and b >= PoloTeam.STARTERS)

## The lineup place under `pt` (on the table), or -1. Each card's catch area reaches halfway into
## the gaps round it.
static func slot_at(pt: Vector2) -> int:
	for i in PoloTeam.LINEUP_SPOTS.size():
		if slot_rect(i).grow(GAP * 0.5).has_point(pt):
			return i
	return -1

func _board_point(gp: Vector2) -> Vector2:
	return board.get_global_transform().affine_inverse() * gp

## Slides each card (or pid) to its place on the table ({card or pid: position}) in SWAP_TIME,
## then `done`; at once with reduce motion on.
func _slide(to: Dictionary, done: Callable) -> void:
	busy = true
	var finish := func():
		busy = false
		done.call()
	var moves := {}
	for k in to:
		var node: Control = cards[k] if k is int else k
		moves[node] = to[k]
	if not Juice.enabled():
		for node: Control in moves:
			node.position = moves[node]
		finish.call()
		return
	var tw := create_tween().set_parallel(true)
	for node: Control in moves:
		tw.tween_property(node, "position", moves[node], SWAP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(finish)

## A refused drop: his border flashes red twice.
func _refused(pid: int) -> void:
	bad_pid = pid
	if not Juice.enabled():
		bad_pid = -1
		return
	var card: Button = cards[pid]
	var tw := create_tween()
	tw.tween_method(func(v: float):
		bad_t = v
		if is_instance_valid(card):
			card.queue_redraw(), 0.0, BAD_TIME, BAD_TIME)
	tw.tween_callback(func():
		bad_pid = -1
		if is_instance_valid(card):
			card.queue_redraw())

## DEV's test panel, testing form in Developer Mode (nothing otherwise).
func _render_bottom() -> void:
	for ch in bottom.get_children():
		ch.queue_free()
	if not dev_on:
		return
	var bh := UI.hbox(GAP)
	var pl := _picked()
	var l := Deck.label(Deck.fit(pl.short_name(), 84) if pl != null else "TAP A PLAYER", 8, UI.GOLD if pl != null else UI.DIM)
	l.custom_minimum_size = Vector2(86, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bh.add_child(l)
	for b in [["HEAT UP", 1], ["COOL DOWN", -1], ["RESET", 0]]:
		var by: int = b[1]
		var btn := Deck.button(b[0], func(): _dev_form(by), "normal", 70, 22)
		btn.disabled = pl == null
		bh.add_child(btn)
	bh.add_child(Deck.button("DONE", _dev_toggle, "primary", 50, 22))
	bottom.add_child(bh)

# ------------------------------------------------------------------ Developer Mode
func _picked() -> PoloPlayer:
	for p: PoloPlayer in c.team().roster:
		if p.id == dev_pick:
			return p
	return null

## The form his card shows: the test one, else his own.
func shown_form(p: PoloPlayer) -> String:
	return String(dev_forms.get(p.id, p.form_state()))

## DEV on: taps pick a card. DONE: every test form goes back to the real one, animated.
func _dev_toggle() -> void:
	dev_on = not dev_on
	if not dev_on:
		for p: PoloPlayer in c.team().roster:
			if dev_forms.has(p.id) and fxs.has(p.id):
				fxs[p.id].play(String(dev_forms[p.id]), p.form_state(), true)
		dev_forms.clear()
		dev_pick = -1
	_render_bottom()
	_redraw_cards()

func _dev_select(pid: int) -> void:
	dev_pick = pid
	_render_bottom()
	_redraw_cards()

## +1 a step hotter, -1 cooler, 0 back to NORMAL; on the picked card only.
func _dev_form(by: int) -> void:
	var p := _picked()
	if p == null:
		return
	var was := shown_form(p)
	var now := PlayerForm.NORMAL if by == 0 else StarFx.step(was, by)
	if now == was:
		Game.toast("Already %s" % PlayerForm.FORM_NAMES[now], UI.DIM)
		return
	dev_forms[p.id] = now
	fxs[p.id].play(was, now, true)
	_redraw_cards()

func _redraw_cards() -> void:
	for pid in cards:
		cards[pid].queue_redraw()

## The roster in position order (the bench): keeper, center, center-D, two drivers, two utilities (best first
## at each), then the rest by position and overall.
static func ordered(roster: Array) -> Array:
	var left: Array = roster.duplicate()
	left.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.overall() > b.overall())
	var out: Array = []
	for pos in CollegeGen.ROSTER_POS:
		for p: PoloPlayer in left:
			if p.pos == pos:
				out.append(p)
				left.erase(p)
				break
	left.sort_custom(func(a: PoloPlayer, b: PoloPlayer):
		var ia := POS_ORDER.find(a.pos)
		var ib := POS_ORDER.find(b.pos)
		return ia < ib if ia != ib else a.overall() > b.overall())
	out.append_array(left)
	return out

# ------------------------------------------------------------------ the cards
func _paint_card(ci: CanvasItem, mode: String, p: PoloPlayer, fx: StarFx) -> void:
	var w := CARD.x
	var bench := on_bench(p)
	var edge := UI.GOLD if mode != "normal" else UI.TEXT
	if dev_on and p.id == dev_pick:
		edge = UI.ACCENT
	if p.id == drag_pid:
		# lifted: a shadow under it, its border lit and a pixel bigger all round
		ci.draw_rect(Rect2(2, LIFT + 2.0, w, CARD.y), Color(0, 0, 0, 0.35))
		Deck.frame(ci, Rect2(-1, -1, w + 2, CARD.y + 2), Color(0, 0, 0, 0), UI.GOLD)
		edge = UI.TEXT
	if p.id == bad_pid and int(bad_t / (BAD_TIME / 4.0)) % 2 == 0:
		edge = UI.BAD
	if p.id == picked:
		# tapped: the border flashes gold and pulses out a pixel, twice
		var on := int(pick_t / (PICK_TIME / 4.0)) % 2 == 0
		edge = UI.GOLD if on else UI.TEXT
		if on:
			Deck.frame(ci, Rect2(-1, -1, w + 2, CARD.y + 2), Color(0, 0, 0, 0), UI.GOLD)
	paint_card(ci, p, team(), fx, shown_form(p), edge, bench, false, true, scout_team != null)

## A player's card on its own (the postgame HOT star reveal draws it too): `state` the form his
## stars show, `edge` the border colour, `bench` muted navy for a substitute (else the keeper's is
## red), top left at the origin, CARD in size. Flat colours only: a solid portrait panel over a
## solid info panel, one divider, one 1 px border. Unspent upgrades never show here (the
## mandatory upgrade pages take care of them); an injury is a small red cross by his class year.
## `recruit`: a high-school prospect's card on the Recruiting screen, the same card with what
## doesn't apply to him left off (cap number, injury, XP bar, form). `current`: the Roster
## screen's card, only his current stars (no hollow POTENTIAL, no MAX). `scouting`: another
## program's player (Scout Opponent): no XP bar either.
static func paint_card(ci: CanvasItem, p: PoloPlayer, team: PoloTeam, fx: StarFx, state: String, edge: Color, bench: bool = false,
		recruit: bool = false, current: bool = false, scouting: bool = false) -> void:
	var w := CARD.x
	var h := CARD.y
	var gk := p.is_keeper() and not bench
	var top := SUB_TOP if bench else GK_TOP if gk else TOP_BG
	var info := SUB_INFO if bench else GK_INFO if gk else INFO_BG
	ci.draw_rect(Rect2(1, 1, w - 2, SPLIT - 1), top)
	# his headshot (Portrait: front on, in your cap, keepers in red), zoomed in (CARD_ZOOM): his
	# cap at the panel's top, the last of his shoulders under the divider
	Portrait.draw_zoomed(ci, Vector2(floorf(w * 0.5), 2), p, team, Portrait.CARD_ZOOM)
	Deck.text(ci, 5, 7, Deck.pos_tag(p), 8, UI.TEXT)
	if p.number > 0 and not recruit:
		Deck.rtext(ci, w - 5, 7, "#%d" % p.number, 8, UI.TEXT)
	# HOT / VERY HOT, low on the left of the portrait (his red stars say it too)
	if state != PlayerForm.NORMAL:
		var words := String(PlayerForm.FORM_NAMES[state]).split(" ")
		for i in words.size():
			Deck.text(ci, 5, SPLIT - 5.0 - (words.size() - 1 - i) * 8.0, words[i], 8, PlayerForm.form_color(state))
	# SUSPENDED (a coaching decision): a red band low on the portrait, with the games left
	if p.is_suspended() and not recruit and not scouting:
		ci.draw_rect(Rect2(1, SPLIT - 19, w - 2, 18), Color(0.55, 0.04, 0.08, 0.92))
		Deck.ctext(ci, Rect2(0, SPLIT - 19, w, 9), "SUSPENDED", 8, Color("ff5a5a"))
		Deck.ctext(ci, Rect2(0, SPLIT - 11, w, 9), "%d GAME%s" % [p.susp, "" if p.susp == 1 else "S"], 8, UI.TEXT)
	# PROVE ME WRONG: the backup promised the start, gold, until that game is played
	elif not recruit and not scouting and Game.career != null and CoachEvents.locked(Game.career) == p.id:
		ci.draw_rect(Rect2(1, SPLIT - 19, w - 2, 18), Color(0.35, 0.27, 0.0, 0.92))
		Deck.ctext(ci, Rect2(0, SPLIT - 19, w, 9), "PROVE ME WRONG", 8, UI.GOLD)
		Deck.ctext(ci, Rect2(0, SPLIT - 11, w, 9), "STARTING", 8, UI.TEXT)
	ci.draw_rect(Rect2(1, SPLIT, w - 2, h - SPLIT - 1), info)
	ci.draw_rect(Rect2(1, SPLIT, w - 2, 1), DIVIDER)
	# his surname, his class year beside it (quieter), a red cross before it while he's hurt
	var yr := p.year_text()
	var hurt := 8.0 if p.is_injured() and not recruit else 0.0
	var room := w - 15.0 - Deck.text_w(yr) - hurt
	var name_size := 8 if Deck.text_w(p.short_name()) <= room else 7
	var name := Deck.fit(p.short_name(), room, name_size)
	Deck.text(ci, 5, SPLIT + 5.0, name, name_size, UI.TEXT)
	var yr_x := w - 6.0 - Deck.text_w(yr)
	Deck.text(ci, yr_x, SPLIT + 5.0, yr, 8, Color("9edcff"))
	if hurt > 0.0:
		Deck.pat(ci, Vector2(yr_x - hurt, SPLIT + 3.0), CROSS, {"#": INJURY})
	# his stars; MAX beside them when he's fully developed (no XP bar: nothing left to fill).
	# `current`: his current stars alone, and nothing at all once he's maxed
	var line := star_line(p, state)
	fx.bare = current
	fx.draw(ci, STAR_X, STAR_Y, line.cur, line.cur if current else line.pot, line.state, Color("596170"), Deck.STAR_SHAPE)
	if recruit or scouting:
		pass   # (no XP: he isn't playing for you yet; or he's another program's, and its bar going would say he's maxed)
	elif Development.is_maxed(p):
		if not current:
			Deck.rtext(ci, w - 6, STAR_Y + 4.0, "MAX", 8, UI.GOLD)
	else:
		Deck.xp_bar(ci, Rect2(5, XP_Y, w - 10, 2), xp_fill(p))
	# the border last, so no sprite pixel breaks its edge
	_outline(ci, Rect2(Vector2.ZERO, CARD), 1.0, edge)

## Tokens already earned keep the card full; otherwise use the existing XP threshold.
static func xp_fill(p: PoloPlayer) -> float:
	return 1.0 if p.tokens > 0 else Development.progress(p)

## An open place in the seven: dark navy, a dashed border, a plus and OPEN SPOT. Nobody's card.
func _paint_open(ci: CanvasItem, mode: String) -> void:
	var w := CARD.x
	var h := CARD.y
	var col := UI.GOLD if mode != "normal" else Deck.EDGE
	ci.draw_rect(Rect2(1, 1, w - 2, h - 2), SLOT_BG)
	_dashes(ci, Rect2(0, 0, w, h), col)
	Deck.pat(ci, Vector2(floorf(w * 0.5) - 2.0, 17), PLUS, {"#": col})
	Deck.ctext(ci, Rect2(0, 30, w, 10), "OPEN SPOT", 8, UI.DIM if mode == "normal" else UI.GOLD)

## An empty bench place: a grey card, a muted dashed border, EMPTY.
func _paint_empty(ci: Control) -> void:
	ci.draw_rect(Rect2(1, 1, CARD.x - 2, CARD.y - 2), Color(SUB_INFO, 0.75))
	_dashes(ci, Rect2(Vector2.ZERO, CARD), Color(SUB_EDGE, 0.6))
	Deck.ctext(ci, Rect2(0, floorf(CARD.y * 0.5) - 5.0, CARD.x, 10), "EMPTY", 8, Color(SUB_EDGE, 0.8))

## A thin dashed border: 3 px on, 2 off, round the edge of `r`.
static func _dashes(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var x := 2.0
	while x < r.size.x - 2.0:
		var dw := minf(3.0, r.size.x - 2.0 - x)
		ci.draw_rect(Rect2(r.position.x + x, r.position.y, dw, 1), col)
		ci.draw_rect(Rect2(r.position.x + x, r.end.y - 1, dw, 1), col)
		x += 5.0
	var y := 2.0
	while y < r.size.y - 2.0:
		var dh := minf(3.0, r.size.y - 2.0 - y)
		ci.draw_rect(Rect2(r.position.x, r.position.y + y, 1, dh), col)
		ci.draw_rect(Rect2(r.end.x - 1, r.position.y + y, 1, dh), col)
		y += 5.0

## The card's star bar: {cur, pot, eff, state, color, word}. The form's colour
## (PlayerForm.form_color) and its name when it isn't NORMAL. `state`: a form to show instead
## of his own (Developer Mode).
static func star_line(p: PoloPlayer, state: String = "") -> Dictionary:
	if state == "":
		state = p.form_state()
	return {"cur": p.stars, "pot": p.pot_stars, "eff": PlayerForm.effective(p.stars, state), "state": state,
		"color": PlayerForm.form_color(state),
		"word": String(PlayerForm.FORM_NAMES[state]) if state != PlayerForm.NORMAL else ""}
