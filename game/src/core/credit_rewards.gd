class_name CreditRewards
## COACHING CREDITS EARNED (the Credit Economy update): these are the only things in a career that
## pay credits. Nothing else does: no gate, no awards, no records, no events, no PRO bonus.
## (Bought credits, the store's packs, are the Vault's: not earned, and untouched here.)
##
##   a REGULAR-SEASON game (game_lines): a win +3; and for a win the best ranking bonus that
##   applies, never more than one (the No. 1 team +8, else a Top 5 team +5, else a team ranked
##   above you +3, all from the poll out before the game); won by 5+ goals +2; a shutout +3.
##   A loss pays nothing. Playoff games pay through the achievements instead.
##   ACHIEVEMENTS (season_lines), once a season each, the moment they're reached.
##   THE NEW SEASON: +15 as it starts (season_start), the first season of a career too.
##
## Every payment is claimed first under an id (Career.cr_claims, saved: "2026:start",
## "2026:streak5", "2026:g:3:CULA:USC:2"), so nothing pays twice: not a reopened summary, not a
## reload, not a check run again. Credits have no cap and never expire.

const WIN := 3
const BEAT_HIGHER := 3
const BEAT_TOP5 := 5
const BEAT_NO1 := 8
const TOP5 := 5
const MARGIN := 2
const MARGIN_BY := 5
const SHUTOUT := 3
const SEASON_START := 15

## The season's achievements: [id, credits, label], in the order they're checked.
const ACHIEVEMENTS := [
	["streak5", 5, "5-GAME WIN STREAK"],
	["streak10", 8, "10-GAME WIN STREAK"],
	["undefeated", 15, "UNDEFEATED REGULAR SEASON"],
	["conf_final", 8, "REACHED CONFERENCE FINAL"],
	["conf_champ", 15, "CONFERENCE CHAMPIONS"],
	["nat_bid", 8, "NCSA TOURNAMENT BID"],
	["nat_semi", 8, "REACHED NCSA SEMIFINALS"],
	["nat_final", 8, "REACHED NCSA FINAL"],
	["nat_champ", 23, "NATIONAL CHAMPIONS"],
	["d3_bid", 8, "NCSA DIVISION III BID"],
	["d3_final", 8, "REACHED DIVISION III FINAL"],
	["d3_champ", 23, "DIVISION III NATIONAL CHAMPIONS"],
]

## What game `g` (yours, finished, in round `r`) earns: [[label, credits], ...], before anything
## is paid. `ranks` is the poll before the game (id -> 1..30). Changes nothing.
static func game_lines(c: Career, g: Dictionary, r: Dictionary, ranks: Dictionary) -> Array:
	if g.r == null or Schedule.is_playoff(r) or Schedule.winner(g) != c.school:
		return []
	var home: bool = g.h == c.school
	var opp: String = g.a if home else g.h
	var s: Array = g.r.s
	var mine := int(s[0] if home else s[1])
	var theirs := int(s[1] if home else s[0])
	var so: Array = g.r.get("so", [])
	var out: Array = [["WIN", WIN]]
	var me_rank := int(ranks.get(c.school, 0))
	var opp_rank := int(ranks.get(opp, 0))
	if opp_rank == 1:
		out.append(["BEAT THE NO. 1 TEAM", BEAT_NO1])
	elif opp_rank > 0 and opp_rank <= TOP5:
		out.append(["BEAT A TOP 5 TEAM", BEAT_TOP5])
	elif opp_rank > 0 and me_rank > 0 and opp_rank < me_rank:
		out.append(["UPSET VICTORY", BEAT_HIGHER])
	if mine - theirs >= MARGIN_BY:
		out.append(["WIN BY %d+" % MARGIN_BY, MARGIN])
	if theirs == 0 and (so.is_empty() or int(so[1] if home else so[0]) == 0):
		out.append(["SHUTOUT", SHUTOUT])
	return out

## The poll out now, as id -> rank (the team ratings' order before the first poll).
static func ranks_now(c: Career) -> Dictionary:
	var poll := Poll.latest(c)
	return Poll.rank_map(poll if not poll.is_empty() else {"ranks": Poll.hierarchy(c.teams)})

## Pays game `g`'s credits once (`ranks`: the poll before it). Returns the lines paid ([] if
## nothing, or already paid).
static func pay_game(c: Career, g: Dictionary, r: Dictionary, ranks: Dictionary) -> Array:
	var id := "%d:g:%d:%s:%s:%d" % [c.year, c.week, String(g.h), String(g.a), int(g.get("d", 0))]
	if g.get("cr", false) or id in c.cr_claims:
		return []
	g["cr"] = true
	c.cr_claims.append(id)
	var lines := game_lines(c, g, r, ranks)
	for ln in lines:
		c.add_credits(int(ln[1]), String(ln[0]))
	return lines

## The season's achievements reached and not yet paid: pays each once. Returns the lines paid.
static func season_lines(c: Career) -> Array:
	var out: Array = []
	if c.phase != "season" or c.schedule.is_empty():
		return out
	var run := best_streak(c)
	var row: Dictionary = c.table.get(c.school, Schedule.empty_row())
	var reached := {
		"streak5": run >= 5,
		"streak10": run >= 10,
		"undefeated": c._regular_done() and int(row.l) == 0 and int(row.w) > 0,
		"conf_final": c._reached("conf_final"),
		"conf_champ": c.school in c.season.get("conf_champs", []),
		"nat_bid": c.school in c.season.get("nat_seeds", []),
		"nat_semi": c._reached("nat_sf"),
		"nat_final": c._reached("nat_final"),
		"nat_champ": _won_round(c, "nat_final"),
		"d3_bid": c.school in c.season.get("d3_seeds", []),
		"d3_final": c.school in [Schedule.d3_game(c.schedule, "d3_final").get("h", ""), Schedule.d3_game(c.schedule, "d3_final").get("a", "")],
		"d3_champ": Schedule.d3_game(c.schedule, "d3_final").get("r") != null and Schedule.winner(Schedule.d3_game(c.schedule, "d3_final")) == c.school,
	}
	for a in ACHIEVEMENTS:
		if bool(reached[a[0]]) and claim(c, String(a[0])):
			c.add_credits(int(a[1]), String(a[2]))
			out.append([String(a[2]), int(a[1])])
	return out

## +15 for the season that's starting, once.
static func season_start(c: Career) -> int:
	if not claim(c, "start"):
		return 0
	c.add_credits(SEASON_START, "NEW SEASON", false)   # (automatic: spends like any yellow, never exchanges)
	return SEASON_START

## Claims this season's `key` (`year:key`): true the first time only.
static func claim(c: Career, key: String) -> bool:
	var id := "%d:%s" % [c.year, key]
	if id in c.cr_claims:
		return false
	c.cr_claims.append(id)
	return true

## Your longest run of wins this season so far (every game you've played, playoffs too).
static func best_streak(c: Career) -> int:
	var best := 0
	var run := 0
	for r in c.schedule:
		for g in c.my_games(r):
			if g.r == null:
				continue
			if Schedule.winner(g) == c.school:
				run += 1
				best = maxi(best, run)
			else:
				run = 0
	return best

## Did you win round `kind`'s game?
static func _won_round(c: Career, kind: String) -> bool:
	for r in c.schedule:
		if String(r.kind) != kind:
			continue
		for g in c.my_games(r):
			if g.r != null and Schedule.winner(g) == c.school:
				return true
	return false

## Lines as text prints them: "WIN: +3" and the coin (CreditCoin.TAG).
static func text(lines: Array) -> Array:
	return lines.map(func(ln): return "%s: %s" % [String(ln[0]), CreditCoin.tag(int(ln[1]), true)])

static func total(lines: Array) -> int:
	var n := 0
	for ln in lines:
		n += int(ln[1])
	return n

## Claims from seasons long gone are dropped (they can never match again): this one and last.
static func prune(c: Career) -> void:
	c.cr_claims = c.cr_claims.filter(func(id): return int(String(id).get_slice(":", 0)) >= c.year - 1)
