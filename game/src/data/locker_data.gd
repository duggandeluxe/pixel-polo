class_name LockerData
extends RefCounted
## Effect chips for the hub's event cards (Moments). (The locker room that
## once followed every game, with its team talks, is gone: the POSTGAME REVIEW and the coaching
## events, Postgame and CoachEvents, took its place.)
## Effects are Career.apply_effects() entries: {t, v, target?, key?}. Types:
## train_boost (next week's training, a fraction),
## rep (coach rep), credits (a cost: never a payment), rating (a player's rating), injure,
## and chance {p, win, win_text, lose, lose_text}. target "player" means the one the
## choice is about; otherwise it's the whole team.

## Short labels for an effect list: ["+30 XP (him)", "+8% training next wk", ...]
static func chips(effects: Array) -> Array:
	var out := []
	for e in effects:
		var who: String = " (him)" if e.get("target", "team") == "player" else ""
		match String(e.t):
			"train_boost":
				out.append("%+d%% training next wk" % int(round(float(e.v) * 100)))
			"rep":
				out.append("%+d coach rep" % int(e.v))
			"credits":
				out.append(CreditCoin.tag(int(e.v), true))
			"rating":
				out.append("+%d XP%s" % [int(e.v) * Development.CARD_XP_PER_POINT, who])
			"injure":
				out.append("%s injury%s" % ["minor" if int(e.v) <= 1 else "moderate", who])
			"chance":
				out.append("%d%%: %s, else %s" % [int(round(float(e.p) * 100)), " ".join(chips(e.win)), " ".join(chips(e.lose))])
	return out
