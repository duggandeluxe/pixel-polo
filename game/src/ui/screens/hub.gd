extends BaseScreen
## The season home screen: settings and the chips up top, the conference table beside the
## team card, the next five weeks on a timeline, then back / roster / training / coaching /
## PLAY (which opens the matchup preview). Tap the conference table for the standings and
## playoffs, the timeline for the whole season schedule, the team card for the DYNASTY HUB
## (program, league news, records, recruiting, ...).
## Shows anything queued for the coach (welcome, goals, the season review, cards,
## job offers) one dialog at a time.

const SPAN := 5          # games (or weeks without one) on the timeline

var busy := false   # a game or a week is already on its way (screen changes fade): ignore more taps

func _init() -> void:
	detail = true   # (its team logos: TeamLogo's fine pixels)

func _ready() -> void:
	c = Game.career
	if c == null:
		Game.goto("title")
		return
	if not c.pending_event.is_empty():
		Game.goto("coach_event", {}, false)   # a coaching event still to answer (a reload): it comes first
		return
	if not CoachEvents.popups(c).is_empty():
		Game.goto("coach_event", {}, false)   # a challenge result not yet seen (the app closed on it): once
		return
	build(c.team().name.to_upper(), false, true)
	# the home screen draws its own top row (gear, chips), so the stock header goes
	title_label.get_parent().visible = false
	_render()
	Sfx.music("menu")
	Sfx.crowd(0.0)
	await get_tree().process_frame
	if not _process_queue() and not _open_cuts() and not Game.open_upgrades() and not _division_invite():
		_deadline_warning()

func on_back() -> void:
	_back()

func _render() -> void:
	body.add_child(_top_bar())
	var top := UI.hbox(6)
	body.add_child(top)
	top.add_child(_tappable(_standings(), func(): Game.goto("conference"), "Full standings and playoffs"))
	top.add_child(_tappable(_team_card(), func(): Game.goto("more"), "The Dynasty Hub: program, news, records and more"))
	# spare height splits evenly above and below the schedule
	body.add_child(UI.spacer(0, 2, true))
	var sched := PanelContainer.new()
	sched.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var sv := UI.vbox(3)
	sched.add_child(sv)
	if c.in_offseason():
		sv.add_child(_sched_head("THE OFF-SEASON", c.calendar_text()))
		if c.phase == "cuts":
			sv.add_child(_cuts_banner())
			body.add_child(_tappable(sched, func(): Game.goto("roster_cuts"), "Make your roster cuts"))
		else:
			sv.add_child(_done_banner())
			body.add_child(_tappable(sched, func(): Game.goto("recruiting"), "Your recruits for next season"))
	else:
		sv.add_child(_sched_head("SEASON SCHEDULE", _progress_text()))
		sv.add_child(_timeline())
		body.add_child(_tappable(sched, func(): Game.goto("schedule"), "The whole season schedule"))
	body.add_child(UI.spacer(0, 2, true))
	body.add_child(_nav())

# ------------------------------------------------------------------ top bar
func _top_bar() -> Control:
	var h := UI.hbox(5)
	var gear := Deck.icon_button("gear", func(): Game.goto("settings"), 26, 22, "normal", 2)
	gear.tooltip_text = "Settings"
	_light(gear)
	h.add_child(gear)
	# the National Top 20, with where you are in it
	var rank := Poll.rank_in(Poll.latest(c), c.school)
	var top := Deck.button("TOP 20  #%d" % rank if rank > 0 and rank <= Poll.TOP else "TOP 20", func(): Game.goto("top20"), "normal", 0, 22)
	top.tooltip_text = "The National Top 20 poll"
	_light(top)
	h.add_child(top)
	var aw := Deck.button("AWARDS", func(): Game.goto("awards"), "normal", 0, 22)
	aw.name = "Awards"
	aw.tooltip_text = "Conference awards: player, rookie, offensive and defensive player of the week"
	_light(aw)
	h.add_child(aw)
	h.add_child(UI.spacer(0, 0, true))
	if Store.pro:
		h.add_child(_chip("POLO +", UI.GOOD))
	h.add_child(credits_chip())
	h.add_child(_chip("%s  %s" % [c.season_label(), c.calendar_text()], UI.TEXT))
	for ch in h.get_children():
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return h

## Lets a whole panel be tapped, without changing how it looks.
func _tappable(panel: Control, cb: Callable, tip: String) -> Control:
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	panel.add_child(b)
	return panel

# ------------------------------------------------------------------ top left: the conference
## Your conference, four rows: the top four, or the top three and you when you're lower down.
## Your row gets a gold outline.
func _standings() -> Control:
	var t := c.team()
	var p := UI.panel(Deck.NAVY, UI.BORDER)
	var v := UI.vbox(0)
	p.add_child(v)
	var head := UI.hbox(4)
	v.add_child(head)
	var conf := UI.label(c.conf_abbr(), 20, UI.TEXT, "big")
	conf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conf.clip_text = true
	conf.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(conf)
	var rl := UI.label("RECORD", 8, UI.ACCENT, "caps")
	rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rl)
	v.add_child(_hline(UI.ACCENT))
	v.add_child(UI.spacer(0, 1))
	var order := Schedule.conf_table(c.teams, c.table, t.conf)
	var rows: Array = range(mini(4, order.size()))
	var mine := order.find(c.school)
	if mine >= 4:
		rows = [0, 1, 2, mine]
	for i in rows:
		var id: String = order[i]
		var r: Dictionary = c.table[id]
		v.add_child(_table_row(i + 1, Colleges.display_name((c.teams[id] as PoloTeam).name).to_upper(), "%d-%d" % [r.cw, r.cl], id == c.school))
	return p

func _table_row(rank: int, name: String, rec: String, me: bool) -> Control:
	var p := PanelContainer.new()
	# every row gets the same padding, so the outlined row's text lines up with the rest
	var st := UI.sb(Deck.NAVY, UI.GOLD if me else Color.TRANSPARENT, 2 if me else 0, 6, 3)
	p.add_theme_stylebox_override("panel", st)
	var h := UI.hbox(6)
	p.add_child(h)
	h.add_child(fixed_label(str(rank), 10, UI.TEXT))
	var nl := UI.label(name, 8, UI.TEXT)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nl)
	var rl := fixed_label(rec, 24, UI.TEXT)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(rl)
	return p

func _hline(col: Color) -> Control:
	var d := UI.canvas(0, 1, func(ci): ci.draw_rect(Rect2(0, 0, ci.size.x, 1), col))
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return d

# ------------------------------------------------------------------ top right: the team
## Big logo on the left; name, WATER POLO, record and rating on the right; a faint pixel
## wave along the bottom.
func _team_card() -> Control:
	var t := c.team()
	var p := UI.panel(Deck.NAVY, UI.BORDER)
	p.add_child(UI.canvas(0, 0, _draw_waves))
	var h := UI.hbox(8)
	p.add_child(h)
	var logo := TeamLogo.widget(t, TeamLogo.LARGE, 3)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(logo)
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(UI.team_title(Colleges.display_name(t.name).to_upper(), t.mascot, 150))
	var wp := UI.label("W A T E R   P O L O", 8, UI.ACCENT, "caps")
	wp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(wp)
	v.add_child(UI.spacer(0, 3))
	var stats := UI.hbox(0)
	v.add_child(stats)
	stats.add_child(_stat("RECORD", c.record_text()))
	var d := UI.canvas(1, 0, func(ci): ci.draw_rect(Rect2(0, 0, 1, ci.size.y), UI.ACCENT))
	stats.add_child(d)
	stats.add_child(_stat("RATING", str(t.overall_display())))
	return p

func _stat(label: String, value: String) -> Control:
	var v := UI.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UI.label(label, 8, UI.ACCENT, "caps")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var n := UI.label(value, 20, UI.TEXT, "big")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	return v

## Two rows of stepped pixel waves, a shade off the panel colour.
func _draw_waves(ci: Control) -> void:
	var w := floorf(ci.size.x)
	var y := floorf(ci.size.y) - 3.0
	var col := Deck.NAVY.lightened(0.07)
	var x := 2.0
	while x < w - 2.0:
		var phase := int(x / 4.0) % 4
		var dy: float = [0.0, -1.0, -2.0, -1.0][phase]
		ci.draw_rect(Rect2(x, y + dy - 3.0, 4, 1), col)
		ci.draw_rect(Rect2(x, y + dy - 2.0, 4, 3.0 - dy), col.darkened(0.02))
		x += 4.0

# ------------------------------------------------------------------ the timeline
## The timeline's entries: one per game of yours (up to three a week), one for a week without
## one. {w: week index, g: the game or {}}.
func _entries() -> Array:
	var out: Array = []
	for i in c.schedule.size():
		var mine := c.my_games(c.schedule[i])
		if mine.is_empty():
			out.append({"w": i, "g": {}})
		for g in mine:
			out.append({"w": i, "g": g})
	return out

## Where the timeline starts: your last result, then your next game (or this week) and what's
## after it; at the season's ends, the first or last five.
func _first_entry(entries: Array) -> int:
	var now := entries.size() - 1
	for k in entries.size():
		var e: Dictionary = entries[k]
		if e.w > c.week or (e.w == c.week and (e.g.is_empty() or e.g.r == null)):
			now = k
			break
	return clampi(now - 1, 0, maxi(0, entries.size() - SPAN))

## What the timeline shows for an entry: a node on the season path.
## state: next / win / loss / upcoming / tbd (playoff not drawn yet) / bye / out
## head: the strip on top (GAME 7, or the playoff round); mark: a milestone tag on its right
## (CONF, or a final's TITLE); opp: the other team (its logo); big: the result, or where it's
## played; name: the opponent along the bottom.
func _week(e: Dictionary) -> Dictionary:
	var i: int = e.w
	var r: Dictionary = c.schedule[i]
	var d := {"name": "", "head": "", "mark": "", "big": "", "state": "upcoming", "opp": null, "final": false}
	var g: Dictionary = e.g
	var playoff := Schedule.is_playoff(r)
	var round := String(Schedule.SHORT_NAMES.get(String(r.kind), String(r.name)))
	d.final = String(r.kind) in ["conf_final", "nat_final"]
	if (e.g as Dictionary).has("k"):   # (a Division III Championship game, in that week)
		round = String(Schedule.D3_SHORT.get(String(e.g.k), round))
		d.final = String(e.g.k) == "d3_final"
	if not Schedule.drawn(r):
		d.merge({"name": String(r.name).capitalize().replace("Conference", "Conf").replace("Ncsa", "NCSA"), "head": round, "big": "TBD", "state": "tbd"}, true)
	elif g.is_empty():
		var bye := not playoff or c.bye_week(i)
		d.merge({"name": "", "head": round if playoff else "WEEK %d" % (i + 1), "big": "BYE" if bye else "OUT", "state": "bye" if bye else "out"}, true)
	else:
		var home: bool = g.h == c.school
		var opp: PoloTeam = c.teams[g.a if home else g.h]
		d.opp = opp
		d.name = Colleges.display_name(opp.name).to_upper()
		d["short"] = String(Colleges.school(opp.id).get("mascot", d.name)).to_upper()
		var n := Schedule.game_no(c.schedule, c.school, g)
		d.head = round if playoff else ("GAME %d" % n if n > 0 else String(r.name))
		if not playoff and Schedule.is_conf_game(r, g):
			d.mark = "CONF"
		elif d.final:
			d.mark = "TITLE"
		d.big = "NEUTRAL" if Schedule.is_neutral(g) else ("HOME" if home else "AWAY")
		if g.r != null:
			var won := Schedule.winner(g) == c.school
			d.big = ("W " if won else "L ") + Schedule.score_text(g, home)
			d.state = "win" if won else "loss"
		elif i == c.week and g == c.my_game():
			d.state = "next"
	return d

## The season so far, under the heading: GAME 7 OF 16 in the regular season (counted from your
## schedule), the round and your record in the playoffs.
func _progress_text() -> String:
	var total := Schedule.team_games(c.schedule, c.school).size()
	if c.week < c.schedule.size() and Schedule.is_playoff(c.schedule[c.week]):
		return "%s  -  %s" % [c.calendar_text(), c.record_text()]
	return "GAME %d OF %d" % [mini(Schedule.games_played(c.schedule, c.school) + 1, total), total]

## The heading row: SEASON SCHEDULE (or THE OFF-SEASON), and where you are on the right.
func _sched_head(title: String, right: String) -> Control:
	var h := UI.hbox(6)
	var t := UI.label(title, 20, UI.TEXT, "big")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var p := PanelContainer.new()
	p.name = "SeasonProgress"
	p.add_theme_stylebox_override("panel", UI.sb(Deck.NAVY, UI.BORDER_HI, 1, 5, 1))
	var pl := UI.label(right, 8, UI.GOLD, "caps")
	p.add_child(pl)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(p)
	return h

func _timeline() -> Control:
	var entries := _entries()
	var first := _first_entry(entries)
	var weeks: Array = []
	for k in range(first, mini(first + SPAN, entries.size())):
		weeks.append(_week(entries[k]))
	var more := [first > 0, first + SPAN < entries.size()]
	var tl := UI.canvas(0, TL_H, func(ci): _draw_timeline(ci, weeks, more))
	tl.name = "SeasonPath"
	tl.set_meta("weeks", weeks)
	return tl

## The season's over: next season's roster as it stands (NEXT SEASON starts it).
func _done_banner() -> Control:
	var v := UI.vbox(2)
	v.custom_minimum_size = Vector2(0, TL_H)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := UI.label("SEASON COMPLETE", 16, UI.GOLD, "big")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var over := Recruiting.over_by(c)
	var line := UI.label("PROJECTED ROSTER: %d / %d    %s" % [Recruiting.projected(c), c.roster_max(),
		"%d PLAYER%s MUST BE CUT" % [over, "" if over == 1 else "S"] if over > 0 else "NO CUTS REQUIRED"], 8, UI.WARN if over > 0 else UI.TEXT, "caps")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(line)
	return v

## After the season, over the cap: how many must go before next season can start.
func _cuts_banner() -> Control:
	var v := UI.vbox(2)
	v.custom_minimum_size = Vector2(0, TL_H)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := UI.label("ROSTER CUTS REQUIRED", 16, UI.WARN, "big")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var line := UI.label("CURRENT ROSTER: %d / %d    PLAYERS TO CUT: %d" % [c.team().roster.size(), c.roster_max(), Offseason.cuts_needed(c)], 8, UI.TEXT, "caps")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(line)
	return v

const TL_H := 58          # the path's height: the NEXT GAME tab, then the nodes
const NODE_GAP := 10      # between two nodes: the path runs through it
const NODE_Y := 7         # a node's top (the tab sits on its edge)
const NODE_H := 49
const HEAD_H := 11        # a node's top strip

## The season path: a node per game, joined by the path (solid where it's been played, gold into
## the next game, dotted ahead), arrows off either end when there are more games that way.
func _draw_timeline(ci: Control, weeks: Array, more: Array) -> void:
	var w := floorf(ci.size.x)
	var col_w := w / SPAN
	var mid := NODE_Y + HEAD_H + (NODE_H - HEAD_H) * 0.5
	var nodes: Array = []
	for i in weeks.size():
		var x0 := floorf(col_w * i + NODE_GAP * 0.5)
		nodes.append(Rect2(x0, NODE_Y, floorf(col_w * (i + 1) - NODE_GAP * 0.5) - x0, NODE_H))
	# the path: before the first node, between nodes, after the last
	var played := func(d: Dictionary) -> bool: return String(d.state) in ["win", "loss", "bye", "out"]
	for i in range(-1, weeks.size()):
		var from := 0.0 if i < 0 else (nodes[i] as Rect2).end.x
		var to := w if i == weeks.size() - 1 else (nodes[i + 1] as Rect2).position.x if i + 1 < nodes.size() else w
		if i < 0 and not more[0]:
			continue
		if i == weeks.size() - 1 and not more[1]:
			continue
		var done_before: bool = i < 0 or played.call(weeks[i])
		var into: Dictionary = weeks[i + 1] if i + 1 < weeks.size() else {}
		if done_before and (into.is_empty() or played.call(into)):
			ci.draw_rect(Rect2(from, mid - 1, to - from, 3), UI.TEXT)
		elif done_before and String(into.get("state", "")) == "next":
			ci.draw_rect(Rect2(from, mid - 1, to - from, 3), UI.GOLD)
		else:
			var x := from + 1.0
			while x < to - 1.0:
				ci.draw_rect(Rect2(x, mid - 1, 2, 2), UI.ACCENT)
				x += 4.0
	if more[0]:
		_arrow(ci, Vector2(1, mid), -1)
	if more[1]:
		_arrow(ci, Vector2(w - 2, mid), 1)
	for i in weeks.size():
		_draw_node(ci, nodes[i], weeks[i])

## A little pixel arrowhead with its tip at `at`, pointing `dir` (-1 left, 1 right): more games that way.
func _arrow(ci: Control, at: Vector2, dir: int) -> void:
	for k in 3:
		ci.draw_rect(Rect2(at.x - dir * k, at.y - k, 1, 1 + 2 * k), UI.ACCENT)

## One game on the path. Completed: a green (win) or red (loss) edge and its score; the next
## game: a yellow frame, a brighter tile and the NEXT GAME tab; still to come: plain navy.
func _draw_node(ci: Control, r: Rect2, d: Dictionary) -> void:
	var state: String = d.state
	var muted := state in ["bye", "out", "tbd"]
	var edge: Color = {"win": UI.GOOD, "loss": UI.BAD, "next": UI.GOLD}.get(state, UI.BORDER_HI if not muted else UI.DIM2)
	var fill := Deck.NAVY_HEAD if state == "next" else (Deck.NAVY if not muted else Color("0a1a50"))
	ci.draw_rect(r, UI.INK)
	ci.draw_rect(r.grow(-1), edge)
	var inner := r.grow(-2)
	if state == "next":
		inner = r.grow(-3)   # (a two-pixel yellow frame)
	ci.draw_rect(inner, fill)
	# the top strip: GAME 7 or the round, and a milestone tag
	var head := Rect2(inner.position, Vector2(inner.size.x, HEAD_H))
	var head_fill := Color("e0b52a") if d.final else UI.INK.lerp(fill, 0.35)
	ci.draw_rect(head, head_fill)
	var head_col := UI.INK if d.final else (UI.GOLD if state == "next" else UI.DIM)
	var mark: String = d.mark
	var mark_w := 0.0
	if mark != "" and not d.final:
		mark_w = Deck.text_w(mark) + 4.0
		var mr := Rect2(head.end.x - mark_w - 1, head.position.y + 1, mark_w, HEAD_H - 2)
		ci.draw_rect(mr, UI.ACCENT.darkened(0.45))
		Deck.ctext(ci, mr, mark, 8, UI.ACCENT)
	Deck.text(ci, head.position.x + 3, head.position.y + HEAD_H * 0.5, Deck.fit(String(d.head), head.size.x - mark_w - 6), 8, head_col, "caps")
	# a result's colour down the left edge
	if state in ["win", "loss"]:
		ci.draw_rect(Rect2(inner.position.x, head.end.y, 2, inner.end.y - head.end.y), edge)
	# the logo (crisp, 1:1) and the result or where it's played
	var body_y := head.end.y + 2
	var big_x := inner.position.x + 5
	if d.opp != null:
		TeamLogo.paint(ci, Vector2(inner.position.x + 5, body_y), d.opp, TeamLogo.MEDIUM)
		big_x += TeamLogo.box(TeamLogo.MEDIUM).x + 3
	var big_col: Color = {"win": UI.GOOD, "loss": UI.BAD, "next": UI.GOLD}.get(state, UI.DIM2 if muted else UI.DIM)
	var big_r := Rect2(big_x, body_y, inner.end.x - big_x - 2, TeamLogo.box(TeamLogo.MEDIUM).y)
	if d.opp == null:
		Deck.ctext(ci, big_r, Deck.fit(String(d.big), big_r.size.x, 8, "caps"), 8, big_col, "caps")
	else:
		Deck.text(ci, big_r.position.x, big_r.position.y + big_r.size.y * 0.5, Deck.fit(String(d.big), big_r.size.x, 8, "body"), 8, big_col, "body")
	# the opponent along the bottom
	if String(d.name) != "":
		var nr := Rect2(inner.position.x + 2, inner.end.y - 11, inner.size.x - 4, 10)
		# (the whole name when it fits, else the mascot: the logo beside it says which)
		var nm := String(d.name) if Deck.text_w(String(d.name), 8, "body") <= nr.size.x else String(d.get("short", d.name))
		Deck.ctext(ci, nr, Deck.fit(nm, nr.size.x, 8, "body"), 8, UI.DIM2 if muted else UI.TEXT, "body")
	# the next game's tab, on its top edge
	if state == "next":
		var tab := String(d.get("tab", "NEXT GAME"))
		var tw := Deck.text_w(tab) + 8.0
		var tr := Rect2(floorf(r.get_center().x - tw * 0.5), 0, tw, 10)
		ci.draw_rect(tr, UI.INK)
		ci.draw_rect(tr.grow(-1), UI.GOLD)
		Deck.ctext(ci, tr, tab, 8, UI.INK)

# ------------------------------------------------------------------ bottom row
func _nav() -> Control:
	var h := UI.hbox(5)
	var back := Deck.icon_button("left", _back, 34, 22, "normal", 2)
	_light(back)
	back.tooltip_text = "Title screen (your career is saved)"
	h.add_child(back)
	var hurt := c.team().roster.filter(func(p: PoloPlayer): return p.is_injured()).size()
	var ups := c.team().roster.filter(func(p: PoloPlayer): return p.tokens > 0).size()
	# COACHING is the gameplan and recruiting screen (facilities and staff are under MORE / Training)
	# after the season there's no practice to plan: the roster cuts take its place
	var middle: Array = ["TRAINING", "training"]
	if c.in_offseason():
		middle = ["CUTS", "roster_cuts"] if c.phase == "cuts" else ["RECRUIT", "recruiting"]
	for it in [["ROSTER", "roster"], middle, ["COACHING", "coaching"]]:
		var scr: String = it[1]
		var b := Deck.button(it[0], func(): Game.goto(scr), "normal", 0, 22)
		b.name = "Nav_" + scr
		_light(b)
		b.add_theme_font_override("font", UI.font_big)
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
		if scr == "roster":
			Deck.nav_status_badges(b, ups > 0, hurt > 0)
	h.add_child(_play_button())
	return h

## Medium blue with a white edge, a step lighter than the page.
func _light(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UI.chunky(UI.BG_HI, UI.BORDER))
	b.add_theme_stylebox_override("hover", UI.chunky(Color("4f8bff"), UI.BORDER))
	b.add_theme_stylebox_override("pressed", UI.chunky(UI.BG2, UI.BORDER, false, true))
	b.add_theme_stylebox_override("hover_pressed", UI.chunky(UI.BG2, UI.BORDER, false, true))

## PLAY opens the matchup preview; with no game this week it moves the season on instead.
func _play_button() -> Button:
	var label := "PLAY"
	var cb := _open_matchup
	if c.game_over:
		label = "TITLE"
		cb = _back
	elif c.phase == "cuts":
		label = "ROSTER CUTS"
		cb = func(): Game.goto("roster_cuts")
	elif c.in_offseason():
		label = "NEXT SEASON"
		cb = _next_season
	elif c.game_done_this_week():
		label = "NEXT WEEK"
		cb = _sim_week
	elif not c.has_game():
		label = "SIM WEEK"
		cb = _sim_week
	var b := Deck.button(label, cb, "primary", 0, 22)
	b.add_theme_font_override("font", UI.font_big)
	b.add_theme_font_size_override("font_size", 20)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

# ------------------------------------------------------------------ actions
func _open_matchup() -> void:
	if busy or _process_queue():
		return
	Game.goto("matchup")

func _back() -> void:
	Game.save_career()
	Sfx.play("back")
	Game.goto("title")

func _sim_week() -> void:
	if busy or _process_queue() or c.game_over or Game.open_upgrades():
		return
	busy = true
	c.sim_week_without_me()
	c.end_week()
	Game.save_career()
	Game.goto("hub", {}, false)

## RECRUITING DEADLINE APPROACHING! (the Roster Needs & Recruiting Deadline update): once a
## season (Career.recruit_warned), when your own games are over (recruiting closes with NEXT
## SEASON) and something's unresolved (Recruiting.deadline: a pinned prospect unsigned, a starting
## place nobody can fill next season, cuts to come). Informational: nothing is signed, paid or
## unpinned. True if it showed.
func _deadline_warning() -> bool:
	if c.game_over or c.phase == "cuts" or c.recruit_warned == c.season_label():
		return false
	if not (c.in_offseason() or c.next_game().is_empty()):
		return false
	var d := Recruiting.deadline(c)
	if not bool(d.issues):
		return false
	c.recruit_warned = c.season_label()
	Game.save_career()
	Game.dialog("RECRUITING DEADLINE APPROACHING!", "Your season is over, and recruiting closes when you start next season. Review your recruits and next season's roster before then.\n\n" + Recruiting.deadline_text(d), [
		["REVIEW RECRUITS", func(): Game.goto("recruiting", {"tab": "PINNED" if not (d.pinned as Array).is_empty() else "MARKET"}), "primary"],
		["LATER", Callable(), "ghost"]])
	return true

## NEXT SEASON: says what happens (seniors leave, your signings join, cuts if it's over the cap),
## then runs the roster transition (Career.end_week). That transition closes recruiting: with
## anything unresolved (Recruiting.deadline) the FINAL RECRUITING WARNING comes first, RETURN TO
## RECRUITING (nothing changed) or CONTINUE TO OFFSEASON (the transition, as ever).
func _next_season() -> void:
	if busy or _process_queue() or c.game_over or Game.open_upgrades():
		return
	var go := func():
		if busy:
			return
		busy = true
		c.end_week()
		Game.save_career()
		Game.goto("hub", {}, false)
	var d := Recruiting.deadline(c)
	if bool(d.issues):
		Game.dialog("FINAL RECRUITING WARNING", "You are about to close the recruiting period.\n\n" + Recruiting.deadline_text(d) +
			"\n\nUnsigned recruits from this class will no longer be available after the recruiting period ends. Your %d signed recruit%s join as freshmen." % [
			c.incoming.size(), "" if c.incoming.size() == 1 else "s"], [
			["RETURN TO RECRUITING", func(): Game.goto("recruiting", {"tab": "PINNED" if not (d.pinned as Array).is_empty() else "MARKET"}), "primary"],
			["CONTINUE TO OFFSEASON", go, "ghost"]])
		return
	var over := Recruiting.over_by(c)
	var text := "Your %d senior%s graduate%s and your %d signed recruit%s join as freshmen. Projected roster: %d / %d." % [
		Recruiting.graduating(c).size(), "" if Recruiting.graduating(c).size() == 1 else "s", "s" if Recruiting.graduating(c).size() == 1 else "",
		c.incoming.size(), "" if c.incoming.size() == 1 else "s", Recruiting.projected(c), c.roster_max()]
	if over > 0:
		text += "\n\nYou will need to cut %d player%s before the season starts." % [over, "" if over == 1 else "s"]
	Game.dialog("START %s?" % c.next_season_label(), text, [
		["CONTINUE", go, "primary"],
		["NOT YET", Callable(), "ghost"]])

## After the season, over the cap: the cuts come before anything else (once the queue is done).
## True if they were opened.
func _open_cuts() -> bool:
	if c.phase != "cuts" or c.game_over:
		return false
	Game.goto("roster_cuts", {}, false)
	return true

# ------------------------------------------------------------------ a new division
## NEW DIVISION AVAILABLE!: a pack this account owns and this dynasty doesn't play, asked once
## (Career.div_answers, saved). ADD NEXT SEASON never changes the season under way. True if asked.
func _division_invite() -> bool:
	var due: Array = c.division_invites(func(d): return Store.division_owned(d))
	if due.is_empty():
		return false
	var d: int = due[0]
	var name := Colleges.division_name(d).capitalize().replace("Division Iii", "Division III").replace("Division Ii", "Division II")
	var answer := func(add: bool) -> void:
		c.answer_division(d, add)
		Game.save_career()
		_division_invite()
	Game.dialog("NEW DIVISION AVAILABLE!", "Would you like to add %s teams to this dynasty? The new schools will become active at the beginning of your next season." % name, [
		["ADD NEXT SEASON", answer.bind(true), "primary"], ["NOT NOW", answer.bind(false), "ghost"]])
	return true

# ------------------------------------------------------------------ the queue
## Shows the item at the front of the queue. It's only removed once the coach has dealt
## with it, so closing the app on a dialog (a job offer) shows it again next
## time. True if something was shown (the caller should wait).
func _process_queue() -> bool:
	if c.queue.is_empty():
		return false
	var q: Dictionary = c.queue[0]
	match String(q.type):
		"info":
			Game.dialog(q.title, q.text, [["OK", _next_item, "primary"]])
		"season":
			Game.dialog("%s SEASON" % c.season_label(), "A new season begins.\n\nNEW SEASON BONUS: %s" % CreditCoin.tag(int(q.get("bonus", 0)), true), [["LET'S GO", _next_item, "primary"]])
		"recap":
			Game.goto("recap", q)   # the recap screen removes it
		"offers":
			_offers_dialog(q.offers)
		"card":
			_card_dialog(q)
		"achievement":
			Game.achievement_dialog(q, _next_item)
		"awards":
			_awards_note(q)
		_:
			_drop_item()
			return _process_queue()
	return true

## The week's conference awards are out (ConfAwards): one of yours won one, a dialog (VIEW AWARDS);
## otherwise just a toast, and on with the queue.
func _awards_note(q: Dictionary) -> void:
	var mine: Array = q.get("mine", [])
	if mine.is_empty():
		Game.toast("%s CONFERENCE AWARDS ANNOUNCED" % String(q.get("label", "")))
		_next_item()
		return
	# THE WEEKLY AWARD CELEBRATION (WeeklyAwardShow): each of your winners in turn, from the award
	# records themselves; the queue item leaves (saved) only once the last is closed, so a reload
	# before then shows them again and never after
	var yr := int(q.get("year", c.year))
	var wk := int(q.get("week", 0))
	var recs: Array = c.conf_awards.filter(func(a): return not bool(a.get("hist", false)) and int(a.get("year", -1)) == yr and int(a.get("week", -1)) == wk and String(a.get("team", "")) == c.school)
	if recs.is_empty():
		_next_item()
		return
	WeeklyAwardShow.play(self, c, recs, _next_item)

## An event card: two choices, each a trade-off. The card leaves the queue the moment you
## choose, so its effects can never apply twice.
func _card_dialog(q: Dictionary) -> void:
	var cd := Moments.card(String(q.id))
	var p := c.team().find_id(int(q.get("pid", 0)))
	if cd.is_empty() or (p == null and String(cd.get("who", "any")) != "any"):
		_next_item()   # its player has left the program
		return
	var options: Array = []
	for ch in cd.choices:
		var choice: Dictionary = ch
		options.append([Moments.fill(String(choice.label), p), LockerData.chips(choice.effects), func():
			var cost := Career.cost_of(choice.effects)
			if cost > c.wallet():
				# it costs credits you don't have: the card stays until you can pay or pick the other
				StorePrompt.need(c, cost, "That choice", func(): _process_queue())
				return
			_drop_item()
			var lines := c.apply_effects(choice.effects, p)
			Game.save_career()
			var said := Moments.fill(String(choice.get("result", "")), p)
			if not lines.is_empty():
				said = " ".join(lines)
			Game.dialog(String(cd.title), said if said != "" else "Done.", [["OK", _after_choice, "primary"]])])
	_choice_dialog(String(cd.title), Moments.fill(String(cd.text), p), options)

## After a choice: the hub redraws (numbers changed) and the next queued thing shows.
func _after_choice() -> void:
	Game.goto("hub", {}, false)

## A dialog with one row per choice: the choice and what it does.
func _choice_dialog(title: String, text: String, options: Array) -> void:
	var layer := Game.dialog(title, text, [])
	var v: VBoxContainer = layer.get_child(1).get_child(0).get_child(0)
	for o in options:
		var cb: Callable = o[2]
		var row := UI.vbox(0)
		row.add_child(UI.label(String(o[0]), 8, UI.GOLD, "caps"))
		row.add_child(CreditCoin.rich("  " + ", ".join(o[1]), 8, UI.ACCENT))
		v.add_child(row_button(row, func():
			if not is_instance_valid(layer) or layer.is_queued_for_deletion():
				return   # one choice per dialog, even with two taps in the same frame
			layer.queue_free()
			Sfx.play("confirm")
			cb.call(), false, 24))

func _drop_item() -> void:
	if not c.queue.is_empty():
		c.queue.pop_front()
	Game.save_career()

func _next_item() -> void:
	_drop_item()
	if not _process_queue() and not _open_cuts():
		Game.open_upgrades()   # the queue's done: then the roster cuts, or any upgrades still to spend

## JOB OFFERS after a good season: take one, or STAY.
func _offers_dialog(offers: Array) -> void:
	if offers.is_empty():
		_next_item()
		return
	var lines := PackedStringArray()
	for id in offers:
		var t: PoloTeam = c.teams[id]
		lines.append("- %s (%s): school rating %d, %s pool" % [t.name, c.conf_name(t.conf), roundi(t.prestige), Pools.get_def(t.pool).name])
	var head := "Word gets around. These schools want you as their head coach:"
	var tail := "\n\nA new job means a new roster, new colours and a new home pool. Your staff come with you."
	var buttons: Array = []
	for id in offers:
		var tid: String = id
		buttons.append(["TAKE %s" % Colleges.short_name(c.teams[tid]).to_upper(), func():
			_drop_item()
			Offseason.take_job(c, tid)
			Game.save_career()
			Game.goto("hub", {}, false), "primary"])
	buttons.append(["STAY", _next_item, "ghost"])
	Game.dialog("JOB OFFERS", head + "\n\n" + "\n".join(lines) + tail, buttons)
