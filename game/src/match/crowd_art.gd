class_name CrowdArt
extends RefCounted
## THE CROWD ATMOSPHERE UPGRADES: who is in the stands, what they wear and how they cheer
## (PoolArt._stands). Three levels; how full the stands are is the level's, not the game's:
##   Level 1 SPARSE CROWD        about a quarter of the seats: scattered fans, little groups of
##                               2-4, empty sections and rows. Ordinary casual clothes, never
##                               picked to match anyone. Mostly still; the odd small cheer.
##   Level 2 FULL CROWD          nearly every seat: half in the home school's two colours, half in
##                               the same casual clothes, mixed through the stands. Arms up on a
##                               goal, little groups celebrating, more cheering in between.
##   Level 3 MAXIMUM ATMOSPHERE  (the former Level 4 SOLD OUT!, unchanged) full stands, a student
##                               section in school colours bouncing together, flags, the school's
##                               logo on banners along the rail, a wave round the stands and giant
##                               flags.
## At a neutral site the two schools share the stands, block by block. Pure art: nothing here
## reaches a home-pool edge or anything else the game plays with.
## The stands are fixed for a match: who sits where and in what comes from the seat and the
## match's `seed` (style()), never from the clock, so only the cheering moves.
## Developer Mode: `override` (a level 1-3) shows in a real match without owning anything.

const SECTION := 13           # columns either side of the middle: the student section
const BIG_CROWD := 0.75       # how full the stands must be for the wave and the giant flags
const TOP := 3
const NAMES := ["SPARSE CROWD", "FULL CROWD", "MAXIMUM ATMOSPHERE"]
const SPARSE := 0.25          # Level 1: about how full (the pattern's own average: sparse_seat)
const FULL := 0.975           # Levels 2 and 3
const HOME_SHARE := 500       # Level 2: of every 1000 fans, this many in the home colours
## Casual clothes: what anybody wears to a game. Nobody's picked to match a school.
const CASUAL := ["d63c3c", "3a6fd8", "3fa34d", "f0c93a", "eeeeea", "2a2a2e", "8a8f98", "27355e",
	"7a2433", "e9792f", "2f9e9a", "7a5236", "e07aa8", "7e57c2", "8fc3ef", "7d8a3a"]

## Developer Mode's live preview (the pause menu's CROWD button): never saved, never owned.
static var override := 0

## How full the stands are for the game itself (the plain crowd, with no Crowd Atmosphere level:
## the tutorial, multiplayer): the program's following, and more when the game matters
## (`importance` 0 an ordinary game, 1 a big one or the conference tournament, 2 the NCSA Championship).
static func attendance(base: float, importance: int) -> float:
	return clampf(base + [0.0, 0.15, 0.35][clampi(importance, 0, 2)], 0.0, 1.0)

## The level a match shows: Developer Mode's override, else the level worn.
static func level_for(worn: int) -> int:
	if override > 0 and bool(Game.settings.get("dev_mode", false)):
		return clampi(override, 1, TOP)
	return clampi(worn, 1, TOP)

## What the stands look like: {lv, home, away, neutral, crowd, calm, close, big, seed}. `crowd` is
## the level's fill (the game's own `crowd` is ignored: the level decides). {} without a home team
## (the plain crowd). `seed` fixes who sits where for the match.
static func style(lv: int, home: PoloTeam, away: PoloTeam, neutral: bool, _crowd: float, calm: bool, importance := 0, seed := 0) -> Dictionary:
	if home == null:
		return {}
	lv = clampi(lv, 1, TOP)
	return {"lv": lv, "home": home, "away": away, "neutral": neutral, "crowd": SPARSE if lv == 1 else FULL,
		"calm": calm, "close": false, "big": importance >= 1, "seed": seed}

## The wave and the giant flags: Level 3, with the stands full.
static func sold_out(st: Dictionary) -> bool:
	return int(st.get("lv", 1)) >= 3 and float(st.get("crowd", 0.0)) >= BIG_CROWD

static func _centre(v: PoolView) -> int:
	return int(Geo.HALF * v.sx() * 0.6 / 7.0) + int(v.width / 14.0)

## A seat's fixed draw, 0..999, from the seat (column `a`, row `b`) and the match's seed `s`.
static func _h(a: int, b: int, s: int) -> int:
	var x := (a * 73856093) ^ (b * 19349663) ^ (s * 83492791)
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return (x & 0x7fffffff) % 1000

## Whose school a column of the stands is: the home school's, or at a neutral site by blocks.
static func _team(st: Dictionary, i: int) -> PoloTeam:
	if bool(st.neutral) and st.away != null and posmod(i, 40) >= 20:
		return st.away
	return st.home

static func in_section(st: Dictionary, i: int, v: PoolView) -> bool:
	return int(st.lv) >= 3 and absi(i - _centre(v)) <= SECTION

## Is seat (column `i`, row `row`) taken?
static func seated(st: Dictionary, i: int, row: int) -> bool:
	var sd := int(st.get("seed", 0))
	if int(st.lv) <= 1:
		return sparse_seat(sd, i, row)
	return _h(i, row, sd) >= int((1.0 - FULL) * 1000.0)

## Level 1: sections of 10 columns, some empty, some rows of a section empty; in the rest the odd
## fan alone and little groups of 2-4 together, more in some sections than others.
static func sparse_seat(sd: int, i: int, row: int) -> bool:
	var blk := floori(i / 10.0)
	var pull := _h(blk, 101, sd)
	if pull < 200:
		return false                        # an empty section
	if _h(blk, row + 211, sd) < 180:
		return false                        # a row empty in this section
	var w := 0.6 + pull / 1000.0             # (0.8 .. 1.6: a busier section or a quieter one)
	if _h(i, row + 307, sd) < int(135.0 * w):
		return true                         # a fan on their own
	for back in 4:                          # a group of 2-4 that starts here or just before
		var j := i - back
		if _h(j, row + 409, sd) < int(90.0 * w) and 2 + _h(j, row + 601, sd) % 3 > back:
			return true
	return false

## A fan's shirt. `col` is the plain crowd's (PoolArt.CROWD), kept by Level 3 for its neutral fans.
static func fan_colour(st: Dictionary, col: Color, seed: int, i: int, row: int, back: int, v: PoolView) -> Color:
	var lv := int(st.lv)
	if lv >= 3:   # (the former SOLD OUT!, as it was)
		var tm := _team(st, i)
		if in_section(st, i, v):
			return (tm.c1 if row % 2 == 0 else tm.c2).darkened(back * 0.08)
		if seed % 100 < 55:
			return (tm.c2 if seed % 4 == 0 else tm.c1).darkened(0.05 + back * 0.1)
		return col
	var sd := int(st.get("seed", 0))
	if lv == 2 and _h(i, row + 503, sd) < HOME_SHARE:
		var tm2 := _team(st, i)
		return (tm2.c1 if _h(i, row + 701, sd) < 500 else tm2.c2).darkened(0.05 + back * 0.1)
	return casual(sd, i, row).darkened(0.1 + back * 0.1)

## A neutral fan's clothes: one of CASUAL, by the seat.
static func casual(sd: int, i: int, row: int) -> Color:
	return Color(CASUAL[_h(i, row + 809, sd) % CASUAL.size()])

## Is fan (i, row) a home-team fan at Level 2? (For checks: fan_colour decides.)
static func home_fan(st: Dictionary, i: int, row: int) -> bool:
	return int(st.lv) == 2 and _h(i, row + 503, int(st.get("seed", 0))) < HOME_SHARE

## How high a fan is off the seat (px, up is negative), from a goal's `excite` (0..1+) and the
## level's own cheering. Arms go up (PoolArt) at Level 2 and up when it's past a pixel.
static func fan_jump(st: Dictionary, t: float, i: int, v: PoolView, row := 0, seed := 0, excite := 0.0) -> float:
	var lv := int(st.lv)
	var sd := int(st.get("seed", 0))
	var calm := bool(st.calm)
	var j := 0.0
	match lv:
		1:   # a few react to a goal, a little; now and then one cheers on their own
			if excite > 0.0 and _h(i, row + 907, sd) < 300:
				j = -roundf(absf(sin(t * 13.0 + seed)) * 2.0 * excite)
			if not calm and _h(i, row + 911, sd) < 250 and fposmod(t / 6.0 + _h(i, row + 913, sd) / 1000.0, 1.0) < 0.05:
				j = minf(j, -1.0)
		2:   # everybody on a goal, little groups of them higher; cheering between goals
			if excite > 0.0:
				j = -roundf(absf(sin(t * 13.0 + seed)) * 3.0 * excite)
				if _h(floori(i / 5.0), floori(row / 2.0) + 919, sd) < 350:
					j = minf(j, -roundf(absf(sin(t * 16.0 + floori(i / 5.0))) * 4.0 * excite))
			if not calm and _h(i, row + 923, sd) < 400 and fposmod(t / 4.0 + _h(i, row + 929, sd) / 1000.0, 1.0) < 0.08:
				j = minf(j, -2.0)
		_:   # the former SOLD OUT!: the students' chant, the wave
			if excite > 0.0:
				j = -roundf(absf(sin(t * 13.0 + seed)) * 3.0 * excite)
			if calm:
				return j
			if in_section(st, i, v):
				j = minf(j, -roundf(maxf(0.0, sin(t * (8.0 if bool(st.close) else 5.0))) * (3.0 if bool(st.close) else 2.0)))
			if sold_out(st):
				var span := int(v.width / 7.0) + 30
				var head := int(fposmod(t * 30.0, float(span))) + int(v.cam.x * v.sx() * 0.6 / 7.0) - 8
				if absi(i - head) <= 3:
					j = minf(j, -4.0)
	return j

## Do this level's fans put their arms up when they're off their seats?
static func arms(st: Dictionary) -> bool:
	return int(st.lv) >= 2

## The share of seats taken in a stretch of the stands (Developer Mode's density check).
static func fill_of(st: Dictionary, cols := 400, rows := 6) -> float:
	var n := 0
	for row in rows:
		for i in cols:
			if seated(st, i, row):
				n += 1
	return float(n) / float(cols * rows)

## Flags, banners and giant flags, anchored to the stands (they scroll with them): Level 3.
static func draw_extras(ci: CanvasItem, v: PoolView, t: float, size: Vector2, st: Dictionary, top: float, bottom: float, scroll: float) -> void:
	var lv := int(st.lv)
	if lv < 3:
		return
	var wave := 0 if bool(st.calm) else int(t * 6.0) % 2
	# banners on the rail
	var step := 112.0
	var x := -fposmod(scroll, step)
	var n := int(floorf(scroll / step))
	while x < size.x:
		var tm := _team(st, n * 16)
		ci.draw_rect(Rect2(x + 6, bottom - 11, 30, 13), tm.c1)
		ci.draw_rect(Rect2(x + 6, bottom - 11, 30, 1), tm.c2)
		TeamLogo.draw_in(ci, Rect2(x + 11, bottom - 10, 20, 12), tm)
		x += step
		n += 1
	# flags in the section and along the stands
	var fstep := 56.0
	var fx := -fposmod(scroll + 28.0, fstep)
	var k := int(floorf((scroll + 28.0) / fstep))
	while fx < size.x:
		var tm2 := _team(st, k * 8)
		var y := top - 4.0
		ci.draw_rect(Rect2(fx, y, 1, 14), Color("c9d3dd"))
		ci.draw_rect(Rect2(fx + 1, y + wave, 7, 3), tm2.c1)
		ci.draw_rect(Rect2(fx + 1, y + 3 + wave, 7, 2), tm2.c2)
		fx += fstep
		k += 1
	if not sold_out(st):
		return
	# giant flags with the school's logo, swaying
	var gstep := 168.0
	var gx := -fposmod(scroll + 84.0, gstep)
	var g := int(floorf((scroll + 84.0) / gstep))
	while gx < size.x:
		var tm3 := _team(st, g * 24)
		var sway := 0.0 if bool(st.calm) else roundf(sin(t * 2.5 + g) * 2.0)
		ci.draw_rect(Rect2(gx, top - 12, 1, 24), Color("c9d3dd"))
		ci.draw_rect(Rect2(gx + 1, top - 12 + sway, 26, 16), tm3.c1)
		ci.draw_rect(Rect2(gx + 1, top - 12 + sway, 26, 2), tm3.c2)
		TeamLogo.draw_in(ci, Rect2(gx + 4, top - 10 + sway, 20, 12), tm3)
		gx += gstep
		g += 1
