class_name PlayerEdit
## PIXEL POLO +'S EDIT PLAYER: a player's name and cap number, and nothing else: no position,
## rating, potential, age, development, form, XP, recruiting value, eligibility or statistic is
## ever touched, and his id stays, so he's the same man. Only your own roster (the profile only
## offers it there). His name is read live almost everywhere; what was written down as text
## (his awards and the records he set in this dynasty) is updated here. The historical book isn't
## his to change, so a mark from before the dynasty is left alone.

const NAME_MAX := 12
const NUMBER_RANGE := Vector2i(1, 99)
const KEEPER_CAPS := [1, 13, 21]   # the keepers' caps, and only theirs (PoloTeam.free_number)

## Why this name and number can't be saved ("" if they can).
static func check(team: PoloTeam, p: PoloPlayer, first: String, last: String, number: int) -> String:
	if first.strip_edges() == "" or last.strip_edges() == "":
		return "ENTER A FIRST AND LAST NAME"
	if first.strip_edges().length() > NAME_MAX or last.strip_edges().length() > NAME_MAX:
		return "NAMES ARE %d LETTERS AT MOST" % NAME_MAX
	if number < NUMBER_RANGE.x or number > NUMBER_RANGE.y:
		return "CAP NUMBERS ARE 1 TO 99"
	if p.is_keeper() and not number in KEEPER_CAPS:
		return "KEEPERS WEAR 1, 13 OR 21"
	if not p.is_keeper() and number in KEEPER_CAPS:
		return "1, 13 AND 21 ARE KEEPERS' CAPS"
	for q: PoloPlayer in team.roster:
		if q != p and q.number == number:
			return "#%d IS TAKEN BY %s" % [number, q.last.to_upper()]
	return ""

## Saves them on `p`, on the team `c` coaches, or says why not. A player who isn't on it: refused.
static func apply(c: Career, p: PoloPlayer, first: String, last: String, number: int) -> String:
	if not c.team().roster.has(p):
		return "ONLY YOUR OWN PLAYERS"
	var why := check(c.team(), p, first, last, number)
	if why != "":
		return why
	var old_full := "%s %s" % [p.first, p.last]
	var old_short := Records.holder(p)
	p.first = first.strip_edges()
	p.last = last.strip_edges()
	p.number = number
	_rewrite(c, p, old_full, old_short)
	return ""

## The text the dynasty wrote about him.
static func _rewrite(c: Career, p: PoloPlayer, old_full: String, old_short: String) -> void:
	var full := "%s %s" % [p.first, p.last]
	for list: Array in [c.conf_awards, c.tourney_awards]:
		for a in list:
			if int(a.get("pid", 0)) == p.id:
				a["name"] = full
	for a in c.awards:
		if int(a.get("pid", 0)) == p.id or (not a.has("pid") and String(a.get("name", "")) == old_full and String(a.get("team", "")) == c.school):
			a["name"] = full
	var books: Array = [c.records.ncsa]
	books.append_array((c.records.school as Dictionary).values())
	for book: Dictionary in books:
		for k in book:
			var m: Dictionary = book[k]
			# (a dynasty's year is its season label, "2026-27"; a historical one is a number)
			if String(m.get("name", "")) == old_short and String(m.get("team", "")) == c.school and str(m.get("year", "")).contains("-"):
				m["name"] = Records.holder(p)
	if c.award_players.has(str(p.id)):
		c.award_players[str(p.id)] = JSON.stringify(p.to_dict())
