class_name Colleges
## The college world: 30 fictional schools in 5 conferences. Every school has exactly one
## home pool (see Pools); they all play in "harbor" until more pools exist. Tier 1 is the
## bottom conference, tier 5 the top; a new career can start at any school. `mark`
## (initials) and `logo` (one of TeamLogo.STYLES) pick the school's logo; they're display
## only and never saved.

const LEAGUE := "NCSA"

## The five conferences, drawn on the map: three in the West, two in the East. They come in
## different sizes. `rr` is how many times the members meet (the four-team PEC plays a double
## round robin). `tier` ranks them by strength (prestige ceilings). `id` is the
## conference in saves, schedules and tables, and never changes; `name` and `abbr` are only what
## the screens show (`abbr` where there's no room for the name). `old` is every name it showed
## before (the Conference Rebranding, then NCC's rename), for text a save wrote then
## (Career._rename_conferences).
const CONFERENCES := [
	{"id": "MPSF", "name": "Pacific Elite Conference", "abbr": "PEC", "old": ["MPSF"], "tier": 5, "region": "west", "rr": 2},
	{"id": "BIGWEST", "name": "Golden Coast Conference", "abbr": "GCC", "old": ["Big West"], "tier": 4, "region": "west", "rr": 1},
	{"id": "WCC", "name": "Western Water Polo Conference", "abbr": "WWPC", "old": ["WCC"], "tier": 3, "region": "west", "rr": 1},
	{"id": "NWPC", "name": "Northeast Coast Conference", "abbr": "NCC", "old": ["NWPC", "Northeast Collegiate Conference"], "tier": 2, "region": "east", "rr": 1},
	{"id": "MAWPC", "name": "Atlantic Water Polo Conference", "abbr": "AWPC", "old": ["MAWPC"], "tier": 1, "region": "east", "rr": 1},
]

## `name` is the team as shown everywhere ("Los Angeles Bears"); `short` ("CULA") is its id in
## saves and on the scoreboard; no university or college name is kept or shown. `ovr` is the school's original overall
## (with `off` and `def`, its original scoring and goal-prevention split; `ovr` is their average):
## only the INITIAL TEAM STRENGTH TARGET a brand-new career's first roster is generated to
## (CollegeGen.make_initial_roster). Once that roster exists, none of the three is read again:
## the team's overall, OFF and DEF are its seven starters' (PoloTeam.team_overall). `prestige` is the program's reputation
## (recruiting, job offers, facilities). `c3` is a third school colour, shown on the picker only.
const SCHOOLS := [
	{"short": "CULA", "name": "Los Angeles Bears", "venue": "The Bear Den Aquatic Center", "mascot": "Bears", "city": "Los Altos, California", "c1": "2d68c4", "c2": "f2a900", "conf": "MPSF", "ovr": 91, "off": 90, "def": 92, "prestige": 90, "pool": "harbor", "mark": "LA", "logo": "interlock"},
	{"short": "CUSC", "name": "Los Angeles Spartans", "venue": "Spartan Coliseum Natatorium", "mascot": "Spartans", "city": "Sacramento, California", "c1": "990000", "c2": "ffc72c", "conf": "MPSF", "ovr": 90, "off": 92, "def": 88, "prestige": 88, "pool": "harbor", "mark": "SC", "logo": "interlock"},
	{"short": "STAM", "name": "Pacific Grove Redwoods", "venue": "Redwood Grove Aquatics Center", "mascot": "Redwoods", "city": "Santa Teresa, California", "c1": "8c1515", "c2": "ffffff", "conf": "MPSF", "ovr": 89, "off": 87, "def": 91, "prestige": 86, "pool": "harbor", "mark": "PG", "logo": "interlock"},
	{"short": "ALC", "name": "Bayview Golden Grizzlies", "venue": "Golden Claw Natatorium", "mascot": "Golden Grizzlies", "city": "Berkeley, California", "c1": "003262", "c2": "fdb515", "conf": "MPSF", "ovr": 88, "off": 90, "def": 86, "prestige": 84, "pool": "harbor", "mark": "BV", "logo": "interlock"},

	{"short": "LBSC", "name": "Long Beach Barracudas", "venue": "Barracuda Bay Aquatic Center", "mascot": "Barracudas", "city": "Long Beach, California", "c1": "111111", "c2": "ffc72a", "conf": "BIGWEST", "ovr": 82, "off": 84, "def": 80, "prestige": 71, "pool": "harbor", "mark": "LB", "logo": "interlock"},
	{"short": "CUSD", "name": "San Diego Sea Kings", "venue": "King's Tide Natatorium", "mascot": "Sea Kings", "city": "San Diego, California", "c1": "182b49", "c2": "c69214", "conf": "BIGWEST", "ovr": 81, "off": 80, "def": 82, "prestige": 69, "pool": "harbor", "mark": "SD", "logo": "interlock"},
	{"short": "ICU", "name": "Irvine Aardvarks", "venue": "The Burrow Aquatic Center", "mascot": "Aardvarks", "city": "Irvine, California", "c1": "0064a4", "c2": "ffd200", "conf": "BIGWEST", "ovr": 78, "off": 77, "def": 79, "prestige": 63, "pool": "harbor", "mark": "I", "logo": "circle"},
	{"short": "CRBU", "name": "Riverside Knights", "venue": "Knightfall Natatorium", "mascot": "Knights", "city": "Riverside, California", "c1": "002d62", "c2": "c5a253", "conf": "BIGWEST", "ovr": 77, "off": 79, "def": 75, "prestige": 61, "pool": "harbor", "mark": "R", "logo": "shield"},
	{"short": "CCSB", "name": "Santa Barbara Bulls", "venue": "The Bullring Natatorium", "mascot": "Bulls", "city": "Santa Barbara, California", "c1": "003660", "c2": "febc11", "conf": "BIGWEST", "ovr": 75, "off": 75, "def": 75, "prestige": 57, "pool": "harbor", "mark": "SB", "logo": "interlock"},
	{"short": "CSFU", "name": "Fullerton Mammoths", "venue": "Mammoth Springs Aquatic Center", "mascot": "Mammoths", "city": "Fullerton, California", "c1": "00274c", "c2": "ff7900", "c3": "ffffff", "conf": "BIGWEST", "ovr": 70, "off": 72, "def": 68, "prestige": 47, "pool": "harbor", "mark": "F", "logo": "angled"},

	{"short": "SJCU", "name": "San Jose Warriors", "venue": "Warrior's Forge Natatorium", "mascot": "Warriors", "city": "San José, California", "c1": "0055a2", "c2": "e5a823", "conf": "WCC", "ovr": 83, "off": 81, "def": 85, "prestige": 73, "pool": "harbor", "mark": "SJ", "logo": "interlock"},
	{"short": "PPCU", "name": "Malibu Breakers", "venue": "Breaker Point Aquatic Center", "mascot": "Breakers", "city": "Malibu, California", "c1": "00205c", "c2": "e35205", "conf": "WCC", "ovr": 79, "off": 81, "def": 77, "prestige": 65, "pool": "harbor", "mark": "P", "logo": "circle"},
	{"short": "UCDS", "name": "Davis Mustangs", "venue": "Mustang Run Natatorium", "mascot": "Mustangs", "city": "Davis, California", "c1": "022851", "c2": "ffbf00", "conf": "WCC", "ovr": 78, "off": 76, "def": 80, "prestige": 63, "pool": "harbor", "mark": "D", "logo": "shield"},
	{"short": "LMMU", "name": "Los Angeles Mountain Lions", "venue": "Lion's Crest Aquatic Center", "mascot": "Mountain Lions", "city": "Los Marina, California", "c1": "a6192e", "c2": "00205b", "conf": "WCC", "ovr": 77, "off": 78, "def": 76, "prestige": 61, "pool": "harbor", "mark": "L", "logo": "angled"},
	{"short": "UPAC", "name": "Stockton Scorpions", "venue": "Delta Den Natatorium", "mascot": "Scorpions", "city": "Stockton, California", "c1": "f47920", "c2": "121212", "conf": "WCC", "ovr": 76, "off": 76, "def": 76, "prestige": 59, "pool": "harbor", "mark": "P", "logo": "angled"},
	{"short": "SCCU", "name": "Santa Clara Stallions", "venue": "Stallion Springs Natatorium", "mascot": "Stallions", "city": "Santa Clara, California", "c1": "b30738", "c2": "ffffff", "conf": "WCC", "ovr": 72, "off": 72, "def": 72, "prestige": 51, "pool": "harbor", "mark": "S", "logo": "circle"},
	{"short": "USAF", "name": "Colorado Springs Skyhawks", "venue": "Skyhawk Summit Aquatic Center", "mascot": "Skyhawks", "city": "Colorado Springs, Colorado", "c1": "003594", "c2": "b2b4b2", "conf": "WCC", "ovr": 71, "off": 74, "def": 68, "prestige": 49, "pool": "harbor", "mark": "AF", "logo": "interlock"},
	{"short": "SMCC", "name": "Moraga Highlanders", "venue": "Highlander Hollow Natatorium", "mascot": "Highlanders", "city": "Moraga, California", "c1": "d80024", "c2": "06315b", "conf": "WCC", "ovr": 70, "off": 70, "def": 70, "prestige": 47, "pool": "harbor", "mark": "M", "logo": "angled"},

	{"short": "FORDU", "name": "Bronx Lambs", "venue": "Iron Fleece Aquatic Center", "mascot": "Lambs", "city": "Bronx, New York", "c1": "860038", "c2": "ffffff", "conf": "MAWPC", "ovr": 86, "off": 88, "def": 84, "prestige": 80, "pool": "harbor", "mark": "F", "logo": "block"},
	{"short": "NANA", "name": "Annapolis Mariners", "venue": "Admiral's Harbor Aquatic Center", "mascot": "Mariners", "city": "Annapolis, Maryland", "c1": "00205b", "c2": "c5b783", "conf": "MAWPC", "ovr": 74, "off": 76, "def": 72, "prestige": 55, "pool": "harbor", "mark": "N", "logo": "block"},
	{"short": "GWU", "name": "Washington Sentinels", "venue": "Liberty Basin Aquatic Center", "mascot": "Sentinels", "city": "Washington, D.C.", "c1": "e4cc94", "c2": "033c5a", "conf": "MAWPC", "ovr": 73, "off": 72, "def": 74, "prestige": 53, "pool": "harbor", "mark": "GW", "logo": "interlock"},
	{"short": "BUCK", "name": "Lewisburg Buffalo", "venue": "Thunderhoof Natatorium", "mascot": "Buffalo", "city": "Lewisburg, Pennsylvania", "c1": "e87722", "c2": "003865", "conf": "MAWPC", "ovr": 69, "off": 69, "def": 69, "prestige": 44, "pool": "harbor", "mark": "B", "logo": "block"},
	{"short": "WAGN", "name": "Staten Island Hawks", "venue": "Hawk's Nest Aquatic Center", "mascot": "Hawks", "city": "Staten Island, New York", "c1": "006747", "c2": "ffffff", "conf": "MAWPC", "ovr": 68, "off": 70, "def": 66, "prestige": 42, "pool": "harbor", "mark": "W", "logo": "block"},
	{"short": "MSMU", "name": "Emmitsburg Highlanders", "venue": "Highland Keep Natatorium", "mascot": "Highlanders", "city": "Emmitsburg, Maryland", "c1": "003a70", "c2": "ffffff", "conf": "MAWPC", "ovr": 67, "off": 67, "def": 67, "prestige": 40, "pool": "harbor", "mark": "M", "logo": "shield"},
	{"short": "HURST", "name": "Erie Lakehawks", "venue": "Lakehawk Landing Aquatic Center", "mascot": "Lakehawks", "city": "Erie, Pennsylvania", "c1": "00573f", "c2": "ffffff", "conf": "MAWPC", "ovr": 62, "off": 63, "def": 61, "prestige": 30, "pool": "harbor", "mark": "H", "logo": "circle"},

	{"short": "PRIN", "name": "New Jersey Bengals", "venue": "Bengal Basin Aquatics Complex", "mascot": "Bengals", "city": "Princeton, New Jersey", "c1": "e77500", "c2": "121212", "conf": "NWPC", "ovr": 80, "off": 82, "def": 78, "prestige": 67, "pool": "harbor", "mark": "NJ", "logo": "interlock"},
	{"short": "HVRD", "name": "Cambridge Redhawks", "venue": "Redhawk Roost Aquatic Center", "mascot": "Redhawks", "city": "Cambridge, Massachusetts", "c1": "a51c30", "c2": "ffffff", "conf": "NWPC", "ovr": 76, "off": 77, "def": 75, "prestige": 59, "pool": "harbor", "mark": "H", "logo": "shield"},
	{"short": "BROW", "name": "Providence Grizzlies", "venue": "Grizzly Grotto Natatorium", "mascot": "Grizzlies", "city": "Providence, Rhode Island", "c1": "4e3629", "c2": "c00404", "c3": "ffffff", "conf": "NWPC", "ovr": 74, "off": 74, "def": 74, "prestige": 55, "pool": "harbor", "mark": "B", "logo": "shield"},
	{"short": "IONA", "name": "New Rochelle Irish", "venue": "Emerald Waters Aquatic Center", "mascot": "Irish", "city": "New Rochelle, New York", "c1": "6f2c3f", "c2": "f2a900", "conf": "NWPC", "ovr": 66, "off": 68, "def": 64, "prestige": 38, "pool": "harbor", "mark": "I", "logo": "block"},
	{"short": "LIUB", "name": "Brooklyn Hammerheads", "venue": "Hammerhead Harbor Natatorium", "mascot": "Hammerheads", "city": "Brooklyn, New York", "c1": "0a3d8f", "c2": "ffc72c", "conf": "NWPC", "ovr": 65, "off": 63, "def": 67, "prestige": 36, "pool": "harbor", "mark": "L", "logo": "circle"},
]

## Conferences of older saves, which keep them until their season ends; then Career.realign
## moves them onto CONFERENCES. "v2": the first 30-school layout (five conferences of six).
const LEGACY_CONFERENCES := [
	{"id": "GCF", "name": "Golden Coast Federation", "tier": 5, "era": "v2"},
	{"id": "SSC", "name": "Southern Shores Conference", "tier": 4, "era": "v2"},
	{"id": "WPA", "name": "Western Polo Association", "tier": 3, "era": "v2"},
	{"id": "NCC", "name": "Northeast Coast Conference", "old": ["Northeast Collegiate Conference"], "tier": 2, "era": "v2"},
	{"id": "CAC", "name": "Capital Atlantic Conference", "tier": 1, "era": "v2"},
]

## A team's name for tight spots: any " University" or " College" on the end comes off.
static func display_name(full: String) -> String:
	for suffix in [" University", " College"]:
		if full.ends_with(suffix):
			return full.substr(0, full.length() - suffix.length())
	return full

## The name a team goes by on screen, from its id: "CULA" -> "Los Angeles Bears". Ids are for
## saves and lookups and are never shown.
static func team_name(id: String) -> String:
	return String(school(id).get("name", id))

## Where a school plays, the name without its mascot: "Los Angeles Bears" -> "Los Angeles".
static func place(id: String) -> String:
	var s := school(id)
	return String(s.get("name", id)).trim_suffix(" " + String(s.get("mascot", "")))

## A team's name where room is short (the live scoreboard, a player's team in a list): its place
## ("Bronx"), or its whole name when another school shares the place ("Los Angeles Bears").
## A team that isn't one of the schools (a quick-match club) keeps its whole name.
static func short_name(t: PoloTeam) -> String:
	var s := school(t.id)
	if s.is_empty() or String(s.name) != t.name:
		return t.name
	var p := place(t.id)
	var shared := SCHOOLS.filter(func(o): return place(String(o.short)) == p).size() > 1
	return t.name if shared else p

## A school's own home pool's name (the Home Waters update: "Hammerhead Harbor Natatorium"),
## fixed in the school's data, never generated; "" for a team that isn't a school.
static func venue_name(id: String) -> String:
	return String(school(id).get("venue", ""))

## A school by id, {} for an id that isn't one.
static func school(id: String) -> Dictionary:
	for s in SCHOOLS:
		if s.short == id:
			return s
	return {}

## All 30 schools.
static func all_schools() -> Array:
	return SCHOOLS.duplicate()

## Every current conference.
static func all_conferences() -> Array:
	return CONFERENCES.duplicate()

static func conference(id: String) -> Dictionary:
	for list in [CONFERENCES, LEGACY_CONFERENCES]:
		for c in list:
			if c.id == id:
				return c
	return {}

## A conference's short name (PEC), for where its name doesn't fit.
static func conf_abbr(id: String) -> String:
	var c := conference(id)
	return String(c.get("abbr", c.get("name", "")))

static func conf_tier(id: String) -> int:
	return int(conference(id).get("tier", 1))

## Where a conference sits on the ladder: 0 at the bottom, 1 at the top, however many there are.
static func tier_frac(id: String) -> float:
	var era := String(conference(id).get("era", ""))
	var top := 1
	for c in CONFERENCES + LEGACY_CONFERENCES:
		if String(c.get("era", "")) == era:
			top = maxi(top, int(c.tier))
	return float(conf_tier(id) - 1) / maxf(1.0, top - 1)

static func is_current_conf(id: String) -> bool:
	return all_conferences().any(func(c): return c.id == id)

## How many times a conference's members meet in the regular season.
static func conf_rr(id: String) -> int:
	return int(conference(id).get("rr", 1))

static func region(id: String) -> String:
	return String(conference(id).get("region", ""))

## The conferences a career's teams play in, bottom tier up (an old save's are its old five).
static func conf_ids_of(teams: Dictionary) -> Array:
	var ids := {}
	for id in teams:
		ids[(teams[id] as PoloTeam).conf] = true
	return _by_tier(CONFERENCES + LEGACY_CONFERENCES).filter(func(cid): return ids.has(cid))

static func _by_tier(list: Array) -> Array:
	var out: Array = list.duplicate()
	out.sort_custom(func(a, b): return a.tier < b.tier)
	return out.map(func(c): return c.id)

static func schools_in(conf: String) -> Array:
	return all_schools().filter(func(s): return s.conf == conf)
