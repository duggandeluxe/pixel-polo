extends RefCounted
## SIM PARITY: your team, simulated (SIM THIS GAME), plays exactly as well as an AI team of the
## same strength. The same school, the same seeds, once as yours and once as the AI's: its results
## and its strength through the season must match closely. Your upgrades are spent each week, as
## the game makes you before every game (AI programs spend theirs at once: Development.ai_spend);
## left unspent, your team falls behind (measured 2026-10-30: 40 seasons, wins 0.85 / 0.85,
## conference finals 0.70 / 0.75, the same when spent).
##   godot --headless --path game -- --test sim_parity

var r   # the test runner

const SEEDS := 16
const SCHOOL := "CULA"
const OTHER := "ALC"   # (the career is coached here when the CULA side is the AI's)

func run(runner) -> void:
	r = runner
	print("sim parity")
	Store.reset_for_tests()
	var mine := _seasons(SCHOOL)
	var ai := _seasons(OTHER)

	for k in mine:
		print("    %-14s as yours %7.2f   as AI %7.2f" % [k, float(mine[k]) / SEEDS, float(ai[k]) / SEEDS])
	r.check(absf(float(mine.win_pct) - float(ai.win_pct)) / SEEDS < 0.08, "your simmed team wins as often as the same AI team (%.2f vs %.2f)" % [float(mine.win_pct) / SEEDS, float(ai.win_pct) / SEEDS])
	r.check(absf(float(mine.gd) - float(ai.gd)) / SEEDS < 1.0, "...by the same margins (%.2f vs %.2f a game)" % [float(mine.gd) / SEEDS, float(ai.gd) / SEEDS])

## Simulates the regular season with `coach` as your school; CULA's numbers, summed over SEEDS.
func _seasons(coach: String, spend := true) -> Dictionary:
	var out := {"final": 0.0, "semi_w": 0.0, "semi_n": 0.0, "win_pct": 0.0, "gd": 0.0, "ovr_start": 0.0, "ovr_end": 0.0, "hurt_starters": 0.0, "tokens": 0.0, "heat": 0.0}
	for sd in range(500, 500 + SEEDS):
		Game.progress = Progression.fresh()
		var c := Career.new_game(coach, "A", "B", sd)
		Game.career = c
		c.queue.clear()
		var t: PoloTeam = c.teams[SCHOOL]
		out.ovr_start += t.team_overall(false)
		var w := 0
		var l := 0
		var gd := 0
		var hurt := 0
		var tok := 0
		var heat := 0
		var looks := 0
		var guard := 0
		while c.week < 13 and guard < 40 and not c.in_offseason():
			guard += 1
			while c.has_game():
				c.sim_my_game()
			c.queue.clear()
			# (the coach spends his upgrades, as the game makes him before every game)
			for p in (c.team().roster if spend else []):
				while Development.pending(p) > 0:
					var spent := false
					for k in p.key_ratings():
						if Development.spend(p, k):
							spent = true
							break
					if not spent:
						break
			looks += 1
			hurt += t.starters().filter(func(p): return p.is_injured()).size()
			tok += t.roster.reduce(func(a, p): return a + Development.pending(p), 0)
			heat += t.starters().reduce(func(a, p): return a + p.heat, 0)
			c.end_week()
		for rd in c.schedule.slice(0, 10):
			for g in rd.games:
				if g.r == null or (g.h != SCHOOL and g.a != SCHOOL):
					continue
				var home: bool = g.h == SCHOOL
				var us: int = int(g.r.s[0 if home else 1])
				var them: int = int(g.r.s[1 if home else 0])
				gd += us - them
				if Schedule.winner(g) == SCHOOL:
					w += 1
				else:
					l += 1
		for rd in c.schedule:
			if rd.kind == "conf_semi":
				for g in rd.games:
					if g.r != null and (g.h == SCHOOL or g.a == SCHOOL):
						out.semi_n += 1.0
						out.semi_w += 1.0 if Schedule.winner(g) == SCHOOL else 0.0
			if rd.kind == "conf_final":
				for g in rd.games:
					if g.r != null and (g.h == SCHOOL or g.a == SCHOOL):
						out.final += 1.0
		out.win_pct += float(w) / maxf(1.0, w + l)
		out.gd += float(gd) / maxf(1.0, w + l)
		out.ovr_end += t.team_overall(false)
		out.hurt_starters += float(hurt) / maxf(1.0, looks)
		out.tokens += float(tok) / maxf(1.0, looks)
		out.heat += float(heat) / maxf(1.0, looks)
	Game.career = null
	return out
