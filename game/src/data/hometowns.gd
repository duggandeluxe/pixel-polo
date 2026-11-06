class_name Hometowns
## PLAYER HOMETOWNS (the Hometown & Appearance update): where a player is from, "City, State" for
## an American, "City, Country" for an international, kept on the player for good (PoloPlayer.home:
## a transfer, a new season or a reload never changes it).
##
## About 70% American, 30% international (INTL_SHARE). Americans by STATES' weights (California the
## most), internationals by COUNTRIES' (the water polo nations first), a city from that place's
## list. These are the game's own design targets, not real demographics. A school's starting roster
## (CollegeGen.give_home with its id) leans a little local: once a player is American, LOCAL_SHARE
## of the time he's from the school's own area (LOCAL: its state and the ones beside it). Recruits
## and everyone else use the broad pool. Nothing here touches a rating, a price or a portrait:
## where a player is from is his identity only (his skin tone is drawn separately, the same for
## everybody: PoloPlayer.random_skin).
##
## Spellings are plain ASCII (the pixel font's letters): Nis, Sao Paulo.

const INTL_SHARE := 0.30
const LOCAL_SHARE := 0.30

## [state, weight, cities]; "Other States" share their 12 between the rest.
const STATES := [
	["California", 45.0, []],   # (NORCAL + SOCAL below)
	["Texas", 12.0, ["Houston", "Austin", "Dallas", "San Antonio", "Katy", "Cypress", "The Woodlands", "Plano", "Sugar Land", "Fort Worth"]],
	["Florida", 8.0, ["Miami", "Tampa", "Orlando", "Fort Lauderdale", "Boca Raton", "Jacksonville", "Sarasota", "Coral Gables"]],
	["New York", 7.0, ["Brooklyn", "Queens", "Bronx", "Staten Island", "Manhattan", "Westchester", "Buffalo", "Rochester"]],
	["Illinois", 5.0, ["Chicago", "Naperville", "Evanston", "Oak Park", "Hinsdale", "Wheaton"]],
	["Pennsylvania", 4.0, ["Philadelphia", "Pittsburgh", "Bethlehem", "Lancaster", "Erie", "State College"]],
	["New Jersey", 4.0, ["Princeton", "Montclair", "Hoboken", "Summit", "Morristown", "Newark"]],
	["Nevada", 3.0, ["Las Vegas", "Henderson", "Reno"]],
]
const OTHER_US := 12.0
const OTHER_STATES := {
	"Arizona": ["Phoenix", "Scottsdale", "Tucson"], "Colorado": ["Denver", "Boulder", "Colorado Springs"],
	"Washington": ["Seattle", "Bellevue", "Tacoma"], "Oregon": ["Portland", "Eugene", "Bend"],
	"Hawaii": ["Honolulu", "Kailua", "Hilo"], "Utah": ["Salt Lake City", "Provo", "Park City"],
	"Maryland": ["Annapolis", "Bethesda", "Baltimore"], "Virginia": ["Arlington", "Alexandria", "Richmond"],
	"Massachusetts": ["Boston", "Cambridge", "Newton"], "Connecticut": ["Greenwich", "Stamford", "New Haven"],
	"Rhode Island": ["Providence", "Newport", "Warwick"], "Georgia": ["Atlanta", "Savannah", "Marietta"],
	"Ohio": ["Columbus", "Cincinnati", "Cleveland"], "Michigan": ["Ann Arbor", "Detroit", "Grand Rapids"],
	"Minnesota": ["Minneapolis", "St. Paul", "Edina"], "D.C.": ["Washington"],
}
## California, north and south (a Northern California school leans north).
const NORCAL := ["Sacramento", "San Jose", "Palo Alto", "Berkeley", "Menlo Park", "Walnut Creek", "Davis", "Santa Cruz",
	"San Mateo", "Orinda", "Danville", "Los Gatos", "Stockton", "Monterey", "Oakland", "Fremont"]
const SOCAL := ["Los Angeles", "Newport Beach", "Huntington Beach", "Irvine", "Long Beach", "San Diego", "Santa Barbara",
	"Pasadena", "Rancho Cucamonga", "Santa Monica", "Laguna Beach", "San Clemente", "Mission Viejo", "Manhattan Beach",
	"Coronado", "Ventura", "Oceanside", "Fullerton", "Riverside", "Malibu"]
## [country, weight, cities]; "Other countries" share their 12.
const COUNTRIES := [
	["Serbia", 18.0, ["Belgrade", "Novi Sad", "Nis", "Kragujevac", "Subotica"]],
	["Croatia", 16.0, ["Split", "Dubrovnik", "Zagreb", "Rijeka", "Zadar", "Sibenik"]],
	["Hungary", 13.0, ["Budapest", "Szeged", "Debrecen", "Eger", "Pecs", "Gyor"]],
	["Montenegro", 10.0, ["Kotor", "Herceg Novi", "Budva", "Podgorica", "Bar"]],
	["Italy", 9.0, ["Rome", "Naples", "Genoa", "Florence", "Savona", "Recco", "Palermo"]],
	["Spain", 8.0, ["Barcelona", "Madrid", "Valencia", "Sabadell", "Terrassa", "Seville"]],
	["Greece", 8.0, ["Athens", "Piraeus", "Thessaloniki", "Patras", "Chania"]],
	["Australia", 6.0, ["Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide"]],
]
const OTHER_INTL := 12.0
const OTHER_COUNTRIES := {
	"Germany": ["Berlin", "Hanover", "Duisburg"], "France": ["Marseille", "Paris", "Nice"],
	"Netherlands": ["Amsterdam", "Rotterdam", "Utrecht"], "Canada": ["Toronto", "Montreal", "Calgary"],
	"Brazil": ["Rio de Janeiro", "Sao Paulo"], "Argentina": ["Buenos Aires", "Cordoba"],
	"Japan": ["Tokyo", "Osaka"], "South Africa": ["Cape Town", "Durban"], "Nigeria": ["Lagos", "Abuja"],
	"Ghana": ["Accra", "Kumasi"],
}
## A school's area, by its state ("CA-N" / "CA-S": California's halves): the places a local player
## comes from.
const LOCAL := {
	"CA-N": [["California", NORCAL]], "CA-S": [["California", SOCAL]],
	"Colorado": [["Colorado", ["Denver", "Boulder", "Colorado Springs"]], ["Utah", ["Salt Lake City", "Provo"]]],
	"New York": [["New York", ["Brooklyn", "Queens", "Bronx", "Staten Island", "Manhattan", "Westchester"]], ["New Jersey", ["Hoboken", "Montclair", "Newark"]]],
	"New Jersey": [["New Jersey", ["Princeton", "Montclair", "Hoboken", "Summit", "Morristown"]], ["New York", ["Brooklyn", "Staten Island", "Manhattan"]], ["Pennsylvania", ["Philadelphia"]]],
	"Pennsylvania": [["Pennsylvania", ["Philadelphia", "Pittsburgh", "Bethlehem", "Lancaster", "Erie", "State College"]], ["New Jersey", ["Princeton", "Summit"]]],
	"Maryland": [["Maryland", ["Annapolis", "Bethesda", "Baltimore", "Columbia"]], ["Virginia", ["Arlington", "Alexandria"]], ["D.C.", ["Washington"]]],
	"D.C.": [["D.C.", ["Washington"]], ["Maryland", ["Bethesda", "Annapolis"]], ["Virginia", ["Arlington", "Alexandria"]]],
	"Massachusetts": [["Massachusetts", ["Boston", "Cambridge", "Newton", "Wellesley"]], ["Rhode Island", ["Providence"]], ["Connecticut", ["Greenwich"]]],
	"Illinois": [["Illinois", ["Chicago", "Naperville", "Peoria", "Springfield"]], ["Missouri", ["St. Louis"]]],
	"West Virginia": [["West Virginia", ["Morgantown", "Charleston", "Clarksburg"]], ["Pennsylvania", ["Pittsburgh"]], ["Ohio", ["Columbus"]]],
	"Connecticut": [["Connecticut", ["New Haven", "Greenwich", "Hartford", "Stamford"]], ["Rhode Island", ["Providence"]], ["Massachusetts", ["Boston"]]],
	"Texas": [["Texas", ["Dallas", "Plano", "Austin", "Houston"]], ["Oklahoma", ["Tulsa"]]],
	"Rhode Island": [["Rhode Island", ["Providence", "Newport", "Warwick"]], ["Massachusetts", ["Boston", "Cambridge"]], ["Connecticut", ["New Haven"]]],
}
## Old saves wrote "Newport Beach, CA": the states as the screens show them now.
const OLD_ST := {"CA": "California", "WA": "Washington", "CO": "Colorado", "TX": "Texas", "IL": "Illinois",
	"NY": "New York", "MD": "Maryland", "FL": "Florida", "HI": "Hawaii"}

## A hometown: "City, State" or "City, Country". `school`: a school's id for its starting roster's
## local lean ("": the broad pool). Its dice are `rng`'s.
static func pick(rng: RandomNumberGenerator, school: String = "") -> String:
	if rng.randf() < INTL_SHARE:
		return _from(rng, COUNTRIES, OTHER_INTL, OTHER_COUNTRIES)
	var area := area_of(school)
	if area != "" and rng.randf() < LOCAL_SHARE:
		var places: Array = LOCAL[area]
		var place: Array = places[rng.randi() % places.size()]
		var cities: Array = place[1]
		return _join(String(cities[rng.randi() % cities.size()]), String(place[0]))
	return _from(rng, STATES, OTHER_US, OTHER_STATES)

## The weighted place, then a city of it.
static func _from(rng: RandomNumberGenerator, list: Array, other_w: float, others: Dictionary) -> String:
	var total := other_w
	for e in list:
		total += float(e[1])
	var r := rng.randf() * total
	for e in list:
		r -= float(e[1])
		if r < 0.0:
			var cities: Array = e[2]
			if String(e[0]) == "California":
				cities = SOCAL if rng.randf() < 0.55 else NORCAL
			return _join(String(cities[rng.randi() % cities.size()]), String(e[0]))
	var keys: Array = others.keys()
	var k: String = keys[rng.randi() % keys.size()]
	var oc: Array = others[k]
	return _join(String(oc[rng.randi() % oc.size()]), k)

static func _join(city: String, place: String) -> String:
	return "Washington, D.C." if place == "D.C." else "%s, %s" % [city, place]

## A school's area for the local lean (LOCAL's keys), "" for none (a quick-match club).
static func area_of(school: String) -> String:
	if school == "":
		return ""
	var city := String(Colleges.school(school).get("city", ""))
	if city == "":
		return ""
	var parts := city.split(", ")
	var st := parts[parts.size() - 1]
	if st == "California":
		return "CA-S" if parts[0] in Regions.SOCAL_CITIES else "CA-N"
	return st if LOCAL.has(st) else ""

## Is this hometown American (a US state, or D.C.)?
static func is_us(home: String) -> bool:
	var place := home.get_slice(", ", 1) if home.contains(", ") else ""
	if place in ["D.C.", "California"] or OLD_ST.has(place):
		return true
	for e in STATES:
		if String(e[0]) == place:
			return true
	return OTHER_STATES.has(place)

## The place part: "California", "Serbia" ("" with none).
static func place_of(home: String) -> String:
	if not home.contains(", "):
		return ""
	var place := home.get_slice(", ", 1)
	return String(OLD_ST.get(place, place))

## The old table (Regions) put one state on a whole region's towns ("Princeton, NY") and none on
## the towns abroad ("Belgrade"): their real places, for showing an old save's hometowns right.
const OLD_TOWNS := {"Portland": "Oregon", "Eugene": "Oregon", "Salt Lake City": "Utah", "Phoenix": "Arizona",
	"Ann Arbor": "Michigan", "Columbus": "Ohio", "Indianapolis": "Indiana", "Greenwich": "Connecticut",
	"Princeton": "New Jersey", "Boston": "Massachusetts", "Providence": "Rhode Island", "Arlington": "Virginia",
	"Philadelphia": "Pennsylvania", "Pittsburgh": "Pennsylvania", "Atlanta": "Georgia",
	"Belgrade": "Serbia", "Budapest": "Hungary", "Zagreb": "Croatia", "Athens": "Greece", "Barcelona": "Spain",
	"Naples": "Italy", "Sydney": "Australia", "Toronto": "Canada", "Rotterdam": "Netherlands"}

## As the screens show it: an old save's "Newport Beach, CA" as "Newport Beach, California", its
## "Princeton, NY" as "Princeton, New Jersey", its "Belgrade" as "Belgrade, Serbia" (only the words:
## the saved hometown stays exactly as it is). A hometown made since is shown as it is.
static func shown(home: String) -> String:
	var city := home.get_slice(", ", 0) if home.contains(", ") else home
	var place := home.get_slice(", ", 1) if home.contains(", ") else ""
	if place != "" and not OLD_ST.has(place):
		return home   # (written the new way already)
	if OLD_TOWNS.has(city):
		return "%s, %s" % [city, OLD_TOWNS[city]]
	return "%s, %s" % [city, OLD_ST[place]] if OLD_ST.has(place) else home
