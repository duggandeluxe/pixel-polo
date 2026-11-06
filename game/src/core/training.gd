class_name Training
## The weekly practice plan: one team focus and an intensity. Practice gives every player XP
## (Development.training_xp), never attribute points: those only come from the upgrade tokens
## XP earns. A specialised focus gives more to players weaker in the attribute it works; the
## intensity scales the XP and the injury risk; RECOVERY heals every injury and gives no XP.
## The week is processed once, when it ends (Career.train_week).

const FOCI := {
	"balanced": {"name": "BALANCED"},
	"shooting": {"name": "SHOOTING"},
	"passing": {"name": "PASSING"},
	"swimming": {"name": "SWIMMING"},
	"strength": {"name": "STRENGTH"},
	"defense": {"name": "DEFENSE"},
	"recovery": {"name": "RECOVERY"},
}
const FOCUS_ORDER := ["balanced", "shooting", "passing", "swimming", "strength", "defense", "recovery"]

const INTENSITY := ["", "LIGHT", "NORMAL", "HARD"]

const RATING_CAP := 99
## An AI program takes a RECOVERY week once this many of its players are hurt.
const AI_RECOVER_AT := 2

## This week's chance of a training injury for each of your players (the intensity's risk, less
## what your medical room takes off). 0 in a RECOVERY week.
static func injury_chance(c: Career) -> float:
	if String(c.training.get("focus", "balanced")) == "recovery":
		return 0.0
	return Development.injury_risk(int(c.training.get("intensity", 2)), c.fac("medical"))

## An AI program's week, [focus, intensity]: a normal balanced week, or RECOVERY once enough of
## its players are hurt. The same XP and injury rules as yours, nothing extra.
static func ai_plan(t: PoloTeam) -> Array:
	var hurt := t.roster.filter(func(p: PoloPlayer): return p.is_injured()).size()
	return ["recovery", 2] if hurt >= AI_RECOVER_AT else ["balanced", 2]
