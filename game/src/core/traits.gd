class_name Traits
## One trait for one of the best players, for the attribute he's maxed out, worked out from his
## attributes alone (so a save can always fill them in the same way). Each one changes a small thing in a match.
## (No trait is about his hand: the old LEFTY SNIPER is gone with the Position Identity update,
## no lefty gets a bonus. A save's is worked out again on load: PoloPlayer.from_dict.)

const ALL := {
	"cannon": {"name": "CANNON", "text": "Shoots harder than anyone: faster shots, and a full pull costs him half the accuracy."},
	"ice": {"name": "ICE", "text": "Ice in his veins: sharper with the shot clock running out, and in the last minute."},
	"wrestler": {"name": "WRESTLER", "text": "Wins the fight on 2 m: draws more exclusions as a center, gives fewer away guarding one."},
	"ball_hawk": {"name": "BALL HAWK", "text": "Reads passes: reaches further for them and picks off more."},
	"playmaker": {"name": "PLAYMAKER", "text": "Zips passes: they get there faster and are harder to pick off."},
	"jet": {"name": "JET", "text": "The fastest man in the water, and in the sprint."},
	"wall": {"name": "WALL", "text": "A keeper who fills the goal: more saves."},
}
## Only the best get one: OVERALL at least this (0-10)...
const MIN_OVR := 9.25
## ...and the attribute the trait is about maxed out (or as near as makes no difference).
const STANDOUT := 9.9
## JET is about swimming, which isn't one of the four (PoloPlayer.speed, 0-100, as it always was):
## this fast, or JET_GOOD fast and one of the best.
const JET_ANY := 84
const JET_GOOD := 82

## The trait this player's attributes earn, or "". A quick-match club's player (PoloPlayer.pro)
## by his 0-100 ratings, as before 2.0.
static func best_for(p: PoloPlayer) -> String:
	if p.pro:
		return _pro_best_for(p)
	if p.attrs.is_empty():
		return ""
	var o := p.rating10()
	if p.is_keeper():
		return "wall" if o >= MIN_OVR and p.attr("blk") >= STANDOUT else ""
	if o < MIN_OVR:
		return "jet" if p.speed >= JET_ANY else ""
	if p.is_keeper():
		return "wall" if p.attr("blk") >= STANDOUT else ""
	var sho := p.attr("sho")
	var scores := {}
	if sho >= STANDOUT:
		scores["cannon"] = 1.0 + (p.attr("str") - 5.0) * 0.1
		scores["ice"] = 0.5
	if p.pos in [PoloPlayer.Pos.CENTER, PoloPlayer.Pos.DEFENDER] and p.attr("str") >= STANDOUT:
		scores["wrestler"] = 1.5
	if p.attr("dfn") >= STANDOUT:
		scores["ball_hawk"] = 0.8
	if p.attr("pas") >= STANDOUT:
		scores["playmaker"] = 0.8
	if p.speed >= JET_GOOD:
		scores["jet"] = (p.speed - JET_GOOD) * 0.25 + 0.5
	var best := ""
	for id in ALL:   # ALL's order breaks ties
		if scores.has(id) and (best == "" or float(scores[id]) > float(scores[best])):
			best = id
	return best

## A quick-match club's trait, from his 0-100 ratings: the good ones (overall 71) or anyone with
## one rating at 84.
static func _pro_best_for(p: PoloPlayer) -> String:
	var ovr := roundi(p.legacy_overall())
	if p.is_keeper():
		return "wall" if p.keeping >= 80 and (ovr >= 71 or p.keeping >= 84) else ""
	var top := 0
	for k in p.legacy_keys():
		top = maxi(top, p.rating(k))
	if ovr < 71 and top < 84:
		return ""
	var scores := {}
	if p.shoot >= 82:
		scores["cannon"] = p.shoot - 82 + 1.0
	if p.shoot >= 78:
		scores["ice"] = (p.shoot - 78) * 0.5
	if p.pos in [PoloPlayer.Pos.CENTER, PoloPlayer.Pos.DEFENDER] and p.strength >= 80:
		scores["wrestler"] = p.strength - 80 + 1.0
	if p.defense >= 80:
		scores["ball_hawk"] = p.defense - 80 + 0.5
	if p.passing >= 80:
		scores["playmaker"] = p.passing - 80 + 0.5
	if p.speed >= 82:
		scores["jet"] = p.speed - 82 + 0.5
	var best := ""
	for id in ALL:
		if scores.has(id) and (best == "" or float(scores[id]) > float(scores[best])):
			best = id
	return best

static func has(p: PoloPlayer, id: String) -> bool:
	return p != null and p.trait_id == id

static func title(id: String) -> String:
	return String(ALL[id].name) if ALL.has(id) else ""

static func text(id: String) -> String:
	return String(ALL[id].text) if ALL.has(id) else ""

## What the shooter's trait does to a shot: {speed, spread, full_spread} for ShotModel, and
## `skill` to add to his shooting. `from`: where he shoots from; `clutch`: shot clock nearly
## out or the last minute of the game.
static func shot_mods(shooter: PoloPlayer, from: Vector2, clutch: bool) -> Dictionary:
	var m := {"speed": 1.0, "spread": 1.0, "full_spread": 1.0, "skill": 0.0}
	match shooter.trait_id:
		"cannon":
			m.speed = 1.12
			m.full_spread = 0.5
		"ice":
			if clutch:
				m.skill = 10.0
	return m
