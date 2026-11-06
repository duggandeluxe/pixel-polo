class_name CoachEvents
extends RefCounted
## COACHING EVENTS: DECISIONS & CONSEQUENCES. After the POSTGAME REVIEW, maybe (CHANCE) one
## coaching situation from the game just played (or, for PRACTICE DISCIPLINE, the practice week),
## with two answers whose consequences are real and shown in full before you confirm:
##   XP now            Development.award_xp (never past his potential, every token it pays for)
##   CREDITS           the coaching credits you already have (Career.add_credits / spend_credits);
##                     a cost you can't afford can't be chosen; nothing goes below zero
##   NEXT-GAME XP      one multiplier on a player's positive game XP in your next game
##                     (Development.award_game `mults`), never two: PROVE ME WRONG's first, else
##                     the biggest bonus (2X; 3X only from a SPECIAL CHALLENGE), else a failed
##                     choice's penalty (0.75X / 0.5X); never on event, training or earlier XP
##   SPECIAL CHALLENGE 1 in 20 of A STAR IN THE MAKING, A GOALKEEPER'S CONFIDENCE, DEFENSIVE
##                     MASTERCLASS and THE BIG RIVALRY: a much harder target for 3X (rolled once,
##                     when the event is made, and saved with it)
##   CHALLENGES        a stat line to reach in the next game (his real line: goals + assists,
##                     goals, saves, steals + blocks), or a result (win / loss)
##   SUSPENSIONS       PoloPlayer.susp: out of your next game (no start, no sub, no sim), the
##                     lineup's best legal man in his place
##   HOT STAR PROGRESS PlayerForm (PoloPlayer.heat_bonus: part of a GOOD grade, never a whole
##                     one); a BAD grade forgiven (NORMAL) as COLD recovery
## Whatever rides on the next game is saved (Career.coach_pending) and settled once, with that
## game's XP (award_game, called by Career._award_game_xp, which runs once a game, played or
## simmed); what it came to is saved too (Career.coach_results) for the postgame to show once.
##
## THE TEAM LEADER: the game has no named captain, so the events that need one (THE CAPTAIN'S
## SPEECH, THE BIG RIVALRY) go to the team's leader: the senior (else the oldest class) with the
## most career games. Nothing is ever named captain.

const CHANCE := 0.6           # a game is followed by an event this often (when one fits)
const LOG_MAX := 12           # games remembered (Career.event_log), for no-repeats and cooldowns
const RESULTS_MAX := 40       # settled consequences kept (the newest)
const WAIT_GAMES := 3         # THE BACKUP BREAKOUT's challenge waits this many games for him to play

## How often each kind of event comes, when one of its kind fits (the spec's targets).
const CATEGORY_WEIGHT := {"dev": 45.0, "challenge": 30.0, "money": 20.0, "discipline": 5.0}

## The scenarios: id, cat, weight (within its category), cooldown (games before it can come
## back), headline, subject ("player": his portrait; "team": the logo), stories (2-3 short
## sentences, 25-45 words, {vars} from the game's own numbers), and two choices {label, text}.
## The four with a rare SPECIAL CHALLENGE (SPECIAL) also have a special_story, told when the
## event rolled its special variant. What a choice does is apply(); what it says it does,
## stakes() (the same numbers).
const EVENTS := [
	{"id": "star_in_making", "cat": "dev", "weight": 1.0, "cooldown": 3, "headline": "A STAR IN THE MAKING", "subject": "player",
		"stories": [
			"{Cls} {name} broke out with {line} and is starting to turn heads. He's confident, but there's still more to prove. Do you praise him, or challenge him to do it again?",
			"Nobody expected {name} to take over like that: {line} from a {cls}. The whole locker room noticed. Do you celebrate the breakout, or push him to prove it wasn't a one-off?"],
		"special_story": "{name} is turning heads after {line}. The staff think he's ready for an even bigger challenge, the kind that only comes along once in a while.",
		"choices": [
			{"label": "PRAISE HIM", "text": "Recognize him in front of the team."},
			{"label": "CHALLENGE HIM", "text": "Make him prove it again."}]},
	{"id": "backup_breakout", "cat": "dev", "weight": 1.0, "cooldown": 4, "headline": "THE BACKUP BREAKOUT", "subject": "player",
		"stories": [
			"{name} came off the bench and made an impact: {line}. He's hungry to prove he can do it again. Do you reward him, or set another challenge?",
			"When the call came, {name} was ready, with {line} off the bench. Backups who seize their minutes earn more of them. Reward the breakout, or make him do it again?"],
		"choices": [
			{"label": "REWARD HIM", "text": "Recognize what he did with his minutes."},
			{"label": "PROVE IT AGAIN", "text": "One good game is not enough."}]},
	{"id": "captains_speech", "cat": "dev", "weight": 1.0, "cooldown": 4, "headline": "THE CAPTAIN'S SPEECH", "subject": "player",
		"stories": [
			"After the {score} win, {name} gave the team a strong message. As its most experienced {cls}, his words carry weight. Now everyone needs to back it up. Reward his leadership, or challenge the whole team?",
			"{name} held the team together in the {score} win and told them so afterwards. Leadership like that matters. Do you reward the leader, or challenge the team to back him up?"],
		"choices": [
			{"label": "RECOGNIZE THE LEADER", "text": "Single out the team's leader."},
			{"label": "CHALLENGE THE TEAM", "text": "Everyone backs it up next game."}]},
	{"id": "keeper_confidence", "cat": "dev", "weight": 1.0, "cooldown": 3, "headline": "A GOALKEEPER'S CONFIDENCE", "subject": "player",
		"stories": [
			"{name} was a wall: {saves} saves, {save_pct}% of the shots he faced. He's feeling confident, and his teammates need him to keep it going. Do you reward him, or push him further?",
			"{saves} saves at {save_pct}%. {name} can carry a night like this into the next one, if he believes it. Do you build him up, or set him a saves challenge?"],
		"special_story": "{name} made {saves} saves, and the staff believe there's even more in him. A rare chance: one huge night in goal could define his season.",
		"choices": [
			{"label": "BUILD CONFIDENCE", "text": "Tell him he was the difference."},
			{"label": "SAVES CHALLENGE", "text": "Do it again, next game."}]},
	{"id": "rough_night", "cat": "challenge", "weight": 1.0, "cooldown": 3, "headline": "A ROUGH NIGHT", "subject": "player",
		"stories": [
			"It wasn't {name}'s night. {rough} He knows he needs to improve, and he's looking to you for guidance. Do you encourage him, or demand a response?",
			"{name} will want this one back. {rough} He was first in the pool the next morning. An arm around the shoulder, or a challenge?"],
		"choices": [
			{"label": "ENCOURAGE HIM", "text": "One game doesn't define him."},
			{"label": "DEMAND A RESPONSE", "text": "Answer it in the next game."}]},
	{"id": "defensive_masterclass", "cat": "dev", "weight": 1.0, "cooldown": 3, "headline": "DEFENSIVE MASTERCLASS", "subject": "player",
		"stories": [
			"{name} dominated at the defensive end: {line}. The coaching staff want to build on that effort. Do you reward him, or raise expectations?",
			"They held {opp_goals} goals, and {name} was the reason: {line}. Defense is a habit. Reward him now, or challenge him to do it again?"],
		"special_story": "{name} owned the defensive end: {line}. The staff see a defensive legend in the making, if he can raise his game even higher.",
		"choices": [
			{"label": "REWARD HIM", "text": "Give him the game ball."},
			{"label": "DEFENSIVE CHALLENGE", "text": "Do it again next game."}]},
	{"id": "recruiting_ripple", "cat": "money", "weight": 1.0, "cooldown": 4, "headline": "RECRUITING RIPPLE", "subject": "team",
		"stories": [
			"{feat} Your success has recruits calling about the program. Take an immediate reward, or invest in outreach and bet on the next win?",
			"{feat} High school coaches are asking about the program. A sure reward now, or a bigger payoff riding on the next result?"],
		"choices": [
			{"label": "TAKE THE REWARD", "text": "Take the goodwill while it's there."},
			{"label": "INVEST IN RECRUITING", "text": "Spend now. Win next game and it pays."}]},
	{"id": "practice_discipline", "cat": "discipline", "weight": 1.0, "cooldown": 8, "headline": "PRACTICE DISCIPLINE", "subject": "player",
		"stories": [
			"{name} has been ignoring instructions in practice all week, and the team is watching how you handle it. Do you work with him privately, or suspend him?",
			"The assistants say {name} keeps doing his own thing in practice, and it's starting to spread. Nothing has cost a game yet. A private fix, or a suspension?"],
		"choices": [
			{"label": "HANDLE IT PRIVATELY", "text": "Extra one-on-one coaching."},
			{"label": "SUSPEND HIM", "text": "He sits out the next game."}]},
	{"id": "big_rivalry", "cat": "challenge", "weight": 1.0, "cooldown": 4, "headline": "THE BIG RIVALRY", "subject": "team",
		"stories": [
			"Next up: {opp}. {why} The pressure is building, and {name}, the team's leader, wants to lead them to a win. Keep him focused, or raise the stakes?",
			"{opp} are next. {why} {name}, the team's most experienced player, will set the tone. Do you keep things steady, or go all in?"],
		"special_story": "Next up: {opp}. {why} {name} wants this one badly. A rare chance: a win built on a huge game from him would be legendary.",
		"choices": [
			{"label": "KEEP HIM FOCUSED", "text": "Same preparation as any week."},
			{"label": "RAISE THE STAKES", "text": "Put it on the leader to win it."}]},
	{"id": "learning_experience", "cat": "challenge", "weight": 1.0, "cooldown": 4, "headline": "THE LEARNING EXPERIENCE", "subject": "player",
		"stories": [
			"{name} has worked hard but hasn't found his rhythm: {form}. The {score} loss didn't help. Do you encourage him, or challenge him to learn from adversity?",
			"After the {score} loss, {name} sat alone at the end of the bench ({form}). Tough nights can teach the most. Reassure him, or make the next one count?"],
		"choices": [
			{"label": "ENCOURAGE HIM", "text": "Reassure him. Keep working."},
			{"label": "LEARN THROUGH ADVERSITY", "text": "If the next one is lost, make it count."}]},
	{"id": "cost_of_victory", "cat": "money", "weight": 1.0, "cooldown": 4, "headline": "THE COST OF VICTORY", "subject": "team",
		"stories": [
			"A {score} win, but it took everything. {heavy} carried the load and are feeling it. Spend credits to reward them, or keep the money and challenge {name}?",
			"{score}. The team found a way, but nobody left the pool fresh. Reward {heavy} with extra recovery, or save the credits and set {name} a challenge?"],
		"choices": [
			{"label": "INVEST IN THE TEAM", "text": "Extra recovery for the hardest workers."},
			{"label": "INDIVIDUAL CHALLENGE", "text": "Keep the money. Challenge {name}."}]},
	{"id": "prove_me_wrong", "cat": "challenge", "weight": 0.35, "cooldown": 10, "headline": "PROVE ME WRONG", "subject": "player",
		"stories": [
			"Backup {pos} {name} has grown frustrated with his limited opportunities. After another game watching from the bench, he approaches you and asks for a chance to prove he belongs in the starting lineup. He believes he can help the team win, and his teammates have noticed his determination. But starting him means trusting a player who hasn't established himself. Do you give him more development time, or put your confidence in him and make him prove it in the next game?",
			"{name} knocks on your office door. He's done waiting: he wants to start. He's been sharp in practice, and he says he'll prove it if you give him the chance. Starting him means {displaced} sits. It's a gamble, and everybody's development rides on it."],
		"choices": [
			{"label": "KEEP HIM DEVELOPING", "text": "His chance will come. Keep improving in practice."},
			{"label": "GIVE HIM THE START", "text": "He starts the next game. Win, and everyone gains. Lose, and everyone pays."}]},
]

## XP and credits, all in one place (against a level-up of 450+ XP and a game's 30-80). The
## HIGH STAKES update doubled the XP (THE BACKUP BREAKOUT's set at +40 / +150); credits stay
## modest. PROVE ME WRONG's (pmw_safe, PMW_WIN, PMW_LOSS) are as they were.
const XP := {"star_praise": 80, "backup_reward": 40, "backup_ok": 150, "leader": 90, "team_win": 30, "keeper": 50,
	"rough_encourage": 60, "rough_ok": 160, "def_star": 90, "rivalry_calm": 40, "learn": 60, "private": 40, "recovery": 30,
	"cost_ok": 120, "pmw_safe": 25}
const COINS := {"ripple_now": 20, "ripple_cost": 15, "ripple_win": 50, "private": 15, "recovery": 15}
## HOT STAR PROGRESS, in parts of a GOOD grade (the bar is the run over PlayerForm.HOT_AT = 3,
## so 0.3 is 10 percentage points of it): +20 / +30 points, and 10 points lost on a failure.
const HOT := {"star_praise": 0.6, "keeper": 0.9, "loss": 0.3}
const COLD_RECOVERY := 2      # A ROUGH NIGHT's encouragement forgives his last two BAD grades (doubled)
const MULT_2X := 2.0
const MULT_3X := 3.0
const PMW_WIN := 1.5
const PMW_LOSS := 0.75
## A risky choice that fails: this multiplier on his positive game XP (the team's, for THE
## CAPTAIN'S SPEECH), when he played. Events not here have no failure penalty.
const FAIL_MULT := {"star_in_making": 0.75, "backup_breakout": 0.5, "captains_speech": 0.75, "keeper_confidence": 0.5,
	"rough_night": 0.5, "defensive_masterclass": 0.75, "big_rivalry": 0.5, "learning_experience": 0.75, "cost_of_victory": 0.75}
## ...and 10 points of his HOT STAR PROGRESS too.
const FAIL_HOT := ["star_in_making", "keeper_confidence"]

## THE RARE SPECIAL CHALLENGE: when one of these four is drawn, a 1 in 20 chance (rolled once,
## when the event is made, and saved with it: Career.pending_event.special) that its risky choice
## is the special one: a much harder target for 3X GAME XP. Its choice's name here.
const SPECIAL_CHANCE := 0.05
const SPECIAL := {"star_in_making": "PROVE HE'S ELITE", "keeper_confidence": "ULTIMATE SAVES TEST",
	"defensive_masterclass": "DEFENSIVE LEGEND", "big_rivalry": "LEGENDARY LEADER"}
const SPECIAL_TEXT := ""   # (its gold SPECIAL CHALLENGE mark says it)

## Who each event is about and when it's drawn, in words (what when() checks, below), for the
## Developer Mode panel (coach_lab). [who, rule]. Every event also needs its man on your roster,
## not suspended, with nothing else riding on him, and never last game's event or one inside its
## cooldown.
const ELIGIBILITY := {
	"star_in_making": ["FIELD PLAYER OR GOALKEEPER, FRESHMAN OR SOPHOMORE", "A young player's big game: 3+ goals, or 2+ goals in 4+ goals and assists; a young keeper's 12+ saves at 60%+. Needs a next game."],
	"backup_breakout": ["SUBSTITUTE (NOT IN THE LINEUP'S SEVEN), FIELD OR KEEPER", "A sub who made it count: 2+ goals and assists, or a goal and 2+ steals and blocks; a keeper's 6+ saves. Needs a saved lineup and a next game."],
	"captains_speech": ["THE TEAM LEADER (NO NAMED CAPTAIN)", "A win by 3+ that the team leader played in. The leader: the senior (else the oldest class) with the most career games."],
	"keeper_confidence": ["GOALKEEPER", "The keeper's 10+ saves at 60%+, and a next game."],
	"rough_night": ["FIELD PLAYER OR GOALKEEPER", "A field player's 4+ shots and no goal, or a keeper under 40% with 9+ goals against. Needs a next game."],
	"defensive_masterclass": ["FIELD PLAYER (THE KEEPER IF NO FIELD PLAYER QUALIFIES)", "The opponent held to 7 or fewer and a field player's 3+ recorded steals and blocks, or the keeper's 8+ saves when held to 5 or fewer. Needs a next game."],
	"recruiting_ripple": ["THE TEAM (NO PLAYER)", "A win by 5+, or a third straight win or more, and a next game."],
	"practice_discipline": ["FIELD STARTER (NEVER THE KEEPER)", "The practice week, not the game: a field starter whose suspension still leaves a legal seven with a keeper, and a next game."],
	"big_rivalry": ["THE TEAM LEADER", "The next opponent is big: a playoff game, a top-two team in your conference, or a top-20 ranked team."],
	"learning_experience": ["ANY PLAYER IN A SLUMP", "A loss, and a player who played with more BAD grades than GOOD in his recent games. Needs a next game."],
	"cost_of_victory": ["THE THREE WHO WORKED HARDEST (FIELD OR KEEPER)", "A win by 1 or 2 (a shootout too): the three with the most work get the recovery, the first of them free the challenge. Needs a next game."],
	"prove_me_wrong": ["A BACKUP WHO CAN LEGALLY START", "A bench player (not suspended or injured) who can legally start in his natural place, and nothing else riding on the next game for anyone."],
}

## The last game's review (Postgame), as roll() saw it: kept in memory for the Developer Mode
## panel to test an event's real conditions on. Never saved.
static var last_review := {}
## The decisions made this session (newest last, at most DECISIONS_MAX), for the Developer Mode
## panel's history: the game saves only what a next game settles (Career.coach_results). Never saved.
const DECISIONS_MAX := 20
static var decisions: Array = []

static func scenario(id: String) -> Dictionary:
	for ev in EVENTS:
		if ev.id == id:
			return ev
	return {}

## A scenario's two choices.
static func choices_of(ev: Dictionary) -> Array:
	return ev.choices

## The two choices this event offers: its scenario's, the risky one renamed when it rolled the
## special variant (only one version of it is ever offered).
static func choices_for(ev: Dictionary) -> Array:
	var chs: Array = scenario(String(ev.get("id", ""))).get("choices", []).duplicate(true)
	if is_special(ev) and chs.size() > 1:
		chs[1] = {"label": SPECIAL[String(ev.id)], "text": SPECIAL_TEXT}
	return chs

## This event is the rare special one (only ever one of SPECIAL's four).
static func is_special(ev: Dictionary) -> bool:
	return bool(ev.get("special", false)) and SPECIAL.has(String(ev.get("id", "")))

## "2X", "3X", "0.75X", "0.5X", "1.5X".
static func mx(m: float) -> String:
	return ("%dX" % roundi(m)) if is_equal_approx(m, roundf(m)) else ("%sX" % str(snappedf(m, 0.01)))

# ------------------------------------------------------------------ drawing one
## After the review: maybe one event (CHANCE), a category by CATEGORY_WEIGHT among those with an
## event that fits, then an event by weight (not last game's, not inside its cooldown, its
## subject real and eligible: when()). Logged either way, so it's never drawn again for this
## game. Returns the event ({} for none): {id, pid?, vars, story, pids, field, year, week, ...}.
static func roll(c: Career, rv: Dictionary) -> Dictionary:
	last_review = rv
	var ev := {}
	if c.rng.randf() < CHANCE:
		var by_cat := {}
		for sc in EVENTS:
			if not _allowed(c, String(sc.id), int(sc.cooldown)):
				continue
			var ctx := when(String(sc.id), c, rv)
			if ctx.is_empty():
				continue
			if not by_cat.has(sc.cat):
				by_cat[sc.cat] = []
			(by_cat[sc.cat] as Array).append([sc, ctx])
		var cat: Variant = _weighted(c, by_cat.keys(), func(k): return float(CATEGORY_WEIGHT.get(k, 1.0)))
		if cat != null:
			var it: Array = _weighted(c, by_cat[cat], func(x): return float(x[0].weight))
			ev = it[1]
			ev["id"] = String(it[0].id)
			var stories: Array = it[0].stories
			ev["story"] = c.rng.randi() % stories.size()
			ev["special"] = roll_special(c, String(ev.id))
	if not ev.is_empty():
		ev["pids"] = rv.players.map(func(pl): return int(pl.pid))
		ev["field"] = rv.players.filter(func(pl): return not pl.gk).map(func(pl): return int(pl.pid))
		ev["year"] = c.year
		ev["week"] = c.week
	c.event_log.append(String(ev.get("id", "")))
	while c.event_log.size() > LOG_MAX:
		c.event_log.pop_front()
	return ev

## The 1-in-20 SPECIAL CHALLENGE roll, once, when one of SPECIAL's four is made (its own die, so
## the career's draws stay as they were): false for every other event.
static func roll_special(c: Career, id: String) -> bool:
	if not SPECIAL.has(id):
		return false
	var die := RandomNumberGenerator.new()
	die.seed = hash([c.rng.seed, c.rng.state, c.year, c.week, id, "special"])
	return die.randf() < SPECIAL_CHANCE

## One of `items` by `weight` (c.rng); null when there's nothing.
static func _weighted(c: Career, items: Array, weight: Callable):
	var total := 0.0
	for x in items:
		total += weight.call(x)
	if items.is_empty() or total <= 0.0:
		return null
	var pick := c.rng.randf() * total
	for x in items:
		pick -= weight.call(x)
		if pick <= 0.0:
			return x
	return items.back()

## Not the last game's event, and not within its cooldown (games since it last came).
static func _allowed(c: Career, id: String, cooldown: int) -> bool:
	var seen: Array = c.event_log
	for i in range(seen.size() - 1, -1, -1):
		if String(seen[i]) == id:
			return seen.size() - i > maxi(1, cooldown)
	return true

## Scenario `id`'s check on this game: its context ({pid?, vars, ...}), or {} when it isn't true
## (or its subject isn't real, on your roster and free to take it on).
static func when(id: String, c: Career, rv: Dictionary) -> Dictionary:
	match id:
		"star_in_making": return _when_star(c, rv)
		"backup_breakout": return _when_backup(c, rv)
		"captains_speech": return _when_speech(c, rv)
		"keeper_confidence": return _when_keeper(c, rv)
		"rough_night": return _when_rough(c, rv)
		"defensive_masterclass": return _when_defense(c, rv)
		"recruiting_ripple": return _when_ripple(c, rv)
		"practice_discipline": return _when_discipline(c, rv)
		"big_rivalry": return _when_rivalry(c, rv)
		"learning_experience": return _when_learning(c, rv)
		"cost_of_victory": return _when_cost(c, rv)
		"prove_me_wrong": return _when_pmw(c, rv)
	return {}

# ------------------------------------------------------------------ the conditions
## His line as the game recorded it ("2 goals and 4 assists"); a simmed game's estimated steals
## (Postgame.from_sim) never count.
static func _real(rv: Dictionary, pl: Dictionary, k: String) -> int:
	if k in (rv.get("estimated", []) as Array):
		return 0
	return int(pl.get(k, 0))

## Someone who can carry an event: on your roster now, not suspended.
static func _ok(c: Career, pid: int) -> PoloPlayer:
	var p := c.team().find_id(pid)
	return p if p != null and not p.is_suspended() else null

## Your next game is drawn (something can ride on it).
static func _next_game(c: Career) -> bool:
	return c.next_game().has("opp")

## Nobody has something riding on the next game already (one decision at a time per player).
static func _free(c: Career, pid: int) -> bool:
	return not c.coach_pending.any(func(e): return int(e.get("pid", -1)) == pid or int(e.get("rep", -1)) == pid)

## A freshman's (or a sophomore's) outstanding game: 3+ goals, or 2+ goals in 4+ goals and
## assists; a young keeper's 12+ saves at 60%+. Needs a next game for the challenge.
static func _when_star(c: Career, rv: Dictionary) -> Dictionary:
	if not _next_game(c):
		return {}
	var best := {}
	var best_v := 0.0
	for pl in rv.players:
		if int(pl.year) > 2 or _ok(c, int(pl.pid)) == null or not _free(c, int(pl.pid)):
			continue
		var v := 0.0
		if pl.gk:
			if int(pl.sv) >= 12 and Postgame.save_pct(pl) >= 0.6:
				v = int(pl.sv) * 0.4
		elif int(pl.g) >= 3 or (int(pl.g) >= 2 and int(pl.g) + int(pl.a) >= 4):
			v = int(pl.g) * 2.0 + int(pl.a) + (1.0 if int(pl.year) == 1 else 0.0)
		if v > best_v:
			best = pl
			best_v = v
	if best.is_empty():
		return {}
	return {"pid": int(best.pid), "vars": _vars(c, best, rv)}

## Someone who came in for the lineup's seven (a sub, or a man starting in another's place) and
## made it count: 2+ goals and assists, or a goal and 2+ steals and blocks; a keeper's 6+ saves.
static func _when_backup(c: Career, rv: Dictionary) -> Dictionary:
	if not _next_game(c) or not c.team().has_lineup():
		return {}
	var seven: Array = c.team().lineup.slice(0, PoloTeam.STARTERS)
	var best := {}
	var best_v := 0.0
	for pl in rv.players:
		if int(pl.pid) in seven or _ok(c, int(pl.pid)) == null or not _free(c, int(pl.pid)):
			continue
		var v := 0.0
		if pl.gk:
			v = float(pl.sv) if int(pl.sv) >= 6 else 0.0
		else:
			var ga := int(pl.g) + int(pl.a)
			var d := _real(rv, pl, "st") + _real(rv, pl, "bl")
			if ga >= 2 or (int(pl.g) >= 1 and d >= 2):
				v = ga * 2.0 + d
		if v > best_v:
			best = pl
			best_v = v
	if best.is_empty():
		return {}
	return {"pid": int(best.pid), "vars": _vars(c, best, rv)}

## The team's leader: the oldest class's man with the most career games (then the best).
static func leader(c: Career) -> PoloPlayer:
	var best: PoloPlayer = null
	for p in c.team().roster:
		if p.is_suspended():
			continue
		if best == null or [p.year, p.totals.get("gp", 0), p.overall()] > [best.year, best.totals.get("gp", 0), best.overall()]:
			best = p
	return best

## A win by 3+ that the leader played in.
static func _when_speech(c: Career, rv: Dictionary) -> Dictionary:
	var g: Array = rv.team.g
	var lead := leader(c)
	if not rv.get("won", false) or int(g[0]) - int(g[1]) < 3 or lead == null:
		return {}
	var pl: Dictionary = _pl(rv, lead.id)
	if pl.is_empty():
		return {}
	return {"pid": lead.id, "vars": _vars(c, pl, rv)}

## 10+ saves at 60%+, and a next game for the challenge.
static func _when_keeper(c: Career, rv: Dictionary) -> Dictionary:
	var k := Postgame.keeper(rv)
	if k.is_empty() or int(k.sv) < 10 or Postgame.save_pct(k) < 0.6 or not _next_game(c) or _ok(c, int(k.pid)) == null or not _free(c, int(k.pid)):
		return {}
	return {"pid": int(k.pid), "vars": _vars(c, k, rv)}

## A field player's 4+ shots and no goal, or a keeper's night under 40% with 9+ goals against.
static func _when_rough(c: Career, rv: Dictionary) -> Dictionary:
	if not _next_game(c):
		return {}
	var worst := {}
	var worst_v := 0.0
	for pl in rv.players:
		if _ok(c, int(pl.pid)) == null or not _free(c, int(pl.pid)):
			continue
		var v := 0.0
		if pl.gk:
			if int(pl.ga) >= 9 and Postgame.save_pct(pl) < 0.4:
				v = float(pl.ga)
		elif int(pl.sh) >= 4 and int(pl.g) == 0:
			v = float(pl.sh)
		if v > worst_v:
			worst = pl
			worst_v = v
	if worst.is_empty():
		return {}
	var vars := _vars(c, worst, rv)
	vars["rough"] = ("He made %d saves but let in %d, %d%% of the shots he faced." % [int(worst.sv), int(worst.ga), roundi(Postgame.save_pct(worst) * 100.0)]) if worst.gk \
		else ("He took %d shots and didn't score%s." % [int(worst.sh), "" if int(worst.a) == 0 else (", though he did have %d assist%s" % [int(worst.a), "" if int(worst.a) == 1 else "s"])])
	return {"pid": int(worst.pid), "vars": vars}

## Held to 7 or fewer, and a field player with 3+ steals and blocks (recorded), or the keeper's
## 8+ saves when they were held to 5 or fewer.
static func _when_defense(c: Career, rv: Dictionary) -> Dictionary:
	if int(rv.team.g[1]) > 7 or not _next_game(c):
		return {}
	var best := {}
	var best_v := 0
	for pl in rv.players:
		if pl.gk or _ok(c, int(pl.pid)) == null or not _free(c, int(pl.pid)):
			continue
		var d := _real(rv, pl, "st") + _real(rv, pl, "bl")
		if d >= 3 and d > best_v:
			best = pl
			best_v = d
	if best.is_empty():
		var k := Postgame.keeper(rv)
		if not k.is_empty() and int(rv.team.g[1]) <= 5 and int(k.sv) >= 8 and _ok(c, int(k.pid)) != null and _free(c, int(k.pid)):
			best = k
	if best.is_empty():
		return {}
	var vars := _vars(c, best, rv)
	vars["opp_goals"] = "them to %d" % int(rv.team.g[1])
	return {"pid": int(best.pid), "vars": vars}

## A real accomplishment: a win by 5+, or the third straight win or more.
static func _when_ripple(c: Career, rv: Dictionary) -> Dictionary:
	if not rv.get("won", false):
		return {}
	var g: Array = rv.team.g
	var streak := int(rv.get("streak", 0))
	var feat := ""
	if streak >= 3:
		feat = "%d straight wins, the latest %d-%d." % [streak, int(g[0]), int(g[1])]
	elif int(g[0]) - int(g[1]) >= 5:
		feat = "A %d-%d win, and nobody saw it coming that big." % [int(g[0]), int(g[1])]
	if feat == "" or not _next_game(c):
		return {}
	return {"vars": {"feat": feat}}

## A field starter whose suspension still leaves a legal seven (never your keeper), with your
## next game to sit out. The practice week, not a game: nothing he did in the game is claimed.
static func _when_discipline(c: Career, rv: Dictionary) -> Dictionary:
	if not _next_game(c):
		return {}
	var t := c.team()
	var cands: Array = t.starters().filter(func(p: PoloPlayer): return not p.is_keeper() and _free(c, p.id) and suspension_ok(t, p) != null)
	if cands.is_empty():
		return {}
	var p: PoloPlayer = cands[c.rng.randi() % cands.size()]
	return {"pid": p.id, "vars": _vars(c, _pl(rv, p.id), rv, p)}

## Your next opponent is a big one: a playoff game, a top-two team in your conference, or a
## ranked team (the poll); the leader to carry it.
## Is the next game a big one? A playoff game, a top-two team in your conference, or a top-20 team.
static func big_game(c: Career) -> bool:
	var ng := c.next_game()
	if not ng.has("opp"):
		return false
	var opp := String(ng.opp)
	if Schedule.is_playoff(c.cur()):
		return true
	if (c.teams[opp] as PoloTeam).conf == c.team().conf and c.conf_rank(opp) <= 2:
		return true
	var rank := Poll.rank_in(Poll.latest(c), opp)
	return rank > 0 and rank <= 20

static func _when_rivalry(c: Career, rv: Dictionary) -> Dictionary:
	var ng := c.next_game()
	var lead := leader(c)
	if not ng.has("opp") or lead == null or not _free(c, lead.id):
		return {}
	var opp := String(ng.opp)
	var why := ""
	var nr: Dictionary = c.schedule[c.week] if c.week < c.schedule.size() else {}
	for w in range(c.week, c.schedule.size()):
		if c.my_games(c.schedule[w]).any(func(g): return g.r == null):
			nr = c.schedule[w]
			break
	var rank := Poll.rank_in(Poll.latest(c), opp)
	if Schedule.is_playoff(nr):
		why = "It's the playoffs: lose and the season's over."
	elif (c.teams[opp] as PoloTeam).conf == c.team().conf and c.conf_rank(opp) <= 2:
		why = "They're %s in the conference standings." % ["", "first", "second"][c.conf_rank(opp)]
	elif rank > 0 and rank <= 20:
		why = "They're ranked #%d in the country." % rank
	if why == "":
		return {}
	var pl := _pl(rv, lead.id)
	var vars := _vars(c, pl, rv, lead)
	vars["opp"] = Colleges.display_name((c.teams[opp] as PoloTeam).name).to_upper()
	vars["why"] = why
	return {"pid": lead.id, "vars": vars, "opp": opp}

## A loss, and a player who played with more BAD grades than GOOD in his recent games.
static func _when_learning(c: Career, rv: Dictionary) -> Dictionary:
	if rv.get("won", false) or not _next_game(c):
		return {}
	var pick := {}
	var low := 0
	for pl in rv.players:
		var p := _ok(c, int(pl.pid))
		if p == null or not _free(c, p.id):
			continue
		var run := PlayerForm.run_score(p.form)
		if run < low:
			pick = pl
			low = run
	if pick.is_empty():
		return {}
	var p := c.team().find_id(int(pick.pid))
	var vars := _vars(c, pick, rv)
	var bad := p.form.filter(func(x): return int(x) == PlayerForm.BAD).size()
	vars["form"] = "%d BAD grade%s in his last %d games" % [bad, "" if bad == 1 else "s", p.form.size()]
	return {"pid": p.id, "vars": vars}

## A win by one or two (a shootout too); the three who did the most (heavy) for recovery, the
## best of them for the challenge.
static func _when_cost(c: Career, rv: Dictionary) -> Dictionary:
	var g: Array = rv.team.g
	if not rv.get("won", false) or int(g[0]) - int(g[1]) > 2 or not _next_game(c):
		return {}
	var load: Array = rv.players.filter(func(pl): return _ok(c, int(pl.pid)) != null)
	load.sort_custom(func(a, b): return _work(rv, a) > _work(rv, b))
	var heavy: Array = load.slice(0, 3)
	if heavy.is_empty():
		return {}
	var star = null
	for pl in heavy:
		if _free(c, int(pl.pid)):
			star = pl
			break
	if star == null:
		return {}
	var vars := _vars(c, star, rv)
	vars["heavy"] = ", ".join(heavy.map(func(pl): return String(pl.name).to_upper()))
	return {"pid": int(star.pid), "vars": vars, "heavy": heavy.map(func(pl): return int(pl.pid))}

static func _work(rv: Dictionary, pl: Dictionary) -> float:
	if pl.gk:
		return float(pl.sv) * 0.5
	return float(pl.g) + float(pl.a) + _real(rv, pl, "st") + _real(rv, pl, "bl") + float(pl.get("sh", 0)) * 0.25

## A real backup (on the bench, not suspended or hurt) who can legally start in your next game,
## and nothing else riding on it.
static func _when_pmw(c: Career, rv: Dictionary) -> Dictionary:
	if not _next_game(c) or not c.coach_pending.is_empty():
		return {}
	var t := c.team()
	var starters := t.starters()
	var cands: Array = []
	for p in t.roster:
		if p in starters or p.is_suspended() or p.is_injured():
			continue
		var pr := promotion(t, p)
		if not pr.is_empty():
			cands.append([p, pr])
	if cands.is_empty():
		return {}
	cands.sort_custom(func(a, b): return (a[0] as PoloPlayer).overall() > (b[0] as PoloPlayer).overall())
	var it: Array = cands[c.rng.randi() % mini(3, cands.size())]
	var p: PoloPlayer = it[0]
	var vars := _vars(c, _pl(rv, p.id), rv, p)
	vars["pos"] = p.pos_long().to_lower()
	vars["displaced"] = (t.find_id(int(it[1].displaced)) as PoloPlayer).short_name().to_upper()
	return {"pid": p.id, "vars": vars, "place": int(it[1].place), "displaced": int(it[1].displaced)}

## Where `p` (a backup) could start: the lineup place he's most natural in, legally (the place's
## position rules, two lefties at most), the weakest man there going to the bench.
## {place, displaced} or {}.
static func promotion(t: PoloTeam, p: PoloPlayer) -> Dictionary:
	var seven: Array = t.starters()
	if seven.size() < PoloTeam.STARTERS or p in seven:
		return {}
	var best := {}
	var best_key := []
	for i in PoloTeam.STARTERS:
		if not PoloTeam.fits(p, i):
			continue
		var trial := seven.duplicate()
		trial[i] = p
		if not PoloTeam.legal(trial) or trial.filter(func(q: PoloPlayer): return q.is_lefty()).size() > 2:
			continue
		var key := [PoloTeam.fit_rank(p, i), (seven[i] as PoloPlayer).overall()]
		if best.is_empty() or key < best_key:
			best = {"place": i, "displaced": (seven[i] as PoloPlayer).id}
			best_key = key
	return best

## Suspending `p` leaves a legal seven with a keeper in goal: the man who'd take his place
## (null if it doesn't). Changes nothing.
static func suspension_ok(t: PoloTeam, p: PoloPlayer) -> PoloPlayer:
	var before := t.starters()
	var i := before.find(p)
	p.susp += 1
	var after := t.starters()
	p.susp -= 1
	if after.size() < PoloTeam.STARTERS or not PoloTeam.legal(after) or not after[0].is_keeper():
		return null
	if i >= 0 and after[i] != p:
		return after[i]
	for q in after:
		if not q in before:
			return q
	return null

static func _pl(rv: Dictionary, pid: int) -> Dictionary:
	for pl in rv.get("players", []):
		if int(pl.pid) == pid:
			return pl
	return {}

## A story's numbers, all from the game's record: his name, class, his line.
static func _vars(c: Career, pl: Dictionary, rv: Dictionary, p: PoloPlayer = null) -> Dictionary:
	if p == null:
		p = c.team().find_id(int(pl.get("pid", 0)))
	var g: Array = rv.get("team", {}).get("g", [0, 0])
	var out := {"name": p.short_name().to_upper() if p != null else "", "cls": ["", "freshman", "sophomore", "junior", "senior"][clampi(p.year if p != null else 1, 0, 4)],
		"score": "%d-%d" % [int(g[0]), int(g[1])]}
	out["Cls"] = String(out.cls).capitalize()
	if not pl.is_empty():
		out["line"] = game_line(pl, rv)
		out["saves"] = str(int(pl.get("sv", 0)))
		out["save_pct"] = str(roundi(Postgame.save_pct(pl) * 100.0)) if pl.get("gk", false) else "0"
	return out

## A player's game in words: "12 saves", "2 goals and 4 assists", "3 steals and 2 blocks" (only
## what the game recorded).
static func game_line(pl: Dictionary, rv: Dictionary = {}) -> String:
	if pl.get("gk", false):
		return "%d saves" % int(pl.sv)
	var parts := PackedStringArray()
	for k in [["g", "goal"], ["a", "assist"], ["st", "steal"], ["bl", "block"]]:
		var n := _real(rv, pl, k[0])
		if n > 0:
			parts.append("%d %s%s" % [n, k[1], "" if n == 1 else "s"])
	if parts.is_empty():
		return "a quiet line"
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]

# ------------------------------------------------------------------ the stakes
## What a choice will do, in words, before it's made: [[text, "good" | "bad" | "info"], ...].
## Short: the reward, the target, SUCCESS and FAILURE. The same numbers apply() uses.
static func stakes(c: Career, ev: Dictionary, i: int) -> Array:
	var who := _name(c, int(ev.get("pid", 0)))
	var id := String(ev.id)
	var out: Array = []
	match [id, i]:
		["star_in_making", 0]:
			out = [["+%d XP TO %s" % [XP.star_praise, who], "good"], ["+%d%% HOT STAR PROGRESS" % _pp(HOT.star_praise), "good"]]
		["backup_breakout", 0]:
			out = [["+%d XP TO %s" % [XP.backup_reward, who], "good"]]
		["backup_breakout", 1]:
			out = [["%s: 2 GOALS NEXT GAME HE PLAYS" % who, "info"], ["SUCCESS: +%d XP" % XP.backup_ok, "good"],
				["FAILURE: %s GAME XP" % mx(FAIL_MULT.backup_breakout), "bad"], ["(WAITS UP TO %d GAMES FOR HIM TO PLAY)" % WAIT_GAMES, "info"]]
		["captains_speech", 0]:
			out = [["+%d XP TO %s (TEAM LEADER)" % [XP.leader, who], "good"]]
		["captains_speech", 1]:
			out = [["WIN NEXT GAME: +%d XP EACH TO ALL WHO PLAY" % XP.team_win, "good"],
				["LOSE: %s GAME XP FOR ALL WHO PLAY" % mx(FAIL_MULT.captains_speech), "bad"]]
		["keeper_confidence", 0]:
			out = [["+%d XP TO %s" % [XP.keeper, who], "good"], ["+%d%% HOT STAR PROGRESS" % _pp(HOT.keeper), "good"]]
		["rough_night", 0]:
			var p := c.team().find_id(int(ev.get("pid", 0)))
			var bad := 0 if p == null else mini(COLD_RECOVERY, p.form.filter(func(x): return int(x) == PlayerForm.BAD).size())
			out = [["+%d XP TO %s" % [XP.rough_encourage, who], "good"],
				["DOUBLE COLD RECOVERY: LAST %d BAD GRADE%s FORGIVEN" % [bad, "" if bad == 1 else "S"] if bad > 0 else "(NO BAD GRADE TO FORGIVE)", "good" if bad > 0 else "info"]]
		["rough_night", 1]:
			out = _chal_text(c, ev, "+%d XP" % XP.rough_ok)
		["defensive_masterclass", 0]:
			out = [["+%d XP TO %s" % [XP.def_star, who], "good"]]
		["recruiting_ripple", 0]:
			out = [["+%d CREDITS NOW" % COINS.ripple_now, "good"]]
		["recruiting_ripple", 1]:
			out = [["-%d CREDITS NOW" % COINS.ripple_cost, "bad"], ["WIN NEXT GAME: +%d CREDITS" % COINS.ripple_win, "good"],
				["LOSE: THE %d IS GONE" % COINS.ripple_cost, "bad"]]
		["practice_discipline", 0]:
			out = [["-%d CREDITS NOW" % COINS.private, "bad"], ["+%d XP TO %s" % [XP.private, who], "good"], ["%s STAYS AVAILABLE" % who, "info"]]
		["practice_discipline", 1]:
			var rep := suspension_ok(c.team(), c.team().find_id(int(ev.get("pid", 0)))) if c.team().find_id(int(ev.get("pid", 0))) != null else null
			out = [["%s MISSES THE NEXT GAME" % who, "bad"],
				["%s STARTS: 2X GAME XP IF HE PLAYS" % (rep.short_name().to_upper() if rep != null else "A REPLACEMENT"), "good"]]
		["big_rivalry", 0]:
			out = [["+%d XP TO %s (TEAM LEADER)" % [XP.rivalry_calm, who], "good"]]
		["big_rivalry", 1]:
			if is_special(ev):
				var ch := challenge(c, ev)
				out = [["WIN + %s %s" % [who, ch.label], "info"], ["SUCCESS: %s 3X GAME XP" % who, "good"],
					["WIN, TARGET MISSED: NORMAL GAME XP", "info"], ["LOSE: %s %s GAME XP" % [who, mx(FAIL_MULT.big_rivalry)], "bad"]]
			else:
				out = [["WIN: %s 2X GAME XP" % who, "good"], ["LOSE: %s %s GAME XP" % [who, mx(FAIL_MULT.big_rivalry)], "bad"]]
		["learning_experience", 0]:
			out = [["+%d XP TO %s" % [XP.learn, who], "good"]]
		["learning_experience", 1]:
			var ch := challenge(c, ev)
			out = [["LOSE + %s %s: 2X GAME XP" % [who, ch.label], "good"], ["LOSE, TARGET MISSED: %s GAME XP" % mx(FAIL_MULT.learning_experience), "bad"],
				["WIN: NORMAL GAME XP", "info"]]
		["cost_of_victory", 0]:
			out = [["-%d CREDITS NOW" % COINS.recovery, "bad"], ["+%d XP EACH TO %s" % [XP.recovery, ", ".join((ev.get("heavy", []) as Array).map(func(id): return _name(c, int(id))))], "good"]]
		["cost_of_victory", 1]:
			out = _chal_text(c, ev, "+%d XP" % XP.cost_ok)
		["prove_me_wrong", 0]:
			out = [["+%d XP NOW TO %s" % [XP.pmw_safe, who], "good"], ["NO LINEUP CHANGE, NO WAGER", "info"]]
		["prove_me_wrong", 1]:
			out = [["%s STARTS NEXT GAME (%s TO THE BENCH)" % [who, _name(c, int(ev.get("displaced", 0)))], "info"],
				["WIN: TEAM 1.5X GAME XP, %s 2X" % who, "good"],
				["LOSE: TEAM 0.75X GAME XP", "bad"], ["LOSE: %s'S XP BAR RESET TO 0" % who, "bad"]]
		_:
			if i == 1:   # the multiplier challenges: star, keeper, defense
				out = _chal_text(c, ev, "%s GAME XP" % mx(float(challenge(c, ev).mult)))
	return out

## Percentage points of the HOT STAR bar `amount` (parts of a GOOD grade) is.
static func _pp(amount: float) -> int:
	return roundi(amount / PlayerForm.HOT_AT * 100.0)

## A next-game challenge's words: the target, what making it pays, what missing it costs.
static func _chal_text(c: Career, ev: Dictionary, reward: String) -> Array:
	var ch := challenge(c, ev)
	var id := String(ev.id)
	var out: Array = [["%s: %s NEXT GAME" % [_name(c, int(ev.get("pid", 0))), ch.label], "info"], ["SUCCESS: %s" % reward, "good"]]
	if FAIL_MULT.has(id):
		out.append(["FAILURE: %s GAME XP" % mx(float(FAIL_MULT[id])), "bad"])
	else:
		out.append(["FAILURE: NORMAL GAME XP, NO BONUS", "bad"])
	if id in FAIL_HOT:
		out.append(["FAILURE: -%d%% HOT STAR PROGRESS" % _pp(HOT.loss), "bad"])
	return out

## The next-game target for a challenge choice: {stat, n, label, mult}. The special variant's are
## much harder (5 goals, 16 saves, 5 steals + blocks) for 3X; a keeper's always saves.
static func challenge(c: Career, ev: Dictionary) -> Dictionary:
	var p := c.team().find_id(int(ev.get("pid", 0)))
	var gk := p != null and p.is_keeper()
	var sp := is_special(ev)
	var out := {}
	match String(ev.id):
		"star_in_making":
			if sp:
				out = {"stat": "sv", "n": 16, "label": "16 SAVES"} if gk else {"stat": "g", "n": 5, "label": "5 GOALS"}
			else:
				out = {"stat": "sv", "n": 10, "label": "10 SAVES"} if gk else {"stat": "ga", "n": 3, "label": "3 GOALS + ASSISTS"}
		"keeper_confidence":
			out = {"stat": "sv", "n": 16, "label": "16 SAVES"} if sp else {"stat": "sv", "n": 10, "label": "10 SAVES"}
		"defensive_masterclass":
			if sp:
				out = {"stat": "sv", "n": 16, "label": "16 SAVES"} if gk else {"stat": "stbl", "n": 5, "label": "5 STEALS + BLOCKS"}
			else:
				out = {"stat": "sv", "n": 8, "label": "8 SAVES"} if gk else {"stat": "stbl", "n": 2, "label": "2 STEALS + BLOCKS"}
		"big_rivalry":
			if sp:
				out = {"stat": "sv", "n": 16, "label": "16 SAVES"} if gk else {"stat": "ga", "n": 5, "label": "5 GOALS + ASSISTS"}
		"rough_night", "cost_of_victory", "learning_experience":
			out = {"stat": "sv", "n": 8, "label": "8 SAVES"} if gk else {"stat": "ga", "n": 2, "label": "2 GOALS + ASSISTS"}
		"backup_breakout":
			out = {"stat": "g", "n": 2, "label": "2 GOALS"}
	if not out.is_empty():
		out["mult"] = MULT_3X if sp else MULT_2X
	return out

## Why a choice can't be made now ("" when it can): a cost you can't afford.
static func blocked(c: Career, ev: Dictionary, i: int) -> String:
	var cost := 0
	match [String(ev.id), i]:
		["recruiting_ripple", 1]: cost = COINS.ripple_cost
		["practice_discipline", 0]: cost = COINS.private
		["cost_of_victory", 0]: cost = COINS.recovery
	if cost > 0 and c.wallet() < cost:
		return "NOT ENOUGH CREDITS (%d NEEDED)" % cost
	if [String(ev.id), i] == ["prove_me_wrong", 1]:
		var p := c.team().find_id(int(ev.get("pid", 0)))
		if p == null or promotion(c.team(), p).is_empty():
			return "HE CAN'T LEGALLY START NOW"
	if [String(ev.id), i] == ["practice_discipline", 1]:
		var p := c.team().find_id(int(ev.get("pid", 0)))
		if p == null or suspension_ok(c.team(), p) == null:
			return "NO LEGAL LINEUP WITHOUT HIM"
	return ""

static func _name(c: Career, pid: int) -> String:
	var p := c.team().find_id(pid)
	return p.short_name().to_upper() if p != null else "HIM"

# ------------------------------------------------------------------ applying a choice
## Applies choice `i` of event `ev` once (the caller clears the pending event and saves): what
## happens now, and anything riding on the next game (Career.coach_pending). Returns lines:
## [[text, kind], ...].
static func apply(c: Career, ev: Dictionary, i: int) -> Array:
	if blocked(c, ev, i) != "":
		return []
	var t := c.team()
	var pid := int(ev.get("pid", 0))
	var p := t.find_id(pid)
	var out: Array = []
	var id := String(ev.id)
	var head := String(scenario(id).get("headline", ""))
	var fail := float(FAIL_MULT.get(id, 0.0))
	match [id, i]:
		["star_in_making", 0]:
			out.append_array(_xp_now(c, [p], XP.star_praise))
			out.append(_hot(p, HOT.star_praise))
		["backup_breakout", 0]:
			out.append_array(_xp_now(c, [p], XP.backup_reward))
		["captains_speech", 0], ["big_rivalry", 0]:
			out.append_array(_xp_now(c, [p], XP.leader if id == "captains_speech" else XP.rivalry_calm))
		["captains_speech", 1]:
			out.append(_pend(c, ev, head, {"k": "team", "need": "win", "xp": XP.team_win, "fail_mult": fail, "label": "WIN THE NEXT GAME",
				"reward": "+%d XP EACH / LOSE: %s" % [XP.team_win, mx(fail)]}))
		["keeper_confidence", 0]:
			out.append_array(_xp_now(c, [p], XP.keeper))
			out.append(_hot(p, HOT.keeper))
		["rough_night", 0]:
			out.append_array(_xp_now(c, [p], XP.rough_encourage))
			out.append(_forgive(p, COLD_RECOVERY))
		["defensive_masterclass", 0]:
			out.append_array(_xp_now(c, [p], XP.def_star))
		["learning_experience", 0]:
			out.append_array(_xp_now(c, [p], XP.learn))
		["prove_me_wrong", 0]:
			out.append_array(_xp_now(c, [p], XP.pmw_safe))
		["recruiting_ripple", 0]:
			c.add_credits(COINS.ripple_now, "COACHING EVENT")
			out.append(["+%d CREDITS" % COINS.ripple_now, "good"])
		["recruiting_ripple", 1]:
			c.spend_credits(COINS.ripple_cost, "COACHING EVENT")
			out.append(["-%d CREDITS: RECRUITING OUTREACH" % COINS.ripple_cost, "bad"])
			out.append(_pend(c, ev, head, {"k": "invest", "need": "win", "coins": COINS.ripple_win, "label": "WIN THE NEXT GAME", "reward": "+%d CREDITS" % COINS.ripple_win}))
		["practice_discipline", 0]:
			c.spend_credits(COINS.private, "COACHING EVENT")
			out.append(["-%d CREDITS: EXTRA ONE-ON-ONE COACHING" % COINS.private, "bad"])
			out.append_array(_xp_now(c, [p], XP.private))
			out.append(["%s STAYS AVAILABLE" % _name(c, pid), "info"])
		["practice_discipline", 1]:
			var rep := suspension_ok(t, p)
			p.susp = 1
			out.append(["%s SUSPENDED FOR THE NEXT GAME" % _name(c, pid), "bad"])
			out.append(_pend(c, ev, head, {"k": "susp", "rep": rep.id if rep != null else -1, "mult": MULT_2X,
				"label": "%s STARTS FOR %s" % [rep.short_name().to_upper() if rep != null else "A REPLACEMENT", _name(c, pid)], "reward": "2X GAME XP IF HE PLAYS"}))
		["big_rivalry", 1]:
			var e := {"k": "result", "need": "win", "mult": MULT_2X, "fail_mult": fail, "label": "WIN THE NEXT GAME",
				"reward": "%s 2X GAME XP / LOSE: %s" % [_name(c, pid), mx(fail)]}
			if is_special(ev):
				var ch := challenge(c, ev)
				e.merge({"stat": ch.stat, "n": int(ch.n), "mult": MULT_3X, "label": "WIN + %s %s" % [_name(c, pid), ch.label],
					"reward": "3X GAME XP / LOSE: %s" % mx(fail)}, true)
			out.append(_pend(c, ev, head, e))
		["learning_experience", 1]:
			var ch := challenge(c, ev)
			out.append(_pend(c, ev, head, {"k": "learn", "stat": ch.stat, "n": int(ch.n), "mult": MULT_2X, "fail_mult": fail,
				"label": "LOSE + %s %s" % [_name(c, pid), ch.label], "reward": "2X GAME XP / MISSED: %s / WIN: NORMAL" % mx(fail)}))
		["cost_of_victory", 0]:
			c.spend_credits(COINS.recovery, "COACHING EVENT")
			out.append(["-%d CREDITS: RECOVERY SUPPORT" % COINS.recovery, "bad"])
			out.append_array(_xp_now(c, _players(c, ev.get("heavy", [])), XP.recovery))
		["prove_me_wrong", 1]:
			out.append_array(_promote(c, ev, head))
		_:
			# the challenges: star 1, backup 1, keeper 1, rough 1, defense 1, cost 1
			var ch := challenge(c, ev)
			var ok := {}
			match id:
				"backup_breakout": ok = {"xp": XP.backup_ok}
				"rough_night": ok = {"xp": XP.rough_ok}
				"cost_of_victory": ok = {"xp": XP.cost_ok}
				_: ok = {"mult": float(ch.mult)}
			var e := {"k": "chal", "stat": ch.stat, "n": int(ch.n), "label": "%s %s" % [_name(c, pid), ch.label],
				"reward": (("+%d XP" % int(ok.xp)) if ok.has("xp") else "%s GAME XP" % mx(float(ok.mult))) + (" / MISS: %s" % mx(fail) if fail > 0.0 else ""),
				"wait": id == "backup_breakout"}
			if fail > 0.0:
				e["fail_mult"] = fail
			if id in FAIL_HOT:
				e["hot_loss"] = HOT.loss
			e.merge(ok)
			out.append(_pend(c, ev, head, e))
	return out

## Records what rides on the next game. Returns its line.
static func _pend(c: Career, ev: Dictionary, head: String, e: Dictionary) -> Array:
	c.coach_seq += 1
	e["eid"] = c.coach_seq
	e["event"] = String(ev.id)
	e["title"] = head
	e["pid"] = int(ev.get("pid", -1))
	e["team"] = c.school
	e["made"] = [c.year, c.week]
	e["games"] = 0
	e["special"] = is_special(ev)   # (the variant, saved: it can't become the other one)
	if bool(ev.get("dev", false)):
		e["dev"] = true   # (made by Developer Mode's TRIGGER EVENT: settles exactly as any other)
	c.coach_pending.append(e)
	return ["NEXT GAME: %s - %s" % [String(e.label), String(e.reward)], "info"]

## PROVE ME WRONG's promotion: the backup into his place for the next game, the man there to the
## bench, the lineup as it was kept to put back after.
static func _promote(c: Career, ev: Dictionary, head: String) -> Array:
	var t := c.team()
	var p := t.find_id(int(ev.pid))
	var pr := promotion(t, p)
	var had := t.has_lineup()
	if not had:
		t.lineup = default_lineup(t)
	var was := t.lineup.duplicate()
	var place := int(pr.place)
	var displaced := int(pr.displaced)
	# (the seven as they stand: put the backup where the displaced man's place is)
	var seven := t.starters()
	for i in PoloTeam.STARTERS:
		t.lineup[i] = seven[i].id
	var from := t.lineup.find(p.id)
	t.lineup[place] = p.id
	if from >= 0:
		t.lineup[from] = displaced
	else:
		var open := -1
		for j in range(PoloTeam.STARTERS, t.lineup.size()):
			if t.find_id(int(t.lineup[j])) == null:
				open = j
				break
		if open >= 0:
			t.lineup[open] = displaced
	var out: Array = [["%s STARTS NEXT GAME; %s TO THE BENCH" % [p.short_name().to_upper(), _name(c, displaced)], "info"]]
	out.append(_pend(c, ev, head, {"k": "pmw", "place": place, "displaced": displaced, "was": was, "had": had, "set": t.lineup.duplicate(),
		"label": "%s STARTS" % p.short_name().to_upper(), "reward": "WIN: TEAM 1.5X, HIM 2X / LOSE: TEAM 0.75X, HIS BAR RESET"}))
	return out

## Your seven and bench as the team would pick them (no lineup set yet).
static func default_lineup(t: PoloTeam) -> Array:
	var out: Array = t.starters().map(func(q: PoloPlayer): return q.id)
	var bench: Array = t.roster.filter(func(q: PoloPlayer): return not out.has(q.id))
	bench.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.overall() > b.overall())
	for j in PoloTeam.LINEUP_SPOTS.size() - PoloTeam.STARTERS:
		out.append((bench[j] as PoloPlayer).id if j < bench.size() else -1)
	return out

## The player PROVE ME WRONG has starting (nobody may move him before the game), or -1.
static func locked(c: Career) -> int:
	for e in c.coach_pending:
		if String(e.k) == "pmw":
			return int(e.pid)
	return -1

static func _players(c: Career, ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var p := c.team().find_id(int(id))
		if p != null:
			out.append(p)
	return out

## Event XP now, as lines.
static func _xp_now(c: Career, players: Array, xp: int) -> Array:
	return give_xp(players.filter(func(p): return p != null), xp).map(func(s): return [s, "good"])

## +`amount` (part of a GOOD grade) of HOT STAR PROGRESS, within the system's limits: it builds to
## one GOOD grade's worth at most, so it can only help a real run (HOT still takes good games).
static func _hot(p: PoloPlayer, amount: float) -> Array:
	if p == null:
		return ["", "info"]
	var before := p.heat_bonus
	p.heat_bonus = minf(1.0, p.heat_bonus + amount)
	return ["+%d%% HOT STAR PROGRESS FOR %s" % [roundi((p.heat_bonus - before) / PlayerForm.HOT_AT * 100.0), p.short_name().to_upper()], "good"]

## COLD recovery: his most recent `n` BAD grades forgiven (NORMAL), his heat as it was.
static func _forgive(p: PoloPlayer, n: int = 1) -> Array:
	if p == null:
		return ["", "info"]
	var done := 0
	for k in range(p.form.size() - 1, -1, -1):
		if done >= n:
			break
		if int(p.form[k]) == PlayerForm.BAD:
			p.form[k] = 0
			done += 1
	if done == 0:
		return ["(%s HAD NO BAD GRADE TO FORGIVE)" % p.short_name().to_upper(), "info"]
	return ["COLD RECOVERY: %s'S LAST %s FORGIVEN" % [p.short_name().to_upper(), "BAD GRADE" if done == 1 else "%d BAD GRADES" % done], "good"]

## A failed challenge's -`amount` of HOT STAR PROGRESS: only what he has (his run of grades and
## any boost, never below none), so the bar drops but a grade earned in the water stays his.
static func hot_loss(p: PoloPlayer, amount: float) -> Array:
	if p == null:
		return ["", "info"]
	var have := maxf(0.0, PlayerForm.run_score(p.form) + p.heat_bonus)
	var lost := minf(amount, have)
	if lost <= 0.0:
		return ["(%s HAD NO HOT STAR PROGRESS TO LOSE)" % p.short_name().to_upper(), "info"]
	p.heat_bonus -= lost
	return ["-%d%% HOT STAR PROGRESS FOR %s" % [_pp(lost), p.short_name().to_upper()], "bad"]

## Event XP: exactly `xp` each (no class multiplier), never past his potential. Lines to show.
static func give_xp(players: Array, xp: int) -> Array:
	var out: Array = []
	var got := 0
	var maxed: Array = []
	var tokens := 0
	for p: PoloPlayer in players:
		if Development.is_maxed(p) or p.tokens >= Development.boxes_left(p):
			maxed.append(p.short_name())
			continue
		tokens += Development.award_xp(p, xp)
		got += 1
	if players.size() == 1 and got == 1:
		out.append("%s +%d XP." % [players[0].short_name(), xp])
	elif got > 0:
		out.append("+%d XP to %d player%s." % [xp, got, "" if got == 1 else "s"])
	if tokens > 0:
		out.append("%d NEW ATTRIBUTE UPGRADE%s!" % [tokens, "" if tokens == 1 else "S"])
	if not maxed.is_empty():
		out.append("%s: fully developed, no XP." % ", ".join(maxed))
	return out

## Resets his HEATING UP (the temporary form: his streak of grades and his heat), nothing else.
## True if he had any.
static func cool(p: PoloPlayer) -> bool:
	var had := p.heat > 0 or not p.form.is_empty()
	p.heat = 0
	p.form = []
	return had

# ------------------------------------------------------------------ settling the next game
## Your team's game XP for one finished game, with whatever coaching decisions ride on it
## settled from its real result and stat lines (`lines`: {id: line}, `won`). Each settles "ok"
## (made), "fail" (missed: its failure multiplier, if it has one, on a player who played),
## "even" (normal game XP: THE LEARNING EXPERIENCE won, a LEGENDARY LEADER's win without his
## target) or "void". Each player gets ONE multiplier on his positive game XP, never two: PROVE
## ME WRONG's for everyone who played when it's on; else the biggest bonus he made (2X, 3X);
## else his failure penalty (0.75X, 0.5X). Then event XP and credits paid, HOT STAR PROGRESS
## lost, a promoted backup's bar reset on a loss, the suspensions served, the lineup put back.
## Each consequence once: it's removed from Career.coach_pending and its result saved
## (Career.coach_results). Returns Development.award_game's.
static func award_game(c: Career, t: PoloTeam, lines: Dictionary, won: bool) -> Dictionary:
	var settled: Array = []   # [e, outcome ("ok" | "fail" | "even" | "void"), note]
	var keep: Array = []
	var mults := {}
	var pmw = null
	for e in c.coach_pending:
		var pid := int(e.get("pid", -1))
		var played := lines.has(pid)
		match String(e.k):
			"chal":
				if not played:
					if bool(e.get("wait", false)) and int(e.games) + 1 < WAIT_GAMES and t.find_id(pid) != null:
						e.games = int(e.games) + 1
						keep.append(e)
						continue
					settled.append([e, "fail", "%s DIDN'T PLAY" % _name(c, pid)])
					continue
				var have := _stat(lines[pid], String(e.stat))
				settled.append([e, "ok" if have >= int(e.n) else "fail", "%s: %d OF %d" % [_name(c, pid), have, int(e.n)]])
			"result":
				var ok: bool = won if String(e.need) == "win" else not won
				var note := ("WON" if won else "LOST") + ("" if played else " (%s DIDN'T PLAY)" % _name(c, pid))
				if not ok and e.has("stat") and played:
					note = "LOST, %s: %d OF %d" % [_name(c, pid), _stat(lines[pid], String(e.stat)), int(e.n)]
				if ok and e.has("stat"):
					# the LEGENDARY LEADER: the win AND his own target
					var have := _stat(lines.get(pid, {}), String(e.stat))
					note = "WON, %s: %d OF %d" % [_name(c, pid), have, int(e.n)]
					if have < int(e.n):
						settled.append([e, "even", note])
						continue
				settled.append([e, "ok" if ok else "fail", note])
			"learn":
				if won:
					settled.append([e, "even", "WON: NORMAL GAME XP"])
				elif not played:
					settled.append([e, "fail", "LOST (%s DIDN'T PLAY)" % _name(c, pid)])
				else:
					var have := _stat(lines[pid], String(e.stat))
					settled.append([e, "ok" if have >= int(e.n) else "fail", "LOST, %s: %d OF %d" % [_name(c, pid), have, int(e.n)]])
			"team":
				settled.append([e, "ok" if won else "fail", "WON" if won else "LOST"])
			"invest":
				settled.append([e, "ok" if won else "fail", "WON" if won else "LOST"])
			"susp":
				var rep := int(e.get("rep", -1))
				settled.append([e, "ok" if lines.has(rep) else "fail", "%s %s" % [_name(c, rep), "PLAYED" if lines.has(rep) else "DIDN'T PLAY"]])
			"pmw":
				# he must really have started: in his place in the lineup, and in the water
				var started := played and t.lineup.size() > int(e.place) and int(t.lineup[int(e.place)]) == pid
				if not started:
					settled.append([e, "void", "%s DIDN'T START: THE WAGER IS VOID" % _name(c, pid)])
				else:
					pmw = e
					settled.append([e, "ok" if won else "fail", "WON" if won else "LOST"])
	# the multipliers: PROVE ME WRONG's first, for everyone who played; else one each
	if pmw != null:
		for id in lines:
			mults[int(id)] = (MULT_2X if int(id) == int(pmw.pid) else PMW_WIN) if won else PMW_LOSS
	var cands := {}   # id: [multipliers he's due]
	for s in settled:
		var e: Dictionary = s[0]
		if String(e.k) == "pmw":
			continue
		var m := 0.0
		if s[1] == "ok" and e.has("mult"):
			m = float(e.mult)
		elif s[1] == "fail" and e.has("fail_mult"):
			m = float(e.fail_mult)
		if m <= 0.0:
			continue
		var who: Array = lines.keys() if String(e.k) == "team" else [int(e.get("rep", -1)) if String(e.k) == "susp" else int(e.pid)]
		who = who.filter(func(id): return lines.has(int(id)))
		if who.is_empty():
			continue
		if pmw != null:
			s[2] = String(s[2]) + " (PROVE ME WRONG'S MULTIPLIER APPLIED INSTEAD)"
			continue
		for id in who:
			if not cands.has(int(id)):
				cands[int(id)] = []
			(cands[int(id)] as Array).append(m)
	for id in cands:
		var ms: Array = cands[id]
		var ups: Array = ms.filter(func(m): return m > 1.0)
		mults[id] = ups.max() if not ups.is_empty() else ms.min()
	var got := Development.award_game(t, lines, won, mults)
	# then what's paid after the game's XP
	for s in settled:
		var e: Dictionary = s[0]
		var res := {"eid": int(e.eid), "event": String(e.event), "title": String(e.title), "k": String(e.k), "pid": int(e.pid),
			"outcome": String(s[1]), "note": String(s[2]), "label": String(e.label), "lines": [], "shown": false, "year": c.year, "week": c.week,
			"special": bool(e.get("special", false))}
		var ln: Array = res.lines
		var ok: bool = s[1] == "ok"
		var who := int(e.pid)
		var xp0 := _xp_of(t.find_id(who))
		if e.has("stat") and lines.has(who) and not (String(e.k) == "learn" and won):
			# a statistical objective really attempted (the CHALLENGE RESULT popup's): his own line from
			# this game, the target, and each condition as it was decided
			var mine: Dictionary = lines[who]
			res["stat"] = String(e.stat)
			res["n"] = int(e.n)
			res["have"] = _stat(mine, String(e.stat))
			res["line"] = {"g": int(mine.get("g", 0)), "a": int(mine.get("a", 0)), "sv": int(mine.get("sv", 0)),
				"st": int(mine.get("st", 0)), "bl": int(mine.get("bl", 0))}
			res["won"] = won
			if String(e.k) in ["result", "learn"]:
				res["cond"] = "lose" if String(e.k) == "learn" else String(e.get("need", "win"))
		match String(e.k):
			"chal", "result", "learn":
				if ok and e.has("xp"):
					var p := t.find_id(who)
					ln.append_array(_xp_now(c, [p] if p != null else [], int(e.xp)))
				elif ok and e.has("mult"):
					ln.append(_mult_line(c, got, who, float(e.mult), "good"))
				elif s[1] == "fail" and e.has("fail_mult"):
					ln.append(_mult_line(c, got, who, float(e.fail_mult), "bad"))
				else:
					ln.append(["NORMAL GAME XP APPLIED", "info"])
				if s[1] == "fail" and e.has("hot_loss") and lines.has(who):
					ln.append(hot_loss(t.find_id(who), float(e.hot_loss)))
			"team":
				if ok:
					ln.append_array(_xp_now(c, _players(c, lines.keys()), int(e.xp)))
				else:
					var base := 0
					var xp := 0
					for id in got:
						base += int(got[id].get("base", got[id].xp))
						xp += int(got[id].xp)
					ln.append(["TEAM PENALTY: %s GAME XP (%d -> %d)" % [mx(float(e.fail_mult)), base, xp], "bad"])
			"invest":
				if ok:
					c.add_credits(int(e.coins), "COACHING EVENT")
					ln.append(["+%d CREDITS" % int(e.coins), "good"])
				else:
					ln.append(["THE %d CREDITS ARE GONE" % COINS.ripple_cost, "bad"])
			"susp":
				var g: Dictionary = got.get(int(e.rep), {})
				if ok and g.has("mult"):
					ln.append(["%s 2X GAME XP: %d -> %d XP" % [_name(c, int(e.rep)), int(g.base), int(g.xp)], "good"])
				elif ok:
					ln.append(["%s PLAYED" % _name(c, int(e.rep)), "info"])
				ln.append(["%s SERVED HIS SUSPENSION" % _name(c, int(e.pid)), "info"])
			"pmw":
				if s[1] == "void":
					ln.append(["NO BONUS, NO PENALTY", "info"])
				else:
					res["team_mult"] = PMW_WIN if ok else PMW_LOSS
					var team_xp := 0
					var team_base := 0
					for id in got:
						if int(id) != int(e.pid):
							team_xp += int(got[id].xp)
							team_base += int(got[id].get("base", got[id].xp))
					var mine: Dictionary = got.get(int(e.pid), {"xp": 0, "base": 0})
					res["team_xp"] = [team_base, team_xp]
					res["his_xp"] = [int(mine.get("base", mine.xp)), int(mine.xp)]
					if ok:
						ln.append(["TEAM BONUS: +50%% GAME XP (%d -> %d)" % [team_base, team_xp], "good"])
						ln.append(["%s BONUS: 2X GAME XP (%d -> %d)" % [_name(c, int(e.pid)), int(res.his_xp[0]), int(res.his_xp[1])], "good"])
					else:
						ln.append(["TEAM PENALTY: 0.75X GAME XP (%d -> %d)" % [team_base, team_xp], "bad"])
						ln.append(["%s: 0.75X GAME XP (%d -> %d)" % [_name(c, int(e.pid)), int(res.his_xp[0]), int(res.his_xp[1])], "bad"])
						var p := t.find_id(int(e.pid))
						var lost := 0
						if p != null:
							lost = p.xp
							p.xp = 0   # (only the bar: his levels, tokens and attributes stay)
						res["lost"] = lost
						res["need"] = Development.xp_needed(p) if p != null else 0
						ln.append(["%s'S XP BAR RESET: %d XP LOST (0 / %d)" % [_name(c, int(e.pid)), lost, int(res.need)], "bad"])
				_restore(t, e)
		if res.has("stat"):
			res["applied"] = _applied(c, t, got, e, String(s[1]), who, xp0)
		c.coach_results.append(res)
	c.coach_pending = keep
	while c.coach_results.size() > RESULTS_MAX:
		c.coach_results.pop_front()
	# suspensions served: one game off each (he didn't play it)
	for p in t.roster:
		if p.susp > 0 and not lines.has(p.id):
			p.susp -= 1
	return got

## What a multiplier came to for player `pid`: "3X GAME XP ACTIVATED: HEGEDUS 40 -> 120 XP", a
## penalty's "0.75X GAME XP: ...", or why it didn't (he didn't play, another applied instead).
static func _mult_line(c: Career, got: Dictionary, pid: int, m: float, kind: String) -> Array:
	var g: Dictionary = got.get(pid, {})
	if not got.has(pid):
		return ["%s DIDN'T PLAY: NO GAME XP%s" % [_name(c, pid), " TO MULTIPLY" if kind == "good" else ", NO PENALTY"], "info"]
	if g.has("mult") and is_equal_approx(float(g.mult), m):
		if kind == "good":
			return ["%s GAME XP ACTIVATED: %s %d -> %d XP" % [mx(m), _name(c, pid), int(g.base), int(g.xp)], "good"]
		return ["%s GAME XP: %s %d -> %d XP" % [mx(m), _name(c, pid), int(g.base), int(g.xp)], "bad"]
	if g.has("mult"):
		return ["%s'S GAME XP (%s APPLIED): %d -> %d" % [_name(c, pid), mx(float(g.mult)), int(g.base), int(g.xp)], "info"]
	return ["NORMAL GAME XP APPLIED", "info"]

## A player's development XP in all (levels included); 0 for nobody.
static func _xp_of(p: PoloPlayer) -> int:
	if p == null:
		return 0
	var out := p.xp
	for n in Development.level_index(p):
		out += Development.xp_required(n)
	return out

## What a settled statistical challenge really did to his XP (read after it's paid): {kind: "xp",
## xp} for fixed XP (0 if he's fully developed), {kind: "mult", mult, base, xp, intended} for the
## one game multiplier he got (another may have applied instead: one a game), {kind: "none"}.
static func _applied(c: Career, t: PoloTeam, got: Dictionary, e: Dictionary, outcome: String, who: int, xp0: int) -> Dictionary:
	if outcome == "ok" and e.has("xp"):
		return {"kind": "xp", "xp": _xp_of(t.find_id(who)) - xp0}
	var meant := float(e.get("mult", 0.0)) if outcome == "ok" else (float(e.get("fail_mult", 0.0)) if outcome == "fail" else 0.0)
	var g: Dictionary = got.get(who, {})
	if meant > 0.0 and g.has("mult"):
		return {"kind": "mult", "mult": float(g.mult), "base": int(g.get("base", g.xp)), "xp": int(g.xp), "intended": meant}
	return {"kind": "none"}

## The settled results the CHALLENGE RESULT popup (ChallengeShow) is for, not yet shown: a
## statistical objective really attempted (his line recorded). Never PROVE ME WRONG, wagers,
## team or win-only results, suspensions, instant rewards, or a challenge he never got to try.
static func popups(c: Career) -> Array:
	return unshown(c).filter(func(r): return is_stat_result(r))

static func is_stat_result(r: Dictionary) -> bool:
	return r.has("stat") and r.has("have") and String(r.get("k", "")) in ["chal", "learn", "result"] and String(r.get("outcome", "")) in ["ok", "fail", "even"]

static func _stat(line: Dictionary, stat: String) -> int:
	match stat:
		"ga": return int(line.get("g", 0)) + int(line.get("a", 0))
		"stbl": return int(line.get("st", 0)) + int(line.get("bl", 0))
	return int(line.get(stat, 0))

## After PROVE ME WRONG's game: the lineup as it was, if you haven't changed it since; else
## just the two put back where they were (if they're still in those places); else as you left it.
static func _restore(t: PoloTeam, e: Dictionary) -> void:
	if t.lineup == (e.get("set", []) as Array):
		t.lineup = (e.was as Array).duplicate() if bool(e.get("had", true)) else []
		return
	var place := int(e.place)
	var at := t.lineup.find(int(e.displaced))
	if place < t.lineup.size() and int(t.lineup[place]) == int(e.pid) and at >= PoloTeam.STARTERS:
		t.lineup[at] = int(e.pid)
		t.lineup[place] = int(e.displaced)
		t.sync_lineup()

## Everything still riding on a game that won't come (the season's over): undone without a
## reward or a penalty, the lineup put back, saved as void.
static func void_all(c: Career, why: String) -> void:
	for e in c.coach_pending:
		if String(e.k) == "pmw" and c.teams.has(String(e.team)):
			_restore(c.teams[String(e.team)], e)
		c.coach_results.append({"eid": int(e.eid), "event": String(e.event), "title": String(e.title), "k": String(e.k), "pid": int(e.pid),
			"outcome": "void", "note": why, "label": String(e.label), "lines": [["NO BONUS, NO PENALTY", "info"]], "shown": true, "year": c.year, "week": c.week})
	c.coach_pending = []

## Every player's development XP in all, levels included (to tell what a decision paid).
static func xp_sum(t: PoloTeam) -> int:
	var out := 0
	for p in t.roster:
		out += p.xp
		for n in Development.level_index(p):
			out += Development.xp_required(n)
	return out

## Remembers a decision just applied (the session's history, never saved): what was picked, and
## what it changed now (`before`: {wallet, xp, susp} from just before apply()).
static func note_decision(c: Career, ev: Dictionary, i: int, lines: Array, before: Dictionary) -> void:
	var p := c.team().find_id(int(ev.get("pid", -1)))
	var chs := choices_for(ev)
	decisions.append({"event": String(ev.get("id", "")), "title": String(scenario(String(ev.get("id", ""))).get("headline", "")),
		"pid": int(ev.get("pid", -1)), "name": p.short_name().to_upper() if p != null else "THE TEAM",
		"choice": String(chs[i].label) if i < chs.size() else "", "special": is_special(ev), "dev": bool(ev.get("dev", false)),
		"xp": xp_sum(c.team()) - int(before.get("xp", 0)), "credits": c.wallet() - int(before.get("wallet", 0)),
		"susp": (p.susp - int(before.get("susp", 0))) if p != null else 0,
		"lines": lines.filter(func(l): return String(l[0]) != ""), "when": "%s %s" % [c.season_label(), c.calendar_text()]})
	while decisions.size() > DECISIONS_MAX:
		decisions.pop_front()

## The settled consequences the postgame hasn't shown yet.
static func unshown(c: Career) -> Array:
	return c.coach_results.filter(func(r): return not bool(r.get("shown", false)))

## Marks every settled consequence shown (the postgame's showed them once).
static func mark_shown(c: Career) -> void:
	for r in c.coach_results:
		r["shown"] = true
