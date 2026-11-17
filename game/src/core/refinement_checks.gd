class_name RefinementChecks
extends RefCounted
## THE DYNASTY REFINEMENT UPDATE'S NUMBERED TESTS (its section 22): what Developer Mode's DYNASTY
## REFINEMENT TESTS (refine_lab.gd) and `--test refinement` both run. Sandboxed: scratch careers,
## vaults and VisualUpgrades, never Store.looks, Store.bank or a save. Each result is
## {n, group, text, ok, look}; `look` means the check needs eyes or a screen: the lab points you
## at it, and tests/refinement_test.gd checks it with the real screens.

const GROUPS := {"A": "DYNASTY HUB", "B": "HISTORICAL RECORDS", "C": "INSTANT REPLAY (REMOVED)", "D": "BROADCAST", "E": "VICTORY",
	"F": "CURRENCY", "G": "SHOP", "H": "PIXEL POLO +", "I": "RECRUITING UI", "J": "GAMEPLAY"}
const DT := 1.0 / 60.0
const F := DefenseFormation.F

var out: Array = []
var group := "A"

func _ok(n: int, ok: bool, text: String) -> void:
	out.append({"n": n, "group": group, "text": text, "ok": ok, "look": false})

func _look(n: int, text: String, where: String) -> void:
	out.append({"n": n, "group": group, "text": text, "ok": true, "look": true, "where": where})

## Everything, `reps` plays per gameplay sample.
static func run_all(reps: int = 40) -> Array:
	var t: RefinementChecks = RefinementChecks.new()
	var was := Play.instant_drops
	Play.instant_drops = false
	t._hub()
	t._records()
	t._replay()
	t._broadcast()
	t._victory()
	t._currency()
	t._shop()
	t._pro()
	t._recruiting()
	t._gameplay(reps)
	Play.instant_drops = was
	return t.out

# ------------------------------------------------------------------ A
func _hub() -> void:
	group = "A"
	_look(1, "School Rating is gone from the Dynasty Hub", "program")
	var t := League.make_team(3, 1)
	_ok(2, t.offense_display() > 0 and t.defense_display() > 0 and t.goalkeeping_display() > 0 and Colleges.SCHOOLS.all(func(s): return s.has("prestige")), "offense, defense and goalkeeper ratings all stand")
	_look(3, "no empty or broken panels", "program")
	_look(4, "Hub navigation works", "more")

# ------------------------------------------------------------------ B
func _records() -> void:
	group = "B"
	# (setups: a begun career may already have a week of its own games behind it, which can
	# break records: that's its dynasty, not where it started)
	var a := Career.new_setup(901)
	var b := Career.new_setup(902)
	var named := true
	var assists := true
	for id in RecordBook.SCHOOLS:
		var book := Records.school_book(a, id)
		for k in Records.KEYS:
			named = named and String(book[k].name).strip_edges() != "" and int(book[k].v) > 0 and not String(book[k].name).to_lower() in Records.NO_NAME
		assists = assists and String(book.season_assists.name) != ""
	_ok(5, named and RecordBook.SCHOOLS.size() == 30, "all 30 schools, all %d records: a value and a named holder" % Records.KEYS.size())
	_ok(6, assists, "Assists in a Season has a holder everywhere")
	var same := true
	for id in RecordBook.SCHOOLS:
		same = same and Records.school_book(a, id) == Records.school_book(b, id)
	_ok(7, same and Records.ncsa_book(a) == Records.ncsa_book(b), "two dynasties, different schools and seeds: identical books")
	var c := Career.new_setup(903)
	c.school = "CULA"
	c.teams["GWU"].prestige = 11.0   # (the old book was scaled by whatever the prestige was by then)
	_ok(8, Records.school_book(c, "GWU") == Records.school_book(a, "GWU"), "the book is fixed data: nothing about a dynasty changes where it starts")
	var old := int(Records.school_book(c, "CULA").season_goals.v)
	Records.breaks(c, "season_goals", old + 5, "Z. Current", "CULA")
	_ok(9, int(Records.school_book(c, "CULA").season_goals.v) == old + 5 and String(Records.school_book(c, "CULA").season_goals.name) == "Z. Current", "a dynasty's player can break one")
	_ok(10, int(Records.school_book(a, "CULA").season_goals.v) == old and int(RecordBook.SCHOOLS.CULA.season_goals[0]) == old, "...and it touches no other dynasty, nor the canon")
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	d.records.school.CULA.season_assists.name = ""
	d.records.school.CULA.career_assists = {"v": 0, "name": "", "team": "", "year": ""}
	var back := Career.from_dict(d)
	var bk: Dictionary = back.records.school.CULA
	_ok(11, int(bk.season_goals.v) == old + 5 and String(bk.season_goals.name) == "Z. Current" and String(bk.season_assists.name) != "" and String(bk.career_assists.name) != "", "an old save: achievements kept, blanks filled")

# ------------------------------------------------------------------ C
## INSTANT REPLAY: removed from the game since (VisualUpgrades.RETIRED). What's checked now is that
## it's gone and that an old save that had it still loads, nothing else lost and nothing refunded.
func _replay() -> void:
	group = "C"
	var ids: Array = VisualUpgrades.CATS.map(func(cd): return String(cd.id))
	_ok(12, VisualUpgrades.cat("replay").is_empty() and ids == ["goal", "crowd", "broadcast", "pregame", "scoreboard"], "INSTANT REPLAY is gone: five Visual Upgrades left")
	var old := VisualUpgrades.from_dict({"unlocked": {"replay": 2, "crowd": 2, "broadcast": 3}, "equipped": {"replay": 2, "crowd": 2, "broadcast": 2},
		"celebs": [1], "celeb": 1, "celeb_v": VisualUpgrades.CELEB_V, "crowd_v": VisualUpgrades.CROWD_V})
	_ok(13, not old.unlocked.has("replay") and not old.equipped.has("replay") and old.level("crowd") == 2 and old.worn("broadcast") == 2 and old.worn_celeb() == 1,
		"an old save that owned it loads without it, every other upgrade owned and worn as before")
	_ok(14, not old.to_dict().unlocked.has("replay") and not old.to_dict().equipped.has("replay"), "...and saves without it")
	var paid := _mig({"unlocked": {"replay": 2}, "equipped": {"replay": 2}})
	_ok(15, paid.bank.balance == 0 and paid.looks.unlocked.is_empty(), "no refund for it: the balance is left exactly as it was")
	var l4 := _mig({"unlocked": {"replay": 4}, "bought": [{"txn": "r4", "what": "replay:4", "n": 40}]})
	_ok(16, l4.bank.balance == 40 * Wallet.RATE, "the old 3D replay's Level 4 refund (an account from before the currency move) still paid, once")

## An account with `looks` (and `blue` Blue Coins) through the migration.
func _mig(looks: Dictionary, blue := 0) -> Dictionary:
	var old := CoinVault.new()
	old.balance = blue
	var s := {"v": 0, "bank": CoinVault.new(), "old": old, "looks": VisualUpgrades.from_dict(looks), "pro": false, "pro_coins": false}
	s["report"] = EconomyMigration.run(s)
	return s

# ------------------------------------------------------------------ D
func _broadcast() -> void:
	group = "D"
	_ok(21, VisualUpgrades.top("broadcast") == 3 and VisualUpgrades.price_of("broadcast", 2) == 125 and VisualUpgrades.price_of("broadcast", 3) == 250, "three levels: free, 125, 250")
	_ok(22, not (VisualUpgrades.cat("broadcast").tiers as Array).any(func(t): return String(t[0]).contains("NATIONAL")) and VisualUpgrades.new().level("broadcast") <= 3, "Level 4 isn't listed anywhere")
	var s := _mig({"unlocked": {"broadcast": 4}, "equipped": {"broadcast": 4}, "bought": [{"txn": "x", "what": "broadcast:4", "n": 100}]})
	var lk: VisualUpgrades = s.looks
	_ok(23, lk.level("broadcast") == 3 and lk.worn("broadcast") == 3, "a Level 4 owner keeps 1-3 and wears 3")
	var again := EconomyMigration.run(s)
	_ok(24, (s.bank as CoinVault).balance == 500 and not bool(again.ran), "...and is refunded 100 Blue x 5 = 500, once")
	_ok(25, BroadcastFx.new(1).level == 1 and BroadcastFx.new(3).level == 3 and BroadcastFx.new(4).level == 3, "Levels 1-3 work; nothing plays a Level 4")

# ------------------------------------------------------------------ E
func _victory() -> void:
	group = "E"
	# (no longer a Visual Upgrade, and the win presentation itself is gone from the game since)
	_ok(26, not ResourceLoader.exists("res://src/match/victory_show.gd"), "no victory presentation: a win goes straight to the full-time panel")
	_ok(27, VisualUpgrades.cat("victory").is_empty() and not VisualUpgrades.BUILT.has("victory"), "Victory Presentation isn't sold in Visual Upgrades")
	var old := VisualUpgrades.from_dict({"unlocked": {"victory": 4, "crowd": 2}, "equipped": {"victory": 3}})
	_ok(29, not old.unlocked.has("victory") and not old.equipped.has("victory") and old.level("crowd") == 2, "an old save's Victory levels are dropped, the rest kept")

# ------------------------------------------------------------------ F
func _currency() -> void:
	group = "F"
	_look(37, "no Blue Coins on any screen", "more")
	var names: Array = (load("res://src/core/wallet.gd") as Script).get_script_method_list().map(func(m): return String(m.name))
	_ok(38, not ("exchange" in names or "spend_blue" in names or "blue" in names), "the exchange is gone from the wallet")
	var s := _mig({}, 25)
	_ok(39, (s.bank as CoinVault).balance == 125 and (s.old as CoinVault).balance == 0, "25 Blue = 125 Yellow, old balance retired")
	var y := CoinVault.new()
	y.balance = 300
	var old := CoinVault.new()
	old.balance = 10
	var st := {"v": 0, "bank": y, "old": old, "looks": VisualUpgrades.new(), "pro": false, "pro_coins": false}
	EconomyMigration.run(st)
	_ok(40, y.balance == 350, "existing Polo Points are kept, not converted (300 + 50)")
	EconomyMigration.run(st)
	EconomyMigration.run(st)
	_ok(41, y.balance == 350, "running it again does nothing")
	var c := Career.new_game("CULA", "A", "B", 906)
	c.credits = 130
	var lk := VisualUpgrades.new()
	var bank := CoinVault.new()
	_ok(42, lk.buy_tier("crowd", c, bank) == "" and c.credits == 5, "premium purchases spend Polo Points")
	var v := CoinVault.new()
	v.credit(500, "t1")
	_ok(43, v.balance == 500 and not v.credit(500, "t1") and v.balance == 500, "a coin purchase lands once in the shared balance")
	var c2 := Career.new_game("GWU", "A", "B", 907)
	c2.credits = 0
	_ok(44, Wallet.yellow(c2, v) == 500, "bought coins are in every dynasty")
	var c3 := Career.new_game("GWU", "A", "B", 908)
	c3.credits = 40
	var sp := Wallet.spend_yellow(c3, 60, "TEST", v)
	_ok(45, bool(sp.ok) and int(sp.earned) == 40 and int(sp.legacy) == 20 and Wallet.dynasty_yellow(c2) == 0, "the dynasty's coins go first and stay that dynasty's")
	var r := _mig({"packs": ["chaos", "spirit"], "bought": [{"txn": "a", "what": "chaos", "n": 50}, {"txn": "b", "what": "spirit", "n": 75}]})
	_ok(46, (r.bank as CoinVault).balance == 625 and (r.looks as VisualUpgrades).packs.is_empty() and int((r.bank as CoinVault).sources.get("refund", 0)) == 625, "retired packs refunded at 5:1, entitlement gone")
	var d: Dictionary = JSON.parse_string(JSON.stringify(c3.to_dict()))
	_ok(47, Career.from_dict(d).credits == c3.credits and not d.has("blue"), "loading adds nothing; the shared coins aren't in a save")

# ------------------------------------------------------------------ G
func _shop() -> void:
	group = "G"
	var coins: Array = Store.PACK_IDS.map(func(id): return int(Store.product(id).credits))
	_ok(48, coins == [60, 180, 350, 800], "the packs sell 60 / 180 / 350 / 800 Polo Points (the Polo Points Economy update)")
	var dollars: Array = Store.PACK_IDS.map(func(id): return float(Store.product(id).usd))
	_ok(48, dollars == [1.99, 5.99, 9.99, 19.99] and is_equal_approx(float(Store.product(Store.PRO_ID).usd), 7.99), "$1.99, $5.99, $9.99, $19.99; Pixel Polo + $7.99")
	_look(49, "Cap Shop stays removed (your Nov 4 decision)", "")
	_ok(54, Colleges.SCHOOLS.size() == 30, "the same 30 schools")
	_ok(55, Colleges.CONFERENCES.size() == 5 and Career.new_game("CULA", "A", "B", 955).teams.size() == 30, "a dynasty has only those schools and five conferences")

# ------------------------------------------------------------------ H
func _pro() -> void:
	group = "H"
	_ok(58, Store.PRO_PERKS.size() == 2 and String(Store.PRO_PERKS[0]).contains("200"), "the card's two benefits")
	_look(59, "a new purchase grants 200 once (--test refinement)", "")
	_look(60, "a restore grants nothing (--test refinement)", "")
	var c := Career.new_game("CULA", "A", "B", 909)
	var p: PoloPlayer = c.team().roster[2]
	var id := p.id
	var stats := JSON.stringify(p.to_dict().get("stats", {}))
	var pos := p.pos
	var attrs := p.attrs.duplicate()
	var free := c.team().free_number(false)
	var why := PlayerEdit.apply(c, p, "Marcus", "Bennett", free)
	_ok(61, why == "" and p.first == "Marcus" and p.last == "Bennett", "names can be edited")
	_ok(62, p.number == free, "cap numbers can be edited")
	var keys := PlayerEdit.check(c.team(), p, "", "X", 5) != "" and PlayerEdit.check(c.team(), p, "A", "B", 0) != "" \
		and PlayerEdit.check(c.team(), p, "A", "B", 1) != "" and PlayerEdit.check(c.team(), p, "A", "B", c.team().roster[3].number) != ""
	_ok(63, p.pos == pos and keys, "the position isn't editable, and bad names and numbers are refused")
	_ok(64, p.attrs == attrs, "nor are attributes")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var q: PoloPlayer = back.team().find_id(id)
	_ok(65, q != null and q.last == "Bennett" and q.number == free, "edits survive a save")
	_ok(66, q != null and q.id == id and JSON.stringify(q.to_dict().get("stats", {})) == stats, "same id, same statistics")

# ------------------------------------------------------------------ I
func _recruiting() -> void:
	group = "I"
	_look(68, "the TEAM NEEDS panel is cleaner", "recruiting")
	_look(69, "text is readable", "recruiting")
	_look(70, "position labels line up", "recruiting")
	_look(71, "nothing overlaps", "recruiting")
	var c := Career.new_game("CULA", "A", "B", 910)
	var n := RosterNeeds.of(c)
	_ok(72, n.has("ready") and RosterNeeds.GROUPS.all(func(g): return n.has(g)), "the calculation is the same RosterNeeds")

# ------------------------------------------------------------------ J
static func _setup(seed_value: int, defending: bool) -> Play:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := Play.new(League.make_team(3, 1), League.make_team(2, 2), Play.Kind.HALF_COURT, rng)
	p.defending = defending
	for a in p.attackers:
		a.pos = a.home
		a.target = a.home
	for d in p.defenders:
		d.pos = d.mark.pos + (Geo.goal_center() - d.mark.pos).normalized() * (0.55 if d.mark.tag == "C" else 1.0)
		d.target = d.pos
	for s in p.attackers + p.defenders:
		s.player.trait_id = ""
	p.drive_timer = 99.0
	return p

static func _man_up(seed_value: int, defending: bool, from: String) -> Play:
	var p := _setup(seed_value, defending)
	p.give_ball(PlaySetup._by_tag(p, from))
	p._exclusion(p.defenders[seed_value % 5 + 1], null)
	p.freeze = 0.0
	for i in 90:
		p.shot_clock = 20.0
		p.step(DT)
		if p.over or p.holder == null:
			break
	p.restart = false
	p.pass_first = false
	p.free_throw = false
	return p

## A wing pass on the man-up, `set_up` run on it first: "caught", "stolen" or "tipped".
static func _wing(p: Play, to: String, set_up: Callable = Callable()) -> String:
	if p.over or p.holder == null:
		return ""
	if set_up.is_valid():
		set_up.call(p)
	var tgt := PlaySetup._by_tag(p, to)
	if not p.pass_to(tgt):
		return ""
	for i in 180:
		p.shot_clock = 20.0
		p.step(DT)
		if p.over:
			return "stolen"
		if p.holder == tgt:
			return "caught"
		if p.ball.state == Ball.State.LOOSE:
			return "tipped"
	return ""

func _gameplay(n: int) -> void:
	group = "J"
	# wing passes
	var open := {"caught": 0, "all": 0}
	var keeper_stolen := {"n": 0}
	for sd in n:
		for defending in [false, true]:
			var r := _wing(_man_up(5000 + sd, defending, "1"), "5", func(p: Play):
				# a wing stepped in deep: the case the keeper used to take
				p.holder.pos = Vector2(28.7, 15.0)
				PlaySetup._by_tag(p, "5").pos = Vector2(28.7, 5.0)
				p.keeper.pos = Vector2(Geo.KEEPER_X, Geo.GOAL_Y))
			if r != "":
				open.all += 1
				if r == "caught":
					open.caught += 1
	_ok(73, open.all > 0 and float(open.caught) / open.all >= 0.9, "open wing to wing on a 6 on 5 gets there: %d of %d" % [open.caught, open.all])
	var hit := {"n": 0, "all": 0}
	for sd in n:
		var r := _wing(_man_up(5200 + sd, false, "1"), "5", func(p: Play):
			var d: Swimmer = p.defenders.filter(func(s): return not s.out)[0]
			d.pos = PlaySetup._by_tag(p, "1").pos.lerp(PlaySetup._by_tag(p, "5").pos, 0.25)
			d.target = d.pos
			d.player.attrs["dfn"] = 10.0)
		if r != "":
			hit.all += 1
			if r != "caught":
				hit.n += 1
	# (the wing-to-wing lob, Play.WING_LOB_PEAK: it goes up over the keeper, so over a man in the lane too;
	# before it, a defender there cut it out some of the time)
	_ok(74, hit.all > 0 and hit.n == 0, "the wing-to-wing lob goes over an active defender in the lane: cut out %d of %d" % [hit.n, hit.all])
	var sides := []
	for defending in [false, true]:
		var p := _man_up(5400, defending, "1")
		p.pass_to(PlaySetup._by_tag(p, "5"))
		sides.append([p.swing_pass(), p._keeper_pick(0.2, 0.55)])
	_ok(75, sides[0] == sides[1] and bool(sides[0][0]), "the same rule for the CPU's attack and yours")
	# keepers
	var left := PlayAI.keeper_set_y(Vector2(27.2, 3.6), 0.7)
	var right := PlayAI.keeper_set_y(Vector2(27.2, 16.4), 0.7)
	_ok(76, left < Geo.GOAL_Y - 0.5, "the ball out left, he goes left: %.2f m" % (Geo.GOAL_Y - left))
	_ok(77, absf((right - Geo.GOAL_Y) - (Geo.GOAL_Y - left)) < 0.001, "out right he mirrors it: %.2f m" % (right - Geo.GOAL_Y))
	var p := _setup(5500, false)
	p.give_ball(PlaySetup._by_tag(p, "3"))
	var top_step := 0.0
	for i in 240:
		if i == 60:
			p.give_ball(PlaySetup._by_tag(p, "5"))
		if i == 150:
			p.give_ball(PlaySetup._by_tag(p, "1"))
		var was := p.keeper.pos
		p.shot_clock = 20.0
		p.freeze = 0.0
		p.step(DT)
		if p.over:
			break
		top_step = maxf(top_step, was.distance_to(p.keeper.pos))
	_ok(78, top_step < 0.12, "he swims there: at most %.3f m a frame" % top_step)
	var good := PlayAI.keeper_set_y(Vector2(27.2, 3.6), 1.0)
	var poor := PlayAI.keeper_set_y(Vector2(27.2, 3.6), 0.0)
	_ok(79, good < poor and absf(good - Geo.GOAL_Y) <= Geo.GOAL_HALF - PlayAI.KEEPER_POST_GAP + 0.001, "his skill still decides how true he sets, and he never leaves the far corner")
	# entries: the dropper a step off the lane, the centre partly open
	var tally := {"caught": 0, "foul": 0, "stolen": 0}
	for sd in n * 4:
		var q := _setup(5600 + sd, false)
		q.give_ball(PlaySetup._by_tag(q, "3"))
		q.instant_drop(F.M_DROP)
		for i in 150:
			q.step(DT)
		q.restart = false
		q.first_pass = true
		var cc := PlaySetup._by_tag(q, "C")
		var dr0 := q.f_dropper
		dr0.pos = q.holder.pos.lerp(cc.pos, 0.7) + Vector2(0, 0.4)
		dr0.target = dr0.pos
		q.pass_to(cc)
		var o := String(q.drop_entry.get("outcome", ""))
		if o != "":
			tally["foul" if o == "foul" else ("caught" if o == "catch" else "stolen")] += 1
	_ok(80, tally.caught > 0, "a good ball to a slightly open centre can land: %s" % str(tally))
	_ok(81, tally.foul > 0 and tally.foul < tally.caught + tally.stolen, "...or draw an ordinary foul, not every time")
	var blocked := {"stopped": 0, "all": 0}
	for sd in n:
		var q := _setup(5900 + sd, false)
		q.give_ball(PlaySetup._by_tag(q, "3"))
		q.instant_drop(F.M_DROP)
		for i in 180:
			q.step(DT)
		q.restart = false
		q.first_pass = true
		var cc := PlaySetup._by_tag(q, "C")
		var dr := q.f_dropper
		dr.pos = q.holder.pos.lerp(cc.pos, 0.7)   # right in the lane
		dr.target = dr.pos
		q.pass_to(cc)
		blocked.all += 1
		if String(q.drop_entry.get("outcome", "")) in ["steal", "tip"]:
			blocked.stopped += 1
	_ok(82, blocked.stopped == blocked.all and blocked.all > 0, "through a set dropper it's stopped: %d of %d" % [blocked.stopped, blocked.all])
	# calling a drop
	var seq := true
	var formed := true
	for f in [F.M_DROP, F.FOUR_FIVE, F.FIVE_DROP, F.THREE_FOUR]:
		var q := _setup(6100 + f, true)
		q.give_ball(PlaySetup._by_tag(q, "3"))
		for i in 30:
			q.step(DT)
		var clock := q.shot_clock
		seq = seq and q.select_formation(f) and q.formation == F.PRESS and q.drop_pending == f
		for i in 120:
			q.step(DT)
			if q.drop_fouled:
				break
		var fouls := q.events.filter(func(e): return e.k == "foul").size()
		seq = seq and q.drop_fouled and fouls == 1 and q.formation == f and q.restart and q.shot_clock <= clock + 0.001
		formed = formed and q.freeze > 0.0
		var froze := q.shot_clock
		for i in int(Play.DROP_FOUL_FREEZE * 60.0):
			q.step(DT)
		var dr := q.f_dropper
		formed = formed and dr != null and q.shot_clock == froze and dr.pos.distance_to(DefenseFormation.drop_spot(q, PlaySetup._by_tag(q, "C"))) < 2.2
	_ok(83, seq, "all four drops: an ordinary foul on the ball, then the drop")
	_ok(84, formed, "it forms in the stoppage: there by the free throw")
	var q2 := _setup(6200, false)
	q2.give_ball(PlaySetup._by_tag(q2, "3"))
	q2.ai_drop = F.M_DROP
	for i in 30:
		q2.step(DT)
	DropCall.call_formation(q2, F.M_DROP, "centre")
	var before := q2.formation
	for i in 120:
		q2.step(DT)
		if q2.drop_fouled:
			break
	_ok(85, before == F.PRESS and q2.drop_fouled and q2.formation == F.M_DROP, "the CPU's drop goes the same way")
	var q3 := _setup(6300, true)
	q3.give_ball(PlaySetup._by_tag(q3, "3"))
	for i in 30:
		q3.step(DT)
	q3.select_formation(F.M_DROP)
	for k in 8:
		q3.select_formation(F.THREE_FOUR)
		for i in 30:
			q3.step(DT)
	_ok(86, q3.events.filter(func(e): return e.k == "foul").size() <= 1 and q3.formation == F.M_DROP, "pressing it again and again: one foul")
	var q4 := _setup(6400, true)
	q4.give_ball(PlaySetup._by_tag(q4, "3"))
	for i in 30:
		q4.step(DT)
	var c0 := q4.shot_clock
	q4.select_formation(F.M_DROP)
	for i in 60:
		q4.step(DT)
		if q4.drop_fouled:
			break
	var at := q4.shot_clock
	for i in 90:
		q4.step(DT)
	_ok(87, at <= c0 and q4.shot_clock == at and q4.restart, "the shot clock isn't reset, and it waits for the free throw")
	# 5 DROP
	var q5 := _setup(6500, true)   # your defence: A5 is the "5"
	q5.give_ball(PlaySetup._by_tag(q5, "3"))
	q5.instant_drop(F.FIVE_DROP)
	var a5 := PlaySetup._by_tag(q5, "5")
	var from := a5.pos
	for i in 240:
		q5.shot_clock = 20.0
		q5.step(DT)
	var closer := a5.pos.distance_to(Geo.goal_center()) < from.distance_to(Geo.goal_center()) - 1.0
	_ok(88, closer, "position 5 slides at the cage: %.1f m closer" % (from.distance_to(Geo.goal_center()) - a5.pos.distance_to(Geo.goal_center())))
	var line := (Geo.goal_center() - from).normalized()
	var off_line := absf((a5.pos - from).cross(line))
	_ok(89, off_line < 0.5, "along his line to the goal, not up the screen: %.2f m off it" % off_line)
	var q6 := _setup(6500, false)   # the CPU's defence: its 5 is across the pool
	q6.give_ball(PlaySetup._by_tag(q6, "3"))
	q6.instant_drop(F.FIVE_DROP)
	var b5 := DefenseFormation.slide_man(q6)
	var from6 := b5.pos
	for i in 240:
		q6.shot_clock = 20.0
		q6.step(DT)
	var mir := absf((b5.pos.y - Geo.GOAL_Y) + (a5.pos.y - Geo.GOAL_Y)) < 0.6 and b5.tag == "1" and absf(b5.pos.x - a5.pos.x) < 0.6
	_ok(90, mir, "and it mirrors for the other direction (%s: y %.1f from %.1f)" % [b5.tag, b5.pos.y, from6.y])
	var side := "right"
	var cd := q6.call_drive(side)
	_ok(91, cd == b5 and cd.drive_t > 0.0, "a DRIVE call goes to him")
	var jumps := {"yes": 0, "all": 0}
	for sd in n:
		var q7 := _setup(6600 + sd, true)
		var s5 := PlaySetup._by_tag(q7, "5")
		q7.give_ball(s5)
		q7.instant_drop(F.FIVE_DROP)
		jumps.all += 1
		for i in 240:
			q7.shot_clock = 20.0
			q7.step(DT)
			if q7.over:
				break
			if q7.f_helper != null:
				jumps.yes += 1
				break
	_ok(92, jumps.yes > 0 and jumps.yes < jumps.all, "D4 can jump him, and doesn't always: %d of %d" % [jumps.yes, jumps.all])
	_look(93, "nothing else broke (--test all)", "")
