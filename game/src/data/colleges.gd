class_name Colleges
## The college world: 30 fictional Division I schools in 5 conferences, and the 24 Division II and
## III schools of the expansion (EXPANSION_SCHOOLS). Every school has exactly one
## home pool (see Pools); they all play in "harbor" until more pools exist. Tier 1 is the
## bottom conference, tier 5 the top; a new career can start at any school. `mark`
## (initials) and `logo` (one of TeamLogo.STYLES) pick the school's logo; they're display
## only and never saved.

const LEAGUE := "NCSA"
## The divisions. Every career has D1; D2 and D3 are expansion packs (Store), switched on per
## dynasty (Career.divisions).
const D1 := 1
const D2 := 2
const D3 := 3
const DIVISION_NAMES := {1: "DIVISION I", 2: "DIVISION II", 3: "DIVISION III"}

## THE LOWER DIVISIONS' SWITCH (developers only: there is no setting for it anywhere in the game).
## false: Division II and III are hibernated. Pixel Polo is a Division I game: the packs are never
## owned, sold or listed (Store), the new-career picker shows Division I alone with no division
## controls, no invitation or settings row adds one, the Developer Mode lab is gone, a career's
## queued divisions wait (Career.activate_pending), and a career that plays Division II or III is
## left out of the slot list and CONTINUE (Game.slot_hidden), its file untouched and its slot never
## reused. Nothing is deleted: every school, conference, rule, trophy, record and save stays.
## true: all of it is back exactly as it was.
const ENABLE_LOWER_DIVISIONS := false
## What the game reads (the constant above; only the tests ever change it, to check both ways).
static var lower_divisions := ENABLE_LOWER_DIVISIONS

## Division `d` is in the game right now (Division I always is).
static func division_enabled(d: int) -> bool:
	return d == D1 or lower_divisions
## The conference whose tournament is the Division II Championship.
const D2_CONF := "WWPA"

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
	{"short": "STAM", "name": "Stanford Redwoods", "venue": "Redwood Grove Aquatics Center", "mascot": "Redwoods", "city": "Santa Teresa, California", "c1": "8c1515", "c2": "ffffff", "conf": "MPSF", "ovr": 89, "off": 87, "def": 91, "prestige": 86, "pool": "harbor", "mark": "S", "logo": "block"},
	{"short": "ALC", "name": "Berkeley Golden Grizzlies", "venue": "Golden Claw Natatorium", "mascot": "Golden Grizzlies", "city": "Berkeley, California", "c1": "003262", "c2": "fdb515", "conf": "MPSF", "ovr": 88, "off": 90, "def": 86, "prestige": 84, "pool": "harbor", "mark": "A", "logo": "shield"},

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
	{"short": "UPAC", "name": "Stockton Bengals", "venue": "Delta Den Natatorium", "mascot": "Bengals", "city": "Stockton, California", "c1": "f47920", "c2": "121212", "conf": "WCC", "ovr": 76, "off": 76, "def": 76, "prestige": 59, "pool": "harbor", "mark": "P", "logo": "angled"},
	{"short": "SCCU", "name": "Santa Clara Stallions", "venue": "Stallion Springs Natatorium", "mascot": "Stallions", "city": "Santa Clara, California", "c1": "b30738", "c2": "ffffff", "conf": "WCC", "ovr": 72, "off": 72, "def": 72, "prestige": 51, "pool": "harbor", "mark": "S", "logo": "circle"},
	{"short": "USAF", "name": "Colorado Springs Skyhawks", "venue": "Skyhawk Summit Aquatic Center", "mascot": "Skyhawks", "city": "Colorado Springs, Colorado", "c1": "003594", "c2": "b2b4b2", "conf": "WCC", "ovr": 71, "off": 74, "def": 68, "prestige": 49, "pool": "harbor", "mark": "AF", "logo": "interlock"},
	{"short": "SMCC", "name": "Moraga Highlanders", "venue": "Highlander Hollow Natatorium", "mascot": "Highlanders", "city": "Moraga, California", "c1": "d80024", "c2": "06315b", "conf": "WCC", "ovr": 70, "off": 70, "def": 70, "prestige": 47, "pool": "harbor", "mark": "M", "logo": "angled"},

	{"short": "FORDU", "name": "Bronx Lambs", "venue": "Iron Fleece Aquatic Center", "mascot": "Lambs", "city": "Bronx, New York", "c1": "860038", "c2": "ffffff", "conf": "MAWPC", "ovr": 86, "off": 88, "def": 84, "prestige": 80, "pool": "harbor", "mark": "F", "logo": "block"},
	{"short": "NANA", "name": "Annapolis Mariners", "venue": "Admiral's Harbor Aquatic Center", "mascot": "Mariners", "city": "Annapolis, Maryland", "c1": "00205b", "c2": "c5b783", "conf": "MAWPC", "ovr": 74, "off": 76, "def": 72, "prestige": 55, "pool": "harbor", "mark": "N", "logo": "block"},
	{"short": "GWU", "name": "Washington Patriots", "venue": "Liberty Basin Aquatic Center", "mascot": "Patriots", "city": "Washington, D.C.", "c1": "e4cc94", "c2": "033c5a", "conf": "MAWPC", "ovr": 73, "off": 72, "def": 74, "prestige": 53, "pool": "harbor", "mark": "GW", "logo": "interlock"},
	{"short": "BUCK", "name": "Lewisburg Buffalo", "venue": "Thunderhoof Natatorium", "mascot": "Buffalo", "city": "Lewisburg, Pennsylvania", "c1": "e87722", "c2": "003865", "conf": "MAWPC", "ovr": 69, "off": 69, "def": 69, "prestige": 44, "pool": "harbor", "mark": "B", "logo": "block"},
	{"short": "WAGN", "name": "Staten Island Hawks", "venue": "Hawk's Nest Aquatic Center", "mascot": "Hawks", "city": "Staten Island, New York", "c1": "006747", "c2": "ffffff", "conf": "MAWPC", "ovr": 68, "off": 70, "def": 66, "prestige": 42, "pool": "harbor", "mark": "W", "logo": "block"},
	{"short": "MSMU", "name": "Emmitsburg Highlanders", "venue": "Highland Keep Natatorium", "mascot": "Highlanders", "city": "Emmitsburg, Maryland", "c1": "003a70", "c2": "ffffff", "conf": "MAWPC", "ovr": 67, "off": 67, "def": 67, "prestige": 40, "pool": "harbor", "mark": "M", "logo": "shield"},
	{"short": "HURST", "name": "Erie Lakehawks", "venue": "Lakehawk Landing Aquatic Center", "mascot": "Lakehawks", "city": "Erie, Pennsylvania", "c1": "00573f", "c2": "ffffff", "conf": "MAWPC", "ovr": 62, "off": 63, "def": 61, "prestige": 30, "pool": "harbor", "mark": "H", "logo": "circle"},

	{"short": "PRIN", "name": "Princeton Bengals", "venue": "Bengal Basin Aquatics Complex", "mascot": "Bengals", "city": "Princeton, New Jersey", "c1": "e77500", "c2": "121212", "conf": "NWPC", "ovr": 80, "off": 82, "def": 78, "prestige": 67, "pool": "harbor", "mark": "P", "logo": "shield"},
	{"short": "HVRD", "name": "Cambridge Redhawks", "venue": "Redhawk Roost Aquatic Center", "mascot": "Redhawks", "city": "Cambridge, Massachusetts", "c1": "a51c30", "c2": "ffffff", "conf": "NWPC", "ovr": 76, "off": 77, "def": 75, "prestige": 59, "pool": "harbor", "mark": "H", "logo": "shield"},
	{"short": "BROW", "name": "Providence Grizzlies", "venue": "Grizzly Grotto Natatorium", "mascot": "Grizzlies", "city": "Providence, Rhode Island", "c1": "4e3629", "c2": "c00404", "c3": "ffffff", "conf": "NWPC", "ovr": 74, "off": 74, "def": 74, "prestige": 55, "pool": "harbor", "mark": "B", "logo": "shield"},
	{"short": "IONA", "name": "New Rochelle Irish", "venue": "Emerald Waters Aquatic Center", "mascot": "Irish", "city": "New Rochelle, New York", "c1": "6f2c3f", "c2": "f2a900", "conf": "NWPC", "ovr": 66, "off": 68, "def": 64, "prestige": 38, "pool": "harbor", "mark": "I", "logo": "block"},
	{"short": "LIUB", "name": "Brooklyn Hammerheads", "venue": "Hammerhead Harbor Natatorium", "mascot": "Hammerheads", "city": "Brooklyn, New York", "c1": "0a3d8f", "c2": "ffc72c", "conf": "NWPC", "ovr": 65, "off": 63, "def": 67, "prestige": 36, "pool": "harbor", "mark": "L", "logo": "circle"},
]

## THE DIVISION II & III EXPANSION. These conferences and schools are separate from the thirty above
## on purpose: CONFERENCES and SCHOOLS stay exactly the Division I game (the Road to Glory tiers, the
## first thirty's saves and dice), and a career only holds the divisions it has switched on
## (Career.divisions). Their ids never match a Division I conference's: this NWPC is NEWPC and
## this MPSF East is MPSFE, because Division I's old ids "NWPC" and "MPSF" are the NCC and the PEC.
## `div` is the division. Their `tier` only sets the prestige ceiling (Offseason._prestige): a
## middle one, so no school is held down for being Division II or III. `tourney` false: a
## conference with too few schools for a tournament.
const EXPANSION_CONFERENCES := [
	{"id": "WWPA", "name": "Western Water Polo Association", "abbr": "WWPA", "tier": 3, "region": "west", "rr": 1, "div": 2},
	{"id": "SCIAC", "name": "Southern California Intercollegiate Athletic Conference", "abbr": "SCIAC", "tier": 3, "region": "west", "rr": 1, "div": 3},
	{"id": "MPSFE", "name": "Mountain Pacific Sports Federation - East", "abbr": "MPSF EAST", "tier": 3, "region": "east", "rr": 1, "div": 3},
	{"id": "NEWPC", "name": "Northeast Water Polo Conference", "abbr": "NWPC", "tier": 3, "region": "east", "rr": 1, "div": 3},
]

## The 24 expansion schools. `ovr` and `t_off` / `t_def` / `t_gk` (stars) are only the first roster's
## targets (CollegeGen.make_expansion_roster); after that the players decide everything, as for
## the thirty. `venue` is the real home pool. `real`, `rpi` and `rec` are the research behind the
## targets: only the Developer Mode's DIVISION EXPANSION TESTING screen ever shows them.
const EXPANSION_SCHOOLS := [
	{"short": "D2_01", "name": "La Mirada Falcons", "venue": "Splash! La Mirada Regional Aquatics Center", "mascot": "Falcons", "city": "La Mirada, California", "c1": "c8102e", "c2": "ffffff", "conf": "WWPA", "div": 2, "ovr": 65, "t_off": 3.0, "t_def": 3.0, "t_gk": 3.0, "prestige": 36, "pool": "harbor", "mark": "LM", "logo": "interlock", "real": "Biola University", "rpi": 37, "rec": "8-21"},
	{"short": "D2_02", "name": "Irvine Goldhawks", "venue": "William Woollett Jr. Aquatics Center", "mascot": "Goldhawks", "city": "Irvine, California", "c1": "00573d", "c2": "f2b705", "conf": "WWPA", "div": 2, "ovr": 72, "t_off": 3.5, "t_def": 3.5, "t_gk": 3.5, "prestige": 51, "pool": "harbor", "mark": "I", "logo": "block", "real": "Concordia University Irvine", "rpi": 26, "rec": "20-13"},
	{"short": "D2_03", "name": "Fresno Firebirds", "venue": "Sunnyside Aquatics Center", "mascot": "Firebirds", "city": "Fresno, California", "c1": "0b3d91", "c2": "f47a1f", "conf": "WWPA", "div": 2, "ovr": 60, "t_off": 2.5, "t_def": 2.5, "t_gk": 2.5, "prestige": 26, "pool": "harbor", "mark": "FP", "logo": "interlock", "real": "Fresno Pacific University", "rpi": 45, "rec": "5-19"},
	{"short": "D2_04", "name": "Erie Golden Sentinels", "venue": "Carneval Athletic Pavilion Aquatic Center", "mascot": "Golden Sentinels", "city": "Erie, Pennsylvania", "c1": "7a1f2b", "c2": "d4a72c", "conf": "WWPA", "div": 2, "ovr": 66, "t_off": 3.0, "t_def": 3.0, "t_gk": 3.0, "prestige": 38, "pool": "harbor", "mark": "E", "logo": "shield", "real": "Gannon University", "rpi": 35, "rec": "13-10"},
	{"short": "D2_05", "name": "Lebanon Clawcats", "venue": "McKendree Metro Rec Plex", "mascot": "Clawcats", "city": "Lebanon, Illinois", "c1": "4b2e83", "c2": "ffffff", "conf": "WWPA", "div": 2, "ovr": 67, "t_off": 3.0, "t_def": 3.0, "t_gk": 3.0, "prestige": 40, "pool": "harbor", "mark": "LC", "logo": "interlock", "real": "McKendree University", "rpi": 33, "rec": "10-13"},
	{"short": "D2_06", "name": "Salem Sabertooths", "venue": "The Bridge Sports Complex", "mascot": "Sabertooths", "city": "Salem, West Virginia", "c1": "1e6b3a", "c2": "ffffff", "conf": "WWPA", "div": 2, "ovr": 68, "t_off": 3.5, "t_def": 3.0, "t_gk": 3.0, "prestige": 42, "pool": "harbor", "mark": "S", "logo": "block", "real": "Salem University", "rpi": 32, "rec": "15-15"},
	{"short": "D2_07", "name": "Merced Lynx", "venue": "UC Merced Aquatics Center", "mascot": "Lynx", "city": "Merced, California", "c1": "0a2f6b", "c2": "f2b62b", "conf": "WWPA", "div": 2, "ovr": 58, "t_off": 2.5, "t_def": 2.5, "t_gk": 2.0, "prestige": 22, "pool": "harbor", "mark": "M", "logo": "circle", "real": "University of California, Merced", "rpi": 48, "rec": "4-18"},

	{"short": "D3_01", "name": "Pasadena Woodchucks", "venue": "Braun Pool", "mascot": "Woodchucks", "city": "Pasadena, California", "c1": "ff6c0c", "c2": "ffffff", "conf": "SCIAC", "div": 3, "ovr": 46, "t_off": 2.0, "t_def": 2.0, "t_gk": 1.5, "prestige": 15, "pool": "harbor", "mark": "CP", "logo": "interlock", "real": "California Institute of Technology", "rpi": 52, "rec": "1-16"},
	{"short": "D3_02", "name": "Thousand Oaks Royals", "venue": "Samuelson Aquatics Center", "mascot": "Royals", "city": "Thousand Oaks, California", "c1": "4a2a86", "c2": "f2b21b", "conf": "SCIAC", "div": 3, "ovr": 66, "t_off": 3.0, "t_def": 3.0, "t_gk": 3.0, "prestige": 38, "pool": "harbor", "mark": "TO", "logo": "interlock", "real": "California Lutheran University", "rpi": 36, "rec": "12-12"},
	{"short": "D3_03", "name": "Orange Pumas", "venue": "Allred Aquatics Center", "mascot": "Pumas", "city": "Orange, California", "c1": "7a0f27", "c2": "a7a9ac", "conf": "SCIAC", "div": 3, "ovr": 64, "t_off": 3.0, "t_def": 2.5, "t_gk": 3.0, "prestige": 34, "pool": "harbor", "mark": "O", "logo": "block", "real": "Chapman University", "rpi": 41, "rec": "9-18"},
	{"short": "D3_04", "name": "Claremont Bucks", "venue": "Axelrood Pool", "mascot": "Bucks", "city": "Claremont, California", "c1": "6b1d2c", "c2": "d6a21e", "conf": "SCIAC", "div": 3, "ovr": 77, "t_off": 3.5, "t_def": 4.0, "t_gk": 4.0, "prestige": 61, "pool": "harbor", "mark": "CB", "logo": "interlock", "real": "Claremont-Mudd-Scripps Colleges", "rpi": 18, "rec": "22-5"},
	{"short": "D3_05", "name": "Los Angeles Wildcats", "venue": "De Mandel Aquatics Center", "mascot": "Wildcats", "city": "Los Angeles, California", "c1": "f26a21", "c2": "151515", "conf": "SCIAC", "div": 3, "ovr": 65, "t_off": 3.0, "t_def": 3.0, "t_gk": 3.0, "prestige": 36, "pool": "harbor", "mark": "LA", "logo": "interlock", "real": "Occidental College", "rpi": 40, "rec": "9-19"},
	{"short": "D3_06", "name": "Claremont Sagebirds", "venue": "Haldeman Pool", "mascot": "Sagebirds", "city": "Claremont, California", "c1": "0a4f9e", "c2": "f08a24", "conf": "SCIAC", "div": 3, "ovr": 74, "t_off": 3.5, "t_def": 3.5, "t_gk": 3.5, "prestige": 55, "pool": "harbor", "mark": "CS", "logo": "interlock", "real": "Pomona-Pitzer Colleges", "rpi": 23, "rec": "19-13"},
	{"short": "D3_07", "name": "La Verne Jaguars", "venue": "Las Flores Park Aquatics Center", "mascot": "Jaguars", "city": "La Verne, California", "c1": "1f6b45", "c2": "f08a1d", "conf": "SCIAC", "div": 3, "ovr": 61, "t_off": 2.5, "t_def": 2.5, "t_gk": 2.5, "prestige": 28, "pool": "harbor", "mark": "LV", "logo": "interlock", "real": "University of La Verne", "rpi": 44, "rec": "4-16"},
	{"short": "D3_08", "name": "Redlands Mastiffs", "venue": "Thompson Aquatic Center", "mascot": "Mastiffs", "city": "Redlands, California", "c1": "7b1e3a", "c2": "b1b3b3", "conf": "SCIAC", "div": 3, "ovr": 67, "t_off": 3.0, "t_def": 3.5, "t_gk": 3.0, "prestige": 40, "pool": "harbor", "mark": "R", "logo": "block", "real": "University of Redlands", "rpi": 34, "rec": "10-19"},
	{"short": "D3_09", "name": "Whittier Bards", "venue": "Lillian Slade Aquatics Center", "mascot": "Bards", "city": "Whittier, California", "c1": "5b2a86", "c2": "eeb111", "conf": "SCIAC", "div": 3, "ovr": 70, "t_off": 3.0, "t_def": 3.5, "t_gk": 3.5, "prestige": 46, "pool": "harbor", "mark": "W", "logo": "shield", "real": "Whittier College", "rpi": 29, "rec": "12-10"},

	{"short": "D3_10", "name": "Rock Island Norsemen", "venue": "Anne Greve Lund Natatorium", "mascot": "Norsemen", "city": "Rock Island, Illinois", "c1": "0b2a5b", "c2": "f0b323", "conf": "MPSFE", "div": 3, "ovr": 69, "t_off": 3.5, "t_def": 3.0, "t_gk": 3.0, "prestige": 44, "pool": "harbor", "mark": "RI", "logo": "interlock", "real": "Augustana College", "rpi": 30, "rec": "16-8"},
	{"short": "D3_11", "name": "Sherman Wallabies", "venue": "Hannah Natatorium", "mascot": "Wallabies", "city": "Sherman, Texas", "c1": "4e2a84", "c2": "e8b020", "conf": "MPSFE", "div": 3, "ovr": 62, "t_off": 2.5, "t_def": 3.0, "t_gk": 2.5, "prestige": 30, "pool": "harbor", "mark": "S", "logo": "circle", "real": "Austin College", "rpi": 43, "rec": "7-11"},
	{"short": "D3_12", "name": "New London Dromedaries", "venue": "Lott Natatorium", "mascot": "Dromedaries", "city": "New London, Connecticut", "c1": "0b3a7a", "c2": "ffffff", "conf": "MPSFE", "div": 3, "ovr": 54, "t_off": 2.0, "t_def": 2.5, "t_gk": 2.5, "prestige": 15, "pool": "harbor", "mark": "NL", "logo": "interlock", "real": "Connecticut College", "rpi": 50, "rec": "6-14"},
	{"short": "D3_13", "name": "Baltimore Bluewings", "venue": "Barbara & Jerry Procton Pool", "mascot": "Bluewings", "city": "Baltimore, Maryland", "c1": "0f4d92", "c2": "ffffff", "conf": "MPSFE", "div": 3, "ovr": 71, "t_off": 3.5, "t_def": 3.5, "t_gk": 3.0, "prestige": 49, "pool": "harbor", "mark": "B", "logo": "shield", "real": "Johns Hopkins University", "rpi": 27, "rec": "20-7"},
	{"short": "D3_14", "name": "Erie Cougars", "venue": "Junker Center Pool", "mascot": "Cougars", "city": "Erie, Pennsylvania", "c1": "1a3f7a", "c2": "ffffff", "conf": "MPSFE", "div": 3, "ovr": 59, "t_off": 2.5, "t_def": 2.5, "t_gk": 2.5, "prestige": 24, "pool": "harbor", "mark": "EC", "logo": "interlock", "real": "Penn State Behrend", "rpi": 46, "rec": "9-19"},
	{"short": "D3_15", "name": "Washington Statesmen", "venue": "Henry Memorial Natatorium", "mascot": "Statesmen", "city": "Washington, Pennsylvania", "c1": "b3121d", "c2": "151515", "conf": "MPSFE", "div": 3, "ovr": 49, "t_off": 2.0, "t_def": 2.0, "t_gk": 2.0, "prestige": 15, "pool": "harbor", "mark": "W", "logo": "angled", "real": "Washington & Jefferson College", "rpi": 51, "rec": "2-19"},
	{"short": "D3_16", "name": "Norton Lionhearts", "venue": "Balfour Natatorium", "mascot": "Lionhearts", "city": "Norton, Massachusetts", "c1": "1a5aa8", "c2": "ffffff", "conf": "MPSFE", "div": 3, "ovr": 44, "t_off": 1.5, "t_def": 2.0, "t_gk": 1.5, "prestige": 15, "pool": "harbor", "mark": "N", "logo": "shield", "real": "Wheaton College, Massachusetts", "rpi": 53, "rec": "1-20"},

	{"short": "D3_17", "name": "Cambridge Mechanics", "venue": "Zesiger Center Pool", "mascot": "Mechanics", "city": "Cambridge, Massachusetts", "c1": "a31f34", "c2": "8a8b8c", "c3": "ffffff", "conf": "NEWPC", "div": 3, "ovr": 65, "t_off": 3.0, "t_def": 3.0, "t_gk": 3.0, "prestige": 36, "pool": "harbor", "mark": "CM", "logo": "interlock", "real": "Massachusetts Institute of Technology", "rpi": 39, "rec": "8-20"},
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
	# (only schools in this dynasty count: a Division I save's names never change for a pack it
	# doesn't play. No career open: the thirty, and an expansion school against all 54.)
	var here: Array = SCHOOLS if division_of(t.id) == D1 else all_schools()
	if Game.career != null:
		here = all_schools().filter(func(o): return Game.career.teams.has(String(o.short)))
	var shared := here.filter(func(o): return place(String(o.short)) == p).size() > 1
	return t.name if shared else p

## A school's own home pool's name (the Home Waters update: "Hammerhead Harbor Natatorium"),
## fixed in the school's data, never generated; "" for a team that isn't a school.
static func venue_name(id: String) -> String:
	return String(school(id).get("venue", ""))

## A school by id, {} for an id that isn't one.
static func school(id: String) -> Dictionary:
	for list in [SCHOOLS, EXPANSION_SCHOOLS]:
		for s in list:
			if s.short == id:
				return s
	return {}

## All 54 schools: the thirty, then the expansion's.
static func all_schools() -> Array:
	return SCHOOLS + EXPANSION_SCHOOLS

## Every current conference, Division I's first.
static func all_conferences() -> Array:
	return CONFERENCES + EXPANSION_CONFERENCES

## The schools of division `d` (D1, D2 or D3).
static func schools_of(d: int) -> Array:
	return SCHOOLS.duplicate() if d == D1 else EXPANSION_SCHOOLS.filter(func(s): return int(s.div) == d)

## A conference's division: 1 unless it's one of the expansion's.
static func division(conf: String) -> int:
	return int(conference(conf).get("div", D1))

## A school's division: 1 unless it's one of the expansion's.
static func division_of(id: String) -> int:
	return int(school(id).get("div", D1))

## "DIVISION II", for the screens.
static func division_name(d: int) -> String:
	return String(DIVISION_NAMES.get(d, ""))

static func conference(id: String) -> Dictionary:
	for list in [CONFERENCES, EXPANSION_CONFERENCES, LEGACY_CONFERENCES]:
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
	var out: Array = _by_tier(CONFERENCES + LEGACY_CONFERENCES).filter(func(cid): return ids.has(cid))
	for c in EXPANSION_CONFERENCES:   # (after the thirty's: they keep their order, and their dice)
		if ids.has(c.id):
			out.append(c.id)
	return out

static func _by_tier(list: Array) -> Array:
	var out: Array = list.duplicate()
	out.sort_custom(func(a, b): return a.tier < b.tier)
	return out.map(func(c): return c.id)

static func schools_in(conf: String) -> Array:
	return all_schools().filter(func(s): return s.conf == conf)
