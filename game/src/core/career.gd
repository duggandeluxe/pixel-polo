class_name Career
extends RefCounted
## A college coaching career: your program, the 30-school world, the season and its money.
## Pure data + rules; screens read and call it, Game saves it after every week.

const SAVE_VERSION := 10   # 10: (a retired field); 9: every program's three-man bench (the roll-out); 2: player traits; 3: 8-man rosters; 4: team OVR, several games a week; 5: 18-man programs, the recruiting year; 6: OFF/DEF ratings locked for the season, the Top 20 poll, the scoring engine; 7: seven-man rosters, player stars and HOT/COLD form; 8: XP development, injuries as attribute penalties
const START_YEAR := 2026
## Every program carries seven players across four class years: one goalkeeper and six field
## players, and all seven play every game ("Player Stars & 7-Player Rosters"). Older saves'
## bigger rosters are cut on load (trim_rosters).
const ROSTER_MAX := 7
## Of those, field players (the rest is the one keeper).
const FIELD_MAX := 6
## Every program (yours and the AI's, since the Exclusions & Roll-Out update) carries this many
## more on its bench: the substitutes a rolled player is replaced by (PoloTeam.starters), places
## it may recruit into; any still empty when a season starts are filled with walk-ons
## (WalkOns). A backup keeper can be one of them.
const BENCH_MAX := 3
## Scholarships: funded places on the seven-man roster (not offers a year). A program has this
## many at once; the rest of the roster are walk-ons. A senior's frees up when he graduates.
## (Eight of 18 before seven-man rosters; four of seven keeps that share, a little over half.)
const SCHOL_MAX := 4

const FAC := {
	"pool": {"name": "Aquatic Center", "desc": "A bigger home crowd and program prestige.",
		"cost": [0, 90, 170, 290, 460]},
	"weights": {"name": "Weight Room", "desc": "Program prestige. Players now develop through their own XP.", "cost": [0, 70, 140, 240, 380]},
	"medical": {"name": "Sports Medicine", "desc": "Fewer training injuries (12% less risk per level).", "cost": [0, 70, 140, 240, 380]},
	"video": {"name": "Video Room", "desc": "Program prestige. Players now develop through their own XP.", "cost": [0, 70, 140, 240, 380]},
	"recruit": {"name": "Recruiting Department", "desc": "Program prestige. Recruits are signed with Polo Points on the market.", "cost": [0, 60, 120, 210, 340]},
}
const FAC_ORDER := ["pool", "weights", "medical", "video", "recruit"]
const FAC_MAX := 5
const STAFF := {
	"offense": {"name": "Offensive Coordinator", "desc": "Program prestige. Players now develop through their own XP.", "cost": [60, 150, 300]},
	"defense": {"name": "Defensive Coordinator", "desc": "Program prestige. Players now develop through their own XP.", "cost": [60, 150, 300]},
	"goalie": {"name": "Goalkeeper Coach", "desc": "Program prestige. Players now develop through their own XP.", "cost": [60, 150, 300]},
	"recruiter": {"name": "Recruiting Coordinator", "desc": "Program prestige. Recruits are signed with Polo Points on the market.", "cost": [50, 120, 240]},
}
const STAFF_ORDER := ["offense", "defense", "goalie", "recruiter"]
const STAFF_MAX := 3

## How a playoff loss reads in the season review.
const LOST_IN := {"conf_qf": "conference quarterfinal", "conf_semi": "conference semifinal", "conf_final": "conference final",
	"nat_r1": "NCSA first round", "nat_qf": "NCSA quarterfinal", "nat_sf": "NCSA semifinal"}

## The tutorial a new career opens with (DrillScreen): started, then how it ended. It only ever
## launches from NEW CAREER, so nothing here brings it back when a career is loaded.
const TUTORIAL_PENDING := "pending"
const TUTORIAL_SKIPPED := "skipped"
const TUTORIAL_COMPLETED := "completed"

## The season's states (Championship Elimination): still in it, knocked out of everything left
## (the rest of the league still to play), between seasons.
const STATE_ACTIVE := "ACTIVE"
const STATE_ELIMINATED := "ELIMINATED"
const STATE_OFFSEASON := "OFFSEASON"

var rng := RandomNumberGenerator.new()
var year := START_YEAR
var week := 0
var school := ""
var coach := {"first": "", "last": "", "rep": 10, "wins": 0, "losses": 0, "titles": [], "seasons": 0}
var teams := {}                 # id -> PoloTeam
var sandbox := false            # a Developer Mode test career: never touches the player's profile (not saved)
var credits := 0                # this dynasty's own YELLOW coins (earned / given in it: Wallet), saved with it
var convertible := 0            # how many of `credits` were earned by playing (Wallet's exchange; never shown as a currency)
var cv_earned := 0              # ...every such coin it has ever earned
var cv_out := 0                 # ...and the yellow this save knows it has exchanged (the ledger may know more)
var uid := ""                   # this dynasty's id for the purchased wallet's journal (CoinVault.debit / commit)
var school_fac := {}            # team id -> {facility: level}; facilities stay with the school
var staff := {"offense": 0, "defense": 0, "goalie": 0, "recruiter": 0}   # your staff follow you
var training := {"focus": "balanced", "intensity": 2}
var schedule: Array = []
var table := {}                 # team id -> Schedule.empty_row()
var season := {}
var history: Array = []
var news: Array = []
var queue: Array = []           # things the hub shows next: {type, ...}
var market: Array = []           # the RECRUITING MARKET's prospects (Recruiting): {p, price, sc, legacy}
var incoming: Array = []         # your signed recruits: they join as freshmen after the season
var refreshes := 0               # market refreshes this season (the first is free: Recruiting.REFRESH_COSTS)
var auto_games := 0              # your games since the market's last free post-game roll (Recruiting.after_game)
var new_recruits := false        # NEW RECRUITS AVAILABLE: a free roll not yet seen on the Recruiting screen
var recruits_popped := false     # ...and the hub has played its pop-in for it (not saved: once a session)
var dev_recruits := {}         # the DEV Recruits' spawn log and who's been signed (DevRecruits): {} none yet
var recruit_warned := ""         # the season whose RECRUITING DEADLINE APPROACHING! was shown (once a season)
var injury_seen := ""           # "year:week" when INJURY ACTIVE: ADJUST PRACTICE? was answered (Training opened): back next week if anyone's still hurt
var hub_seen := false           # the Dynasty Hub has been opened from the home team card: its first-time hint is gone for good
var cr_claims: Array = []        # every credit reward paid, by id (CreditRewards.claim): never twice
var conf_awards: Array = []      # every conference weekly award ever given (ConfAwards), for good
var award_players := {}          # pid -> his player as he was when he last won one, as JSON text (ConfAwards.player_of)
var awards_done: Array = []      # the weeks whose awards are decided ("year:week": never twice)
var tourney_awards: Array = []   # every All-Tournament award ever given (TourneyAwards), for good
var tourney_stats := {}          # "year:tid" -> {pid: {team, line}}: a tournament's totals while it's on
var tourney_done: Array = []     # the tournaments decided ("year:tid": never twice)
var national_done: Array = []    # the seasons whose NCSA honours are given (NationalAwards: never twice)
var cut_pool: Array = []         # this off-season's cut players, for the other programs (Offseason): [{p, from}]
var league_news: Array = []      # LEAGUE NEWS (LeagueNews): stories from the dynasty's own results, newest first
var phase := "season"            # "season"; "done": the season's over, NEXT SEASON to come; "cuts": your roster is over its cap (Offseason)
## CHAMPIONSHIP ELIMINATION: where your competitive season stands (STATE_*), saved. ELIMINATED:
## out of every championship still to be played (the hub's SEASON OVER, SIM TO OFFSEASON).
var season_state := STATE_ACTIVE
## ...and how it ended for you ({} none this season): {year, season, kind, round, opp, us, them,
## so, home, selected, shown (the OH NO! screen has been seen), simmed (SIM TO OFFSEASON ran)}
var elim := {}
## ...or how it was won: the NCSA final ({} none this season): {year, season, opp, us, them, so,
## record, conf_title, shown (the CHAMPIONS! screen has been seen)}
var champ := {}
var hot_tip := false            # legacy: the roster's old one-time HOT tip (removed; HotTutorial covers it). Kept for saves.
var hot_tutorial_seen := false  # the first-HOT-star tutorial (HotTutorial) is done or skipped in this dynasty, for good
var hot_tutorial_pid := -1       # ...queued for it: the first of yours to earn a HOT star (-1: nobody yet)
var tutorial := ""               # this career's opening tutorial: TUTORIAL_* ("": a career from before it)
var gameplan: int = DefenseFormation.DEFAULT_DROP   # Coaching's PICK YOUR DEFENSE: the drop each match starts with (MatchFlow.set_gameplan)
var rating_history: Array = []  # every season's starting ratings: {year, ratings: {id: [OVR, OFF, DEF]}}
var final_polls: Array = []     # every season's final Top 20 poll: {year, ranks: [ids, best first]}
var upgraded := false            # loading moved an older save onto 18-man programs (not saved)
var form_rows := {}              # each team's last graded game: id -> PlayerForm.grade_team rows (not saved)
var next_id := 1
var game_over := false
var difficulty := ""        # the difficulty mode this career plays at (Difficulty.MODES; "" until it's picked: the device's)
var dyn_ai := Difficulty.DYN_START   # DYNAMIC's level (0 EASY .. 1 HARD), moved only after a completed game
var dyn_hist: Array = []    # ...and the recent games it's judged on (Difficulty.game_entry)
var train_boost := 0.0          # next week's training XP, from talks and cards (a fraction)
var train_cycle := ""           # the last week whose training was processed ("year-week": never twice)
var cards_seen: Array = []      # event cards already drawn (the `once` ones never repeat)
## THE POSTGAME REVIEW & COACHING EVENTS (Postgame, CoachEvents), all saved: the event drawn
## after the last game until it's answered ({} none), the last games' events ("" for none) for
## no-repeats, each player's season stats as this week began (for the week's award lines:
## ConfAwards), and the last board's
## coach's notes (so the next board says something new when it can).
var pending_event := {}
var event_log: Array = []
## QUARTER LENGTH (Settings): the minutes each quarter of this career's played games lasts
## (MatchState.QUARTER_OPTIONS). 2 for every new career; an older save without it, 2.
var quarter_min := 2
## A coaching decision's consequences still to come (CoachEvents): next-game challenges, wagers,
## suspensions, Prove Me Wrong; each settled once, by your next game (played or simmed). And what
## they came to, for the postgame to show once ("shown"), kept either way.
var coach_pending: Array = []
var coach_results: Array = []
var coach_seq := 0
## The seasons before this dynasty (Legacy): each one's champions; its awards are in the award
## records, marked "hist". Made once, when the career begins; [] for an older save.
var legacy: Array = []
## Every finished season's champions, conference by conference and the NCSA's (TeamHonours: the
## team trophy case): {season, conf: {conf: team}, nat: team}. [] for an older save.
var champions_log: Array = []
var week_base := {}             # {year, week, lines: {pid: {g, a, sv, ga, gp}}}
var last_notes: Array = []
var records := {"school": {}, "ncsa": {}}   # see Records
var awards: Array = []          # every season's award winners: {year, award, name, team}
var last_summary := {}          # the game summary screen's data (not saved)
var last_dev := {}              # your roster's development either side of the last game's XP (dev_snapshot; not saved)
var settled_box := ""           # the last played match settled (MatchState.uid): never twice
var trimmed := false            # loading cut an old over-size roster down (not saved)
var realigned := false          # an old save just moved onto the current conferences (not saved)
var rated := false              # loading gave an older save its season ratings snapshot (not saved)
var converted := false          # loading moved an older save off the old recruiting (not saved)

# ------------------------------------------------------------------ new game
## A new career in one go: the setup (every roster), then your school (begin).
static func new_game(school_id: String, coach_first: String, coach_last: String, seed_value: int) -> Career:
	return new_setup(seed_value).begin(school_id, coach_first, coach_last)

## A DYNASTY SETUP: all 30 schools with their first rosters, made once from `seed_value` before
## you pick a school (Game.dynasty_setup), so the picker's ratings are those very players. No
## school is yours yet: nothing here depends on which you'll pick, and the same seed always
## makes the same players. begin() turns it into your career without making them again.
static func new_setup(seed_value: int) -> Career:
	var c := Career.new()
	c.rng.seed = seed_value
	c.difficulty = Difficulty.new_career_mode()
	for s in Colleges.SCHOOLS:
		var t := PoloTeam.new()
		t.id = s.short
		t.name = s.name
		t.mascot = s.mascot
		t.c1 = Color(s.c1)
		t.c2 = Color(s.c2)
		t.conf = s.conf
		t.prestige = float(s.prestige)
		t.pool = String(s.get("pool", Pools.DEFAULT_ID))
		# the school's original overall (its BASE PROGRAM RATING): its first roster's target, used
		# here once (from now on the team's overall is its seven starters', PoloTeam.team_overall)
		CollegeGen.make_initial_roster(t, c.rng, c.new_id, float(s.ovr))
		# its bench (every program's: the roll-out's substitutes), below the seven, who stay the
		# starters (PoloTeam.starters picks the best seven: the subs are made under them)
		CollegeGen.add_initial_bench(t, c.rng, c.new_id, float(s.ovr), BENCH_MAX, false)
		for p in t.roster:
			Development.ensure(p)   # hidden levels from the attributes they were made with
			PlayerForm.reset(p)     # a new team starts with nobody hot: red stars are only earned in games
		c.teams[t.id] = t
	return c

## Your career from this setup, at `school_id`: the rosters stay exactly as they were made; your
## program just gets its three subs (CollegeGen.add_initial_bench: the starters, and so the
## ratings the picker showed, don't move). Then the first season. Call once, on a setup.
func begin(school_id: String, coach_first: String, coach_last: String) -> Career:
	uid = new_uid()
	difficulty = Difficulty.new_career_mode()   # (DYNAMIC unless changed on the New Career screen)
	Difficulty.reset_new_career()               # (the next new dynasty starts at DYNAMIC again)
	school = school_id
	coach.first = coach_first
	coach.last = coach_last
	var t: PoloTeam = teams[school_id]
	t.is_player = true
	# your lineup: the seven who start now in their places, the subs on the bench (the roster
	# screen's); the players are the very ones the picker rated
	t.lineup = CollegeGen.lineup_of(t)
	t.sync_lineup()
	start_season()
	Legacy.generate(self)   # (the league's past: the three seasons before this one)
	queue.push_front({"type": "info", "title": "WELCOME, COACH %s" % coach_last.to_upper(),
		"text": "The %s have hired you to run their water polo program. Win games, develop your players and build something. Bigger schools will notice." % t.name})
	return self

func new_id() -> int:
	next_id += 1
	return next_id - 1

# ------------------------------------------------------------------ accessors
func team() -> PoloTeam:
	return teams[school]

func conf_name(conf: String = "") -> String:
	return String(Colleges.conference(conf if conf != "" else team().conf).get("name", ""))

## The conference's short name (PEC), where the full one doesn't fit.
func conf_abbr(conf: String = "") -> String:
	return Colleges.conf_abbr(conf if conf != "" else team().conf)

func tier() -> int:
	return Colleges.conf_tier(team().conf)

func season_label() -> String:
	return "%d-%02d" % [year, (year + 1) % 100]

func next_season_label() -> String:
	return "%d-%02d" % [year + 1, (year + 2) % 100]

## Where the year is, for the header chips: "GAME 3/16" in the regular season (your next game,
## or the last one once they're all played), the round in the playoffs, "ROSTER CUTS" after it.
func calendar_text() -> String:
	if phase == "season":
		if week < schedule.size() and Schedule.is_playoff(schedule[week]):
			return String(Schedule.SHORT_NAMES.get(String(schedule[week].kind), "PLAYOFFS"))
		return "GAME %d/%d" % [mini(Schedule.games_played(schedule, school) + 1, Schedule.REGULAR_GAMES), Schedule.REGULAR_GAMES]
	return "ROSTER CUTS" if phase == "cuts" else "SEASON OVER"

## The season in full, for the Dynasty Hub's tracker: "2026-2027". (season_label stays the short
## "2026-27": it's the key in saves, history and awards.)
func season_years() -> String:
	return "%d-%d" % [year, year + 1]

## The week of the season for the Dynasty Hub's tracker: "WEEK 3". It's the calendar week (the
## round `week` is on), so three games in one week are still one week; it starts at WEEK 1 each
## season. Off-season, the phase instead ("ROSTER CUTS", "SEASON OVER").
func week_text() -> String:
	if is_eliminated():
		return "SEASON OVER"
	if phase == "season":
		return "WEEK %d" % (clampi(week, 0, maxi(schedule.size() - 1, 0)) + 1)
	return calendar_text()

func in_offseason() -> bool:
	return phase != "season"

func roster_max() -> int:
	return roster_cap(school)

## The most players school `s` may carry: the seven, and the bench (every program's).
func roster_cap(_s: String) -> int:
	return ROSTER_MAX + BENCH_MAX

## The most keepers school `s` may carry: the one, and a backup on the bench.
func keeper_cap(_s: String) -> int:
	return 2

func fac(key: String) -> int:
	return int(school_fac.get(school, {}).get(key, 1))

func cur() -> Dictionary:
	return schedule[week] if week < schedule.size() else {}

func round_name(r: Dictionary = {}) -> String:
	if r.is_empty():
		r = cur()
	return String(r.get("name", ""))

## Your games this week (up to three), in the order they're played.
func my_games(r: Dictionary = {}) -> Array:
	if r.is_empty():
		r = cur()
	var out: Array = r.get("games", []).filter(func(g): return g.h == school or g.a == school)
	out.sort_custom(func(a, b): return int(a.get("d", 0)) < int(b.get("d", 0)))
	return out

## Your game this week: the next one to play, else the last one played; {} if you aren't
## playing (a bye, or knocked out).
func my_game() -> Dictionary:
	var mine := my_games()
	for g in mine:
		if g.r == null:
			return g
	return mine[mine.size() - 1] if not mine.is_empty() else {}

func has_game() -> bool:
	return not my_game().is_empty() and my_game().r == null

## Your games this week are over but the week hasn't moved on (the app closed on the summary).
func game_done_this_week() -> bool:
	return not my_game().is_empty() and my_game().r != null

## The week number on the calendar (rounds are weeks).
func week_no() -> int:
	return mini(week + 1, schedule.size())

func opponent() -> PoloTeam:
	var g := my_game()
	if g.is_empty():
		return null
	return teams[g.a] if g.h == school else teams[g.h]

func is_home() -> bool:
	return my_game().get("h", "") == school

## Where this week's game is played: always the home team's pool.
func venue() -> PoolDef:
	var g := my_game()
	if g.is_empty():
		return Pools.get_def(team().pool)
	return Pools.get_def((teams[g.h] as PoloTeam).pool)

func venue_home() -> PoolDef:
	return Pools.get_def(team().pool)

## Where this week's game is played, by name (the Home Waters update): the home team's own pool
## (Colleges.venue_name), "" at a neutral site.
func venue_name() -> String:
	var g := my_game()
	if g.is_empty():
		return Colleges.venue_name(school)
	if Schedule.is_neutral(g):
		return ""
	var named := Colleges.venue_name(String(g.h))
	return named if named != "" else venue().name

func record_text(id: String = "") -> String:
	var r: Dictionary = table.get(id if id != "" else school, Schedule.empty_row())
	return "%d-%d" % [r.w, r.l]

func conf_record_text(id: String = "") -> String:
	var r: Dictionary = table.get(id if id != "" else school, Schedule.empty_row())
	return "%d-%d" % [r.cw, r.cl]

## The season records of your team and this week's opponent once this game's result is in
## (`won`: you won it), the way the table will count it: {"us": "6-7 (2-4)", "them": "9-4 (5-1)"},
## overall then conference. A playoff game doesn't go in the table, so it leaves them as they
## are. Changes nothing.
func records_after(won: bool) -> Dictionary:
	var g := my_game()
	if g.is_empty():
		return {}
	var r := cur()
	var counts: bool = not Schedule.is_playoff(r) and not r.get("recorded", false) and not g.get("n", false)
	var conf: bool = Schedule.is_conf_game(r, g)
	var opp: String = g.a if g.h == school else g.h
	var out := {}
	for side in 2:
		var row: Dictionary = table.get(school if side == 0 else opp, Schedule.empty_row())
		var rec := [int(row.w), int(row.l), int(row.cw), int(row.cl)]
		if counts:
			var i := 0 if (side == 0) == won else 1
			rec[i] += 1
			if conf:
				rec[i + 2] += 1
		out["us" if side == 0 else "them"] = "%d-%d (%d-%d)" % rec
	return out

## Your next game still to play (later this week, or after): {"round", "opp", "home"};
## {"round", "tbd": true} when it's a playoff round that isn't drawn yet; {} when the season has
## nothing more for you. Changes nothing.
func next_game() -> Dictionary:
	for w in range(week, schedule.size()):
		var r: Dictionary = schedule[w]
		if not Schedule.drawn(r):
			if w > week:
				return {"round": round_name(r), "tbd": true}
			continue
		for g in my_games(r):
			if g.r == null:
				return {"round": Schedule.game_label(r, g), "opp": g.a if g.h == school else g.h, "home": g.h == school}
	return {}

func conf_rank(id: String = "") -> int:
	var tid := id if id != "" else school
	return Schedule.conf_table(teams, table, teams[tid].conf).find(tid) + 1

func add_news(t: String) -> void:
	news.push_front({"t": t, "y": year, "w": week})
	if news.size() > 40:
		news.resize(40)

## Playoff week i has no game for you: is it a bye (you're still in) rather than being out?
func bye_week(i: int) -> bool:
	var fam := String(schedule[i].kind).substr(0, 4)
	if i == week:
		return Schedule.alive(season, schedule[i], school, team().conf)
	for j in range(i + 1, schedule.size()):
		if String(schedule[j].kind).substr(0, 4) == fam and not my_games(schedule[j]).is_empty():
			return true
	return false

func season_over_for_me() -> bool:
	if week >= schedule.size():
		return true
	if not Schedule.is_playoff(cur()) or not Schedule.drawn(cur()):
		return false
	return my_game().is_empty() and not Schedule.alive(season, cur(), school, team().conf)

# ------------------------------------------------------------------ championship elimination
## Out of every championship still to be played? Only once the NCSA field is drawn: a conference
## tournament loss never ends a season by itself (an at-large bid can still come), so it's the
## NCSA bracket that decides, either by leaving you out or by your loss in it. Read from the
## schedule alone: the same answer however often it's asked.
func knocked_out() -> bool:
	if phase != "season" or week >= schedule.size():
		return false
	var r: Dictionary = cur()
	if not String(r.kind).begins_with("nat_") or not Schedule.drawn(r):
		return false
	var mine := my_games(r)
	if mine.any(func(g): return g.r == null):
		return false   # (a game of yours still to play this round)
	if not season.has("nat_slots"):
		return mine.is_empty()   # (an older save's bracket: no game this round is being out)
	return not Schedule.alive(season, r, school, team().conf)

## The season is over for you but not for the league: the hub's SEASON OVER.
func is_eliminated() -> bool:
	return phase == "season" and season_state == STATE_ELIMINATED

## The OH NO! YOUR SEASON IS OVER screen is still to be seen (once a season).
func elim_pending() -> bool:
	return not elim.is_empty() and int(elim.get("year", -1)) == year and not bool(elim.get("shown", false))

## Keeps season_state with the schedule. `fresh`: a week just ended (an elimination found now gets
## its OH NO! screen; one found on loading a save never replays it). A loss in the NCSA final
## ends the season with no league left to play, so it's straight to the off-season, but it's
## still an elimination for the OH NO! screen. Winning it never is.
func update_season_state(fresh: bool = false) -> void:
	if phase != "season":
		if fresh and season_state == STATE_ACTIVE and elim.is_empty() and _lost_final():
			_record_elimination(false)
		elif fresh and season_state == STATE_ACTIVE and champ.is_empty() and String(season.get("champion", "")) == school:
			_record_title()   # (won it: the CHAMPIONS! screen, once)
		season_state = STATE_OFFSEASON
		return
	if knocked_out():
		if season_state != STATE_ELIMINATED:
			season_state = STATE_ELIMINATED
			if elim.is_empty() or int(elim.get("year", -1)) != year:
				_record_elimination(not fresh)
			# (a decision riding on your next game has no next game now: settled as void)
			CoachEvents.void_all(self, "YOUR SEASON IS OVER")
	else:
		season_state = STATE_ACTIVE

func _lost_final() -> bool:
	var last: Dictionary = schedule[schedule.size() - 1] if not schedule.is_empty() else {}
	if last.is_empty() or String(last.get("kind", "")) != "nat_final":
		return false
	for g in last.games:
		if g.r != null and Schedule.loser(g) == school:
			return true
	return false

## The CHAMPIONS! screen is still to be seen (once, the season you win the NCSA).
func champ_pending() -> bool:
	return not champ.is_empty() and int(champ.get("year", -1)) == year and not bool(champ.get("shown", false))

## The NCSA final you won, kept for the CHAMPIONS! screen.
func _record_title() -> void:
	var e := {"year": year, "season": season_label(), "shown": false, "record": record_text(),
		"conf_title": school in (season.get("conf_champs", []) as Array)}
	var lp := last_played()
	if not lp.is_empty():
		var g: Dictionary = lp[1]
		var home: bool = g.h == school
		var s: Array = g.r.s
		e.merge({"opp": String(g.a if home else g.h), "us": int(s[0] if home else s[1]), "them": int(s[1] if home else s[0]),
			"so": [] if (g.r.so as Array).is_empty() else ([int(g.r.so[0]), int(g.r.so[1])] if home else [int(g.r.so[1]), int(g.r.so[0])])})
	champ = e

## Your last game played this season: [round, game], or [] if there was none.
func last_played() -> Array:
	for w in range(mini(schedule.size() - 1, week), -1, -1):
		var mine := my_games(schedule[w]).filter(func(g): return g.r != null)
		if not mine.is_empty():
			return [schedule[w], mine[mine.size() - 1]]
	return []

## How the season ended, kept for the OH NO! screen and the SEASON OVER hub.
func _record_elimination(shown: bool) -> void:
	var lp := last_played()
	var e := {"year": year, "season": season_label(), "shown": shown, "simmed": false,
		"selected": school in (season.get("nat_seeds", []) as Array)}
	if not lp.is_empty():
		var r: Dictionary = lp[0]
		var g: Dictionary = lp[1]
		var home: bool = g.h == school
		var s: Array = g.r.s
		e.merge({"kind": Schedule.game_kind(r, g), "game_round": Schedule.game_label(r, g), "opp": String(g.a if home else g.h), "home": home,
			"us": int(s[0] if home else s[1]), "them": int(s[1] if home else s[0]), "won": Schedule.winner(g) == school,
			"so": [] if (g.r.so as Array).is_empty() else ([int(g.r.so[0]), int(g.r.so[1])] if home else [int(g.r.so[1]), int(g.r.so[0])])})
	# the round it ended in: the NCSA game you lost, or the selection that left you out
	if bool(e.selected) and String(e.get("kind", "")).begins_with("nat_") and not bool(e.get("won", true)):
		e["round"] = String(Schedule.ROUND_NAMES.get(String(e.kind), e.get("game_round", "")))
	else:
		e["round"] = "NOT SELECTED FOR THE NCSA CHAMPIONSHIP"
	elim = e

## SIM TO OFFSEASON: every week left, the whole league's games (none of yours: you have none), to
## the NCSA final and on into the off-season (Offseason.begin: the awards, the review), at once.
## Only while eliminated, so only once: the off-season it reaches ends the eliminated state.
## True if it reached the off-season.
func sim_to_offseason() -> bool:
	if not is_eliminated() or bool(elim.get("simmed", false)):
		return false
	elim["simmed"] = true
	var guard := schedule.size() + 2
	while phase == "season" and guard > 0:
		guard -= 1
		sim_week_without_me()
		end_week()
	return phase != "season"

# ------------------------------------------------------------------ automatic postseason advance
## Out of this week's tournament round with no game of yours in it: knocked out of the conference
## tournament (or not in it), left out of the NCSA field, or knocked out of the NCSA. Nothing for
## you to play until the next tournament draws (or the season ends): advance_postseason sims it.
## A bye while you're still in is never one (you're through to the next round: it waits for you).
func advance_due() -> bool:
	if phase != "season" or week >= schedule.size() or game_over:
		return false
	var r: Dictionary = cur()
	if not Schedule.is_playoff(r) or not Schedule.drawn(r) or has_game():
		return false
	var key := "conf_slots" if String(r.kind).begins_with("conf_") else "nat_slots"
	if not season.has(key):
		return my_games(r).is_empty()   # (an older save's bracket: no game this round is being out)
	return not Schedule.alive(season, r, school, team().conf)

## THE AUTOMATIC POSTSEASON ADVANCE: every week with nothing for you in it, the league's games only,
## through the normal week (sim_week_without_me + end_week: results, stats, awards, polls, training,
## news, the NCSA draw, the off-season), at once. It stops at your next game (the NCSA field drawn
## with you in it), or runs on through the NCSA final into the off-season. Then FELL JUST SHORT!
## is noted if a conference tournament loss still got you into the NCSA. Never plays a game of
## yours. True if anything changed.
func advance_postseason() -> bool:
	var moved := false
	var guard := schedule.size() + 2
	while guard > 0 and advance_due():
		guard -= 1
		sim_week_without_me()
		end_week()
		moved = true
	if moved and not elim.is_empty() and int(elim.get("year", -1)) == year:
		elim["simmed"] = true   # (the whole season's played: nothing left for SIM TO OFFSEASON)
	return _note_fell_short() or moved

## FELL JUST SHORT!: still to be seen (once a season).
func fell_short_pending() -> bool:
	var f: Dictionary = season.get("fell_short", {})
	return not f.is_empty() and not bool(f.get("shown", false)) and phase == "season"

## Lost in your conference tournament, selected for the NCSA all the same, no NCSA game of yours
## played yet: FELL JUST SHORT! (kept in the season: once, saved).
func _note_fell_short() -> bool:
	if phase != "season" or season.has("fell_short") or week >= schedule.size():
		return false
	if not String(cur().kind).begins_with("nat_") or not school in (season.get("nat_seeds", []) as Array):
		return false
	var loss := {}
	for w in range(0, week):
		var r: Dictionary = schedule[w]
		for g in my_games(r):
			if g.r == null:
				continue
			var kind := Schedule.game_kind(r, g)
			if kind.begins_with("nat_"):
				return false   # (an NCSA game already played: too late for it)
			if kind.begins_with("conf_") and Schedule.loser(g) == school:
				var home: bool = g.h == school
				var s: Array = g.r.s
				loss = {"kind": kind, "round": String(Schedule.ROUND_NAMES.get(kind, Schedule.game_label(r, g))),
					"opp": String(g.a if home else g.h), "us": int(s[0] if home else s[1]), "them": int(s[1] if home else s[0]),
					"so": [] if (g.r.so as Array).is_empty() else ([int(g.r.so[0]), int(g.r.so[1])] if home else [int(g.r.so[1]), int(g.r.so[0])])}
	if loss.is_empty():
		return false   # (no conference tournament loss: the champions go on as ever)
	loss.merge({"shown": false, "year": year, "season": season_label(), "record": record_text(),
		"seed": Schedule.seed_of(season, "nat", school, ""), "at_large": school in (season.get("at_large", []) as Array)})
	season["fell_short"] = loss
	return true

## CONTINUE TO NCSA TOURNAMENT: seen; then any NCSA bye of yours played through (the league's games,
## the normal week), to your first NCSA game. The weeks it simmed.
func continue_to_ncsa() -> int:
	var f: Dictionary = season.get("fell_short", {})
	if not f.is_empty():
		f["shown"] = true
	var n := 0
	var guard := schedule.size() + 2
	while guard > 0 and phase == "season" and week < schedule.size() and not game_over:
		var r: Dictionary = cur()
		if not String(r.kind).begins_with("nat_") or not Schedule.drawn(r) or has_game():
			break
		guard -= 1
		sim_week_without_me()
		end_week()
		n += 1
	advance_postseason()   # (never needed with a game to play; kept so nothing is ever left idle)
	return n

## What's left of the NCSA after you: {round (its name, "" when it's all decided), alive (team
## ids still in), champion (once decided)}. Only results already played: nothing ahead is shown.
func remaining_championship() -> Dictionary:
	var out := {"round": "", "alive": [], "champion": ""}
	if week >= schedule.size():
		return out
	var last: Dictionary = schedule[schedule.size() - 1]
	for g in last.games:
		if g.r != null:
			out.champion = Schedule.winner(g)
	var r: Dictionary = cur()
	if String(r.kind).begins_with("nat_") and Schedule.drawn(r):
		out.round = String(r.name)
		out.alive = (season.get("nat_slots", []) as Array).filter(func(id): return String(id) != "")
	return out

# ------------------------------------------------------------------ money (Wallet)
static var _uid_n := 0
## A dynasty id, made once (a career from before the Universal Coin Wallet gets one on load).
static func new_uid() -> String:
	_uid_n += 1   # (no dice: the game's random stream stays exactly as it was)
	return "%x-%x-%x" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec() & 0xffffffff, _uid_n]

## Yellow coins in (CreditRewards, Coaching Events): this career's own, never shared, never blue
## (Wallet.grant_yellow).
func add_credits(n: int, why: String, convertible_coins: bool = true) -> int:
	return Wallet.grant_yellow(self, n, why, convertible_coins)

## The Yellow Coins you can spend (Wallet.yellow): the game's one currency.
func wallet() -> int:
	return Wallet.yellow(self)

## A coin cost: this dynasty's own first, then the shared ones; all or nothing (Wallet.spend_yellow).
func spend_credits(n: int, what: String = "SPEND") -> bool:
	return bool(Wallet.spend_yellow(self, n, what).ok)

func facility_cost(key: String) -> int:
	var lv := fac(key)
	return 0 if lv >= FAC_MAX else int(FAC[key].cost[lv])

func upgrade_facility(key: String) -> bool:
	var cost := facility_cost(key)
	if cost <= 0 or not spend_credits(cost, "FACILITY"):
		return false
	school_fac[school][key] = fac(key) + 1
	add_news("%s upgraded to level %d" % [FAC[key].name, fac(key)])
	return true

func staff_cost(key: String) -> int:
	var lv := int(staff.get(key, 0))
	return 0 if lv >= STAFF_MAX else int(STAFF[key].cost[lv])

func hire_staff(key: String) -> bool:
	var cost := staff_cost(key)
	if cost <= 0 or not spend_credits(cost, "STAFF"):
		return false
	staff[key] = int(staff.get(key, 0)) + 1
	return true

## Your players with upgrades still to spend (Development.pending), roster order. Every one is
## spent before another game (or week) begins: Game.goto sends a game start to them instead.
func upgrades_due() -> Array:
	if game_over:
		return []
	return team().roster.filter(func(p: PoloPlayer): return Development.pending(p) > 0)

## Why attribute `key` can't take an upgrade now, or "" if it can (tokens aside): it's at 10
## ("MAXED"), or at its own ceiling ("CEILING").
func boost_limit(p: PoloPlayer, key: String) -> String:
	if not key in p.key_ratings():
		return "MAXED"
	if p.attr(key) >= Attributes.MAX - Attributes.PRECISION:
		return "MAXED"
	if Attributes.room(p, key) < Attributes.PRECISION:
		return "CEILING"
	return ""

## An upgrade: one of his tokens for +1 on the attribute (only as far as its ceiling). Credits
## play no part. Nothing changes if he has no token or the attribute has no room.
func boost(p: PoloPlayer, key: String) -> bool:
	return Development.spend(p, key)

# ------------------------------------------------------------------ season
func start_season() -> void:
	coach.seasons = int(coach.seasons) + 1
	week = 0
	season = {"credit_log": [], "conf_seeds": {}, "nat_seeds": [], "conf_champs": [],
		"finish": "", "champion": ""}
	table = {}
	for id in teams:
		table[id] = Schedule.empty_row()
		for p in (teams[id] as PoloTeam).roster:
			p.stats = {}
			PlayerForm.reset(p)   # a new season starts NORMAL; CURRENT and POTENTIAL stay
			p.susp = 0            # (a suspension never carries into a new season)
	CoachEvents.void_all(self, "THE SEASON ENDED BEFORE IT COULD BE SETTLED")
	form_rows = {}
	for id in teams:
		if not school_fac.has(id):
			school_fac[id] = _default_facilities(teams[id])
	_lock_ratings()
	_snap_week()   # (everyone's stats were just emptied: the week starts at nothing)
	schedule = Schedule.build(teams, rng)
	phase = "season"
	season_state = STATE_ACTIVE   # (the COACHING button and the weekly calendar are back)
	elim = {}
	champ = {}
	Recruiting.start_season(self)   # a new market, the free refresh back
	CreditRewards.prune(self)
	var bonus := CreditRewards.season_start(self)   # +15, once a season
	if bonus > 0:
		add_news("NEW SEASON: %s" % CreditCoin.tag(bonus, true))
		queue.append({"type": "season", "bonus": bonus})   # (the new season's credits, announced)
	Poll.preseason(self)
	catch_up()

## The season's ratings snapshot: every team's OVR, OFF and DEF as the season starts, from its
## players then (PoloTeam.ratings). A record only (rating_history, the off-season report's
## "before"): the team overall itself is always the players' now, so it moves with training,
## lineup changes and HEAT UP during the season. Kept for every season in rating_history.
func _lock_ratings() -> void:
	var snap := {}
	var shown := {}
	for id in teams:
		var t: PoloTeam = teams[id]
		snap[id] = _whole(t.ratings())   # saved as loading will read it
		shown[id] = [t.offense_display(), t.defense_display(), t.goalkeeping_display()]
	season["ratings"] = snap
	season["shown"] = shown   # the displayed OFFENSE, DEFENSE, GOALKEEPING (the report's "before")
	rating_history = rating_history.filter(func(h): return int(h.year) != year)
	rating_history.append({"year": year, "ratings": snap.duplicate(true)})

func _default_facilities(t: PoloTeam) -> Dictionary:
	var lv := clampi(1 + int(t.prestige / 25.0), 1, FAC_MAX)
	var out := {}
	for k in FAC_ORDER:
		out[k] = lv
	return out

func _regular_done() -> bool:
	return week >= schedule.filter(func(r): return not Schedule.is_playoff(r)).size()

func _reached(kind: String) -> bool:
	for r in schedule:
		if r.kind == kind:
			for g in r.games:
				if g.h == school or g.a == school:
					return true
	return false

# ------------------------------------------------------------------ games
## Your game, played on the match screen. `box` comes from MatchState.
func finish_my_game(box: Dictionary) -> Dictionary:
	if not has_game() or (box.has("uid") and String(box.uid) == settled_box):
		return last_summary   # (already settled: a game's stats and XP are counted once)
	for id in teams:
		PoloTeam.clear_rolls(teams[id])   # (the game's over: everybody's eligible again)
	settled_box = String(box.get("uid", ""))
	catch_up()
	var cr_before := wallet()
	var g := my_game()
	var home := is_home()
	var us: Array = box.score
	var so: Array = box.get("so", [])
	g.r = {"s": [us[0], us[1]] if home else [us[1], us[0]],
		"so": ([so[0], so[1]] if home else [so[1], so[0]]) if not so.is_empty() else [],
		"w": 0 if (box.won == home) else 1}
	for p in team().roster:
		if p in box.get("played", []):
			p.add_stat("gp")
			if not p.is_keeper():
				p.add_stat("bl", 0)   # blocks are counted in games you play (sims don't have them)
				p.add_stat("ed", 0)   # ...and so are exclusions drawn
				for k in ["to", "ex", "pd"]:   # ...turnovers, exclusions committed, 5 m penalties drawn
					p.add_stat(k, 0)
	for p in box.get("blocks", []):
		p.add_stat("bl")
	for p in box.get("goals", []):
		p.add_stat("g")
	for p in box.get("assists", []):
		p.add_stat("a")
		p.add_stat("pg_a")   # (of them, the ones in a game you played: ConfAwards.PLAYED_GOALS)
	for p in box.get("goals", []):
		p.add_stat("pg_g")
	for p in box.get("steals", []):
		p.add_stat("st")
	for p in box.get("excl_drawn", []):
		p.add_stat("ed")
	for p in box.get("keeper_steals", []):
		p.add_stat("st")
	for p in box.get("turnovers", []):
		p.add_stat("to")
	for p in box.get("excl", []):
		p.add_stat("ex")
	for p in box.get("pen_drawn", []):
		p.add_stat("pd")
	for p in box.get("pen_fouls", []):
		p.add_stat("pf5")   # a penalty foul he committed (a personal foul, with his exclusions "ex")
	if box.get("keeper") != null:
		(box.keeper as PoloPlayer).add_stat("sv", int(box.get("saves", 0)))
		_keeper_against(box.keeper, int(us[1]), int(box.get("saves", 0)))
	# their players' stats too, from what the match recorded (the conference awards read every
	# player), and both sides' shots
	_record_their_box(teams[g.a if home else g.h], box, int(us[0]))
	if box.has("lines"):
		_add_line_stats(team(), box.lines[0], ["sh"])
	# everyone in the water is graded, both teams: their form moves for the next game
	var opp_t: PoloTeam = teams[g.a if home else g.h]
	var xg := GameSim.pregame_expected(team(), opp_t, home, Schedule.is_neutral(g))
	if box.has("lines"):
		_grade(team(), opp_t, box.lines[0], box.lines[1], xg, "played",
			[box.get("assists", []), (box.get("them", {}) as Dictionary).get("lists", {}).get("a", [])])
	# XP for everyone who played, from what the game recorded
	var mine := Development.lines_of(box.get("played", []), {"g": box.get("goals", []), "a": box.get("assists", []),
		"st": box.get("steals", []) + box.get("keeper_steals", []), "bl": box.get("blocks", []),
		"ed": box.get("excl_drawn", []), "to": box.get("turnovers", []), "ex": box.get("excl", []),
		"pd": box.get("pen_drawn", [])},
		box.get("keeper"), int(box.get("saves", 0)), int(us[1]))
	var theirs := {}
	if box.has("them"):
		var th: Dictionary = box.them
		# (everyone of theirs who got in the water: their subs too)
		theirs = Development.lines_of(th.get("played", opp_t.starters()), th.lists, opp_t.keeper(), int(th.saves), int(us[0]))
	elif box.has("lines"):
		theirs = Development.lines_of(opp_t.starters(), {}, opp_t.keeper(), 0, int(us[0]), box.lines[1])
	var xp := _award_game_xp(g, mine if home else theirs, theirs if home else mine)
	if not xp.is_empty():
		# each player's shots (goals among them) for the development sheet's S and %, on its own
		# copy of the lines (the XP above never saw them): from every shot the match recorded, so a
		# sub who came on has his too (box.lines only has the seven who finished)
		var dl: Dictionary = last_dev.get("lines", {})
		var shots: Array = box.get("shots", [])
		for p in team().roster:
			if not dl.has(p.id):
				continue
			if box.has("shots"):
				dl[p.id]["sh"] = shots.count(p)
			elif box.has("lines") and (box.lines[0] as Dictionary).has(p.id):
				dl[p.id]["sh"] = int((box.lines[0][p.id] as Dictionary).get("sh", 0))
	var scores := Moments.game_scores(box.get("goals", []), box.get("assists", []), box.get("keeper"), int(box.get("saves", 0)))
	var broke := Records.game_breaks(self, school, box.get("goals", []), box.get("keeper"), int(box.get("saves", 0)), int(us[0]), int(us[1]), String(g.a if home else g.h))
	var marks: Array = broke.map(func(e): return String(e.line))
	var out := _after_my_game(g, scores, not so.is_empty())
	out["xp"] = xp
	out["dev"] = last_dev if not xp.is_empty() else {}   # (the PLAYER DEVELOPMENT screen's before and after)
	(out.lines as Array).append_array(xp_lines(xp))
	(out.lines as Array).append_array(marks)
	out["records"] = broke   # (the summary celebrates them: RecordShow)
	out["mvp_line"] = Moments.stat_line(team().find_id(int(out.mvp)), box.get("goals", []), box.get("assists", []), box.get("keeper"), int(box.get("saves", 0)))
	out["cr_before"] = cr_before   # the summary fills the CR bar from here
	out["form"] = form_rows.get(school, [])
	out["review"] = Postgame.from_box(self, box)   # the POSTGAME REVIEW's board
	out.review["won"] = out.won
	return out

## The other side of a game you played into their players' stats: who played, and every event
## the match recorded for them (MatchState.box "them"), their keeper's saves and goals against.
func _record_their_box(t: PoloTeam, box: Dictionary, against: int) -> void:
	if not box.has("them"):
		return
	var th: Dictionary = box.them
	for p in th.get("played", t.starters()):
		if p is PoloPlayer and p in t.roster:
			p.add_stat("gp")
	var lists: Dictionary = th.get("lists", {})
	for k in ["g", "a", "st", "bl", "ed", "to", "ex", "pd"]:
		for p in lists.get(k, []):
			if p is PoloPlayer and p in t.roster:
				p.add_stat(k)
				if k in ["g", "a"]:
					p.add_stat("pg_" + k)
	var gk := t.keeper()
	if gk != null:
		gk.add_stat("sv", int(th.get("saves", 0)))
		_keeper_against(gk, against, int(th.get("saves", 0)))
	if box.has("lines"):
		_add_line_stats(t, box.lines[1], ["sh"])

## A keeper's goals allowed, with the saves from those same games ("sva") so a save % only
## ever counts games where both were kept.
func _keeper_against(k: PoloPlayer, allowed: int, saves: int) -> void:
	k.add_stat("ga", allowed)
	k.add_stat("sva", saves)

## Your game, simulated.
func sim_my_game() -> Dictionary:
	catch_up()
	var cr_before := wallet()
	var g := my_game()
	var res := _sim_game(g)
	var side := 0 if g.h == school else 1
	_record_sim_side(team(), res, side)
	_record_sim_side(teams[g.a if side == 0 else g.h], res, 1 - side)   # (theirs too: the conference awards read every player)
	var xp := _award_game_xp(g, _sim_lines(g, res, 0), _sim_lines(g, res, 1))
	var scores := Moments.game_scores(res.goals[side], res.assists[side], team().keeper(), int(res.saves[side]))
	var broke := Records.game_breaks(self, school, res.goals[side], team().keeper(), int(res.saves[side]), int(res.score[side]), int(res.score[1 - side]), String(g.a if side == 0 else g.h))
	var marks: Array = broke.map(func(e): return String(e.line))
	var out := _after_my_game(g, scores, not (res.so as Array).is_empty())
	out["xp"] = xp
	out["dev"] = last_dev if not xp.is_empty() else {}   # (the PLAYER DEVELOPMENT screen's before and after)
	(out.lines as Array).append_array(xp_lines(xp))
	(out.lines as Array).append_array(marks)
	out["records"] = broke   # (the summary celebrates them: RecordShow)
	out["mvp_line"] = Moments.stat_line(team().find_id(int(out.mvp)), res.goals[side], res.assists[side], team().keeper(), int(res.saves[side]))
	out["simmed"] = true
	out["cr_before"] = cr_before
	out["form"] = form_rows.get(school, [])
	out["review"] = Postgame.from_sim(self, res, side, teams[g.a if side == 0 else g.h])
	out.review["won"] = out.won
	return out

## Game XP (Development.award_game) for both sides of one finished game, from their stat lines
## ([home's {id: line}, away's]), exactly once: the game is marked ("xp", saved with the schedule),
## so nothing (a reopened summary, a reload, another pass over the round) awards it again. AI
## players spend their tokens at once (Development.ai_spend). Returns your players' awards,
## {id: {xp, tokens}} ({} if your team wasn't in it or it was already counted).
func _award_game_xp(g: Dictionary, home_lines: Dictionary, away_lines: Dictionary) -> Dictionary:
	if g.get("xp", false) or g.r == null:
		return {}
	g["xp"] = true
	var win := Schedule.winner(g)
	var mine := {}
	for side in 2:
		var tid: String = g.h if side == 0 else g.a
		var t: PoloTeam = teams[tid]
		var got: Dictionary
		if tid == school:
			# your team: the coaching decisions riding on this game settle with it (CoachEvents),
			# and its roster's development is read either side of it, for the PLAYER DEVELOPMENT
			# screen to animate (it only ever shows the difference: nothing is awarded twice)
			var lines: Dictionary = home_lines if side == 0 else away_lines
			var before := dev_snapshot(t)
			got = CoachEvents.award_game(self, t, lines, win == tid)
			last_dev = {"before": before, "after": dev_snapshot(t), "lines": lines.duplicate(true), "xp": got.duplicate(true)}
		else:
			got = Development.award_game(t, home_lines if side == 0 else away_lines, win == tid)
		if tid == school:
			mine = got
		else:
			for p in t.roster:
				Development.ai_spend(p)
	return mine

## Every player on `t`'s roster as his development stands right now: {id: {xp, idx (his level
## index: Development.level_index), need (XP his next token costs), tokens, left (boxes left under
## his ceilings), maxed, attrs: {key: value}}}. Read only: nothing about him changes.
static func dev_snapshot(t: PoloTeam) -> Dictionary:
	var out := {}
	for p in t.roster:
		Development.ensure(p)
		var attrs := {}
		for k in p.key_ratings():
			attrs[k] = Attributes.value(p, k)
		out[p.id] = {"xp": p.xp, "idx": Development.level_index(p), "need": Development.xp_needed(p),
			"tokens": p.tokens, "left": Development.boxes_left(p), "maxed": Development.is_maxed(p), "attrs": attrs}
	return out

## The summary's lines for your players' game XP: the best earner, then who has a new upgrade.
func xp_lines(xp: Dictionary) -> Array:
	var out: Array = []
	var best: PoloPlayer = null
	var up: Array = []
	for id in xp:
		var p := team().find_id(int(id))
		if p == null:
			continue
		if best == null or int(xp[id].xp) > int(xp[best.id].xp):
			best = p
		if int(xp[id].tokens) > 0:
			up.append(p.short_name())
	if best != null:
		out.append("TOP XP: %s +%d" % [best.short_name(), int(xp[best.id].xp)])
	if not up.is_empty():
		out.append("NEW ATTRIBUTE UPGRADE AVAILABLE! %s" % ", ".join(up))
	return out

## A simulated game's stat lines for one side (GameSim.play): who played, goals, assists, the
## keeper's saves and goals against, and the blocks and exclusions drawn its lines recorded.
func _sim_lines(g: Dictionary, res: Dictionary, side: int) -> Dictionary:
	var lines: Dictionary = res.lines[side]
	var t: PoloTeam = teams[g.h if side == 0 else g.a]
	var played: Array = []
	var keeper: PoloPlayer = null
	for id in lines:
		var p := t.find_id(int(id))
		if p == null:
			continue
		played.append(p)
		if lines[id].get("gk", false):
			keeper = p
	return Development.lines_of(played, {"g": res.goals[side], "a": res.assists[side]}, keeper,
		int(res.saves[side]), int(res.score[1 - side]), lines)

func _after_my_game(g: Dictionary, scores: Dictionary = {}, shootout: bool = false) -> Dictionary:
	var r: Dictionary = cur()
	var won := Schedule.winner(g) == school
	var home: bool = g.h == school
	var opp: PoloTeam = teams[g.a if home else g.h]
	var mine: Array = g.r.s if home else [g.r.s[1], g.r.s[0]]
	var margin := int(mine[0]) - int(mine[1])
	var lines: Array = []
	coach.wins = int(coach.wins) + (1 if won else 0)
	coach.losses = int(coach.losses) + (0 if won else 1)
	# the game's credits (CreditRewards), ranked by the poll out before it, paid once
	var credit_lines := CreditRewards.pay_game(self, g, r, CreditRewards.ranks_now(self))
	var kind := Schedule.game_kind(r, g)
	if won and kind == "conf_final":
		coach.titles.append("%s %s" % [season_label(), conf_name()])
		add_news("CONFERENCE CHAMPIONS! %s win the %s" % [team().name, conf_name()])
	if won and kind == "nat_final":
		coach.titles.append("%s NCSA" % season_label())
		add_news("NATIONAL CHAMPIONS! %s win the NCSA title" % team().name)
	if not won and LOST_IN.has(kind) and season.finish == "":
		season.finish = "Lost in the %s" % LOST_IN[kind]
	add_news("%s %s %s %s" % [team().name, "beat" if won else "lose to", opp.name, Schedule.score_text(g, g.h == school)])
	Recruiting.after_game(self)   # every AUTO_EVERY games, a free market roll (NEW RECRUITS AVAILABLE)
	_sim_others(int(g.get("d", Schedule.DAYS)))
	# and what the season has reached with it (a streak, a title...)
	credit_lines.append_array(CreditRewards.season_lines(self))
	# what kind of night it was, and who starred
	var ctx := Moments.context(won, margin, shootout, kind)
	var star := Moments.mvp(team(), scores)
	check_glory()
	return {"won": won, "game": g, "round": Schedule.game_label(r, g), "opp": opp.id, "home": home,
		"earned": CreditRewards.total(credit_lines), "credits": credit_lines, "lines": lines,
		"ctx": ctx, "mvp": star.id if star != null else 0}

## A loaded value with JSON's whole-number floats back as ints, all the way down (ids, weeks,
## stat counts), so it saves again exactly as it was.
static func _whole_deep(v):
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	if v is Array:
		return v.map(func(x): return _whole_deep(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _whole_deep(v[k])
		return out
	return v

## The stats a week's line is made of (week_line; the conference awards: ConfAwards): every
## one a game really records (sims: goals, assists, shots, blocks, exclusions drawn, saves, goals
## against; your played games those and steals, turnovers, exclusions, penalties too).
const WEEK_KEYS := ["g", "a", "sv", "ga", "gp", "st", "bl", "ed", "pd", "to", "ex", "sh", "pf5", "pg_g", "pg_a"]

## Every player's season stats as this week begins (the award week's starting line).
func _snap_week() -> void:
	var lines := {}
	for id in teams:
		for p: PoloPlayer in (teams[id] as PoloTeam).roster:
			var ln := {}
			for k in WEEK_KEYS:
				if p.stat(k) != 0:
					ln[k] = p.stat(k)
			if not ln.is_empty():
				lines[str(p.id)] = ln
	week_base = {"year": year, "week": week, "lines": lines}

## A player's stats this week so far: his season's less where they stood as the week began.
## {} without this week's starting line (an older save mid-week).
func week_line(p: PoloPlayer) -> Dictionary:
	if week_base.is_empty() or int(week_base.get("year", -1)) != year or int(week_base.get("week", -1)) != week:
		return {}
	var base: Dictionary = week_base.lines.get(str(p.id), {})
	var out := {}
	for k in WEEK_KEYS:
		out[k] = p.stat(k) - int(base.get(k, 0))
	return out

## After the review (and the event, if one came): the postgame is over. The week ends after
## your last game of it (up to three a week), and the game is saved.
func close_postgame() -> void:
	last_summary = {}
	last_dev = {}
	pending_event = {}
	if not has_game():
		end_week()

## The Road to Glory: this season's results read again (Progression.note). Anything new opens
## schools for every career from now on and is queued, one notification each, for after the
## postgame. Reading the same results again finds nothing new.
func check_glory() -> void:
	if sandbox:
		return   # (Developer Mode's throwaway seasons earn nothing on the real profile)
	for a in Game.progression().note(self, Game.slot if Game.career == self else 0):
		queue.append({"type": "achievement", "id": a.id, "title": a.title, "count": a.count})
	Game.save_progress()

## A new week: last week's training boost spent, and maybe a card.
func _weekly_mood() -> void:
	train_boost = 0.0
	# not in the last week: the off-season is next, and seniors are about to leave
	if not season_over_for_me() and week + 1 < schedule.size():
		var cd := Moments.pick_card(self)
		if not cd.is_empty():
			cards_seen.append(cd.id)
			queue.append(cd)

# ------------------------------------------------------------------ effects
## Applies talk and card effects. `p` is the player the choice is about. Returns the
## lines to show for chance effects ("They took it personally...").
func apply_effects(effects: Array, p: PoloPlayer = null) -> Array:
	var out: Array = []
	for e in effects:
		var on_player: bool = e.get("target", "team") == "player" and p != null
		var v: float = float(e.get("v", 0))
		match String(e.t):
			"morale", "momentum", "fans", "board":
				pass   # (an older save's queued choice of a removed effect: it does nothing)
			"train_boost":
				train_boost = clampf(train_boost + v, -0.5, 0.5)
			"rep":
				coach.rep = clampi(int(coach.rep) + int(v), 0, 100)
			"credits":
				# a choice can cost credits; none pays any (CreditRewards is the only source)
				if v < 0.0 and not spend_credits(int(-v), "COACHING EVENT"):
					credits = 0   # the UI asks for the credits first (see cost_of); this is a fallback
			"rating":
				var q := p if on_player else team().starters()[rng.randi() % team().starters().size()]
				var key := String(e.get("key", "best"))
				if key == "best":
					key = q.legacy_keys()[0]
					for k in q.legacy_keys():
						if q.rating(k) > q.rating(key):
							key = k
				# (no attribute moves on its own any more: the card's points come as XP)
				var tk := Development.award_xp(q, int(v) * Development.CARD_XP_PER_POINT)
				if tk > 0:
					add_news("%s: NEW ATTRIBUTE UPGRADE AVAILABLE!" % q.short_name())
			"injure":
				var q := p if on_player else team().starters()[1 + rng.randi() % (team().starters().size() - 1)]
				_injure(q, "minor" if int(v) <= 1 else "moderate", String(e.get("kind", "")))
			"chance":
				if rng.randf() < float(e.p):
					out.append_array(apply_effects(e.win, p))
					out.append(String(e.get("win_text", "")))
				else:
					out.append_array(apply_effects(e.lose, p))
					out.append(String(e.get("lose_text", "")))
	return out.filter(func(x): return String(x) != "")

## What a choice costs in credits (its negative "credits" effects).
static func cost_of(effects: Array) -> int:
	var n := 0
	for e in effects:
		if String(e.t) == "credits" and float(e.v) < 0.0:
			n += int(-float(e.v))
	return n

## An injury (Development.injure: its kind rolled now, `sev` "" rolled too). He keeps playing,
## his attributes down until a RECOVERY week. Nothing happens to a player who's already hurt.
func _injure(p: PoloPlayer, sev: String = "", kind: String = "") -> void:
	if Development.injure(p, rng, sev, kind) and p in team().roster:
		add_news("%s: %s injury" % [p.short_name(), Development.injury_text(p)])

## Every other game of this round up to game day `through` (your own games still to play
## wait for you, unless `all`). The league plays day by day, so the tables you see before a
## game are the ones it's played with.
func _sim_others(through: int = Schedule.DAYS, all: bool = false) -> void:
	var r: Dictionary = cur()
	if r.is_empty():
		return   # the off-season: nothing to play
	for g in r.games:
		if g.r != null or (not all and (g.h == school or g.a == school)) or int(g.get("d", 0)) > through:
			continue
		var res := _sim_game(g)
		# every player in the league keeps stats, for the awards and the NCSA record book
		for side in 2:
			var tid: String = g.h if side == 0 else g.a
			var t: PoloTeam = teams[tid]
			_record_sim_side(t, res, side)
			Records.check_game(self, tid, res.goals[side], t.keeper(), int(res.saves[side]), int(res.score[side]), int(res.score[1 - side]), String(g.a if side == 0 else g.h))
		_award_game_xp(g, _sim_lines(g, res, 0), _sim_lines(g, res, 1))
	# every result counts into the table exactly once ("n"), however many times this runs; a
	# round an older save already counted whole is "recorded"
	if not Schedule.is_playoff(r) and not r.get("recorded", false):
		for g in r.games:
			if g.r != null and not g.get("n", false):
				g["n"] = true
				Schedule.record(table, g, Schedule.is_conf_game(r, g))

## One side of a simulated game into its players' stats: games played, goals, assists, the
## keeper's saves and goals against, and the shots, blocks and exclusions drawn its lines
## recorded (GameSim.player_lines: the sim's own, consistent with the score). Nothing more: a sim
## has no steals or turnovers, and none are made up.
func _record_sim_side(t: PoloTeam, res: Dictionary, side: int) -> void:
	for p in t.starters():
		p.add_stat("gp")
	for p in res.goals[side]:
		p.add_stat("g")
	for p in res.assists[side]:
		p.add_stat("a")
	t.keeper().add_stat("sv", int(res.saves[side]))
	_keeper_against(t.keeper(), int(res.score[1 - side]), int(res.saves[side]))
	# (steals, turnovers and exclusions too: a simulated game's stat line counts the same as a
	# played game's for every award and record; until the National Awards update only these three did)
	_add_line_stats(t, res.get("lines", [{}, {}])[side], ["bl", "ed", "sh", "st", "to", "ex"])

## A game's per-player lines ({id: line}) into `t`'s players' stats, `keys` only, field players.
func _add_line_stats(t: PoloTeam, lines: Dictionary, keys: Array) -> void:
	for id in lines:
		var ln: Dictionary = lines[id]
		var p := t.find_id(int(id))
		if p == null or ln.get("gk", false):
			continue
		for k in keys:
			if int(ln.get(k, 0)) > 0:
				p.add_stat(k, int(ln[k]))

## A game nobody plays out, scored by the scoring engine from the two teams' ratings (their
## starters' now) and their form (GameSim). Its seed is saved with the result, so the same game replays the
## same way. Both sevens are graded from the stat lines it hands back.
func _sim_game(g: Dictionary) -> Dictionary:
	var home: PoloTeam = teams[g.h]
	var away: PoloTeam = teams[g.a]
	var neutral := Schedule.is_neutral(g)
	var xg := GameSim.pregame_expected(home, away, true, neutral)   # before the game
	var res := GameSim.play(home, away, rng.randi(), neutral)
	g.r = GameSim.result_of(res)
	_grade(home, away, res.lines[0], res.lines[1], xg, "sim", res.get("assists", [[], []]))
	return res

## Grades both sevens after a game (PlayerForm) and keeps the rows for the summary. `xg` is
## [a's expected goals, b's] from BASE ratings before the game. `assists`: [a's, b's] players
## credited with an assist. A CPU school's coach then gives its HOT STAR help the way your
## coaching events give yours (CoachEvents.cpu_coach).
func _grade(a: PoloTeam, b: PoloTeam, lines_a: Dictionary, lines_b: Dictionary, xg: Array, env: String, assists: Array = [[], []]) -> void:
	var exp_a := PlayerForm.expected(a, [xg[0], xg[1]], env)
	var exp_b := PlayerForm.expected(b, [xg[1], xg[0]], env)
	form_rows[a.id] = PlayerForm.grade_team(a, lines_a, exp_a)
	form_rows[b.id] = PlayerForm.grade_team(b, lines_b, exp_b)
	CoachEvents.cpu_coach(self, a, lines_a, assists[0] if assists.size() > 0 and assists[0] is Array else [])
	CoachEvents.cpu_coach(self, b, lines_b, assists[1] if assists.size() > 1 and assists[1] is Array else [])
	for t: PoloTeam in [a, b]:
		if t.id == school:
			HotTutorial.note_graded(self, form_rows[t.id])

## No game for you this week: everyone else plays.
func sim_week_without_me() -> void:
	_sim_others()

## Before your next game: the days before it are played around the league.
func catch_up() -> void:
	if has_game():
		_sim_others(int(my_game().get("d", 0)) - 1)

# ------------------------------------------------------------------ the week
## Training and health, then on to the next round (or, after the last, the off-season: Offseason).
## With the season done, this is NEXT SEASON: the roster transition. Nothing moves on while the
## roster cuts after a season are still to be made.
func end_week() -> Dictionary:
	if phase == "done":
		Offseason.transition(self)
		return {}
	if in_offseason():
		return {}
	var r: Dictionary = cur()
	if not r.is_empty() and r.games.any(func(g): return g.r == null):
		_sim_others(Schedule.DAYS, true)
	# the week's games are all in: the conference awards are decided (once)
	var t_before := tourney_awards.size()
	var named := ConfAwards.decide_week(self)
	if not named.is_empty():
		queue.append({"type": "awards", "year": year, "week": week, "label": ConfAwards.week_label(self, week),
			"mine": named.filter(func(a): return String(a.team) == school).map(func(a): return [String(a.cat), String(a.name)])})
	# a tournament of yours decided this week (its final played, whoever played it): its PLAYER OF
	# THE TOURNAMENT announced, queued (saved) so it waits for the hub and leaves only once seen;
	# TourneyAwards decides each tournament once, so this is queued once
	for a in tourney_awards.slice(t_before):
		if String(a.cat) == "pot" and String(a.tid) in my_tourneys():
			queue.append({"type": "tourney_award", "year": int(a.year), "tid": String(a.tid)})
	check_glory()   # (a result that came in some other way than your two game paths)
	var report := train_week()
	_weekly_mood()
	# the week in the news (LeagueNews), from its results and the poll they were played under
	var before := CreditRewards.ranks_now(self)
	LeagueNews.week(self, before)
	var top_before := ""
	for id in before:
		if int(before[id]) == 1:
			top_before = String(id)
	Poll.publish(self, week)
	LeagueNews.new_top(self, top_before)
	week += 1
	_snap_week()
	if week < schedule.size() and not Schedule.drawn(schedule[week]):
		Schedule.fill_playoff(schedule, week, teams, table, season)
		_announce_round()
	# an achievement the week reached on its own (a bid, the regular season done unbeaten)
	var paid := CreditRewards.season_lines(self)
	if not paid.is_empty():
		queue.append({"type": "info", "title": "POLO POINTS EARNED", "text": "%s\n\nTOTAL: %s" % ["\n".join(CreditRewards.text(paid)), CreditCoin.tag(CreditRewards.total(paid), true)]})
	if week >= schedule.size():
		Offseason.begin(self)
	catch_up()
	update_season_state(true)   # (knocked out of the NCSA this week: the season's over for you)
	return report

## The tournaments whose PLAYER OF THE TOURNAMENT you're told of (TourneyAwards' tids): your
## conference's, and the NCSA's.
func my_tourneys() -> Array:
	return ["conf:" + team().conf, "nat"]

## This week's training, every program's, exactly once a week (`train_cycle` remembers the
## last one done, and is saved: reloading, reopening Training or changing the plan never runs it
## again). Yours: your focus and intensity (Development.train_team). Returns your report,
## {xp, tokens, hurt, healed} ({} if this week's training was already done).
func train_week() -> Dictionary:
	var cycle := "%d-%d" % [year, week]
	if train_cycle == cycle:
		return {}
	train_cycle = cycle
	var focus := String(training.get("focus", "balanced"))
	var report := {"xp": {}, "tokens": [], "hurt": [], "healed": []}
	# knocked out: no more practice for you (no XP from the weeks you don't play); the league trains
	if not is_eliminated():
		report = Development.train_team(team(), focus, int(training.get("intensity", 2)), rng, fac("medical"), 1.0 + train_boost)
	for id in report.hurt:
		var p := team().find_id(int(id))
		add_news("%s: %s injury in training" % [p.short_name(), Development.injury_text(p)])
	for id in report.tokens:
		add_news("%s: NEW ATTRIBUTE UPGRADE AVAILABLE!" % team().find_id(int(id)).short_name())
	if not (report.healed as Array).is_empty():
		add_news("Recovery week: %d player%s healthy again" % [report.healed.size(), "" if report.healed.size() == 1 else "s"])
	for id in teams:
		if id == school:
			continue
		var t: PoloTeam = teams[id]
		var plan := Training.ai_plan(t)
		Development.train_team(t, plan[0], plan[1], rng, int(school_fac.get(id, {}).get("medical", 1)))
		for p in t.roster:
			Development.ai_spend(p)
	return report

## News when a bracket is drawn: your seed in the conference tournament, the NCSA selection.
func _announce_round() -> void:
	var r: Dictionary = cur()
	var kind := String(r.kind)
	var first := week == 0 or String(schedule[week - 1].kind).substr(0, 4) != kind.substr(0, 4)
	if not first:
		return
	var in_it := Schedule.alive(season, r, school, team().conf)
	if kind.begins_with("conf_"):
		if in_it:
			var bye := my_game().is_empty()
			add_news("%s are the #%d seed in the %s tournament%s" % [team().name, Schedule.seed_of(season, kind, school, team().conf), conf_name(), " (a first-round bye)" if bye else ""])
		elif season.finish == "":
			season.finish = "Missed the conference tournament"
	elif in_it:
		var bye := my_game().is_empty()
		add_news("SELECTED! %s are the #%d seed for the NCSA Championship%s" % [team().name, Schedule.seed_of(season, kind, school, ""), " (a first-round bye)" if bye else ""])
	elif season.finish == "":
		season.finish = "Conference champions" if school in season.conf_champs else "Missed the NCSA Championship"

# ------------------------------------------------------------------ realignment
## A save from before the current conferences (the first 30-school layout) plays its season out
## as it is; between seasons Offseason calls realign.
func needs_realign() -> bool:
	return teams.keys().any(func(id): return not Colleges.is_current_conf(teams[id].conf))

## Moves an old save onto the current conferences: every school takes its place there and keeps
## its id, roster, prestige, facilities and records. Run between seasons, when there's no schedule
## or table left to carry over.
func realign() -> void:
	var old_name := team().name
	for id in teams:
		var t: PoloTeam = teams[id]
		var s := Colleges.school(String(id))
		t.name = s.name
		t.mascot = s.mascot
		t.c1 = Color(s.c1)
		t.c2 = Color(s.c2)
		t.conf = s.conf
		t.pool = String(s.get("pool", Pools.DEFAULT_ID))
	table = {}
	realigned = true
	add_news("REALIGNMENT: %s are now the %s of the %s" % [old_name, team().name, conf_name()])
	# after the season review, before any job offer
	queue.insert(mini(1, queue.size()), {"type": "info", "title": "NCSA REALIGNMENT",
		"text": "The NCSA has realigned: 30 schools in five conferences (PEC, GCC, WWPC, AWPC, NCC) and a 12-team championship. Your program, %s, is now the %s, in the %s. Your roster, staff, facilities and records come with you." % [old_name, team().name, conf_name()]})

# ------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	var td := {}
	for id in teams:
		td[id] = (teams[id] as PoloTeam).to_dict()
	return {"v": SAVE_VERSION, "rng_seed": str(rng.seed), "rng_state": str(rng.state), "year": year, "week": week,
		"school": school,
		"coach": coach.duplicate(true), "teams": td, "credits": credits, "uid": uid, "convertible": convertible, "cv_earned": cv_earned, "cv_out": cv_out,
		"school_fac": school_fac.duplicate(true), "staff": staff.duplicate(),
		"training": training.duplicate(), "schedule": schedule.duplicate(true), "table": table.duplicate(true),
		"season": season.duplicate(true), "history": history.duplicate(true), "news": news.duplicate(true),
		"queue": queue.duplicate(true), "market": Recruiting.to_save(market), "incoming": Recruiting.to_save(incoming),
		"refreshes": refreshes, "auto_games": auto_games, "new_recruits": new_recruits, "dev_recruits": DevRecruits.to_save(dev_recruits), "recruit_warned": recruit_warned, "injury_seen": injury_seen, "hub_seen": hub_seen, "cr_claims": cr_claims.duplicate(), "phase": phase,
		"season_state": season_state, "elim": elim.duplicate(true), "champ": champ.duplicate(true),
		"conf_awards": conf_awards.duplicate(true), "award_players": award_players.duplicate(true), "awards_done": awards_done.duplicate(),
		"national_done": national_done.duplicate(),
		"tourney_awards": tourney_awards.duplicate(true), "tourney_stats": tourney_stats.duplicate(true), "tourney_done": tourney_done.duplicate(),
		"cut_pool": cut_pool.map(func(e): return {"p": (e.p as PoloPlayer).to_dict(), "from": String(e.from)}),
		"league_news": league_news.duplicate(true), "hot_tip": hot_tip, "hot_tutorial_seen": hot_tutorial_seen, "hot_tutorial_pid": hot_tutorial_pid, "tutorial": tutorial, "gameplan": gameplan, "next_id": next_id, "game_over": game_over, "difficulty": difficulty, "quarter_min": quarter_min, "dyn_ai": snappedf(dyn_ai, 0.0001), "dyn_hist": dyn_hist.duplicate(true),
		"train_boost": snappedf(train_boost, 0.0001), "train_cycle": train_cycle, "cards_seen": cards_seen.duplicate(),
		"pending_event": pending_event.duplicate(true), "event_log": event_log.duplicate(),
		"coach_pending": coach_pending.duplicate(true), "coach_results": coach_results.duplicate(true), "coach_seq": coach_seq,
		"legacy": legacy.duplicate(true), "champions_log": champions_log.duplicate(true),
		"week_base": week_base.duplicate(true), "last_notes": last_notes.duplicate(),
		"records": records.duplicate(true), "awards": awards.duplicate(true),
		"rating_history": rating_history.duplicate(true), "final_polls": final_polls.duplicate(true)}

static func from_dict(d: Dictionary) -> Career:
	var c := Career.new()
	# 64-bit RNG numbers are saved as strings: JSON numbers are doubles and would lose bits
	c.rng.seed = String(d.get("rng_seed", "1")).to_int()
	c.rng.state = String(d.get("rng_state", "1")).to_int()
	c.year = int(d.year)
	c.week = int(d.week)
	c.school = String(d.school)
	c.coach = _whole(d.coach)
	for id in d.teams:
		c.teams[id] = PoloTeam.from_dict(d.teams[id])
	c.credits = maxi(0, int(d.credits))
	c.convertible = int(d.get("convertible", 0))   # (a save from before the exchange: nobody can say where its coins came from, so none convert)
	c.cv_earned = int(d.get("cv_earned", 0))
	c.cv_out = int(d.get("cv_out", 0))
	c.uid = String(d.get("uid", ""))
	if c.uid == "":
		c.uid = new_uid()   # (a save from before the Universal Coin Wallet: it never spent through the journal)
	for id in d.school_fac:
		var f := {}
		for k in d.school_fac[id]:
			f[k] = int(d.school_fac[id][k])
		c.school_fac[id] = f
	for k in d.staff:
		c.staff[k] = int(d.staff[k])
	c.training = {"focus": String(d.training.get("focus", "balanced")), "intensity": int(d.training.get("intensity", 2))}
	c.schedule = _ints_in_schedule(d.schedule)
	c.table = {}
	for id in d.table:
		var row := {}
		for k in d.table[id]:
			row[k] = int(d.table[id][k])
		c.table[id] = row
	c.season = _whole(d.season)
	c.season.erase("goals")   # (an older save's season goals: the feature is gone, nothing reads them)
	c.history = _whole(d.get("history", []))
	c.news = _whole(d.get("news", []))
	c.queue = _whole(d.get("queue", []))
	c.market = Recruiting.from_save(d.get("market", []))
	c.incoming = Recruiting.from_save(d.get("incoming", []))
	c.refreshes = int(d.get("refreshes", 0))
	c.auto_games = int(d.get("auto_games", 0))         # (an older save: counting starts now)
	c.new_recruits = bool(d.get("new_recruits", false))
	c.dev_recruits = DevRecruits.from_save(d.get("dev_recruits", d.get("admin_recruits", {})))   # (an older save: "admin_recruits")
	c.recruit_warned = String(d.get("recruit_warned", ""))
	c.injury_seen = String(d.get("injury_seen", ""))
	# (a save from before the hint: that coach already knows the way, so no hint)
	c.hub_seen = bool(d.get("hub_seen", true))
	c.cr_claims = (d.get("cr_claims", []) as Array).map(func(x): return String(x))
	c.conf_awards = _whole_deep(d.get("conf_awards", []))
	for a in c.conf_awards:
		a.stars = float(a.stars)   # (half stars: never a whole-number int)
		a.score = float(a.score)
	c.award_players = d.get("award_players", {})
	c.awards_done = (d.get("awards_done", []) as Array).map(func(x): return String(x))
	c.tourney_awards = _whole_deep(d.get("tourney_awards", []))
	for a in c.tourney_awards:
		a.stars = float(a.stars)   # (half stars: never a whole-number int)
		a.score = float(a.score)
	c.tourney_stats = _whole_deep(d.get("tourney_stats", {}))
	c.tourney_done = (d.get("tourney_done", []) as Array).map(func(x): return String(x))
	c.national_done = (d.get("national_done", []) as Array).map(func(x): return String(x))
	c.cut_pool = (d.get("cut_pool", []) as Array).map(func(e): return {"p": PoloPlayer.from_dict(e.p), "from": String(e.get("from", ""))})
	c.league_news = _whole_deep(d.get("league_news", []))
	c.phase = String(d.get("phase", "season"))
	c.hot_tip = bool(d.get("hot_tip", false))   # (an older save sees the tip once)
	c.hot_tutorial_seen = bool(d.get("hot_tutorial_seen", false))   # (an older save gets the tutorial once, the next time one of his is HOT)
	c.hot_tutorial_pid = int(d.get("hot_tutorial_pid", -1))
	c.tutorial = String(d.get("tutorial", ""))
	# an older save has no gameplan: the default drop
	c.gameplan = int(d.get("gameplan", DefenseFormation.DEFAULT_DROP))
	if not DefenseFormation.is_drop(c.gameplan):
		c.gameplan = DefenseFormation.DEFAULT_DROP
	c.next_id = int(d.get("next_id", 1))
	c.game_over = bool(d.get("game_over", false))
	# difficulty: an older save keeps the mode the device had picked, and its dynamic level comes
	# across from the old -1..+1 scale (Difficulty.from_legacy); none at all, the start
	c.difficulty = String(d.get("difficulty", Game.settings.get("difficulty", Difficulty.DEFAULT_MODE)))
	c.quarter_min = MatchState.valid_quarter_min(d.get("quarter_min", 2))
	if not c.difficulty in Difficulty.MODES:
		c.difficulty = Difficulty.DEFAULT_MODE
	if d.has("dyn_ai"):
		c.dyn_ai = clampf(float(d.dyn_ai), 0.0, 1.0)
	elif d.has("dyn_level"):
		c.dyn_ai = Difficulty.from_legacy(float(d.dyn_level))
	c.dyn_hist = (d.get("dyn_hist", []) as Array).duplicate(true)
	c.train_boost = float(d.get("train_boost", 0.0))
	c.train_cycle = String(d.get("train_cycle", ""))
	c.cards_seen = d.get("cards_seen", [])
	c.pending_event = _whole_deep(d.get("pending_event", {}))
	if CoachEvents.scenario(String(c.pending_event.get("id", ""))).is_empty():
		c.pending_event = {}   # (an older save's award nomination: those events are gone)
	c.event_log = d.get("event_log", [])
	c.coach_pending = _whole_deep(d.get("coach_pending", []))
	c.coach_results = _whole_deep(d.get("coach_results", []))
	c.coach_seq = int(d.get("coach_seq", 0))
	c.legacy = _whole_deep(d.get("legacy", []))
	c.champions_log = _whole_deep(d.get("champions_log", []))
	c.week_base = _whole_deep(d.get("week_base", {}))   # (an older save: none yet, so no weekly awards until next week)
	c.last_notes = d.get("last_notes", [])
	c.records = _whole(d.get("records", {"school": {}, "ncsa": {}}))
	c.awards = _whole(d.get("awards", []))
	c.rating_history = _whole(d.get("rating_history", []))
	c.final_polls = _whole(d.get("final_polls", []))
	c._rename_teams()
	c._unshow_ids()
	c._rename_conferences()
	if int(d.get("v", 1)) < 2:
		c._fill_traits()
	c.trimmed = c.trim_rosters()
	if int(d.get("v", 1)) < 9:
		c.fill_benches()   # (every program's bench, from the roll-out update on)
	if int(d.get("v", 1)) < 5:
		c.upgraded = c.upgrade_rosters()
	if int(d.get("v", 1)) < 7:
		# seven-man rosters: the scholarships go to the best of the seven, as a new program's do
		# (players without stars got theirs from their ratings in PoloPlayer.from_dict)
		for id in c.teams:
			CollegeGen.award_scholarships(c.teams[id], SCHOL_MAX)
	c.rated = c._rate_old_save(d)
	c.converted = c._convert_recruiting(d)
	# (the Position Identity update: every saved lineup made legal, the players where they may
	# play; PoloPlayer.from_dict has already made an old lefty a LFTY)
	for id in c.teams:
		c.teams[id].sync_lineup()
	c._give_missing_homes()
	Records.complete_all(c)   # (an older save: every mark gets its holder; nothing anyone set moves)
	DevRecruits.migrate(c)   # (an older save: whoever already exists is marked generated)
	for id in c.teams:
		DevRecruits.fix_numbers(c.teams[id])   # (their own caps, Blake #11 and Logan #8; not with PIXEL POLO +)
	# the season's state (an older save: worked out from its schedule; an elimination found this way
	# was already lived through, so its OH NO! screen never plays)
	c.season_state = String(d.get("season_state", ""))
	c.elim = _whole_deep(d.get("elim", {}))
	c.champ = _whole_deep(d.get("champ", {}))   # (an older save's title was celebrated its own way: none to replay)
	if not c.season_state in [STATE_ACTIVE, STATE_ELIMINATED, STATE_OFFSEASON]:
		c.season_state = STATE_ACTIVE
	c.update_season_state(false)
	return c

## The Hometown & Appearance update: a saved player with no hometown gets one, once (it saves with
## the career from then on), from dice of his own (his id: the same hometown however often it
## loads before a save; the career's own draws untouched). Nobody else changes: no name, portrait,
## rating, class or award moves, and a hometown he already has is his.
func _give_missing_homes() -> void:
	var people: Array = []
	for id in teams:
		people.append_array((teams[id] as PoloTeam).roster)
	for r in incoming:
		people.append(r.p)
	for e in cut_pool:
		people.append(e.p)
	for p in people:
		var q := p as PoloPlayer
		if q == null or q.home != "":
			continue
		var h := RandomNumberGenerator.new()
		h.seed = hash([q.id, q.first, q.last, "home"])
		q.home = Hometowns.pick(h)
		q.region = "US" if Hometowns.is_us(q.home) else "INTL"

## A save from before the Credit Economy & Recruiting Overhaul (it has no market): the old
## recruiting is gone, not carried. Its points, visits, interest and the 160-man class are
## dropped (nothing becomes credits: the credits balance stays exactly as it was). Prospects
## who had committed to your school are your incoming recruits, as they were promised (no
## price, outside the season's limit). Mid-season the market opens with the free refresh, and
## this season's +15 counts as paid (the old economy paid its own way into it). Caught in the
## old off-season (a transfer portal, spring), the season is "done": players in the portal go
## back to their schools (or, committed to yours, are your incoming recruits) and the hub's NEXT
## SEASON runs the roster transition. Returns whether anything changed.
func _convert_recruiting(d: Dictionary) -> bool:
	if d.has("market"):
		return false
	for list in [d.get("recruits", []), d.get("portal", [])]:
		for rd in list:
			if rd is Dictionary and String(rd.get("committed", "")) == school and rd.has("p"):
				incoming.append(Recruiting.from_commit(self, rd))
	var old_phase := String(d.get("phase", "season"))
	if old_phase in ["portal1", "spring", "portal2", "lock"] or week >= schedule.size():
		# the portal's players go home; your commitments already came across as incoming
		for rd in d.get("portal", []):
			if not rd is Dictionary or not rd.has("p") or String(rd.get("committed", "")) == school:
				continue
			var home := String(rd.get("from", ""))
			if teams.has(home):
				var p := PoloPlayer.from_dict(rd.p)
				p.schol = false
				Offseason.join(self, teams[home], p)
		phase = "done"   # (the hub's NEXT SEASON runs the transition)
		return true
	phase = "season"
	refreshes = 0
	Recruiting.new_market(self)
	CreditRewards.claim(self, "start")
	return true

## A save from before a school was renamed ("LIUB Hammerheads" -> "Brooklyn Hammerheads"): its
## team takes the name it has now, and the news, the inbox and the record books that quote the
## old name quote the new one. Only names change: ids, colours and ratings stay as saved.
## The league news and the headlines' capitals ("PRINCETON BENGALS") follow too, and so does a
## renamed place on its own ("PRINCETON WIN THE NCC!", "All-Conference: ... (Princeton)") where
## the place changed; never a town followed by its state ("Princeton, New Jersey": a hometown).
## A new mascot ("Stockton Bengals" -> "Stockton Scorpions") replaces the saved one as well.
func _rename_teams() -> void:
	var renames := {}
	var places := {}
	for id in teams:
		var t: PoloTeam = teams[id]
		var s := Colleges.school(id)
		if s.is_empty() or t.name == s.name:
			continue
		if t.name != "":
			renames[t.name] = s.name
			renames[t.name.to_upper()] = String(s.name).to_upper()
			var old_mascot := t.mascot if t.mascot != "" else String(s.get("mascot", ""))
			var was := t.name.trim_suffix(" " + old_mascot)
			var now := Colleges.place(id)
			if was != t.name and was != id and was != now:
				places[was] = now
				places[was.to_upper()] = now.to_upper()
		t.name = s.name
		t.mascot = String(s.get("mascot", t.mascot))
	if renames.is_empty():
		return
	news = _renamed_places(_renamed(news, renames), places)
	queue = _renamed_places(_renamed(queue, renames), places)
	records = _renamed_places(_renamed(records, renames), places)
	league_news = _renamed_places(_renamed(league_news, renames), places)

## `v` with every old place in its strings (a whole word, not followed by a comma) swapped for the new one.
static func _renamed_places(v: Variant, places: Dictionary) -> Variant:
	if places.is_empty():
		return v
	var re := RegEx.create_from_string("\\b(%s)\\b(?!,)" % "|".join(places.keys().map(func(p): return String(p).replace(".", "\\."))))
	var fix := func(s: String) -> String:
		var out := ""
		var at := 0
		for m in re.search_all(s):
			out += s.substr(at, m.get_start() - at) + String(places[m.get_string()])
			at = m.get_end()
		return out + s.substr(at)
	return _mapped_strings(v, fix)

static func _mapped_strings(v: Variant, f: Callable) -> Variant:
	if v is String:
		return f.call(v)
	if v is Array:
		return (v as Array).map(func(x): return _mapped_strings(x, f))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _mapped_strings(v[k], f)
		return out
	return v

## `v` with every old team name in its strings swapped for the new one.
static func _renamed(v: Variant, renames: Dictionary) -> Variant:
	if v is String:
		var s: String = v
		for old in renames:
			s = s.replace(old, renames[old])
		return s
	if v is Array:
		return (v as Array).map(func(x): return _renamed(x, renames))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _renamed(v[k], renames)
		return out
	return v

## Text saved when the game still showed ids ("USAF beat Malibu Breakers 7-6", "S. Ward (HVRD)")
## names the teams instead: the news and the inbox's titles, texts and lines. Fields that hold an
## id (a job offer's schools, a record's team) are left alone.
func _unshow_ids() -> void:
	var re := RegEx.create_from_string("\\b(%s)\\b" % "|".join(Colleges.SCHOOLS.map(func(s): return String(s.short))))
	for n in news:
		n.t = _named(String(n.get("t", "")), re)
	for q in queue:
		for k in ["title", "text"]:
			if q.get(k) is String:
				q[k] = _named(q[k], re)
		if q.get("lines") is Array:
			q.lines = (q.lines as Array).map(func(l): return _named(l, re) if l is String else l)

## Text saved before the Conference Rebranding ("2026-27 MPSF", "win the Big West") or NCC's
## rename ("Northeast Collegiate Conference") shows the new names: the news, the inbox, the coach's titles. Every load; the new names never match again.
func _rename_conferences() -> void:
	var to := {}
	for cf in Colleges.CONFERENCES + Colleges.LEGACY_CONFERENCES:
		for old in cf.get("old", []):
			to[String(old)] = String(cf.name)
	var re := RegEx.create_from_string("\\b(%s)\\b" % "|".join(to.keys()))
	var fix := func(t: String) -> String:
		var out := ""
		var at := 0
		for m in re.search_all(t):
			out += t.substr(at, m.get_start() - at) + String(to[m.get_string()])
			at = m.get_end()
		return out + t.substr(at)
	for n in news:
		n.t = fix.call(String(n.get("t", "")))
	for q in queue:
		for k in ["title", "text"]:
			if q.get(k) is String:
				q[k] = fix.call(q[k])
		if q.get("lines") is Array:
			q.lines = (q.lines as Array).map(func(l): return fix.call(l) if l is String else l)
	coach.titles = (coach.get("titles", []) as Array).map(func(t): return fix.call(String(t)))

## `s` with every id `re` finds swapped for its team's name.
static func _named(s: String, re: RegEx) -> String:
	var out := ""
	var at := 0
	for m in re.search_all(s):
		out += s.substr(at, m.get_start() - at) + Colleges.team_name(m.get_string())
		at = m.get_end()
	return out + s.substr(at)

## A save from before the season snapshots (version 5 or older): the season gets its snapshot of
## every team's ratings (worked out from its players, as always now) and its poll so far. Its
## players are never touched. Returns whether anything changed.
func _rate_old_save(_d: Dictionary) -> bool:
	if season.has("ratings") or phase != "season" or week >= schedule.size():
		return false
	_lock_ratings()
	Poll.rebuild(self)
	return true

## A save from before 18-man programs (version 4 or older): every roster is topped up to
## ROSTER_MAX with depth players below its starters (so the starting seven, and the team's
## rating, are just what they were), the best SCHOL_MAX hold the scholarships, everyone gets a
## hometown. (Its old recruiting board goes with the rest of the old recruiting:
## _convert_recruiting.) Returns whether anything changed.
func upgrade_rosters() -> bool:
	for id in teams:
		var t: PoloTeam = teams[id]
		CollegeGen.add_depth(t, rng, new_id, CollegeGen.roster_level(t), ROSTER_MAX)
		for p in t.roster:
			CollegeGen.give_home(p, rng)
		CollegeGen.award_scholarships(t, SCHOL_MAX)
	return true

## A save from before every program had a bench: each AI program short of roster_cap gets its
## subs (a backup keeper first), below its starters, so a rolled player has someone to replace him.
## Nobody already there is touched. Returns whether anything was added.
func fill_benches() -> bool:
	var any := false
	for id in teams:
		var t: PoloTeam = teams[id]
		var short := roster_cap(id) - t.roster.size()
		if id == school or short <= 0:
			continue
		var had := t.roster.size()
		var target := float(Colleges.school(id).get("ovr", 70)) if not Colleges.school(id).is_empty() else 70.0
		CollegeGen.add_initial_bench(t, rng, new_id, target, short, false)
		for p in t.roster.slice(had):
			Development.ensure(p)
		any = true
	return any

## Older saves had bigger rosters (16, then 18): every team over its cap (roster_cap) keeps its
## starting seven and its best (PoloTeam.trim_to). A no-op once a save is converted. Returns
## whether anything changed.
func trim_rosters() -> bool:
	var any := false
	for id in teams:
		if id == school and phase == "cuts":
			continue   # (over the cap on purpose: your cuts are yours to make, never automatic)
		var t: PoloTeam = teams[id]
		var cut := t.trim_to(roster_cap(id))
		if cut.is_empty():
			continue
		any = true
		t.sync_lineup()
		if id == school:
			add_news("Roster set at %d. Released: %s" % [roster_cap(id), ", ".join(cut.map(func(p: PoloPlayer): return p.short_name()))])
	return any

## Saves from before traits: everyone gets the one their ratings earn (no dice involved, so
## loading the same save twice gives the same team).
func _fill_traits() -> void:
	for id in teams:
		for p: PoloPlayer in (teams[id] as PoloTeam).roster:
			p.trait_id = Traits.best_for(p)
	for r in market + incoming:
		var q: PoloPlayer = r.p
		q.trait_id = Traits.best_for(q)

## JSON turns every number into a float. These blobs only hold counts, so whole numbers
## go back to ints.
static func _whole(v: Variant) -> Variant:
	if v is float and v == floorf(v):
		return int(v)
	if v is Array:
		return (v as Array).map(func(x): return _whole(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _whole(v[k])
		return out
	return v

## JSON turns every number into a float; scores, winners and game days are ints again here.
static func _ints_in_schedule(rounds: Array) -> Array:
	for r in rounds:
		for g in r.games:
			if g.has("d"):
				g.d = int(g.d)
			if g.r != null:
				g.r.s = [int(g.r.s[0]), int(g.r.s[1])]
				g.r.so = (g.r.so as Array).map(func(x): return int(x))
				g.r.w = int(g.r.w)
				if g.r.has("sd"):
					g.r.sd = int(g.r.sd)
				if g.r.has("fd"):
					g.r.fd = (g.r.fd as Array).map(func(x): return int(x))
				if g.r.has("rt"):
					g.r.rt = (g.r.rt as Array).map(func(side): return (side as Array).map(func(x): return int(x)))
				for k in ["q", "ot"]:
					if g.r.has(k):
						g.r[k] = (g.r[k] as Array).map(func(side): return (side as Array).map(func(x): return int(x)))
	return rounds
