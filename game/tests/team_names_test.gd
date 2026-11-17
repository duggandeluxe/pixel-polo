extends RefCounted
## The October 2026 team-name update ("College Water Polo | Team Name Update"): every school
## shows a location-based name ("CULA Bears" -> "Los Angeles Bears") and nothing else changes.
## Ids, colours, logos, ratings, rosters and conferences stay as they were; old saves load with
## the new names; the long names fit the screens.
##   godot --headless --path game -- --test names

## Where room is short (the scoreboard): the place, or the whole name for the three in Los Angeles.
const SHORT := {
	"CULA": "Los Angeles Bears", "CUSC": "Los Angeles Spartans", "LMMU": "Los Angeles Mountain Lions",
	"STAM": "Pacific Grove", "ALC": "Bayview", "FORDU": "Bronx", "SJCU": "San Jose", "LBSC": "Long Beach",
	"CUSD": "San Diego", "PRIN": "New Jersey", "PPCU": "Malibu", "UCDS": "Davis", "ICU": "Irvine",
	"CRBU": "Riverside", "UPAC": "Stockton", "HVRD": "Cambridge", "CCSB": "Santa Barbara", "NANA": "Annapolis",
	"BROW": "Providence", "GWU": "Washington", "SCCU": "Santa Clara", "USAF": "Colorado Springs",
	"SMCC": "Moraga", "CSFU": "Fullerton", "BUCK": "Lewisburg", "WAGN": "Staten Island", "MSMU": "Emmitsburg",
	"IONA": "New Rochelle", "LIUB": "Brooklyn", "HURST": "Erie",
}

## The new display names, exactly as the update lists them.
const NAMES := {
	"CULA": "Los Angeles Bears", "CUSC": "Los Angeles Spartans", "STAM": "Pacific Grove Redwoods",
	"ALC": "Bayview Golden Grizzlies", "FORDU": "Bronx Lambs", "SJCU": "San Jose Warriors",
	"LBSC": "Long Beach Barracudas", "CUSD": "San Diego Sea Kings", "PRIN": "New Jersey Bengals",
	"PPCU": "Malibu Breakers", "UCDS": "Davis Mustangs", "ICU": "Irvine Aardvarks",
	"CRBU": "Riverside Knights", "LMMU": "Los Angeles Mountain Lions", "UPAC": "Stockton Scorpions",
	"HVRD": "Cambridge Redhawks", "CCSB": "Santa Barbara Bulls", "NANA": "Annapolis Mariners",
	"BROW": "Providence Grizzlies", "GWU": "Washington Sentinels", "SCCU": "Santa Clara Stallions",
	"USAF": "Colorado Springs Skyhawks", "SMCC": "Moraga Highlanders", "CSFU": "Fullerton Mammoths",
	"BUCK": "Lewisburg Buffalo", "WAGN": "Staten Island Hawks", "MSMU": "Emmitsburg Highlanders",
	"IONA": "New Rochelle Irish", "LIUB": "Brooklyn Hammerheads", "HURST": "Erie Lakehawks",
}

## Every school as it was before the update: [old name, mascot, c1, c2, c3, conference, OVR,
## OFF, DEF, prestige, logo mark, logo style]. All but the name must still match. (The Redwoods'
## and Golden Grizzlies' marks are their November 2026 rebrand's: PG and BV; the Bengals', NJ.) Stockton and
## Washington keep their ids, marks and ratings under new mascots (Scorpions, Sentinels).
const BEFORE := {
	"CULA": ["CULA Bears", "Bears", "2d68c4", "f2a900", "", "MPSF", 91, 90, 92, 90, "LA", "interlock"],
	"CUSC": ["CUSC Spartans", "Spartans", "990000", "ffc72c", "", "MPSF", 90, 92, 88, 88, "SC", "interlock"],
	"STAM": ["STAM Redwoods", "Redwoods", "8c1515", "ffffff", "", "MPSF", 89, 87, 91, 86, "PG", "interlock"],
	"ALC": ["ALC Golden Grizzlies", "Golden Grizzlies", "003262", "fdb515", "", "MPSF", 88, 90, 86, 84, "BV", "interlock"],
	"LBSC": ["LBSC Barracudas", "Barracudas", "111111", "ffc72a", "", "BIGWEST", 82, 84, 80, 71, "LB", "interlock"],
	"CUSD": ["CUSD Sea Kings", "Sea Kings", "182b49", "c69214", "", "BIGWEST", 81, 80, 82, 69, "SD", "interlock"],
	"ICU": ["ICU Aardvarks", "Aardvarks", "0064a4", "ffd200", "", "BIGWEST", 78, 77, 79, 63, "I", "circle"],
	"CRBU": ["CRBU Knights", "Knights", "002d62", "c5a253", "", "BIGWEST", 77, 79, 75, 61, "R", "shield"],
	"CCSB": ["CCSB Bulls", "Bulls", "003660", "febc11", "", "BIGWEST", 75, 75, 75, 57, "SB", "interlock"],
	"CSFU": ["CSFU Mammoths", "Mammoths", "00274c", "ff7900", "ffffff", "BIGWEST", 70, 72, 68, 47, "F", "angled"],
	"SJCU": ["SJCU Warriors", "Warriors", "0055a2", "e5a823", "", "WCC", 83, 81, 85, 73, "SJ", "interlock"],
	"PPCU": ["PPCU Breakers", "Breakers", "00205c", "e35205", "", "WCC", 79, 81, 77, 65, "P", "circle"],
	"UCDS": ["UCDS Mustangs", "Mustangs", "022851", "ffbf00", "", "WCC", 78, 76, 80, 63, "D", "shield"],
	"LMMU": ["LMMU Mountain Lions", "Mountain Lions", "a6192e", "00205b", "", "WCC", 77, 78, 76, 61, "L", "angled"],
	"UPAC": ["UPAC Bengals", "Scorpions", "f47920", "121212", "", "WCC", 76, 76, 76, 59, "P", "angled"],
	"SCCU": ["SCCU Stallions", "Stallions", "b30738", "ffffff", "", "WCC", 72, 72, 72, 51, "S", "circle"],
	"USAF": ["USAF Skyhawks", "Skyhawks", "003594", "b2b4b2", "", "WCC", 71, 74, 68, 49, "AF", "interlock"],
	"SMCC": ["SMCC Highlanders", "Highlanders", "d80024", "06315b", "", "WCC", 70, 70, 70, 47, "M", "angled"],
	"FORDU": ["FORDU Lambs", "Lambs", "860038", "ffffff", "", "MAWPC", 86, 88, 84, 80, "F", "block"],
	"NANA": ["NANA Mariners", "Mariners", "00205b", "c5b783", "", "MAWPC", 74, 76, 72, 55, "N", "block"],
	"GWU": ["GWU Patriots", "Sentinels", "e4cc94", "033c5a", "", "MAWPC", 73, 72, 74, 53, "GW", "interlock"],
	"BUCK": ["BUCK Buffalo", "Buffalo", "e87722", "003865", "", "MAWPC", 69, 69, 69, 44, "B", "block"],
	"WAGN": ["WAGN Hawks", "Hawks", "006747", "ffffff", "", "MAWPC", 68, 70, 66, 42, "W", "block"],
	"MSMU": ["MSMU Highlanders", "Highlanders", "003a70", "ffffff", "", "MAWPC", 67, 67, 67, 40, "M", "shield"],
	"HURST": ["HURST Lakehawks", "Lakehawks", "00573f", "ffffff", "", "MAWPC", 62, 63, 61, 30, "H", "circle"],
	"PRIN": ["PRIN Bengals", "Bengals", "e77500", "121212", "", "NWPC", 80, 82, 78, 67, "NJ", "interlock"],
	"HVRD": ["HVRD Redhawks", "Redhawks", "a51c30", "ffffff", "", "NWPC", 76, 77, 75, 59, "H", "shield"],
	"BROW": ["BROW Grizzlies", "Grizzlies", "4e3629", "c00404", "ffffff", "NWPC", 74, 74, 74, 55, "B", "shield"],
	"IONA": ["IONA Irish", "Irish", "6f2c3f", "f2a900", "", "NWPC", 66, 68, 64, 38, "I", "block"],
	"LIUB": ["LIUB Hammerheads", "Hammerheads", "0a3d8f", "ffc72c", "", "NWPC", 65, 63, 67, 36, "L", "circle"],
}

const LA := ["CULA", "CUSC", "LMMU"]

var r   # the test runner (check)

func run(runner) -> void:
	r = runner
	print("team names")
	_data()
	_new_career()
	_los_angeles()
	_old_save()
	_rebrand_save()
	_bengals_save()
	_bengals_logo()
	_mascot_save()
	await _old_slot()
	_no_effect_on_play()
	_fits()
	_short_names()
	_season_text()
	await _screens()

## 1-8, 12: thirty schools, the new names, everything else as it was.
func _data() -> void:
	r.check(Colleges.SCHOOLS.size() == 30 and NAMES.size() == 30 and BEFORE.size() == 30, "exactly 30 schools (%d)" % Colleges.SCHOOLS.size())
	var ids := {}
	var names := {}
	for s in Colleges.SCHOOLS:
		var id: String = s.short
		ids[id] = true
		names[s.name] = true
		if not BEFORE.has(id):
			r.check(false, "%s is one of the 30 original ids" % id)
			continue
		var b: Array = BEFORE[id]
		r.check(s.name == NAMES[id], "%s is the %s (%s)" % [id, NAMES[id], s.name])
		r.check(String(s.name).ends_with(" " + String(s.mascot)), "%s: the name ends with the mascot" % id)
		var now := [s.mascot, s.c1, s.c2, s.get("c3", ""), s.conf, s.ovr, s.off, s.def, s.prestige, s.mark, s.logo]
		r.check(now == b.slice(1), "%s keeps its mascot, colours, conference, ratings and logo %s" % [id, str(now)])
		r.check(s.get("pool", "") == "harbor", "%s keeps its pool" % id)
		r.check(Colleges.school(id) == s, "%s still finds the school" % id)
	r.check(ids.size() == 30 and ids.keys().all(func(id): return NAMES.has(id)), "the 30 original ids, none new, none lost")
	r.check(names.size() == 30, "no two schools share a name")
	var confs := {}
	for c in Colleges.CONFERENCES:
		confs[c.id] = Colleges.SCHOOLS.filter(func(s): return s.conf == c.id).size()
	r.check(confs == {"MPSF": 4, "BIGWEST": 6, "WCC": 8, "MAWPC": 7, "NWPC": 5}, "the conferences keep their members %s" % str(confs))

## A new career: every team has its new name and its old colours, and its first roster shows its
## original OVR (its OFF and DEF are its players' own lean now, not the table's).
func _new_career() -> void:
	for seed in [7, 2026]:
		var c := Career.new_game("LIUB", "A", "B", seed)
		r.check(c.teams.size() == 30, "seed %d: 30 teams in the career" % seed)
		var wrong: Array = []
		for id in BEFORE:
			var t: PoloTeam = c.teams[id]
			var b: Array = BEFORE[id]
			if t.id != id or t.name != NAMES[id] or t.mascot != b[1] or t.c1 != Color(b[2]) or t.c2 != Color(b[3]) \
					or t.conf != b[5] or t.overall_display() != b[6] or t.initial_strength_target != float(b[6]) \
					or roundi(t.prestige) != b[9] or t.roster.size() != c.roster_cap(id):
				wrong.append(id)
		r.check(wrong.is_empty(), "seed %d: every team has its new name and its old colours, conference and original OVR %s" % [seed, str(wrong)])
		r.check(c.team().name == "Brooklyn Hammerheads" and c.school == "LIUB", "seed %d: coaching LIUB is coaching the Brooklyn Hammerheads" % seed)
		r.check(String(c.queue[0].text).begins_with("The Brooklyn Hammerheads have hired you"), "seed %d: the welcome names the team, never a university" % seed)

## 13: three teams in Los Angeles, three different teams.
func _los_angeles() -> void:
	var c := Career.new_game("CULA", "A", "B", 9)
	var seen := {}
	for id in LA:
		var t: PoloTeam = c.teams[id]
		r.check(t.name.begins_with("Los Angeles ") and t.id == id, "%s is in Los Angeles (%s)" % [id, t.name])
		seen[t.name] = true
		seen[t.c1.to_html(false) + t.c2.to_html(false)] = true
		seen[TeamLogo.spec(t).mark + TeamLogo.spec(t).style] = true
	r.check(seen.size() == 9, "the three Los Angeles teams have their own names, colours and logos")
	r.check(c.teams["CULA"] != c.teams["CUSC"] and c.teams["CUSC"] != c.teams["LMMU"], "...and are three separate teams")
	r.check(TeamLogo.spec(c.teams["CULA"]).mark == "LA" and TeamLogo.spec(c.teams["CUSC"]).mark == "SC" and TeamLogo.spec(c.teams["LMMU"]).mark == "L",
		"each keeps its own logo mark")

## A save from before the update, as written to disk: every team under its old name, and the
## old names in the news, the inbox and the record books.
static func _old_save_of(c: Career) -> Dictionary:
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	for id in d.teams:
		d.teams[id].name = BEFORE[id][0]
	d.news.push_front({"t": "LIUB Hammerheads beat IONA Irish 9-7", "y": d.year, "w": d.week})
	d.queue.append({"type": "info", "title": "CULA Bears", "text": "The CULA Bears and the CUSC Spartans are coming."})
	d.records.ncsa["game_team_goals"] = {"v": 31, "name": "LMMU Mountain Lions", "team": "LMMU", "year": "2026-27"}
	# and text from when the ids were shown, beside a job offer that holds ids
	d.news.push_front({"t": "USAF beat Malibu Breakers 7-6", "y": d.year, "w": d.week})
	d.queue.append({"type": "recap", "title": "2026-27 SEASON REVIEW", "lines": ["Golden Cap (top scorer): S. Ward (HVRD)  35 goals"], "next": "PORTAL"})
	d.queue.append({"type": "offers", "offers": ["CUSC", "ICU"]})
	return d

## 7, 10: an old career loads as the same career, with the new names everywhere.
func _old_save() -> void:
	var c := Career.new_game("LIUB", "A", "B", 41)
	for _i in 3:
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	var d := _old_save_of(c)
	var old := Career.from_dict(d)
	r.check(old.school == "LIUB" and old.team().name == "Brooklyn Hammerheads", "an old LIUB Hammerheads career loads as the Brooklyn Hammerheads")
	r.check(old.teams.keys().all(func(id): return old.teams[id].name == NAMES[id]), "...with every team under its new name")
	r.check(old.news[1].t == "Brooklyn Hammerheads beat New Rochelle Irish 9-7", "...in the news (%s)" % old.news[1].t)
	r.check(old.news[0].t == "Colorado Springs Skyhawks beat Malibu Breakers 7-6", "news from when ids were shown names the team (%s)" % old.news[0].t)
	r.check(old.queue[-2].lines[0] == "Golden Cap (top scorer): S. Ward (Cambridge Redhawks)  35 goals", "...and so does a waiting season review (%s)" % old.queue[-2].lines[0])
	r.check(old.queue[-1].offers == ["CUSC", "ICU"], "a waiting job offer keeps its ids")
	var q: Dictionary = old.queue[-3]
	r.check(q.title == "Los Angeles Bears" and q.text == "The Los Angeles Bears and the Los Angeles Spartans are coming.", "...in the inbox (%s)" % q.text)
	r.check(old.records.ncsa.game_team_goals.name == "Los Angeles Mountain Lions" and old.records.ncsa.game_team_goals.team == "LMMU", "...and in the record books")
	# the same career as if it had been saved with the new names: nothing but the names moved
	var fresh: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	fresh.news.push_front({"t": "Brooklyn Hammerheads beat New Rochelle Irish 9-7", "y": fresh.year, "w": fresh.week})
	fresh.queue.append({"type": "info", "title": "Los Angeles Bears", "text": "The Los Angeles Bears and the Los Angeles Spartans are coming."})
	fresh.records.ncsa["game_team_goals"] = {"v": 31, "name": "Los Angeles Mountain Lions", "team": "LMMU", "year": "2026-27"}
	fresh.news.push_front({"t": "Colorado Springs Skyhawks beat Malibu Breakers 7-6", "y": fresh.year, "w": fresh.week})
	fresh.queue.append({"type": "recap", "title": "2026-27 SEASON REVIEW", "lines": ["Golden Cap (top scorer): S. Ward (Cambridge Redhawks)  35 goals"], "next": "PORTAL"})
	fresh.queue.append({"type": "offers", "offers": ["CUSC", "ICU"]})
	var same := Career.from_dict(fresh)
	r.check(JSON.stringify(old.to_dict()) == JSON.stringify(same.to_dict()), "the old save is the same career: roster, form, schedule, results, table, ratings, colours")
	r.check(old.record_text() == c.record_text() and old.week == c.week and old.table == c.table and old.schedule == c.schedule, "...the same record, week, table and schedule (%s)" % old.record_text())
	var a: PoloTeam = c.teams["LIUB"]
	var b: PoloTeam = old.teams["LIUB"]
	r.check(JSON.stringify(a.to_dict().roster) == JSON.stringify(b.to_dict().roster), "...the same seven, with the same ratings and form")
	r.check(b.c1 == a.c1 and b.c2 == a.c2 and b.rating() == a.rating() and b.off_rating() == a.off_rating() and b.def_rating() == a.def_rating(), "...the same colours and ratings")
	# saved again, it stays renamed
	var again := Career.from_dict(JSON.parse_string(JSON.stringify(old.to_dict())))
	r.check(again.team().name == "Brooklyn Hammerheads" and JSON.stringify(again.to_dict()) == JSON.stringify(old.to_dict()), "saved and loaded again, nothing changes")

## The November 2026 rebrand: a save from before it (Stanford Redwoods, Berkeley Golden Grizzlies)
## loads as the same career, those two teams under their new names, nothing duplicated or lost.
func _rebrand_save() -> void:
	var c := Career.new_game("STAM", "A", "B", 52)
	for _i in 2:
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	d.teams.STAM.name = "Stanford Redwoods"
	d.teams.ALC.name = "Berkeley Golden Grizzlies"
	d.news.push_front({"t": "Stanford Redwoods beat Berkeley Golden Grizzlies 8-7", "y": d.year, "w": d.week})
	d.records.ncsa["game_team_goals"] = {"v": 30, "name": "Stanford Redwoods", "team": "STAM", "year": "2026-27"}
	var old := Career.from_dict(d)
	r.check(old.school == "STAM" and old.team().name == "Pacific Grove Redwoods", "a Stanford Redwoods career loads as the Pacific Grove Redwoods")
	r.check(old.teams.ALC.name == "Bayview Golden Grizzlies" and old.teams.size() == c.teams.size(), "...the Berkeley Golden Grizzlies as the Bayview Golden Grizzlies, no team added or lost")
	r.check(old.news[0].t == "Pacific Grove Redwoods beat Bayview Golden Grizzlies 8-7", "...in the news (%s)" % old.news[0].t)
	r.check(old.records.ncsa.game_team_goals.name == "Pacific Grove Redwoods" and old.records.ncsa.game_team_goals.team == "STAM", "...and in the record books")
	for id in ["STAM", "ALC"]:
		var a: PoloTeam = c.teams[id]
		var b: PoloTeam = old.teams[id]
		r.check(JSON.stringify(a.to_dict().roster) == JSON.stringify(b.to_dict().roster) and a.c1 == b.c1 and a.c2 == b.c2 and a.conf == b.conf and a.rating() == b.rating(),
			"%s keeps its roster, colours, conference and ratings" % id)
	r.check(old.record_text() == c.record_text() and old.schedule == c.schedule and old.table == c.table, "...the same record, schedule and table")

## The New Jersey Bengals rebrand: a whole season played as the Princeton Bengals (the name, its
## capitals and the place alone in the news, the league news, the inbox and the record books)
## loads as exactly the career it would be now: same id, roster, ratings, NCC place, recruiting,
## schedule and table, no team added. Players from Princeton, New Jersey keep their hometown.
func _bengals_save() -> void:
	var c := Career.new_game("PRIN", "A", "B", 61)
	for _i in 40:
		if c.phase != "season":
			break
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	var now := JSON.stringify(c.to_dict())
	var text := now.replace("New Jersey Bengals", "Princeton Bengals").replace("NEW JERSEY BENGALS", "PRINCETON BENGALS")
	# (the place alone, never a state after a town: "Princeton, New Jersey" is a hometown)
	text = RegEx.create_from_string("(?<!, )\\bNew Jersey\\b(?!,)").sub(text, "Princeton", true)
	text = RegEx.create_from_string("(?<!, )\\bNEW JERSEY\\b(?!,)").sub(text, "PRINCETON", true)
	r.check(text != now and "PRINCETON" in text, "a Princeton-era save has the old name in its text")
	var old := Career.from_dict(JSON.parse_string(text))
	var same := Career.from_dict(JSON.parse_string(now))
	r.check(old.school == "PRIN" and old.team().name == "New Jersey Bengals" and old.teams.size() == same.teams.size(), "a Princeton Bengals career loads as the New Jersey Bengals, no team added or lost")
	r.check(JSON.stringify(old.to_dict()) == JSON.stringify(same.to_dict()), "...and is exactly the same career, every word of its news and records moved on")
	var left := RegEx.create_from_string("(?i)princeton(?!, )").search_all(JSON.stringify(old.to_dict()))
	r.check(left.is_empty(), "...with no Princeton left but hometowns (%d)" % left.size())
	var t: PoloTeam = old.teams.PRIN
	r.check(t.conf == "NWPC" and Colleges.conf_abbr(t.conf) == "NCC" and t.c1 == Color("e77500") and t.c2 == Color("121212"), "the Bengals stay in the NCC in orange and black")
	r.check(Colleges.place("PRIN") == "New Jersey" and Colleges.short_name(t) == "New Jersey" and Colleges.venue_name("PRIN") == "Bengal Basin Aquatics Complex", "the scoreboard says New Jersey; the home pool is kept")

## The Bengal tiger head replaced the striped "B": every box has its file, centred in its box
## (never wider or taller), in the tiger's own black, orange and cream, nothing in between.
func _bengals_logo() -> void:
	var team := {"short": "PRIN", "name": "New Jersey Bengals"}
	var cols := {}
	for tag in TeamLogo.ART_BOXES:
		var box: Vector2i = TeamLogo.ART_BOXES[tag]
		var fine: String = TeamLogo.FINE_TAGS.get(tag, "")
		for f in ([false, true] if fine != "" else [false]):
			var tex := TeamLogo.art(team, box, f)
			var want := box if not f else Vector2i(roundi(box.x / TeamLogo.FINE), roundi(box.y / TeamLogo.FINE))
			r.check(tex != null and tex.get_width() <= want.x and tex.get_height() <= want.y and (tex.get_width() == want.x or tex.get_height() == want.y),
				"PRIN %s%s fills its box %s (%s)" % [tag, " fine" if f else "", str(want), str(tex.get_size()) if tex else "none"])
			if tex == null:
				continue
			var img := tex.get_image()
			for y in img.get_height():
				for x in img.get_width():
					var px := img.get_pixel(x, y)
					if px.a > 0.0:
						cols[px.to_html(true)] = true
	r.check(cols.keys().all(func(k): return String(k).ends_with("ff")) and cols.size() == 3, "PRIN's logo is opaque black, orange and cream only %s" % str(cols.keys()))

## The Stockton Scorpions and Washington Sentinels: a save from when they were the Bengals and the
## Patriots loads as the same career, new names and mascots everywhere, the New Jersey Bengals untouched.
func _mascot_save() -> void:
	var c := Career.new_game("UPAC", "A", "B", 64)
	for _i in 2:
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	d.teams.UPAC.name = "Stockton Bengals"
	d.teams.UPAC.mascot = "Bengals"
	d.teams.GWU.name = "Washington Patriots"
	d.teams.GWU.mascot = "Patriots"
	d.news.push_front({"t": "Stockton Bengals beat Washington Patriots 9-8; New Jersey Bengals idle", "y": d.year, "w": d.week})
	d.records.ncsa["game_team_goals"] = {"v": 29, "name": "WASHINGTON PATRIOTS", "team": "GWU", "year": "2026-27"}
	var old := Career.from_dict(d)
	r.check(old.school == "UPAC" and old.team().name == "Stockton Scorpions" and old.team().mascot == "Scorpions", "a Stockton Bengals career loads as the Stockton Scorpions")
	r.check(old.teams.GWU.name == "Washington Sentinels" and old.teams.GWU.mascot == "Sentinels", "...the Washington Patriots as the Washington Sentinels")
	r.check(old.teams.PRIN.name == "New Jersey Bengals" and old.teams.PRIN.mascot == "Bengals" and old.teams.size() == c.teams.size(), "...the New Jersey Bengals untouched, no team added or lost")
	r.check(old.news[0].t == "Stockton Scorpions beat Washington Sentinels 9-8; New Jersey Bengals idle", "...in the news (%s)" % old.news[0].t)
	r.check(old.records.ncsa.game_team_goals.name == "WASHINGTON SENTINELS" and old.records.ncsa.game_team_goals.team == "GWU", "...and in the record books")
	for id in ["UPAC", "GWU"]:
		var a: PoloTeam = c.teams[id]
		var b: PoloTeam = old.teams[id]
		r.check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "%s: roster, ratings, colours and conference exactly as saved" % id)
	r.check(old.record_text() == c.record_text() and old.schedule == c.schedule and old.table == c.table, "...the same record, schedule and table")

## 10: a save slot written before the update shows the new name on the careers screen, from a
## summary cached before the update too, and loads.
func _old_slot() -> void:
	var dir := "user://test_names/"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
	var saved := [Game.save_dir, Game.career, Game.slot, Game.test_mode]
	Game.save_dir = dir
	Game.test_mode = false
	var c := Career.new_game("LIUB", "A", "B", 12)
	var f := FileAccess.open(Game.slot_path(2), FileAccess.WRITE)
	f.store_string(JSON.stringify(_old_save_of(c)))
	f.close()
	var cf := ConfigFile.new()
	cf.set_value("slots", "sum_2", {"team": "LIUB Hammerheads", "season": 1, "record": "0-0", "mtime": FileAccess.get_modified_time(Game.slot_path(2))})
	cf.save(dir + Game.SLOTS_CFG)
	r.check(Game.slot_summary(2).get("team", "") == "Brooklyn Hammerheads", "an old slot's cached summary shows the new name (%s)" % str(Game.slot_summary(2)))
	r.check(Game.slot_summary(2).get("team", "") == "Brooklyn Hammerheads", "...and again from the summary cached now")
	r.check(Game.load_career(2) and Game.career.school == "LIUB" and Game.career.team().name == "Brooklyn Hammerheads", "the old slot loads as the Brooklyn Hammerheads")
	Game.save_dir = saved[0]
	Game.career = saved[1]
	Game.slot = saved[2]
	Game.test_mode = saved[3]
	for g in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + g))

## 14: the names play no part in a game: the same seed under any names sims the same season.
func _no_effect_on_play() -> void:
	var a := Career.new_game("USAF", "A", "B", 77)
	var b := Career.new_game("USAF", "A", "B", 77)
	var back := {}
	for id in b.teams:
		b.teams[id].name = "<%s>" % id
		back["<%s>" % id] = NAMES[id]
	for c in [a, b]:
		seed(77)   # the weekly card is shuffled with the global generator
		for _i in 5:
			while c.has_game():
				c.sim_my_game()
			c.end_week()
	for id in b.teams:
		b.teams[id].name = NAMES[id]
	# (the league news is written about the teams by name: its words follow the names, not the play)
	var ad := a.to_dict()
	var bd: Dictionary = Career._renamed(b.to_dict(), back)
	ad.erase("league_news")
	bd.erase("league_news")
	ad.erase("uid")   # (each dynasty's own id: random by design, nothing the game plays with)
	bd.erase("uid")
	var da := JSON.stringify(ad)
	var db := JSON.stringify(bd)
	r.check(da == db, "the same seed under other names sims the same five weeks (results, ratings, form, recruiting)")

## 11: the long names fit where the names are shown.
func _fits() -> void:
	var c := Career.new_game("USAF", "A", "B", 3)
	for id in NAMES:
		var t: PoloTeam = c.teams[id]
		var up := String(NAMES[id]).to_upper()
		# the final whistle panel: the whole name, never just the id
		r.check(ResultsPanel._fit(t, ResultsPanel.W / 2.0 - 4) == up, "%s: the whole name on the final panel" % id)
		# the hub's team card and the matchup: the big font, on one line or two
		var l: Label = UI.team_title(up, t.mascot, 150)
		var lines := l.text.split("\n")
		r.check(l.get_theme_font_size("font_size") >= 16 and lines.size() <= 2 and " ".join(lines) == up, "%s: a headline (%d px, %d lines)" % [id, l.get_theme_font_size("font_size"), lines.size()])
		for line in lines:
			r.check(UI.text_width(line, l.get_theme_font_size("font_size"), "big") <= 150.0, "%s: '%s' fits 150 px" % [id, line])
		l.free()
		# the game preview has room for every name on one line, so it's no taller than before
		var m: Label = UI.team_title(up, t.mascot, load("res://src/ui/screens/matchup.gd").SIDE_W)
		r.check(m.get_theme_font_size("font_size") >= 16 and not "\n" in m.text, "%s: one line in the big font on the game preview" % id)
		m.free()
		# the fixed columns that list every team: class ranks, standings, the playoff bracket
		var bw := UI.text_width(up, 8)
		r.check(bw <= 116.0 and bw <= 146.0 and UI.text_width("#12 " + up, 8) <= 150.0,
			"%s fits the class ranks, standings and bracket columns (%.0f px)" % [id, bw])
		r.check(UI.text_width(id, 8, "caps") <= 30.0, "%s still fits the scoreboard" % id)
	var la := UI.team_title("LOS ANGELES BEARS", "Bears", 150)
	var cs := UI.team_title("COLORADO SPRINGS SKYHAWKS", "Skyhawks", 150)
	var ml := UI.team_title("LOS ANGELES MOUNTAIN LIONS", "Mountain Lions", 150)
	r.check(la.get_theme_font_size("font_size") == 20 and not "\n" in la.text, "a name that fits stays at 20 px, on one line")
	r.check(cs.text == "COLORADO SPRINGS\nSKYHAWKS", "Colorado Springs over Skyhawks")
	r.check(ml.text == "LOS ANGELES\nMOUNTAIN LIONS", "Los Angeles over Mountain Lions")
	for l in [la, cs, ml]:
		l.free()

## The ids, as whole words: none of them may reach the screen.
static func _id_re() -> RegEx:
	return RegEx.create_from_string("\\b(%s)\\b" % "|".join(NAMES.keys()))

## The short names (the scoreboard's): every team's own, and they fit the scoreboard.
func _short_names() -> void:
	var c := Career.new_game("CULA", "A", "B", 4)
	var seen := {}
	for id in NAMES:
		var t: PoloTeam = c.teams[id]
		var sn := Colleges.short_name(t)
		r.check(sn == SHORT[id] and Colleges.team_name(id) == NAMES[id], "%s: %s, short %s" % [id, Colleges.team_name(id), sn])
		seen[sn] = true
		var d := Hud.fit_name(t, Hud.NAME_MAX)
		r.check(" ".join(d.lines) == sn.to_upper() and float(d.w) <= Hud.NAME_MAX, "%s fits the scoreboard whole (%s, %.0f px)" % [id, str(d.lines), d.w])
	r.check(seen.size() == 30, "no two teams share a short name: the three in Los Angeles go by their whole names")
	# the widest board, between the shot clock on its left and the play calls and pause on its right
	var bw := 126.0 + 2.0 * Hud.NAME_MAX
	var bx := roundf((480.0 - bw) / 2.0)
	r.check(bx - 34.0 >= 2.0 and bx + bw <= 480.0 - 24.0 - 54.0 - 4.0, "the widest scoreboard (%.0f px) leaves room for the shot clock and the play calls" % bw)
	# a quick-match club isn't a school: its whole name, never its code
	var club := League.make_team(0)
	r.check(Colleges.short_name(club) == club.name and not _id_re().search(Colleges.short_name(club)), "a quick-match club goes by its name (%s)" % club.name)

## A whole season's news and inbox (the results, the review, the awards and records) name the teams.
func _season_text() -> void:
	var re := _id_re()
	var c := Career.new_game("LMMU", "A", "B", 8)
	var label := c.season_label()
	var bad: Array = []
	var guard := 0
	var texts := 0
	while c.season_label() == label and guard < 40:
		guard += 1
		for q in c.queue:
			for k in ["title", "text"]:
				if q.get(k) is String:
					texts += 1
					if re.search(q[k]):
						bad.append(q[k])
			for l in q.get("lines", []):
				texts += 1
				if l is String and re.search(l):
					bad.append(l)
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	for n in c.news:
		texts += 1
		if re.search(String(n.t)):
			bad.append(n.t)
	r.check(guard < 40 and texts > 50, "a whole season played (%d lines of news and inbox)" % texts)
	r.check(bad.is_empty(), "no id in a season's news, results, review, awards or records %s" % str(bad.slice(0, 5)))

## Every screen, its tabs and a whole career game: no id in a label, a button or anything drawn.
func _screens() -> void:
	var tree: SceneTree = r.get_tree()
	var re := _id_re()
	Store.reset_for_tests()
	var c := Career.new_game("LMMU", "A", "B", 5)
	Game.career = c
	for _i in 6:
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	c.queue.clear()
	var bad := {}
	var visits: Array = []
	for scr in ["hub", "matchup", "more", "roster", "training", "facilities", "schedule", "top20", "careers", "new_career"]:
		visits.append([scr, ""])
	for tab in ["MARKET", "INCOMING"]:
		visits.append(["recruiting", tab])
	for tab in ["STANDINGS", "PLAYOFFS", "TOP 20"]:
		visits.append(["conference", tab])
	for tab in ["SCHOOL", "NCSA", "AWARDS"]:
		visits.append(["records", tab])
	for v in visits:
		Game.goto(v[0], {"tab": v[1]} if v[1] != "" else {})
		await tree.process_frame
		if v[1] != "" and "tab" in Game.current_screen:
			Game.current_screen.tab = v[1]
			Game.current_screen._render()
		UI.drawn_log = []
		for _i in 3:
			await tree.process_frame
		_scan(re, "%s %s" % v, bad)
	r.check(bad.is_empty(), "no id on any screen %s" % str(bad))
	# a career game: the scoreboard, a quarter break, full time, then the summary
	bad.clear()
	Game.match_cfg = {"us": c.team(), "them": c.opponent(), "seed": 5, "minutes": 1.0, "career": true,
		"home": c.is_home(), "pool": c.venue().id, "autoplay": true}
	for q in c.upgrades_due(): Development.ai_spend(q)   # (XP 2.0: upgrades are spent before a game)
	Game.goto("match", Game.match_cfg)
	await tree.process_frame
	var ms = Game.current_screen
	UI.drawn_log = []
	var guard := 0
	var breaks := 0
	while ms.flow.phase != MatchFlow.Phase.FINAL and guard < 20000:
		guard += 1
		ms._process(1.0 / 30.0)
		if guard % 200 == 0:
			await tree.process_frame
		if ms.flow.phase == MatchFlow.Phase.BREAK:
			breaks += 1
			await tree.process_frame
			await tree.process_frame
			ms.flow.break_done()
	ms._process(1.0 / 30.0)
	await tree.process_frame
	await tree.process_frame
	var drawn: Array = UI.drawn_log
	r.check(ms.flow.phase == MatchFlow.Phase.FINAL and breaks > 0, "a career game played to full time, with its breaks (%d)" % breaks)
	r.check(Hud.fit_name(c.team(), Hud.NAME_MAX).lines == ["LOS ANGELES", "MOUNTAIN LIONS"], "the Los Angeles Mountain Lions on the scoreboard: place over mascot")
	r.check(drawn.has(Scoreboard.abbr(c.team())) and Scoreboard.tier() == 1, "...and, on the Classic board in the game, its abbreviation (%s)" % Scoreboard.abbr(c.team()))
	r.check(drawn.any(func(s): return String(s).begins_with("END OF")), "the quarter-break card was drawn")
	r.check(drawn.has(Scoreboard.abbr(c.opponent())), "the opponent by its abbreviation on the Classic scoreboard (%s)" % Scoreboard.abbr(c.opponent()))
	_scan(re, "match", bad)
	ms._to_career()
	UI.drawn_log = []
	await tree.create_timer(2.5).timeout
	_scan(re, "game_summary", bad)
	r.check(bad.is_empty(), "no id in the game, at full time or on the summary %s" % str(bad))
	UI.drawn_log = null
	for ch in Game.overlay.get_children():
		if ch is Control and ch.mouse_filter == Control.MOUSE_FILTER_STOP:
			ch.queue_free()
	Game.career = null

## Every id on the screen now (its labels and buttons, the overlay's, and what was drawn) into `bad`.
func _scan(re: RegEx, where: String, bad: Dictionary) -> void:
	var texts: Array = (UI.drawn_log as Array).duplicate() if UI.drawn_log != null else []
	for root in [Game.current_screen, Game.overlay]:
		if is_instance_valid(root):
			_texts(root, texts)
	for s in texts:
		var m := re.search(String(s))
		if m != null:
			bad["%s: %s" % [where, m.get_string()]] = String(s)

static func _texts(n: Node, out: Array) -> void:
	if n is Label or n is Button or n is RichTextLabel:
		out.append(n.text)
	if n is Control and (n as Control).tooltip_text != "":
		out.append((n as Control).tooltip_text)
	for ch in n.get_children():
		_texts(ch, out)
