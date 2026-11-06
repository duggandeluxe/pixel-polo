class_name PlayoffBracket
## The PLAYOFFS tab's bracket (Conference screen): a conference tournament, or the NCSA
## Championship, as a real bracket, rounds left to right, each game a navy card connected to the
## game its winner goes on to, the champion's card at the end of the road.
##
## Only a picture of what the schedule already holds: nothing here draws, seeds or plays a game.
## model() rebuilds the bracket the way Schedule.fill_playoff made it: the seeds it saved
## (season.conf_seeds / nat_seeds), placed by Schedule.bracket_order (an empty place a bye), and
## each round's slots the last round's winners (Schedule._advance), read from the games actually
## played. So an upset goes the way it really went, and a game not played yet shows no score and
## whoever's feeding it ("WINNER OF QF1"). Before a conference tournament is drawn the bracket is
## the one the standings would make today (Schedule.conf_table, the same seeding), marked
## PROJECTED, with no games in it.
##
## DETAIL MODE (the Bracket Polish update; Game.set_detail, the Conference screen's PLAYOFFS tab):
## the bracket is drawn at FINE scale, two-thirds of a game pixel a unit (two screen pixels at
## the usual 3x), so its pixel type and logos stay exactly sharp with half again the room: every
## school's full name fits, the NCSA's four rounds too. All the sizes below are in those units
## (scale(): 1 when detail mode is off, the bracket as large as ever). A bracket taller than the
## room scrolls.

const FINE := 2.0 / 3.0       # game pixels a unit in detail mode
const ROW_H := 20             # a team's row: the 28 x 20 logo (TeamLogo.MEDIUM at 1x)
const CARD_H := 46            # two rows, a rule between
const ROW_COMPACT := 16       # a bracket too tall for the room at full size:
const CARD_COMPACT := 38      # ...16-unit rows, the small mark for a logo
const ROOM_H := 285.0         # the room the PLAYOFFS tab has for its bracket (190 game pixels)
const BYE_H := 20             # a bye: one slim row, no card (no game)
const TIGHT := Vector3(34, 16, 5)   # a bracket still too tall at the compact size (the NCSA's): card, bye, pitch
const CAPTION_BTN_H := 26     # the caption's CONFERENCE / NCSA buttons (units)
const CARD_W := Vector2(120, 230)   # a card's width: the narrowest it gets .. the widest
const BIG_LOGO_W := 150       # this wide or more: the full logo; narrower, the small mark...
const LOGO_MIN_W := 112       # ...narrower still: no logo, more name
const GAP_X := 22             # between rounds: the connectors
const PITCH_Y := 8            # between two first-round places
const HEAD_H := 30            # the round names over the columns, an underline under them
const LINE_W := 2             # the connectors' thickness
const PLAQUE := Vector2(108, 88)  # the champion's card (its own column after the final, its heading over it)
const SHADOW := Vector2(3, 3)
const SEED_W := 16
const LOGO_BIG := Vector2(28, 20)
const LOGO_SMALL := Vector2(20, 12)
const LINE := Color(0.36, 0.78, 1.0, 0.55)    # muted cyan; a winner's path gold
const BYE_LINE := Color(1, 1, 1, 0.2)
const WIN_TINT := Color(1.0, 0.82, 0.25, 0.14)  # the winner's row, a touch of gold
const CARD_TOP := Color("12286e")             # a card's top edge, a shade lighter than its navy
const GOLD_DARK := Color("b8860b")
const ROUND_HEADS := {"conf_qf": "QUARTERFINALS", "conf_semi": "SEMIFINALS", "conf_final": "CONFERENCE FINAL",
	"nat_r1": "FIRST ROUND", "nat_qf": "QUARTERFINALS", "nat_sf": "SEMIFINALS", "nat_final": "NCSA FINAL",
	"d3_sf": "SEMIFINALS", "d3_final": "DIVISION III FINAL"}
const SHORT := {"conf_qf": "QF", "conf_semi": "SF", "conf_final": "FINAL", "nat_r1": "R1", "nat_qf": "QF", "nat_sf": "SF", "nat_final": "FINAL", "d3_sf": "SF", "d3_final": "FINAL"}

## Game pixels a unit: FINE in detail mode (the PLAYOFFS tab), else 1.
static func scale() -> float:
	var win := Game.get_window() if Game != null else null
	return FINE if win != null and win.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS else 1.0

# ------------------------------------------------------------------ the model
## The bracket of family `fam` ("conf": conference `conf`'s tournament, "nat": the NCSA's).
## {rounds: [{kind, matches: [{a, b, game, bye, win, label}]}], champion, projected, empty, size}.
## In a match, `a` / `b` are team ids, "" where a bye sits, "?" not decided yet; `win` the winner
## once there is one ("" not yet); `game` the scheduled game ({} for a bye or one not drawn yet);
## `label` its name in the round ("QF2"), "" for a bye.
static func model(c: Career, fam: String, conf: String) -> Dictionary:
	if fam == "d3":
		return _d3_model(c)
	var idx: Array = Schedule._family(c.schedule, fam)
	if idx.is_empty():
		return {"empty": true, "rounds": []}
	var size := 1 << idx.size()
	var seeds: Array = []
	var projected := false
	if fam == "conf":
		seeds = (c.season.get("conf_seeds", {}) as Dictionary).get(conf, [])
		if seeds.is_empty() and not Schedule.drawn(c.schedule[idx[0]]):
			seeds = Schedule.conf_table(c.teams, c.table, conf).slice(0, size)
			projected = true
	else:
		seeds = (c.season.get("nat_seeds", []) as Array).duplicate()   # (a copy: the preview never writes the season)
	# THE NCSA BRACKET PREVIEW: before the field is set, the bracket's own structure with its seed
	# places in it ("#1".."#12": positions, never teams), placed exactly as the real field will be
	# (Schedule._slots: the same order, the same byes); no game, no score, nobody advanced but a
	# bye's seed. Replaced by the real teams the moment the field is named (season.nat_seeds).
	var preview := false
	if fam == "nat" and seeds.is_empty():
		for k in Schedule.NCSA_FIELD:
			seeds.append("#%d" % (k + 1))
		preview = true
		projected = true
	if seeds.is_empty():
		return {"empty": true, "rounds": [], "size": size}
	var slots: Array = Schedule._slots(seeds, size)
	var rounds: Array = []
	var champion := ""
	for k in idx.size():
		var round: Dictionary = c.schedule[idx[k]]
		var matches: Array = []
		var next: Array = []
		var n := 0
		for i in range(0, slots.size(), 2):
			var a: String = slots[i]
			var b: String = slots[i + 1]
			var m := {"a": a, "b": b, "game": {}, "bye": false, "win": "", "label": ""}
			if a == "" or b == "":
				m.bye = a != "" or b != ""
				m.win = a if b == "" else b
				next.append(m.win)
			else:
				n += 1
				m.label = ("GAME %d" % n if round.kind == "nat_r1" else "%s%d" % [SHORT[round.kind], n]) if SHORT[round.kind] != "FINAL" else "FINAL"
				if a != "?" and b != "?" and not projected:
					for g in round.games:
						if (g.h == a and g.a == b) or (g.h == b and g.a == a):
							m.game = g
				if not m.game.is_empty() and m.game.r != null:
					m.win = Schedule.winner(m.game)
				next.append(m.win if m.win != "" else "?")
			matches.append(m)
		rounds.append({"kind": String(round.kind), "matches": matches})
		slots = next
	if slots.size() == 1 and slots[0] != "?" and slots[0] != "":
		champion = slots[0]
	if preview:
		champion = ""
	return {"rounds": rounds, "champion": champion, "projected": projected, "empty": false, "size": size,
		"seeds": seeds, "fam": fam, "conf": conf, "preview": preview}

## The NCSA Division III Championship's bracket: its four seeds as Schedule drew them, its two
## rounds read from the games marked in the NCSA's first two weeks. {empty} until the field is named.
static func _d3_model(c: Career) -> Dictionary:
	var seeds: Array = (c.season.get("d3_seeds", []) as Array).duplicate()
	if seeds.is_empty():
		return {"empty": true, "rounds": [], "size": Schedule.D3_FIELD, "fam": "d3", "conf": ""}
	var slots: Array = Schedule._slots(seeds, Schedule.D3_FIELD)
	var rounds: Array = []
	var champion := ""
	for kind in ["d3_sf", "d3_final"]:
		var games: Array = []
		for r in c.schedule:
			games.append_array((r.games as Array).filter(func(g): return String(g.get("k", "")) == kind))
		var matches: Array = []
		var next: Array = []
		var n := 0
		for i in range(0, slots.size(), 2):
			n += 1
			var m := {"a": slots[i], "b": slots[i + 1], "game": {}, "bye": false, "win": "", "label": "FINAL" if kind == "d3_final" else "SF%d" % n}
			for g in games:
				if (g.h == m.a and g.a == m.b) or (g.h == m.b and g.a == m.a):
					m.game = g
			if not m.game.is_empty() and m.game.r != null:
				m.win = Schedule.winner(m.game)
			next.append(m.win if m.win != "" else "?")
			matches.append(m)
		rounds.append({"kind": kind, "matches": matches})
		slots = next
	if slots.size() == 1 and slots[0] != "?":
		champion = slots[0]
	return {"rounds": rounds, "champion": champion, "projected": false, "empty": false, "size": Schedule.D3_FIELD,
		"seeds": seeds, "fam": "d3", "conf": "", "preview": false}

## Who's in place `side` ("a" / "b") of match `j` of round `k`, as a card shows it: the team, or
## where he'll come from ("WINNER OF QF1"), or "TBD".
static func placeholder(m: Dictionary, k: int, j: int, side: String) -> String:
	if k == 0:
		return "TBD"
	var rounds: Array = m.rounds
	var feeder: Dictionary = rounds[k - 1].matches[j * 2 + (0 if side == "a" else 1)]
	return "WINNER OF %s" % feeder.label if feeder.label != "" else "TBD"

# ------------------------------------------------------------------ the picture
## The bracket, drawn: the rounds share the width (cards between CARD_W), the champion's card in
## a column of its own after the final; as tall as its first round needs, centred in the room,
## scrolling when it's taller (the NCSA's). `you`: your school (a cyan mark).
static func view(c: Career, m: Dictionary, you: String) -> Control:
	m = shown(m)
	var s := scale()
	var cv := UI.canvas(0, 0, func(ci): _draw(ci, c, m, you))
	cv.name = "Bracket"
	cv.custom_minimum_size = Vector2(0, ceilf(content_h(m) * s) + 2)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return cv   # (the tab's own scroll takes a bracket taller than the screen)

## The PEC's bracket as drawn (MPSF: four teams, so its first round is nothing but byes): that
## round left out, the bracket starting with its games. Every other bracket as it is; the model
## (the seeds, the games, the results) is never changed.
const NO_BYE_ROUND := ["MPSF"]
static func shown(m: Dictionary) -> Dictionary:
	if String(m.get("fam", "")) != "conf" or not String(m.get("conf", "")) in NO_BYE_ROUND:
		return m
	var rounds: Array = m.rounds
	while rounds.size() > 1 and (rounds[0].matches as Array).all(func(mt): return mt.bye or (mt.a == "" and mt.b == "")):
		rounds = rounds.slice(1)
	var out := m.duplicate()
	out["rounds"] = rounds
	return out

## A first-round place's height: a card for a game, a slim row for a bye (or nothing at all).
static func _slot_h(mt: Dictionary, card_h: float, bye_h: float = BYE_H) -> float:
	return card_h if not mt.bye and not (mt.a == "" and mt.b == "") else bye_h

## The layout for `width` (units): each round's x and the card width, every match's top
## {x: [], w, y: [[]], mid, plaque: Rect2, bottom, card_h}. The first round stacks its places;
## each later game sits halfway between the two it's fed from; the champion's card after the
## final, level with it.
static func layout(m: Dictionary, width: float, room: float = ROOM_H) -> Dictionary:
	var full := _layout(m, width, float(CARD_H))
	if float(full.bottom) <= room:
		return full
	var compact := _layout(m, width, float(CARD_COMPACT))   # (taller than the room: the compact cards)
	if float(compact.bottom) <= room:
		return compact
	return _layout(m, width, TIGHT.x, TIGHT.y, TIGHT.z)    # (still taller: tighter still, so it never scrolls)

static func _layout(m: Dictionary, width: float, card_h: float, bye_h: float = BYE_H, pitch: float = PITCH_Y) -> Dictionary:
	var rounds: Array = m.rounds
	var n := rounds.size()
	var w := clampf(floorf((width - PLAQUE.x - GAP_X * n) / maxf(1.0, n)), CARD_W.x, CARD_W.y)
	var total := n * w + n * GAP_X + PLAQUE.x
	var x0 := maxf(0.0, floorf((width - total) * 0.5))
	var xs: Array = []
	for k in n:
		xs.append(x0 + k * (w + GAP_X))
	var ys: Array = []
	var mids: Array = []
	var bottom := 0.0
	for k in n:
		var col: Array = []
		var cm: Array = []
		var floor_y := float(HEAD_H)
		for j in rounds[k].matches.size():
			var mt: Dictionary = rounds[k].matches[j]
			var h := _slot_h(mt, card_h, bye_h) if k == 0 else card_h
			var top := floor_y
			if k > 0:
				var mid := floorf((float(mids[k - 1][j * 2]) + float(mids[k - 1][j * 2 + 1])) * 0.5)
				top = maxf(floor_y, mid - floorf(h * 0.5))
			col.append(top)
			cm.append(top + floorf(h * 0.5))
			floor_y = top + h + pitch
			bottom = maxf(bottom, top + h)
		ys.append(col)
		mids.append(cm)
	# the champion's card: its own column, level with the final (inside the head's room)
	var fmid: float = mids[n - 1][0]
	var py := maxf(float(HEAD_H), fmid - floorf(PLAQUE.y * 0.5))
	bottom = maxf(bottom, py + PLAQUE.y)
	return {"x": xs, "w": w, "y": ys, "mid": mids, "bottom": bottom, "card_h": card_h, "bye_h": bye_h,
		"plaque": Rect2(xs[n - 1] + w + GAP_X, py, PLAQUE.x, PLAQUE.y)}

## How tall the bracket is, in units (its own layout's: the heights don't depend on the width).
static func content_h(m: Dictionary) -> float:
	if (m.rounds as Array).is_empty():
		return 0.0
	return float(layout(m, 720.0).bottom)

static func _draw(ci: CanvasItem, c: Career, m: Dictionary, you: String) -> void:
	var rounds: Array = m.rounds
	if rounds.is_empty():
		return
	var s := scale()
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var size: Vector2 = (ci as Control).size / s
	var lay := layout(m, size.x, size.y if m.has("caption") else ROOM_H)   # (the NCSA's view: all the page's height)
	var dy := 0.0 if m.has("caption") else maxf(0.0, floorf((size.y - float(lay.bottom)) * 0.5))   # (centred in the room it has; the NCSA's view from the top)
	var w: float = lay.w
	var card_h: float = lay.card_h
	var last := rounds.size() - 1
	# the round names, an underline each (the final's in gold)
	for k in rounds.size():
		var x: float = lay.x[k]
		var head := String(ROUND_HEADS.get(rounds[k].kind, rounds[k].kind))
		var col := UI.GOLD if k == last else UI.ACCENT
		Deck.text(ci, x, dy + 9, head, 24, col, "big")
		ci.draw_rect(Rect2(x, dy + 21, w, 2), Color(col, 0.35))
		ci.draw_rect(Rect2(x, dy + 21, minf(w, Deck.text_w(head, 24, "big")), 2), Color(col, 0.85))
	var pr: Rect2 = lay.plaque
	Deck.text(ci, pr.position.x, dy + 9, "CHAMPION", 24, UI.GOLD, "big", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	ci.draw_rect(Rect2(pr.position.x, dy + 21, pr.size.x, 2), Color(UI.GOLD, 0.85))
	# the connectors first, the cards over them
	for k in rounds.size():
		var x: float = lay.x[k]
		for j in rounds[k].matches.size():
			var mt: Dictionary = rounds[k].matches[j]
			if mt.a == "" and mt.b == "":
				continue
			var y: float = dy + float(lay.mid[k][j])
			var col := BYE_LINE if mt.bye else (UI.GOLD if mt.win != "" else LINE)
			if k == last:
				_hline(ci, x + w, pr.position.x, y, col)   # (the final on to the champion)
				continue
			var ty: float = dy + float(lay.mid[k + 1][j / 2])
			var turn := x + w + floorf(GAP_X * 0.5) - 1
			_hline(ci, x + w, turn + LINE_W, y, col)
			_vline(ci, turn, y, ty, col)
			_hline(ci, turn, x + w + GAP_X, ty, col)
	for k in rounds.size():
		var x: float = lay.x[k]
		for j in rounds[k].matches.size():
			var mt: Dictionary = rounds[k].matches[j]
			var y: float = dy + float(lay.y[k][j])
			if mt.bye:
				_bye(ci, c, m, Rect2(x, y, w, float(lay.bye_h)), mt, you)
			elif not (mt.a == "" and mt.b == ""):
				_card(ci, c, m, Rect2(x, y, w, card_h), mt, k, j, k == last, you)
	_plaque(ci, c, m, Rect2(pr.position + Vector2(0, dy), pr.size))
	if m.has("caption"):
		_caption(ci, m.caption, _caption_rect(lay, dy))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The CAPTION (the NCSA view: no header row over the bracket): the open space over the final's
## and the champion's columns, from under their heads to over the final's card. In units.
static func _caption_rect(lay: Dictionary, dy: float) -> Rect2:
	var last: int = (lay.x as Array).size() - 1
	var x0: float = lay.x[last]
	var pr: Rect2 = lay.plaque
	var top := dy + HEAD_H + 2.0
	var bottom := dy + float(lay.y[last][0]) - 6.0
	return Rect2(x0, top, pr.end.x - x0, maxf(0.0, bottom - top))

## The caption's words: the title (big), a gold line under it, the explanation wrapped small.
static func _caption(ci: CanvasItem, cap: Dictionary, r: Rect2) -> void:
	var y := r.position.y + 10
	Deck.text(ci, r.position.x, y, Deck.fit(String(cap.get("title", "")), r.size.x, 24, "big"), 24, UI.ACCENT, "big")
	y += 16
	if String(cap.get("tag", "")) != "":
		Deck.text(ci, r.position.x, y, String(cap.tag), 8, UI.GOLD, "caps")
		y += 12
	var words := String(cap.get("sub", "")).split(" ", false)
	var line := ""
	var limit := r.end.y - 4
	for wd in words:
		var next := wd if line == "" else line + " " + wd
		if line != "" and Deck.text_w(next, 8, "caps") > r.size.x:
			if y > limit:
				return
			Deck.text(ci, r.position.x, y, line, 8, UI.DIM, "caps")
			y += 11
			line = wd
		else:
			line = next
	if line != "" and y <= limit:
		Deck.text(ci, r.position.x, y, line, 8, UI.DIM, "caps")

static func _hline(ci: CanvasItem, x1: float, x2: float, y: float, col: Color) -> void:
	ci.draw_rect(Rect2(floorf(minf(x1, x2)), floorf(y) - floorf(LINE_W * 0.5), floorf(absf(x2 - x1)) + LINE_W, LINE_W), col)

static func _vline(ci: CanvasItem, x: float, y1: float, y2: float, col: Color) -> void:
	ci.draw_rect(Rect2(floorf(x), floorf(minf(y1, y2)) - floorf(LINE_W * 0.5), LINE_W, floorf(absf(y2 - y1)) + LINE_W), col)

## A game: a soft shadow, navy with a lighter top edge, a thin white border (the final's gold,
## doubled), a row a team, a rule between.
static func _card(ci: CanvasItem, c: Career, m: Dictionary, r: Rect2, mt: Dictionary, k: int, j: int, final: bool, you: String) -> void:
	ci.draw_rect(Rect2(r.position + SHADOW, r.size), Color(0, 0, 0, 0.35))
	ci.draw_rect(r, Deck.NAVY)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), CARD_TOP)
	if final:
		ci.draw_rect(r.grow(3), UI.GOLD, false, 1.0)
	ci.draw_rect(r, UI.GOLD if final else Color(1, 1, 1, 0.85), false, 2.0 if final else 1.0)
	var row_h := floorf((r.size.y - 6.0) * 0.5)
	ci.draw_rect(Rect2(r.position.x + 6, r.position.y + 3 + row_h, r.size.x - 12, 1), Color(1, 1, 1, 0.22))
	var g: Dictionary = mt.game
	for sd in 2:
		var side := "a" if sd == 0 else "b"
		var id: String = mt[side]
		var row := Rect2(r.position.x + 1, r.position.y + 2 + sd * (row_h + 2), r.size.x - 2, row_h)
		if id == "?" or id == "":
			Deck.text(ci, row.position.x + 6, row.position.y + row_h * 0.5, Deck.fit(placeholder(m, k, j, side), row.size.x - 12), 8, UI.DIM2)
			continue
		_team_row(ci, c, m, row, id, mt, g, you, final)

## One team's row: seed, logo, full name, score. The winner's in gold (name, score, a gold tint
## and edge along the row); the loser dimmed; your school a cyan mark at the end.
static func _team_row(ci: CanvasItem, c: Career, m: Dictionary, r: Rect2, id: String, mt: Dictionary, g: Dictionary, you: String, final := false) -> void:
	var t: PoloTeam = c.teams.get(id)
	var seed := (m.seeds as Array).find(id) + 1
	var done: bool = mt.win != ""
	var won: bool = mt.win == id
	if won:
		ci.draw_rect(r, WIN_TINT)
		ci.draw_rect(Rect2(r.position.x, r.position.y, 2, r.size.y), UI.GOLD)
	if id == you:
		ci.draw_rect(Rect2(r.end.x - 3, r.position.y + 1, 2, r.size.y - 2), UI.ACCENT)
	var name_col := UI.TEXT if not done else (UI.GOLD if won else UI.DIM2)
	var cy := r.position.y + r.size.y * 0.5
	var x := r.position.x + 5
	Deck.text(ci, x, cy, "%d" % seed if seed > 0 and not m.get("preview", false) else "", 8, UI.DIM if not done or won else UI.DIM2, "caps", HORIZONTAL_ALIGNMENT_RIGHT, SEED_W - 4)
	x += SEED_W
	if r.size.x >= LOGO_MIN_W and t != null:
		var big := r.size.x >= BIG_LOGO_W and r.size.y >= LOGO_BIG.y
		var lb := LOGO_BIG if big else LOGO_SMALL
		TeamLogo.paint(ci, Vector2(x, r.position.y + floorf((r.size.y - lb.y) * 0.5)), t, TeamLogo.MEDIUM if big else TeamLogo.SMALL, 1 if big else 0, false)
		x += lb.x + 5
	var score := ""
	if not g.is_empty() and g.r != null:
		var sc_arr: Array = g.r.s
		score = str(int(sc_arr[0]) if g.h == id else int(sc_arr[1]))
		if not (g.r.so as Array).is_empty():
			var so: Array = g.r.so
			score += "(%d)" % (int(so[0]) if g.h == id else int(so[1]))
	elif not g.is_empty() or not m.projected:
		score = "-"
	var big_score := final and score != "-" and score != ""
	var score_w := Deck.text_w(score, 24, "big") if big_score else (Deck.text_w(score) if score != "" else 0.0)
	var name_w := r.end.x - 7 - score_w - 6 - x
	Deck.text(ci, x, cy, name_for(t, id, name_w), 8, name_col)
	if score != "":
		var scol := UI.GOLD if won else (UI.DIM2 if done else UI.DIM)
		if big_score:
			Deck.text(ci, r.end.x - 7 - score_w, cy, score, 24, scol, "big")
		else:
			Deck.text(ci, r.end.x - 7 - score_w, cy, score, 8, scol)

## A school's name in `w`: in full when it fits ("LOS ANGELES BEARS"), else its nickname
## ("BEARS": tells two schools from one city apart), else the full name cut to fit.
static func name_for(t: PoloTeam, id: String, w: float, font := "caps") -> String:
	if t == null:
		return ("SEED " + id) if id.begins_with("#") else id   # (the preview's seed places)
	var full := Colleges.display_name(t.name).to_upper()
	if Deck.text_w(full, 8, font) <= w:
		return full
	var nick := String(t.mascot).to_upper()
	if nick != "" and Deck.text_w(nick, 8, font) <= w:
		return nick
	return Deck.fit(full, w, 8, font)

## A bye: no game, no card. The team who has it, in a slim row where his first game would have been.
static func _bye(ci: CanvasItem, c: Career, m: Dictionary, r: Rect2, mt: Dictionary, you: String) -> void:
	var id: String = mt.win
	var t: PoloTeam = c.teams.get(id)
	var seed := (m.seeds as Array).find(id) + 1
	var cy := r.position.y + r.size.y * 0.5
	ci.draw_rect(r, Color(1, 1, 1, 0.04))
	if id == you:
		ci.draw_rect(Rect2(r.end.x - 3, r.position.y + 2, 2, r.size.y - 4), UI.ACCENT)
	Deck.text(ci, r.position.x + 5, cy, "%d" % seed if not m.get("preview", false) else "", 8, UI.DIM2, "caps", HORIZONTAL_ALIGNMENT_RIGHT, SEED_W - 4)
	var nx := r.position.x + 5 + SEED_W
	if r.size.x >= LOGO_MIN_W and t != null:
		TeamLogo.paint(ci, Vector2(nx, r.position.y + floorf((r.size.y - LOGO_SMALL.y) * 0.5)), t, TeamLogo.SMALL, 0, false)
		nx += LOGO_SMALL.x + 5
	var bw := Deck.text_w("BYE")
	Deck.text(ci, nx, cy, name_for(t, id, r.end.x - 7 - bw - 6 - nx), 8, UI.DIM2)
	Deck.text(ci, r.end.x - 7 - bw, cy, "BYE", 8, UI.ACCENT)

## The champion's card: the gold cup (TrophyArt: the cabinet's own), the champion's logo and
## name once the final's been played; TBD, the cup in silver, before.
static func _plaque(ci: CanvasItem, c: Career, m: Dictionary, r: Rect2) -> void:
	var id: String = m.champion
	var t: PoloTeam = c.teams.get(id) if id != "" else null
	ci.draw_rect(Rect2(r.position + SHADOW, r.size), Color(0, 0, 0, 0.35))
	ci.draw_rect(r, Deck.NAVY)
	if id != "":
		ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, r.size.y * 0.55), Color(UI.GOLD, 0.08))
	ci.draw_rect(r, UI.GOLD if id != "" else Color(1, 1, 1, 0.5), false, 2.0 if id != "" else 1.0)
	var cup: ImageTexture = TrophyArt.texture("first" if id != "" else "second")
	ci.draw_texture_rect(cup, Rect2(r.position.x + floorf((r.size.x - TrophyArt.W) * 0.5), r.position.y + 2, TrophyArt.W, TrophyArt.H), false)
	var y := r.position.y + TrophyArt.H + 6
	if t != null:
		TeamLogo.paint(ci, Vector2(r.position.x + floorf((r.size.x - LOGO_BIG.x) * 0.5), y - 2), t, TeamLogo.MEDIUM, 1, false)
		y += LOGO_BIG.y + 6
		Deck.text(ci, r.position.x, y, name_for(t, id, r.size.x - 8, "caps"), 8, UI.GOLD, "caps", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	else:
		Deck.text(ci, r.position.x, y + 12, "TBD", 8, UI.DIM2, "caps", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

## A small pixel trophy, 9 x 11, its top-left at `p`: cup, handles, stem, base, a highlight.
static func trophy(ci: CanvasItem, p: Vector2, col: Color) -> void:
	var dark := GOLD_DARK if col == UI.GOLD else Color(col, 0.6)
	ci.draw_rect(Rect2(p + Vector2(2, 0), Vector2(5, 5)), col)          # the cup
	ci.draw_rect(Rect2(p + Vector2(0, 1), Vector2(2, 1)), col)          # handles
	ci.draw_rect(Rect2(p + Vector2(0, 2), Vector2(1, 1)), col)
	ci.draw_rect(Rect2(p + Vector2(7, 1), Vector2(2, 1)), col)
	ci.draw_rect(Rect2(p + Vector2(8, 2), Vector2(1, 1)), col)
	ci.draw_rect(Rect2(p + Vector2(3, 5), Vector2(3, 1)), dark)         # its foot
	ci.draw_rect(Rect2(p + Vector2(4, 6), Vector2(1, 2)), col)          # the stem
	ci.draw_rect(Rect2(p + Vector2(2, 8), Vector2(5, 1)), col)          # the base
	ci.draw_rect(Rect2(p + Vector2(1, 9), Vector2(7, 2)), dark)
	ci.draw_rect(Rect2(p + Vector2(3, 1), Vector2(1, 2)), Color(1, 1, 1, 0.8))   # the shine
