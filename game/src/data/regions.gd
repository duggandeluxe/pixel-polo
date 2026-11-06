class_name Regions
## Where players come from and where the schools are, for recruiting: a prospect's hometown,
## how far a school is from it (the DISTANCE / LOCATION preference) and recruiting pipelines.
## Ten home regions plus overseas; `at` is a rough [longitude, latitude] for the distance.

const LIST := {
	"SOCAL": {"name": "Southern California", "at": [-118.0, 34.0], "w": 32,
		"towns": ["Newport Beach", "Huntington Beach", "Laguna Beach", "San Clemente", "Long Beach", "Irvine",
			"Mission Viejo", "La Jolla", "Coronado", "Santa Barbara", "Pasadena", "Palos Verdes", "Manhattan Beach",
			"Ventura", "Oceanside", "Corona del Mar", "Westlake Village", "Fullerton"], "st": "CA"},
	"NORCAL": {"name": "Northern California", "at": [-122.0, 37.8], "w": 24,
		"towns": ["Palo Alto", "Menlo Park", "Walnut Creek", "San Mateo", "Davis", "Sacramento", "Santa Cruz",
			"Los Gatos", "Orinda", "Danville", "Stockton", "Novato", "Monterey", "Granite Bay"], "st": "CA"},
	"PACNW": {"name": "Pacific Northwest", "at": [-122.5, 46.0], "w": 4,
		"towns": ["Seattle", "Portland", "Bellevue", "Tacoma", "Eugene"], "st": "WA"},
	"MOUNTAIN": {"name": "Mountain West", "at": [-105.5, 39.5], "w": 3,
		"towns": ["Denver", "Boulder", "Colorado Springs", "Salt Lake City", "Phoenix"], "st": "CO"},
	"TEXAS": {"name": "Texas", "at": [-97.0, 30.5], "w": 5,
		"towns": ["Austin", "Houston", "Dallas", "San Antonio", "The Woodlands"], "st": "TX"},
	"MIDWEST": {"name": "Midwest", "at": [-88.0, 42.0], "w": 4,
		"towns": ["Chicago", "Naperville", "Ann Arbor", "Columbus", "Indianapolis"], "st": "IL"},
	"NEAST": {"name": "Northeast", "at": [-73.5, 41.2], "w": 7,
		"towns": ["Brooklyn", "Greenwich", "Princeton", "Boston", "Providence", "Long Island", "Westchester"], "st": "NY"},
	"MIDATL": {"name": "Mid-Atlantic", "at": [-77.0, 39.3], "w": 5,
		"towns": ["Bethesda", "Annapolis", "Arlington", "Philadelphia", "Baltimore", "Pittsburgh"], "st": "MD"},
	"SOUTHEAST": {"name": "Southeast", "at": [-81.5, 28.5], "w": 5,
		"towns": ["Fort Lauderdale", "Miami", "Orlando", "Atlanta", "Tampa"], "st": "FL"},
	"HAWAII": {"name": "Hawaii", "at": [-157.8, 21.3], "w": 3,
		"towns": ["Honolulu", "Kailua", "Hilo"], "st": "HI"},
	"INTL": {"name": "Overseas", "at": [], "w": 8,
		"towns": ["Belgrade", "Budapest", "Zagreb", "Athens", "Barcelona", "Naples", "Sydney", "Toronto", "Rotterdam"], "st": ""},
}
## Southern California's schools (every other California school is in the north).
const SOCAL_CITIES := ["Long Beach", "San Diego", "Irvine", "Riverside", "Santa Barbara", "Fullerton", "Malibu", "Los Marina"]
const STATE_REGION := {"California": "NORCAL", "Colorado": "MOUNTAIN", "New York": "NEAST", "New Jersey": "NEAST",
	"Massachusetts": "NEAST", "Rhode Island": "NEAST", "Maryland": "MIDATL", "D.C.": "MIDATL", "Pennsylvania": "MIDATL"}
## Miles at which DISTANCE stops mattering (the far coast scores zero).
const FAR_MILES := 2600.0
## An overseas prospect is as far from every school.
const INTL_CLOSE := 0.3

static var _school_cache := {}

## The region a school is in, from its city; a school from an old save's world counts as the West.
static func of_school(id: String) -> String:
	if not _school_cache.has(id):
		_school_cache[id] = _school_region(id)
	return _school_cache[id]

static func _school_region(id: String) -> String:
	var city := String(Colleges.school(id).get("city", ""))
	if city == "":
		return "NORCAL"
	var parts := city.split(", ")
	var state := parts[parts.size() - 1]
	if state == "California" and parts[0] in SOCAL_CITIES:
		return "SOCAL"
	return String(STATE_REGION.get(state, "NORCAL"))

## A home region, weighted by where the sport's players come from.
static func random_region(rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in LIST:
		total += int(LIST[k].w)
	var r := rng.randi() % total
	for k in LIST:
		r -= int(LIST[k].w)
		if r < 0:
			return k
	return "SOCAL"

## "Newport Beach, CA" (a city abroad has no state).
static func random_town(rng: RandomNumberGenerator, region: String) -> String:
	var info: Dictionary = LIST.get(region, LIST["SOCAL"])
	var towns: Array = info.towns
	var town: String = towns[rng.randi() % towns.size()]
	return town if String(info.st) == "" else "%s, %s" % [town, info.st]

static func name_of(region: String) -> String:
	return String(LIST.get(region, {}).get("name", region))

## 0..1: how close a school in `school_region` is to home (1 = the same region).
static func closeness(home: String, school_region: String) -> float:
	if home == "INTL" or not LIST.has(home):
		return INTL_CLOSE
	if home == school_region:
		return 1.0
	return clampf(1.0 - miles(home, school_region) / FAR_MILES, 0.0, 1.0)

static func miles(a: String, b: String) -> float:
	var pa: Array = LIST.get(a, {}).get("at", [])
	var pb: Array = LIST.get(b, {}).get("at", [])
	if pa.is_empty() or pb.is_empty():
		return FAR_MILES
	var lat := deg_to_rad((float(pa[1]) + float(pb[1])) * 0.5)
	var dx := (float(pa[0]) - float(pb[0])) * 69.0 * cos(lat)
	var dy := (float(pa[1]) - float(pb[1])) * 69.0
	return sqrt(dx * dx + dy * dy)
