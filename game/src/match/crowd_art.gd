class_name CrowdArt
extends RefCounted
## THE CROWD ATMOSPHERE UPGRADES (the Premium Visual Upgrades update): what the worn level adds to
## the stands (PoolArt._stands). Level 1 is the plain crowd, everybody's. Pure art: how full the
## stands are comes from the game (attendance()), never from what you own, and nothing here
## reaches a home-pool edge or anything else the game plays with.
##   Level 2 HOME SUPPORT     fans in the home school's colours, arms up when they cheer
##   Level 3 STUDENT SECTION  a block of students in school colours bouncing together, waving
##                            flags, the school's logo on banners along the rail
##   Level 4 SOLD OUT!        + when the stands are full enough: a wave round the stands and giant
##                            flags. A quiet game stays a quiet game.
## At a neutral site the two schools share the stands, block by block.
## The SCHOOL SPIRIT PACK adds to any level: scarves, pennant strings, the mascot's banner on the
## roof, school colours round the deck, and gold pennants when the game matters.

const SECTION := 13           # columns either side of the middle: the student section
const BIG_CROWD := 0.75       # how full the stands must be for the wave and the giant flags

## How full the stands are: the program's following, and more when the game matters (`importance`
## 0 an ordinary game, 1 a big one or the conference tournament, 2 the NCSA Championship).
static func attendance(base: float, importance: int) -> float:
	return clampf(base + [0.0, 0.15, 0.35][clampi(importance, 0, 2)], 0.0, 1.0)

## What the stands look like: {lv, home, away, neutral, crowd, calm, close, big}. Level 1
## with no School Spirit: {} (the plain crowd).
static func style(lv: int, home: PoloTeam, away: PoloTeam, neutral: bool, crowd: float, calm: bool, importance := 0) -> Dictionary:
	if lv <= 1 or home == null:
		return {}
	return {"lv": lv, "home": home, "away": away, "neutral": neutral, "crowd": crowd, "calm": calm, "close": false, "big": importance >= 1}

static func sold_out(st: Dictionary) -> bool:
	return int(st.get("lv", 1)) >= 4 and float(st.get("crowd", 0.0)) >= BIG_CROWD

static func _centre(v: PoolView) -> int:
	return int(Geo.HALF * v.sx() * 0.6 / 7.0) + int(v.width / 14.0)

## Whose school a column of the stands is: the home school's, or at a neutral site by blocks.
static func _team(st: Dictionary, i: int) -> PoloTeam:
	if bool(st.neutral) and st.away != null and posmod(i, 40) >= 20:
		return st.away
	return st.home

static func in_section(st: Dictionary, i: int, v: PoolView) -> bool:
	return int(st.lv) >= 3 and absi(i - _centre(v)) <= SECTION

static func fan_colour(st: Dictionary, col: Color, seed: int, i: int, row: int, back: int, v: PoolView) -> Color:
	var tm := _team(st, i)
	if in_section(st, i, v):
		return (tm.c1 if row % 2 == 0 else tm.c2).darkened(back * 0.08)
	if int(st.lv) >= 2 and seed % 100 < 55:
		return (tm.c2 if seed % 4 == 0 else tm.c1).darkened(0.05 + back * 0.1)
	return col

## How high a fan is off his seat (px, up is negative): the students' chant, the wave.
static func fan_jump(st: Dictionary, t: float, i: int, v: PoolView) -> float:
	if bool(st.calm):
		return 0.0
	var j := 0.0
	if in_section(st, i, v):
		j = -roundf(maxf(0.0, sin(t * (8.0 if bool(st.close) else 5.0))) * (3.0 if bool(st.close) else 2.0))
	if sold_out(st):
		var span := int(v.width / 7.0) + 30
		var head := int(fposmod(t * 30.0, float(span))) + int(v.cam.x * v.sx() * 0.6 / 7.0) - 8
		if absi(i - head) <= 3:
			j = minf(j, -4.0)
	return j

## Flags, banners and giant flags, anchored to the stands (they scroll with them).
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

