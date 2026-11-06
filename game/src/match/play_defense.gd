class_name PlayDefense
## Their attack in single player. It runs in a Play with `defending` set (they are its
## Side.US, attacking x = 30). The AI plays every one of your field defenders, exactly as it
## plays theirs on your attack (PlayAI marks, Play's pressure, fouls and steals); you are the
## keeper, and when they shoot you dive (KeeperDuel).

enum Zone { NONE, FRONT, SIDE, BEHIND }

const FRONT_DEG := 70.0        # between him and the goal (within this angle)...
const SIDE_DEG := 115.0        # ...at his side; past this, behind him

## Where `d` is around attacker `a`: in front of him (goal side), at his side, or behind.
static func side_of(d: Swimmer, a: Swimmer) -> int:
	if d == null or a == null:
		return Zone.NONE
	var ang := absf(rad_to_deg((Geo.goal_center() - a.pos).angle_to(d.pos - a.pos)))
	if ang <= FRONT_DEG:
		return Zone.FRONT
	if ang <= SIDE_DEG:
		return Zone.SIDE
	return Zone.BEHIND
