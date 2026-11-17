extends BaseScreen
## Developer Mode's COACHING EVENTS (Settings > Developer Mode): the whole CoachEvents system in
## one place, read from the system itself (its EVENTS, ELIGIBILITY, weights and stakes(): never a
## second copy that could drift).
##   EVENTS             every event (left), the selected one in full (right): who and when, how
##                      often, both answers with the rewards, costs and failure penalties
##                      stakes() shows in the game, and its special version (when it has one)
##                      PREVIEW EVENT   the real event screen on a COPY of your career (or a
##                                      labelled mock one): nothing is applied, saved or used up
##                      TRIGGER EVENT   a real event in your save (after a warning): answered on
##                                      the real screen, applied by apply(), settled by your next
##                                      game like any other; NORMAL or SPECIAL (3X) for the four
##                                      that have one; IGNORE REQUIREMENTS skips the last game's
##                                      conditions, never the safety rules (a real player on your
##                                      roster, free, a legal lineup, a next game, the credits)
##   ACTIVE CHALLENGES  Career.coach_pending as saved; SIMULATE SUCCESS / FAILURE settles one on
##                      a throwaway copy of the career with labelled test inputs (award_game, the
##                      real calculation): what it would pay, nothing saved, the real one still
##                      waits for your next game
##   CHALLENGE ANIMATIONS  the CHALLENGE RESULT popup (ChallengeShow) for every statistical
##                      challenge: a player, NORMAL / SPECIAL, the target, the line he had (goals,
##                      assists, saves, steals, blocks) and the result entered by hand; PREVIEW
##                      RESULT settles it with award_game on a throwaway copy (the game's own
##                      evaluation), SUCCESS / FAILURE load a passing / failing case, REPLAY
##                      plays the last again. Nothing is ever saved
##   HISTORY            this session's decisions (CoachEvents.decisions, never saved) and the
##                      saved settled results (Career.coach_results)
##   GENERATION         the chances and weights roll() uses (shown, never changed)

const RED := Color("ff5a5a")
const TABS := [["EVENTS", "EVENTS"], ["ACTIVE", "ACTIVE CHALLENGES"], ["ANIM", "CHALLENGE ANIMATIONS"], ["HISTORY", "HISTORY"], ["GENERATION", "GENERATION"]]
## CHALLENGE ANIMATIONS: the events whose risky choice sets a statistical objective (THE BIG
## RIVALRY only in its special version), [id, special only].
const ANIM_EVENTS := [["star_in_making", false], ["backup_breakout", false], ["keeper_confidence", false], ["rough_night", false],
	["defensive_masterclass", false], ["big_rivalry", true], ["learning_experience", false], ["cost_of_victory", false]]
const INPUT_NAMES := {"g": "GOALS", "a": "ASSISTS", "sv": "SAVES", "st": "STEALS", "bl": "BLOCKS"}
const CLS := ["", "FR", "SO", "JR", "SR"]

static var tab := "EVENTS"
static var sel := "star_in_making"
static var special := false
static var pick_pid := -1
static var ignore_reqs := false
static var sim_out: Dictionary = {}   # eid: the last simulation's lines
static var _mock: Career = null
static var anim_sel := "star_in_making"
static var anim_sp := false
static var anim_pid := -1
static var anim_vals: Dictionary = {}   # the entered line: {g, a, sv, st, bl}
static var anim_stat := ""              # ...for this objective (reset when it changes)
static var anim_target := -1            # the target (-1: the event's own)
static var anim_won := true
static var anim_last: Dictionary = {}   # the last preview: {res, career, mock} (REPLAY)

func _ready() -> void:
	if not bool(Game.settings.get("dev_mode", false)):
		Game.goto("settings", {}, false)
		return
	build("COACHING EVENTS - DEVELOPER")
	_refresh()

func on_back() -> void:
	Sfx.play("back")
	Game.back("dev_settings")   # (as every Developer Mode lab)

func _refresh() -> void:
	for ch in body.get_children():
		body.remove_child(ch)
		ch.queue_free()
	var tr := UI.hbox(2)
	tr.name = "Tabs"
	for t in TABS:
		var id: String = t[0]
		var b := UI.button(String(t[1]), func():
			tab = id
			_refresh(), "tab_on" if tab == id else "tab", 0, 16)
		b.name = "Tab_" + id
		tr.add_child(b)
	body.add_child(tr)
	match tab:
		"ACTIVE": _active_tab()
		"HISTORY": _history_tab()
		"GENERATION": _generation_tab()
		"ANIM": _anim_tab()
		_: _events_tab()

# ------------------------------------------------------------------ the data (static: tested)
## The career the panel describes: yours, else a mock one (no career loaded).
static func display_career() -> Career:
	return Game.career if Game.career != null else mock_career()

## A throwaway career for previews with nobody eligible (made once a session, never Game.career,
## never saved): MOCK DATA.
static func mock_career() -> Career:
	if _mock == null:
		_mock = Career.new_game("SJCU", "DEV", "LAB", 4242)
		_mock.queue.clear()
	return _mock

static func needs_player(id: String) -> bool:
	return id != "recruiting_ripple"

## Who can safely carry event `id` now: on your roster, not suspended, nothing else riding on him,
## and the event's role (a keeper; a legal substitute; the team leader; a field starter whose
## suspension leaves a legal seven; a backup who can legally start).
static func candidates(c: Career, id: String) -> Array:
	if c == null or not needs_player(id):
		return []
	var t := c.team()
	if id in ["captains_speech", "big_rivalry"]:
		var lead := CoachEvents.leader(c)
		return [lead] if lead != null and CoachEvents._free(c, lead.id) else []
	var seven := t.starters()
	var out: Array = []
	for p: PoloPlayer in t.roster:
		if p.is_suspended() or not CoachEvents._free(c, p.id):
			continue
		var ok := true
		match id:
			"keeper_confidence":
				ok = p.is_keeper()
			"backup_breakout":
				ok = not p in seven and not p.is_injured()
			"practice_discipline":
				ok = p in seven and not p.is_keeper() and CoachEvents.suspension_ok(t, p) != null
			"prove_me_wrong":
				ok = not p in seven and not p.is_injured() and not CoachEvents.promotion(t, p).is_empty()
		if ok:
			out.append(p)
	return out

## when() on the last game without touching the career's dice (two of the checks draw from c.rng).
static func when_safe(c: Career, id: String, rv: Dictionary) -> Dictionary:
	if rv.is_empty():
		return {}
	var st := c.rng.state
	var ctx := CoachEvents.when(id, c, rv)
	c.rng.state = st
	return ctx

## Event `id` as the game would make it: from the last game's real conditions (when()), or, with
## `ignore` on, for player `pid` (his real roster, the last game's line if he played in it,
## anything else labelled a developer test). NORMAL or SPECIAL (only the four that have one).
## Marked dev. {"error": why} when it can't be made.
static func build_event(c: Career, id: String, pid: int, sp: bool, ignore: bool) -> Dictionary:
	if CoachEvents.scenario(id).is_empty():
		return {"error": "NO SUCH EVENT"}
	var rv: Dictionary = CoachEvents.last_review
	var ctx := {}
	if not ignore:
		if rv.is_empty():
			return {"error": "NO RECENT GAME IN MEMORY: PLAY ONE, OR IGNORE THE REQUIREMENTS"}
		ctx = when_safe(c, id, rv)
		if ctx.is_empty():
			return {"error": "THE LAST GAME DOESN'T MEET ITS REQUIREMENTS"}
	else:
		var p: PoloPlayer = null
		if needs_player(id):
			p = c.team().find_id(pid)
			if p == null or not p in candidates(c, id):
				return {"error": "PICK AN ELIGIBLE PLAYER"}
		ctx = _dev_ctx(c, id, p, rv)
	ctx["id"] = id
	ctx["story"] = 0
	ctx["special"] = sp and CoachEvents.SPECIAL.has(id)
	ctx["dev"] = true
	var players: Array = rv.get("players", [])
	ctx["pids"] = players.map(func(pl): return int(pl.pid)) if not players.is_empty() else c.team().starters().map(func(q): return q.id)
	ctx["field"] = players.filter(func(pl): return not pl.gk).map(func(pl): return int(pl.pid))
	ctx["year"] = c.year
	ctx["week"] = c.week
	return ctx

## An event's context for player `p`, its conditions ignored: his real name, class and form; his
## line from the last game if he played in it; the rest of the story's details marked as a test.
static func _dev_ctx(c: Career, id: String, p: PoloPlayer, rv: Dictionary) -> Dictionary:
	var t := c.team()
	var pl: Dictionary = CoachEvents._pl(rv, p.id) if p != null else {}
	var vars := CoachEvents._vars(c, pl, rv, p)
	if rv.is_empty():
		vars["score"] = "(dev test)"
	if not vars.has("line"):
		vars["line"] = "no recorded game (developer test)"
		vars["saves"] = "0"
		vars["save_pct"] = "0"
	var ctx := {"vars": vars}
	if p != null:
		ctx["pid"] = p.id
	match id:
		"rough_night":
			vars["rough"] = "(Developer test: no rough game required.)"
		"defensive_masterclass":
			vars["opp_goals"] = "them (developer test)"
		"recruiting_ripple":
			vars["feat"] = "(Developer test: no streak or big win required.)"
		"big_rivalry":
			var ng := c.next_game()
			var opp := String(ng.get("opp", ""))
			vars["opp"] = Colleges.display_name((c.teams[opp] as PoloTeam).name).to_upper() if c.teams.has(opp) else "YOUR NEXT OPPONENT"
			vars["why"] = "(Developer test: no rivalry required.)"
			ctx["opp"] = opp
		"learning_experience":
			var bad := p.form.filter(func(x): return int(x) == PlayerForm.BAD).size()
			vars["form"] = "%d BAD grade%s in his last %d games" % [bad, "" if bad == 1 else "s", p.form.size()]
		"cost_of_victory":
			var others: Array = t.starters().filter(func(q: PoloPlayer): return q != p and not q.is_suspended())
			others.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.overall() > b.overall())
			var heavy: Array = [p] + others.slice(0, 2)
			ctx["heavy"] = heavy.map(func(q: PoloPlayer): return q.id)
			vars["heavy"] = ", ".join(heavy.map(func(q: PoloPlayer): return q.short_name().to_upper()))
		"prove_me_wrong":
			var pr := CoachEvents.promotion(t, p)
			vars["pos"] = p.pos_long().to_lower()
			vars["displaced"] = (t.find_id(int(pr.displaced)) as PoloPlayer).short_name().to_upper()
			ctx["place"] = int(pr.place)
			ctx["displaced"] = int(pr.displaced)
	return ctx

## Why TRIGGER EVENT can't make event `id` for real now ("" when it can): the safety rules.
static func trigger_block(c: Career, id: String, pid: int, ignore: bool) -> String:
	if c == null:
		return "NO CAREER LOADED: TRIGGER NEEDS YOUR SAVE"
	if not c.pending_event.is_empty():
		return "A REAL COACHING EVENT IS WAITING: ANSWER IT FIRST"
	if not c.last_summary.is_empty():
		return "A POSTGAME IS OPEN: FINISH IT FIRST"
	if not CoachEvents._next_game(c):
		return "NO NEXT GAME: NOTHING CAN RIDE ON IT"
	if id == "prove_me_wrong" and not c.coach_pending.is_empty():
		return "PROVE ME WRONG NEEDS NOTHING ELSE RIDING ON THE NEXT GAME"
	var ev := build_event(c, id, pid, false, ignore)
	if ev.has("error"):
		return String(ev.error)
	if needs_player(id) and not candidates(c, id).any(func(q: PoloPlayer): return q.id == int(ev.get("pid", -1))):
		return "THAT PLAYER CAN'T TAKE THIS EVENT NOW"
	return ""

## A real event into the save (the warning already given): the event screen answers it.
static func trigger(c: Career, id: String, pid: int, sp: bool, ignore: bool) -> bool:
	if trigger_block(c, id, pid, ignore) != "":
		return false
	c.pending_event = build_event(c, id, pid, sp, ignore)
	Game.save_career()
	Game.goto("coach_event", {"review": false, "back_to": "coach_lab"})
	return true

## PREVIEW EVENT's screen parameters: the event on a copy of your career (the last game's real
## conditions if they hold, else the selected player's test version), or on the mock career when
## nobody of yours can take it (or no career is loaded).
static func preview_params(id: String, pid: int, sp: bool, ignore: bool) -> Dictionary:
	var is_mock := Game.career == null
	var c2: Career = mock_career() if is_mock else Career.from_dict(Game.career.to_dict())
	var ev := {"error": "mock"}
	if not is_mock:
		ev = build_event(c2, id, pid, sp, ignore)
		if ev.has("error"):
			var cands := candidates(c2, id)
			var use := pid if cands.any(func(q: PoloPlayer): return q.id == pid) else ((cands[0] as PoloPlayer).id if not cands.is_empty() else -1)
			if not needs_player(id) or use >= 0:
				ev = build_event(c2, id, use, sp, true)
		if ev.has("error"):
			is_mock = true
			c2 = mock_career()
	if is_mock:
		var mc := candidates(c2, id)
		ev = build_event(c2, id, (mc[0] as PoloPlayer).id if not mc.is_empty() else -1, sp, true)
	ev.erase("dev")   # (a preview is never a triggered event)
	return {"preview": ev, "career": c2, "mock": is_mock, "back_to": "coach_lab"}

## A sample of event `id` to read its stakes from (the selected player's, else the first who can).
static func sample(c: Career, id: String, pid: int, sp: bool) -> Dictionary:
	var cands := candidates(c, id)
	var use := pid if cands.any(func(q: PoloPlayer): return q.id == pid) else ((cands[0] as PoloPlayer).id if not cands.is_empty() else -1)
	if needs_player(id) and use < 0:
		c = mock_career()
		cands = candidates(c, id)
		use = (cands[0] as PoloPlayer).id if not cands.is_empty() else -1
	var ev := build_event(c, id, use, sp, true)
	ev["career"] = c
	return ev

## SIMULATE SUCCESS / FAILURE: pending consequence `eid` settled by award_game on a throwaway
## copy of the career, from labelled test inputs (the seven play; his target made, or missed by
## one; the result to match). Nothing in the save changes. {lines: [[text, kind]], outcome} or {error}.
static func simulate(c: Career, eid: int, success: bool) -> Dictionary:
	var c2 := Career.from_dict(c.to_dict())
	var e = null
	for x in c2.coach_pending:
		if int(x.get("eid", -1)) == eid:
			e = x
	if e == null:
		return {"error": "NO SUCH CHALLENGE"}
	c2.coach_pending = [e]   # (this one alone)
	var t := c2.team()
	var k := String(e.k)
	var pid := int(e.get("pid", -1))
	var him := t.find_id(pid)
	var played: Array = t.starters().duplicate()
	if k in ["chal", "result", "learn"] and him != null and not him in played and not him.is_suspended():
		played.append(him)
	if k == "susp":
		var rep := t.find_id(int(e.get("rep", -1)))
		played = played.filter(func(q: PoloPlayer): return success or rep == null or q != rep)
		if success and rep != null and not rep in played:
			played.append(rep)
	var lines := {}
	for q: PoloPlayer in played:
		lines[q.id] = {"sv": 6, "ga": 7} if q.is_keeper() else {}
	var inputs := "%d PLAYED" % played.size()
	if e.has("stat") and lines.has(pid):
		var v := int(e.n) if success else maxi(0, int(e.n) - 1)
		var key := {"ga": "g", "stbl": "st"}.get(String(e.stat), String(e.stat)) as String
		lines[pid][key] = v
		inputs += ", %s %d %s (TARGET %d)" % [CoachEvents._name(c2, pid), v, String(e.stat).to_upper(), int(e.n)]
	var won := success and k != "learn"
	inputs += ", %s" % ("WON" if won else "LOST")
	var w0 := c2.credits
	var x0 := CoachEvents.xp_sum(t)
	var h0 := him.heat_bonus if him != null else 0.0
	var s0 := him.susp if him != null else 0
	var got := CoachEvents.award_game(c2, t, lines, won)
	var res: Dictionary = c2.coach_results.back() if not c2.coach_results.is_empty() else {}
	var out: Array = [["TEST INPUTS, NOT A REAL GAME: %s" % inputs, "info"],
		["OUTCOME: %s - %s" % [String(res.get("outcome", "?")).to_upper(), String(res.get("note", ""))], "good" if res.get("outcome") == "ok" else "bad"]]
	for ln in res.get("lines", []):
		if String(ln[0]) != "":
			out.append([String(ln[0]).to_upper(), String(ln[1])])
	if got.has(pid):
		var g: Dictionary = got[pid]
		out.append(["%s GAME XP: %d -> %d%s" % [CoachEvents._name(c2, pid), int(g.get("base", g.xp)), int(g.xp), (" (%s)" % CoachEvents.mx(float(g.mult))) if g.has("mult") else ""], "info"])
	out.append(["TEAM XP IN ALL: %+d   %+d{coin}" % [CoachEvents.xp_sum(t) - x0, c2.credits - w0], "info"])
	if him != null and not is_equal_approx(him.heat_bonus, h0):
		out.append(["%s HOT STAR PROGRESS: %+d%%" % [CoachEvents._name(c2, pid), roundi((him.heat_bonus - h0) / PlayerForm.HOT_AT * 100.0)], "info"])
	if him != null and s0 > 0:
		out.append(["%s SUSPENSION: %d -> %d GAME%s" % [CoachEvents._name(c2, pid), s0, him.susp, "" if him.susp == 1 else "S"], "info"])
	out.append(["A COPY: NOTHING SAVED. THE REAL CHALLENGE STILL WAITS FOR YOUR NEXT GAME.", "info"])
	return {"lines": out, "outcome": String(res.get("outcome", "")), "got": got, "copy": c2}

## Event `id`'s risky choice sets a statistical objective (the CHALLENGE RESULT popup's kind):
## every challenge but THE CAPTAIN'S SPEECH, RECRUITING RIPPLE, PRACTICE DISCIPLINE, PROVE ME
## WRONG and THE BIG RIVALRY's win-only version.
static func stat_challenge(id: String, sp: bool) -> bool:
	if id == "big_rivalry":
		return sp
	return id in ["star_in_making", "backup_breakout", "keeper_confidence", "rough_night", "defensive_masterclass", "learning_experience", "cost_of_victory"]

## PREVIEW SUCCESS / FAILURE / 3X SUCCESS: the risky choice made and settled on a throwaway copy
## of your career (or the mock one), from labelled test inputs (simulate): the very result the
## popup would get. {res, career} or {error}. Nothing in the save changes.
static func preview_result(id: String, pid: int, success: bool, sp: bool) -> Dictionary:
	var st := anim_setup(id, pid, sp)
	if st.has("error"):
		return st
	var n := int(st.ch.n)
	return preview_custom(id, pid, sp, case_vals(String(st.ch.stat), n, success or id == "big_rivalry"), case_won(id, success), -1)

## A copy of your career (or the mock one) with nothing riding on anyone, event `id` made for
## `pid` (or the first who can take it), and its objective: {c2, ev, ch, mock} or {error}.
static func anim_setup(id: String, pid: int, sp: bool) -> Dictionary:
	if not stat_challenge(id, sp):
		return {"error": "NO STATISTICAL CHALLENGE"}
	var mock := Game.career == null
	var c2 := Career.from_dict((mock_career() if mock else Game.career).to_dict())
	c2.coach_pending = []
	c2.pending_event = {}
	var cands := candidates(c2, id)
	if cands.is_empty() and not mock:
		mock = true
		c2 = Career.from_dict(mock_career().to_dict())
		c2.coach_pending = []
		cands = candidates(c2, id)
	if cands.is_empty():
		return {"error": "NOBODY CAN TAKE IT"}
	var field: Array = cands.filter(func(q: PoloPlayer): return not q.is_keeper())
	var first: PoloPlayer = field[0] if not field.is_empty() and id != "keeper_confidence" else cands[0]   # (a field player first: a keeper's is the saves version)
	var use: int = pid if cands.any(func(q: PoloPlayer): return q.id == pid) else first.id
	var ev := build_event(c2, id, use, sp, true)
	if ev.has("error"):
		return ev
	return {"c2": c2, "ev": ev, "ch": CoachEvents.challenge(c2, ev), "mock": mock, "pid": use}

## A passing (or failing: one short) line for an objective: combined ones split between the two.
static func case_vals(stat: String, n: int, ok: bool) -> Dictionary:
	var v := n if ok else maxi(0, n - 1)
	match stat:
		"ga": return {"g": ceili(v / 2.0), "a": v / 2}
		"stbl": return {"st": ceili(v / 2.0), "bl": v / 2}
	return {stat: v}

## The game's result for a passing (failing) case: THE LEARNING EXPERIENCE is lost either way, a
## LEGENDARY LEADER's failure is a loss; anything else, a win.
static func case_won(id: String, ok: bool) -> bool:
	match id:
		"learning_experience": return false
		"big_rivalry": return ok
	return true

## PREVIEW RESULT: the risky choice made on a throwaway copy and settled by CoachEvents.award_game
## (the game's own evaluation and payout) from the line entered (`vals`), the result (`won`) and
## the target (`target`, -1 the event's): the very result the popup gets after a real game.
## {res, career, mock} or {error}; {res, ..., popup: false} when the game wouldn't show one.
## Nothing in the save changes: temporary copies only.
static func preview_custom(id: String, pid: int, sp: bool, vals: Dictionary, won: bool, target: int) -> Dictionary:
	var st := anim_setup(id, pid, sp)
	if st.has("error"):
		return st
	var c2: Career = st.c2
	CoachEvents.apply(c2, st.ev, 1)
	if c2.coach_pending.is_empty():
		return {"error": "NO CHALLENGE MADE"}
	var e: Dictionary = c2.coach_pending.back()
	if target > 0:
		e["n"] = target
	var t := c2.team()
	var who := int(st.pid)
	var him := t.find_id(who)
	var played: Array = t.starters().duplicate()
	if him != null and not him in played:
		played.append(him)
	var lines := {}
	for q: PoloPlayer in played:
		lines[q.id] = {"sv": 6, "ga": 7} if q.is_keeper() else {}
	var mine := {}
	for k in vals:
		mine[k] = maxi(0, int(vals[k]))
	if him != null and him.is_keeper() and not mine.has("ga"):
		mine["ga"] = 7
	lines[who] = mine
	CoachEvents.award_game(c2, t, lines, won)
	var res: Dictionary = c2.coach_results.back()
	return {"res": res, "career": c2, "mock": bool(st.mock), "popup": CoachEvents.is_stat_result(res)}

func _preview_result(success: bool, sp: bool) -> void:
	_show_preview(preview_result(sel, pick_pid, success, sp))

## Plays a preview's result on the real popup (marked), and remembers it for REPLAY.
func _show_preview(pr: Dictionary) -> void:
	if pr.has("error"):
		Game.toast(String(pr.error), RED)
		return
	if not bool(pr.get("popup", true)):
		Game.toast("%s: NO POPUP IN THE GAME (%s)" % [String(pr.res.outcome).to_upper(), String(pr.res.note)], UI.GOLD)
		return
	anim_last = pr
	ChallengeShow.play(self, pr.career, [pr.res], Callable(), null, "DEVELOPER PREVIEW - TEST INPUTS, NOTHING APPLIED" + ("  |  MOCK DATA" if pr.mock else ""))

## A pending consequence's reward and its penalty, in words, from what's saved with it.
static func reward_of(e: Dictionary) -> String:
	match String(e.get("k", "")):
		"team": return "+%d XP EACH TO ALL WHO PLAY" % int(e.get("xp", 0))
		"invest": return "+%d{coin}" % int(e.get("coins", 0))
		"pmw": return "TEAM %s GAME XP, HIM %s" % [CoachEvents.mx(CoachEvents.PMW_WIN), CoachEvents.mx(CoachEvents.MULT_2X)]
		"susp": return "REPLACEMENT %s GAME XP IF HE PLAYS" % CoachEvents.mx(float(e.get("mult", 2.0)))
	var hot := ", +%d%% HOT STAR PROGRESS" % CoachEvents._pp(float(e.get("hot_gain", e.get("hot_loss", 0.0)))) if e.has("hot_gain") or e.has("hot_loss") else ""
	if e.has("xp"):
		return "+%d XP" % int(e.xp) + hot
	if e.has("mult"):
		return "%s GAME XP" % CoachEvents.mx(float(e.mult)) + hot
	return "-"

static func penalty_of(e: Dictionary) -> String:
	match String(e.get("k", "")):
		"invest": return "THE %d{coin} ARE GONE" % CoachEvents.COINS.ripple_cost
		"pmw": return "TEAM %s GAME XP, HIS XP BAR RESET" % CoachEvents.mx(CoachEvents.PMW_LOSS)
		"susp": return "NONE (HE SERVES THE GAME)"
	var out := "%s GAME XP" % CoachEvents.mx(float(e.fail_mult)) if e.has("fail_mult") else "NONE (NORMAL GAME XP)"
	if e.has("hot_loss"):
		out += ", -%d%% HOT STAR PROGRESS" % CoachEvents._pp(float(e.hot_loss))
	return out

static func target_of(e: Dictionary) -> String:
	match String(e.get("k", "")):
		"susp": return "YOUR NEXT GAME (HE SITS IT)"
		"chal":
			if bool(e.get("wait", false)):
				return "THE NEXT GAME HE PLAYS (%d OF %d WAITED)" % [int(e.get("games", 0)), CoachEvents.WAIT_GAMES]
	return "YOUR NEXT GAME"

static func player_text(p: PoloPlayer) -> String:
	return "#%d %s  %s  %s" % [p.number, p.short_name().to_upper(), Deck.pos_tag(p), CLS[clampi(p.year, 0, 4)]]

# ------------------------------------------------------------------ EVENTS
func _events_tab() -> void:
	var dc := display_career()
	var cands := candidates(Game.career, sel)
	if not cands.is_empty() and not cands.any(func(q: PoloPlayer): return q.id == pick_pid):
		pick_pid = (cands[0] as PoloPlayer).id   # (the selection stays someone who can take it)
	var split := UI.hbox(4)
	split.name = "Split"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var list := UI.vbox(1)
	list.name = "EventList"
	for i in CoachEvents.EVENTS.size():
		var sc: Dictionary = CoachEvents.EVENTS[i]
		var id := String(sc.id)
		var h := UI.hbox(2)
		var nl := UI.label("%d %s" % [i + 1, String(sc.headline)], 8, UI.GOLD if id == sel else UI.TEXT, "caps")
		nl.clip_text = true
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		if CoachEvents.SPECIAL.has(id):
			h.add_child(UI.label("3X", 8, UI.GOLD, "caps"))
		var b := row_button(h, func():
			sel = id
			if not CoachEvents.SPECIAL.has(id):
				special = false
			_refresh(), id == sel, 14)
		b.name = "Event_" + id
		list.add_child(b)
	var ls := UI.scroll(list)
	ls.name = "ListScroll"
	ls.size_flags_stretch_ratio = 37
	split.add_child(ls)
	var det := UI.vbox(2)
	det.name = "Details"
	_details(det, dc)
	var ds := UI.scroll(UI.margin(det, 0, 0, 4, 0))
	ds.name = "DetailScroll"
	ds.size_flags_stretch_ratio = 63
	split.add_child(ds)
	body.add_child(_controls())

func _details(v: VBoxContainer, dc: Career) -> void:
	var sc := CoachEvents.scenario(sel)
	var ex := sample(dc, sel, pick_pid, special)
	var c2: Career = ex.get("career", dc)
	var hl := UI.label(String(sc.headline), 16, UI.GOLD, "big")
	hl.name = "Headline"
	v.add_child(hl)
	v.add_child(_cap("ID: %s   CATEGORY: %s" % [sel, String(sc.cat).to_upper()], 8, UI.DIM, "caps"))
	var story := String((sc.stories as Array)[0])
	for k in ex.get("vars", {}):
		story = story.replace("{%s}" % k, str(ex.vars[k]))
	var d := para(story, UI.TEXT, 150)
	d.name = "Description"
	v.add_child(d)
	var el: Array = CoachEvents.ELIGIBILITY.get(sel, ["", ""])
	_kv(v, "PLAYER", String(el[0]), "Who")
	_kv(v, "WHEN", String(el[1]), "When")
	_kv(v, "FREQUENCY", _freq(sel), "Freq")
	if ex.has("error"):
		v.add_child(para("NO SAMPLE: %s" % String(ex.error), RED, 150))
		return
	var chs := CoachEvents.choices_of(sc)
	ex["special"] = false
	_choice(v, "A", chs[0], CoachEvents.stakes(c2, ex, 0), "ChoiceA")
	_choice(v, "B", chs[1], CoachEvents.stakes(c2, ex, 1), "ChoiceB")
	var has_sp := CoachEvents.SPECIAL.has(sel)
	var sp := _cap("SPECIAL VERSION AVAILABLE: %s" % ("YES" if has_sp else "NO"), 8, UI.GOLD if has_sp else UI.DIM, "caps")
	sp.name = "SpecialAvailable"
	v.add_child(sp)
	if has_sp:
		ex["special"] = true
		var sv := UI.vbox(0)
		sv.name = "SpecialVersion"
		sv.add_child(_cap("SPECIAL CHOICE B - %s  (%s GAME XP)" % [String(CoachEvents.SPECIAL[sel]), CoachEvents.mx(CoachEvents.MULT_3X)], 8, UI.GOLD, "caps"))
		for s in CoachEvents.stakes(c2, ex, 1):
			sv.add_child(_stake(s))
		sv.add_child(_cap("SPECIAL APPEARANCE PROBABILITY: %d%% WHEN THIS EVENT IS DRAWN" % roundi(CoachEvents.SPECIAL_CHANCE * 100.0), 8, UI.ACCENT, "caps"))
		v.add_child(sv)
	if stat_challenge(sel, false) or stat_challenge(sel, true):
		var rr := UI.hbox(3)
		rr.name = "ResultPreview"
		rr.add_child(_cap("RESULT ANIMATION", 8, UI.GOLD))
		if stat_challenge(sel, false):
			var ok := UI.button("SUCCESS", func(): _preview_result(true, false), "ghost", 54, 16)
			ok.name = "ResultOk"
			rr.add_child(ok)
			var no := UI.button("FAILURE", func(): _preview_result(false, false), "ghost", 54, 16)
			no.name = "ResultFail"
			rr.add_child(no)
		if has_sp:
			var lg := UI.button("3X SUCCESS", func(): _preview_result(true, true), "primary", 64, 16)
			lg.name = "ResultLegend"
			rr.add_child(lg)
		v.add_child(rr)
	var who := c2.team().find_id(int(ex.get("pid", -1)))
	v.add_child(_cap("NUMBERS SHOWN FOR %s%s" % [who.short_name().to_upper() if who != null else "YOUR TEAM", "  (MOCK DATA)" if c2 == _mock else ""], 8, UI.DIM, "caps"))

func _kv(v: VBoxContainer, k: String, val: String, nm: String) -> void:
	var l := para("%s: %s" % [k, val], UI.ACCENT, 150)
	l.add_theme_font_override("font", UI.font_caps)
	l.name = nm
	v.add_child(l)

func _choice(v: VBoxContainer, letter: String, ch: Dictionary, st: Array, nm: String) -> void:
	var box := UI.vbox(0)
	box.name = nm
	box.add_child(_cap("CHOICE %s - %s" % [letter, String(ch.label)], 8, UI.TEXT, "caps"))
	if String(ch.text) != "":
		box.add_child(para(String(ch.text), UI.DIM, 150))
	for s in st:
		box.add_child(_stake(s))
	v.add_child(box)

func _stake(s: Array) -> Control:
	return _capc("  " + String(s[0]), 8, UI.GOLD if s[1] == "good" else (RED if s[1] == "bad" else UI.ACCENT), "caps", 150)

## How often: the event's category's share, its weight within the category, its cooldown.
static func _freq(id: String) -> String:
	var sc := CoachEvents.scenario(id)
	var cat := String(sc.cat)
	var cat_total := 0.0
	for k in CoachEvents.CATEGORY_WEIGHT:
		cat_total += float(CoachEvents.CATEGORY_WEIGHT[k])
	var in_cat := 0.0
	for e in CoachEvents.EVENTS:
		if String(e.cat) == cat:
			in_cat += float(e.weight)
	return "%d%% CHANCE OF AN EVENT A GAME; %s CATEGORY %d%% OF THEM; WEIGHT %s OF %s IN IT (%d%%) - WHEN ALL FIT; COOLDOWN %d GAMES" % [
		roundi(CoachEvents.CHANCE * 100.0), cat.to_upper(), roundi(float(CoachEvents.CATEGORY_WEIGHT[cat]) / cat_total * 100.0),
		str(float(sc.weight)), str(in_cat), roundi(float(sc.weight) / in_cat * 100.0), int(sc.cooldown)]

func _controls() -> Control:
	var v := UI.vbox(2)
	v.name = "Controls"
	var car := Game.career
	var r1 := UI.hbox(3)
	v.add_child(r1)
	r1.add_child(UI.label("VARIANT", 8, UI.DIM, "caps"))
	if CoachEvents.SPECIAL.has(sel):
		var n := UI.button("NORMAL - 2X", func():
			special = false
			_refresh(), "tab" if special else "tab_on", 70, 16)
		n.name = "VariantNormal"
		r1.add_child(n)
		var s := UI.button("SPECIAL - 3X", func():
			special = true
			_refresh(), "tab_on" if special else "tab", 70, 16)
		s.name = "VariantSpecial"
		r1.add_child(s)
	else:
		var nv := UI.label("NORMAL ONLY", 8, UI.DIM, "caps")
		nv.name = "VariantNone"
		nv.custom_minimum_size = Vector2(143, 16)
		r1.add_child(nv)
	r1.add_child(UI.spacer(4, 0))
	r1.add_child(UI.label("PLAYER", 8, UI.DIM, "caps"))
	var cands := candidates(car, sel) if car != null else []
	var who := ""
	if not needs_player(sel):
		who = "TEAM EVENT: NO PLAYER"
	elif car == null:
		who = "NO CAREER: MOCK DATA"
	elif not ignore_reqs:
		var ctx := when_safe(car, sel, CoachEvents.last_review)
		var gp := car.team().find_id(int(ctx.get("pid", -1)))
		who = ("GAME PICKS " + player_text(gp)) if gp != null else ("LAST GAME DOESN'T QUALIFY" if not CoachEvents.last_review.is_empty() else "NO RECENT GAME IN MEMORY")
	elif cands.is_empty():
		who = "NOBODY ELIGIBLE (PREVIEW: MOCK)"
	else:
		who = player_text(car.team().find_id(pick_pid))
	var can_pick := car != null and ignore_reqs and needs_player(sel) and cands.size() > 1
	var prev := UI.button("<", func(): _cycle(cands, -1), "ghost", 16, 16)
	prev.name = "PlayerPrev"
	prev.disabled = not can_pick
	r1.add_child(prev)
	var wl := UI.label(who, 8, UI.TEXT, "caps")
	wl.name = "PlayerName"
	wl.clip_text = true
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(wl)
	var nx := UI.button(">", func(): _cycle(cands, 1), "ghost", 16, 16)
	nx.name = "PlayerNext"
	nx.disabled = not can_pick
	r1.add_child(nx)
	var r2 := UI.hbox(3)
	v.add_child(r2)
	var ig := UI.button("IGNORE REQUIREMENTS: %s" % ("ON" if ignore_reqs else "OFF"), func():
		ignore_reqs = not ignore_reqs
		_refresh(), "tab_on" if ignore_reqs else "tab", 130, 18)
	ig.name = "IgnoreReqs"
	r2.add_child(ig)
	var why := trigger_block(car, sel, pick_pid, ignore_reqs)
	var st := UI.label(why if why != "" else "TRIGGER CHANGES YOUR SAVE", 8, RED if why != "" else UI.DIM, "caps")
	st.name = "TriggerStatus"
	st.clip_text = true
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(st)
	var pv := UI.button("PREVIEW EVENT", func(): Game.goto("coach_event", preview_params(sel, pick_pid, special, ignore_reqs)), "primary", 84, 18)
	pv.name = "Preview"
	r2.add_child(pv)
	var tg := UI.button("TRIGGER EVENT", _confirm_trigger, "danger", 84, 18)
	tg.name = "Trigger"
	tg.disabled = why != ""
	r2.add_child(tg)
	return v

func _cycle(cands: Array, d: int) -> void:
	if cands.is_empty():
		return
	var i := cands.find(c.team().find_id(pick_pid)) if c != null else 0
	pick_pid = (cands[posmod(i + d, cands.size())] as PoloPlayer).id
	_refresh()

## TRIGGER EVENT, after a warning: it's real.
func _confirm_trigger() -> void:
	var car := Game.career
	if trigger_block(car, sel, pick_pid, ignore_reqs) != "":
		Sfx.play("error")
		return
	var head := String(CoachEvents.scenario(sel).headline)
	Game.dialog("TRIGGER A REAL EVENT?", "%s%s will open as a real coaching event in your save. Your answer is applied for real: XP, Polo Points, HOT/COLD progress, suspensions, lineup changes and next-game challenges.\n\nUse PREVIEW EVENT to look without changing anything." % [head, " (SPECIAL 3X)" if special and CoachEvents.SPECIAL.has(sel) else ""], [
		["TRIGGER", func(): trigger(car, sel, pick_pid, special, ignore_reqs), "danger"],
		["CANCEL", Callable(), "ghost"]])

# ------------------------------------------------------------------ ACTIVE CHALLENGES
func _active_tab() -> void:
	var v := UI.vbox(3)
	v.name = "Active"
	body.add_child(UI.scroll(v))
	var car := Game.career
	if car == null:
		v.add_child(UI.label("NO CAREER LOADED", 8, UI.DIM, "caps"))
		return
	var note := para("SAVED IN YOUR CAREER. SIMULATE RUNS ON A COPY WITH TEST INPUTS: NOTHING SAVED.", UI.DIM, 440)
	note.add_theme_font_override("font", UI.font_caps)
	v.add_child(note)
	if car.coach_pending.is_empty():
		var n := UI.label("NO ACTIVE CHALLENGES", 8, UI.TEXT, "caps")
		n.name = "None"
		v.add_child(n)
	for e in car.coach_pending:
		var eid := int(e.eid)
		var b := UI.vbox(0)
		var h := UI.hbox(4)
		h.add_child(UI.label(String(e.title), 8, UI.GOLD, "caps"))
		h.add_child(UI.label("SPECIAL - 3X" if bool(e.get("special", false)) else "NORMAL", 8, UI.GOLD if bool(e.get("special", false)) else UI.DIM, "caps"))
		if bool(e.get("dev", false)):
			h.add_child(UI.label("DEV-TRIGGERED", 8, RED, "caps"))
		b.add_child(h)
		var bh := UI.hbox(4)
		var ok := UI.button("SIMULATE SUCCESS", func(): _sim(eid, true), "ghost", 92, 16)
		ok.name = "SimOk_%d" % eid
		bh.add_child(ok)
		var no := UI.button("SIMULATE FAILURE", func(): _sim(eid, false), "ghost", 92, 16)
		no.name = "SimFail_%d" % eid
		bh.add_child(no)
		for kv in [["PLAYER", CoachEvents._name(car, int(e.pid))], ["OBJECTIVE", String(e.label)], ["WHEN", target_of(e)],
				["REWARD", reward_of(e)], ["FAILURE", penalty_of(e)], ["STATUS", "PENDING"]]:
			b.add_child(_capc("%s: %s" % kv, 8, UI.TEXT if kv[0] != "FAILURE" else RED, "caps"))
		for ln in sim_out.get(eid, []):
			b.add_child(_capc(String(ln[0]), 8, UI.GOLD if ln[1] == "good" else (RED if ln[1] == "bad" else UI.ACCENT), "caps", 440))
		b.add_child(bh)
		var p := navy_panel(b)
		p.name = "Pending_%d" % eid
		v.add_child(p)
	for p: PoloPlayer in car.team().roster:
		if p.is_suspended():
			v.add_child(UI.label("%s SUSPENDED: %d GAME%s" % [player_text(p), p.susp, "" if p.susp == 1 else "S"], 8, RED, "caps"))

## _cap with its Polo Points drawn as the coin ("+50{coin}"): a wrapped coin line when it has one.
func _capc(t: String, size: int = 8, col: Color = UI.TEXT, _font: String = "caps", w: int = 100) -> Control:
	if not CreditCoin.has_tag(t):
		var l := _cap(t, size, col)
		l.custom_minimum_size.x = w
		return l
	var rl := CreditCoin.rich(t, size, col, "caps", float(w))
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rl

## A wrapped caps line (UI.label's arguments): long lines never widen the page.
func _cap(t: String, size: int = 8, col: Color = UI.TEXT, _font: String = "caps") -> Label:
	var l := para(t, col, 100)
	l.add_theme_font_override("font", UI.font_caps)
	l.add_theme_font_size_override("font_size", size)
	return l

func _sim(eid: int, ok: bool) -> void:
	var r := simulate(Game.career, eid, ok)
	sim_out[eid] = r.get("lines", [[String(r.get("error", "")), "bad"]])
	_refresh()

# ------------------------------------------------------------------ CHALLENGE ANIMATIONS
func _anim_tab() -> void:
	var split := UI.hbox(4)
	split.name = "AnimSplit"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var list := UI.vbox(1)
	list.name = "AnimList"
	for it in ANIM_EVENTS:
		var id := String(it[0])
		var only_sp: bool = it[1]
		var h := UI.hbox(2)
		var nl := UI.label(String(CoachEvents.scenario(id).headline) + (" - SPECIAL" if only_sp else ""), 8, UI.GOLD if id == anim_sel else UI.TEXT, "caps")
		nl.clip_text = true
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		if CoachEvents.SPECIAL.has(id):
			h.add_child(UI.label("3X", 8, UI.GOLD, "caps"))
		var b := row_button(h, func():
			anim_sel = id
			anim_sp = only_sp or (anim_sp and CoachEvents.SPECIAL.has(id))
			anim_target = -1
			anim_won = case_won(id, true)
			_refresh(), id == anim_sel, 14)
		b.name = "Anim_" + id
		list.add_child(b)
	var ls := UI.scroll(list)
	ls.size_flags_stretch_ratio = 37
	split.add_child(ls)
	var det := UI.vbox(3)
	det.name = "AnimDetails"
	var ds := UI.scroll(UI.margin(det, 0, 0, 4, 0))
	ds.size_flags_stretch_ratio = 63
	split.add_child(ds)
	if anim_sel == "big_rivalry":
		anim_sp = true
	var st := anim_setup(anim_sel, anim_pid, anim_sp)
	det.add_child(UI.label(String(CoachEvents.scenario(anim_sel).headline), 16, UI.GOLD, "big"))
	if st.has("error"):
		det.add_child(_cap(String(st.error), 8, RED))
		return
	anim_pid = int(st.pid)
	var c2: Career = st.c2
	var ch: Dictionary = st.ch
	var stat := String(ch.stat)
	if stat != anim_stat:
		anim_stat = stat
		anim_vals = case_vals(stat, int(ch.n), true)
	# the player
	var cands := candidates(c2, anim_sel)
	var pr := UI.hbox(3)
	pr.add_child(_capw("PLAYER", UI.DIM))
	var pv := UI.button("<", func(): _anim_cycle(cands, -1), "ghost", 16, 16)
	pv.name = "AnimPrev"
	pv.disabled = cands.size() < 2
	pr.add_child(pv)
	var pl := UI.label(player_text(c2.team().find_id(anim_pid)) + ("  (MOCK)" if st.mock else ""), 8, UI.TEXT, "caps")
	pl.name = "AnimPlayer"
	pl.clip_text = true
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr.add_child(pl)
	var nx := UI.button(">", func(): _anim_cycle(cands, 1), "ghost", 16, 16)
	nx.name = "AnimNext"
	nx.disabled = cands.size() < 2
	pr.add_child(nx)
	det.add_child(pr)
	# the variant
	var vr := UI.hbox(3)
	vr.add_child(_capw("VARIANT", UI.DIM))
	if anim_sel == "big_rivalry":
		vr.add_child(UI.label("SPECIAL - 3X ONLY (THE NORMAL ONE IS WIN-ONLY)", 8, UI.GOLD, "caps"))
	elif CoachEvents.SPECIAL.has(anim_sel):
		for o in [[false, "NORMAL - 2X", "AnimNormal"], [true, "SPECIAL - 3X", "AnimSpecial"]]:
			var b := UI.button(String(o[1]), func():
				anim_sp = o[0]
				anim_target = -1
				_refresh(), "tab_on" if anim_sp == o[0] else "tab", 70, 16)
			b.name = String(o[2])
			vr.add_child(b)
	else:
		vr.add_child(UI.label("NORMAL ONLY", 8, UI.DIM, "caps"))
	det.add_child(vr)
	# the objective and the target
	var n := anim_target if anim_target > 0 else int(ch.n)
	var tr := UI.hbox(3)
	tr.add_child(_cap("CHALLENGE: %d %s" % [n, String(ChallengeShow.UNITS[stat][0])], 8, UI.TEXT))
	tr.add_child(_stepper("Target", "TARGET", n, func(v): anim_target = maxi(1, v), 1))
	det.add_child(tr)
	if anim_target > 0 and anim_target != int(ch.n):
		det.add_child(_cap("(THE EVENT'S OWN TARGET IS %d)" % int(ch.n), 8, UI.DIM))
	# what he did
	var ar := UI.hbox(3)
	ar.add_child(_capw("ACTUAL", UI.DIM))
	var keys: Array = {"ga": ["g", "a"], "stbl": ["st", "bl"]}.get(stat, [stat])
	var total := 0
	for k in keys:
		total += int(anim_vals.get(k, 0))
		ar.add_child(_stepper("In_" + k, String(INPUT_NAMES[k]), int(anim_vals.get(k, 0)), func(v):
			anim_vals[k] = maxi(0, v), 0))
	det.add_child(ar)
	var met := total >= n
	var tl := _cap("TOTAL: %d / %d %s  -  %d%% OF THE BAR" % [total, n, String(ChallengeShow.UNITS[stat][1]), roundi(clampf(float(total) / n, 0.0, 1.0) * 100.0)], 8, UI.GOLD if met else Color("ff8a80"))
	tl.name = "AnimTotal"
	det.add_child(tl)
	# the result
	var rr := UI.hbox(3)
	rr.add_child(_capw("TEAM RESULT", UI.DIM))
	for o in [[true, "WIN", "AnimWin"], [false, "LOSS", "AnimLoss"]]:
		var b := UI.button(String(o[1]), func():
			anim_won = o[0]
			_refresh(), "tab_on" if anim_won == o[0] else "tab", 44, 16)
		b.name = String(o[2])
		rr.add_child(b)
	if anim_sel in ["big_rivalry", "learning_experience"]:
		rr.add_child(_cap("(PART OF THE CHALLENGE)" if anim_sel == "big_rivalry" else "(IT COUNTS ONLY ON A LOSS)", 8, UI.ACCENT))
	det.add_child(rr)
	# what's at stake, as the event says it (stakes())
	var ev: Dictionary = st.ev
	for s2 in CoachEvents.stakes(c2, ev, 1):
		det.add_child(_stake(s2))
	# the controls
	var bt := UI.hbox(3)
	bt.name = "AnimButtons"
	for o in [["PREVIEW RESULT", "AnimResult", "primary"], ["SUCCESS", "AnimOk", "ghost"], ["FAILURE", "AnimFail", "ghost"], ["REPLAY", "AnimReplay", "ghost"]]:
		var nm := String(o[1])
		var b := UI.button(String(o[0]), func(): _anim_button(nm), String(o[2]), 0, 18)
		b.name = nm
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if nm == "AnimReplay":
			b.disabled = anim_last.is_empty()
		bt.add_child(b)
	det.add_child(bt)
	det.add_child(_cap("PREVIEW ONLY: TEMPORARY COPIES, NOTHING SAVED. LIVE TESTS (REAL, CHANGE THE SAVE): EVENTS > TRIGGER EVENT.", 8, UI.DIM))

## A small [-] value [+] control.
func _stepper(nm: String, label: String, v: int, set_v: Callable, lo: int) -> Control:
	var h := UI.hbox(1)
	h.name = nm
	h.add_child(_capw(label, UI.DIM))
	var m := UI.button("-", func():
		set_v.call(maxi(lo, v - 1))
		_refresh(), "ghost", 14, 14)
	m.name = "Minus"
	h.add_child(m)
	var l := UI.label(str(v), 8, UI.TEXT, "caps")
	l.name = "Value"
	l.custom_minimum_size = Vector2(14, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(l)
	var pl := UI.button("+", func():
		set_v.call(v + 1)
		_refresh(), "ghost", 14, 14)
	pl.name = "Plus"
	h.add_child(pl)
	return h

func _capw(t: String, col: Color) -> Label:
	return UI.label(t, 8, col, "caps")

func _anim_cycle(cands: Array, d: int) -> void:
	if cands.is_empty():
		return
	var i := -1
	for j in cands.size():
		if (cands[j] as PoloPlayer).id == anim_pid:
			i = j
	anim_pid = (cands[posmod(i + d, cands.size())] as PoloPlayer).id
	_refresh()

func _anim_button(nm: String) -> void:
	match nm:
		"AnimResult":
			_show_preview(preview_custom(anim_sel, anim_pid, anim_sp, anim_vals, anim_won, anim_target))
		"AnimOk", "AnimFail":
			var ok := nm == "AnimOk"
			var st := anim_setup(anim_sel, anim_pid, anim_sp)
			if st.has("error"):
				Game.toast(String(st.error), RED)
				return
			var n := anim_target if anim_target > 0 else int(st.ch.n)
			anim_vals = case_vals(String(st.ch.stat), n, ok or anim_sel == "big_rivalry")
			anim_won = case_won(anim_sel, ok)
			_refresh()
			_show_preview(preview_custom(anim_sel, anim_pid, anim_sp, anim_vals, anim_won, anim_target))
		"AnimReplay":
			if not anim_last.is_empty():
				ChallengeShow.play(self, anim_last.career, [anim_last.res], Callable(), null, "DEVELOPER PREVIEW (REPLAY) - NOTHING APPLIED" + ("  |  MOCK DATA" if anim_last.mock else ""))

# ------------------------------------------------------------------ HISTORY
func _history_tab() -> void:
	var v := UI.vbox(2)
	v.name = "History"
	body.add_child(UI.scroll(v))
	v.add_child(_cap("DECISIONS THIS SESSION (MEMORY ONLY, NEWEST FIRST)", 8, UI.GOLD, "caps"))
	if CoachEvents.decisions.is_empty():
		v.add_child(_cap("NONE YET", 8, UI.DIM, "caps"))
	for i in range(CoachEvents.decisions.size() - 1, -1, -1):
		var d: Dictionary = CoachEvents.decisions[i]
		var b := UI.vbox(0)
		b.add_child(_cap("%s  |  %s  |  %s  |  %s%s%s" % [String(d.when), String(d.title), String(d.name), String(d.choice),
			"  SPECIAL" if d.special else "", "  DEV" if d.dev else ""], 8, UI.TEXT, "caps"))
		b.add_child(_capc("XP %+d   %+d{coin}%s" % [int(d.xp), int(d.credits), "   SUSPENSION +%d GAME" % int(d.susp) if int(d.susp) > 0 else ""], 8, UI.ACCENT, "caps"))
		for ln in d.lines:
			b.add_child(_capc("  " + String(ln[0]).to_upper(), 8, UI.DIM, "caps"))
		var p := navy_panel(b)
		p.name = "Decision_%d" % i
		v.add_child(p)
	v.add_child(_cap("SETTLED CHALLENGES (SAVED, NEWEST FIRST)", 8, UI.GOLD, "caps"))
	var car := Game.career
	if car == null or car.coach_results.is_empty():
		v.add_child(_cap("NONE", 8, UI.DIM, "caps"))
		return
	for i in range(car.coach_results.size() - 1, -1, -1):
		var r: Dictionary = car.coach_results[i]
		var b := UI.vbox(0)
		b.add_child(_cap("%d WEEK %d  |  %s  |  %s  |  %s%s" % [int(r.get("year", 0)), int(r.get("week", 0)) + 1, String(r.title), CoachEvents._name(car, int(r.pid)),
			String(r.label), "  SPECIAL" if bool(r.get("special", false)) else ""], 8, UI.TEXT, "caps"))
		var oc := String(r.outcome)
		b.add_child(_cap("%s - %s" % [{"ok": "SUCCESS", "fail": "FAILURE", "even": "NORMAL GAME XP", "void": "VOID"}.get(oc, oc), String(r.note).to_upper()], 8,
			UI.GOLD if oc == "ok" else (RED if oc == "fail" else UI.ACCENT), "caps"))
		for ln in r.get("lines", []):
			b.add_child(_capc("  " + String(ln[0]).to_upper(), 8, UI.DIM, "caps"))
		var p := navy_panel(b)
		p.name = "Settled_%d" % i
		v.add_child(p)

# ------------------------------------------------------------------ GENERATION
func _generation_tab() -> void:
	var v := UI.vbox(1)
	v.name = "Generation"
	body.add_child(UI.scroll(v))
	var add := func(t: String, col: Color = UI.TEXT):
		var l := para(t, col, 440)
		l.add_theme_font_override("font", UI.font_caps)
		v.add_child(l)
	add.call("SHOWN AS THE GAME USES THEM (COACHEVENTS). NOTHING HERE CHANGES THEM.", UI.DIM)
	add.call("EVENT CHANCE AFTER EACH GAME: %d%% (WHEN AN EVENT FITS)" % roundi(CoachEvents.CHANCE * 100.0), UI.GOLD)
	var tot := 0.0
	for k in CoachEvents.CATEGORY_WEIGHT:
		tot += float(CoachEvents.CATEGORY_WEIGHT[k])
	add.call("CATEGORIES (PICKED AMONG THOSE WITH AN EVENT THAT FITS):", UI.GOLD)
	for k in CoachEvents.CATEGORY_WEIGHT:
		var in_cat: Array = CoachEvents.EVENTS.filter(func(e): return e.cat == k)
		var w := 0.0
		for e in in_cat:
			w += float(e.weight)
		add.call("  %s  WEIGHT %d (%d%%):  %s" % [String(k).to_upper(), int(CoachEvents.CATEGORY_WEIGHT[k]), roundi(float(CoachEvents.CATEGORY_WEIGHT[k]) / tot * 100.0),
			", ".join(in_cat.map(func(e): return "%s %s (%d%%, COOLDOWN %d)" % [String(e.headline), str(float(e.weight)), roundi(float(e.weight) / w * 100.0), int(e.cooldown)]))])
	add.call("NO REPEATS: NEVER THE LAST GAME'S EVENT; EACH WAITS ITS COOLDOWN (GAMES SINCE IT LAST CAME, LAST %d GAMES REMEMBERED)." % CoachEvents.LOG_MAX)
	add.call("ONE DECISION PER PLAYER AT A TIME; PROVE ME WRONG ONLY WHEN NOTHING ELSE RIDES ON THE NEXT GAME.")
	add.call("SPECIAL CHALLENGE: %d%% OF %s (ROLLED ONCE WHEN THE EVENT IS MADE, ITS OWN DIE, SAVED WITH IT)." % [roundi(CoachEvents.SPECIAL_CHANCE * 100.0),
		", ".join(CoachEvents.SPECIAL.keys().map(func(id): return String(CoachEvents.scenario(id).headline)))], UI.GOLD)
	add.call("ONE MULTIPLIER PER PLAYER PER GAME: PROVE ME WRONG'S FIRST, ELSE THE BIGGEST BONUS, ELSE THE SMALLEST PENALTY.")
	add.call("BACKUP BREAKOUT'S CHALLENGE WAITS UP TO %d GAMES FOR HIM TO PLAY." % CoachEvents.WAIT_GAMES)
