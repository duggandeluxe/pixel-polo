extends RefCounted
## The HOT SLOTS cap (PlayerForm.limit_hot / trim_hot: three hot players a team at most, a new
## one has to outplay a 1-star HOT player first, a VERY HOT one only when all three are VERY HOT)
## and the HOT / VERY HOT flame badge on the roster card (HotBadge).
##   godot --headless --path game -- --test hot_cap

const Roster := preload("res://src/ui/screens/roster.gd")
const HotBadge := preload("res://src/ui/hot_badge.gd")
const N := PlayerForm.NORMAL
const H := PlayerForm.HOT
const V := PlayerForm.VERY_HOT

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("hot cap")
	_fresh_career()
	_room()
	_priority()
	_ties_and_bench()
	_several()
	_trim_and_save()
	_graded()
	_badge()

## A fresh team, everyone NORMAL, no grades; its seven (keeper first) and the bench.
func _team() -> PoloTeam:
	var t := League.make_team(1, 1)
	for p: PoloPlayer in t.roster:
		PlayerForm.reset(p)
	return t

## Sets up one game: `held` {index in the seven: [heat, pm]} for the hot ones going in,
## `rising` {index: pm} NORMAL ones the game pushed to HOT; everyone else in the seven played
## at pm 0. Returns [rows, seven].
func _game(t: PoloTeam, held: Dictionary, rising: Dictionary) -> Array:
	var seven := t.starters()
	var rows: Array = []
	for i in seven.size():
		var p: PoloPlayer = seven[i]
		var pm := 0.0
		var before := N
		if held.has(i):
			p.heat = int(held[i][0])
			pm = float(held[i][1])
			before = PlayerForm.state_of(p.heat)
		elif rising.has(i):
			p.heat = 1
			pm = float(rising[i])
		rows.append({"p": p, "pm": pm, "raw": pm, "before": before})
	return [rows, seven]

func _fresh_career() -> void:
	var c := Career.new_setup(7)
	var hot := 0
	for id in c.teams:
		hot += PlayerForm.hot_count(c.teams[id])
	r.check(hot == 0, "a new career: no team starts with anyone hot")

func _room() -> void:
	var t := _team()
	var g := _game(t, {1: [1, 0.0], 2: [2, 0.0]}, {3: -2.0})
	var ch := PlayerForm.limit_hot(t, g[0])
	r.check(ch.is_empty() and (g[1][3] as PoloPlayer).heat == 1 and PlayerForm.hot_count(t) == 3,
		"two hot and one heating up: room for him, nobody else touched")
	t = _team()
	g = _game(t, {}, {1: 1.0, 2: 2.0, 3: 3.0})
	PlayerForm.limit_hot(t, g[0])
	r.check(PlayerForm.hot_count(t) == 3, "three heating up at once on an empty team: all three HOT")

func _priority() -> void:
	# full: two 1-star (pm 1, 3) and a VERY HOT who had a poor game (pm -5)
	var t := _team()
	var g := _game(t, {1: [1, 1.0], 2: [1, 3.0], 3: [2, -5.0]}, {4: 2.0})
	var s: Array = g[1]
	var ch := PlayerForm.limit_hot(t, g[0])
	r.check((s[4] as PoloPlayer).heat == 1 and (s[1] as PoloPlayer).heat == 0, "full team: the newcomer (PM 2) takes the lowest 1-star's spot (PM 1)")
	r.check((s[3] as PoloPlayer).heat == 2 and (s[2] as PoloPlayer).heat == 1, "...the VERY HOT one (PM -5) is never at risk while a 1-star is on the team")
	r.check(ch.size() == 1 and ch[0].in == s[4] and ch[0].out == s[1] and (g[0][1] as Dictionary).get("bumped_by") == s[4],
		"...and the change is reported (in, out, bumped_by on his row)")
	r.check(PlayerForm.hot_count(t) == 3, "...still three hot")
	# a 1-star who outscores the newcomer stays: no stepping over him to a VERY HOT
	t = _team()
	g = _game(t, {1: [1, 4.0], 2: [2, -3.0], 3: [2, -3.0]}, {4: 2.0})
	PlayerForm.limit_hot(t, g[0])
	r.check((g[1][4] as PoloPlayer).heat == 0 and (g[1][1] as PoloPlayer).heat == 1 and (g[1][2] as PoloPlayer).heat == 2,
		"the only 1-star outplayed him: he's shut out, even though both VERY HOT had worse games")
	# all three VERY HOT: now the lowest of them is the one to beat
	t = _team()
	g = _game(t, {1: [2, 1.0], 2: [2, 2.0], 3: [2, 3.0]}, {4: 1.5})
	PlayerForm.limit_hot(t, g[0])
	r.check((g[1][4] as PoloPlayer).heat == 1 and (g[1][1] as PoloPlayer).heat == 0 and (g[1][2] as PoloPlayer).heat == 2,
		"all three VERY HOT: the newcomer (PM 1.5) beats the lowest of them (PM 1), who goes back to NORMAL")
	t = _team()
	g = _game(t, {1: [2, 1.0], 2: [2, 2.0], 3: [2, 3.0]}, {4: 0.5})
	PlayerForm.limit_hot(t, g[0])
	r.check((g[1][4] as PoloPlayer).heat == 0 and PlayerForm.hot_count(t) == 3, "...and one who didn't outplay any of them gets nothing")

func _ties_and_bench() -> void:
	var t := _team()
	var g := _game(t, {1: [1, 2.0], 2: [1, 3.0], 3: [1, 4.0]}, {4: 2.0})
	var p: PoloPlayer = g[1][4]
	p.heat_bonus = 0.0
	var bonus := {p.id: 0.4}   # what he had before push_grade spent it on the rise
	PlayerForm.limit_hot(t, g[0], bonus)
	r.check(p.heat == 0 and (g[1][1] as PoloPlayer).heat == 1, "a tie (PM 2 against PM 2) doesn't take a spot")
	r.check(is_equal_approx(p.heat_bonus, 0.4) and PlayerForm.shut_out(p) and bool((g[0][4] as Dictionary).get("capped", false)),
		"...his HOT STAR PROGRESS is given back and he's marked shut out")
	p.form = [1, 1, 1]
	r.check(String(PlayerForm.momentum(p).next) == "OUTPLAY A HOT TEAMMATE", "...his card's back says what he needs now")
	# a hot player who didn't play the game can't be compared, so he can't be bumped
	t = _team()
	var seven := t.starters()
	var bench: Array = t.roster.filter(func(q): return not seven.has(q))
	r.check(not bench.is_empty(), "the team has a bench")
	(bench[0] as PoloPlayer).heat = 1
	g = _game(t, {1: [2, -4.0], 2: [2, -4.0]}, {4: 9.0})
	PlayerForm.limit_hot(t, g[0])
	r.check((g[1][4] as PoloPlayer).heat == 0 and (bench[0] as PoloPlayer).heat == 1 and (g[1][1] as PoloPlayer).heat == 2,
		"a 1-star on the bench (didn't play): not comparable, and the VERY HOT are still protected while he's 1-star")

func _several() -> void:
	# three 1-star (PM 1, 2, 3), three heating up (PM 5, 4, 2.5) in the same game
	var t := _team()
	var g := _game(t, {1: [1, 1.0], 2: [1, 2.0], 3: [1, 3.0]}, {4: 4.0, 5: 5.0, 6: 2.5})
	var s: Array = g[1]
	var ch := PlayerForm.limit_hot(t, g[0])
	r.check((s[5] as PoloPlayer).heat == 1 and (s[4] as PoloPlayer).heat == 1 and (s[1] as PoloPlayer).heat == 0 and (s[2] as PoloPlayer).heat == 0,
		"best first: PM 5 takes PM 1's spot, PM 4 takes PM 2's")
	r.check((s[6] as PoloPlayer).heat == 0 and (s[3] as PoloPlayer).heat == 1, "PM 2.5 can't beat PM 3 (and can't bump the two who just came in)")
	var outs := ch.filter(func(c): return c.out != null).map(func(c): return (c.out as PoloPlayer).id)
	var uniq := {}
	for id in outs:
		uniq[id] = true
	r.check(outs.size() == 2 and uniq.size() == 2 and PlayerForm.hot_count(t) == 3, "nobody is replaced twice, and the team ends on three")
	# a free slot goes to the best of them, not the first in the lineup
	t = _team()
	g = _game(t, {1: [2, 0.0], 2: [2, 0.0]}, {3: 1.0, 4: 6.0})
	PlayerForm.limit_hot(t, g[0])
	r.check((g[1][4] as PoloPlayer).heat == 1 and (g[1][3] as PoloPlayer).heat == 0,
		"one free spot, two heating up: the better game (PM 6) gets it; the other has only a fresh 1-star to beat, who's protected")

func _trim_and_save() -> void:
	var t := _team()
	var s := t.starters()
	var heats := [0, 1, 2, 1, 2, 1, 0]
	for i in s.size():
		(s[i] as PoloPlayer).heat = heats[i]
		(s[i] as PoloPlayer).last_game = {"pm": float(i)}
	r.check(PlayerForm.trim_hot(t) and PlayerForm.hot_count(t) == 3, "an old save with five hot: trimmed to three")
	r.check((s[2] as PoloPlayer).heat == 2 and (s[4] as PoloPlayer).heat == 2 and (s[5] as PoloPlayer).heat == 1 and (s[1] as PoloPlayer).heat == 0,
		"...the two VERY HOT kept, then the 1-star with the better last game")
	(s[3] as PoloPlayer).form = [1, 1, 1, 0]
	var back := PoloTeam.from_dict(t.to_dict())
	var same := true
	for p: PoloPlayer in t.roster:
		var q := back.find_id(p.id)
		same = same and q != null and q.heat == p.heat and q.form == p.form
	r.check(same and PlayerForm.hot_count(back) == 3, "saved and loaded: the same three hot at the same levels, everyone's grades kept")

## The real thing: a game graded by grade_team on a team already full of 1-star players.
func _graded() -> void:
	var t := _team()
	var s := t.starters()
	for i in [1, 2, 3]:
		(s[i] as PoloPlayer).form = [1, 1, 1]
		(s[i] as PoloPlayer).heat = 1
	var star: PoloPlayer = s[4]
	star.form = [1, 1]
	var lines := {}
	for p: PoloPlayer in s:
		lines[p.id] = {"gk": true, "sv": 0, "ga": 0} if p.is_keeper() else {"g": 0, "sh": 0}
	lines[star.id] = {"g": 5, "sh": 5}
	var rows := PlayerForm.grade_team(t, lines, {})
	r.check(star.heat == 1 and PlayerForm.hot_count(t) == 3, "a big game (GOOD, his third) on a full team: he's HOT, the team still three")
	var bumped := rows.filter(func(w): return w.get("bumped_by") == star)
	r.check(bumped.size() == 1 and (bumped[0].p as PoloPlayer).heat == 0 and String(bumped[0].after) == N and (bumped[0].p as PoloPlayer).form.size() == 4,
		"...one 1-star lost his spot to him: NORMAL on the summary row, his grades kept")
	var mine: Array = rows.filter(func(w): return w.p == star)
	r.check(String(mine[0].before) == N and String(mine[0].after) == H, "...his row reads NORMAL to HOT (the postgame reveal shows it)")

func _badge() -> void:
	var at := Vector2(Roster.STAR_X, Roster.STAR_Y)
	for st in [H, V]:
		var b := HotBadge.rect(at, 3.0, 4.0, st)
		r.check(b.size.x > 0.0 and b.position.y > Roster.SPLIT and b.end.y < Roster.XP_Y, "%s fire: round his red stars, under the divider, clear of the XP bar" % st)
		r.check(b.position.x >= 1.0 and b.end.x <= Roster.CARD.x - 1.0, "%s fire: inside the card's border" % st)
	r.check(HotBadge.rect(at, 3.0, 4.0, V).size.y > HotBadge.rect(at, 3.0, 4.0, H).size.y and HotBadge.rect(at, 3.0, 4.0, N) == Rect2(), "VERY HOT burns bigger; NORMAL has no fire")
	r.check(HotBadge.red_places(3.0, 4.0, V) == [3, 4] and HotBadge.red_places(3.0, 4.0, H) == [3], "the fire sits on exactly his red stars")
	r.check(HotBadge.frame() == 0 and HotBadge.anim_step() == -1,
		"no motion in tests (as with Reduce Motion): the fire holds still")
	r.check(HotBadge.frame(0.0) != HotBadge.frame(HotBadge.FLICKER), "...with motion it flickers")
