class_name Pools
## The venues. Players never edit a pool: each school has exactly one home pool, picked
## here, and a match is drawn in the home team's pool. New pools are added to DEFS by
## hand (a designer's job), then given to schools in Colleges.SCHOOLS.
##
## Every key is optional except id/name; anything left out falls back to DEFAULT_ID's
## value. Colours are hex strings. `rows` is how many rows of seats the grandstand has
## (1-6); `roof` is the colour of the wall/sky band above the stands.

const DEFAULT_ID := "harbor"

const DEFS := {
	"harbor": {
		"id": "harbor",
		"name": "Harbor Natatorium",
		"indoor": true,
		"deck": "e5e0d1",
		"deck_dark": "c9c2ae",
		"water": "0869f5",
		"water_deep": "075ddc",
		"water_shine": "1688ff",
		"tile_line": "0751bd",
		"stands": "141c36",
		"stands_rail": "8b9bc2",
		"stands_edge": "3b5a9a",
		"roof": "141c36",
		"rows": 4,
	},
}

static var _cache: Dictionary = {}

static func has(id: String) -> bool:
	return DEFS.has(id)

static func ids() -> Array:
	return DEFS.keys()

## The pool for `id`, or the default pool if that id doesn't exist (yet).
static func get_def(id: String = DEFAULT_ID) -> PoolDef:
	if not DEFS.has(id):
		id = DEFAULT_ID
	if not _cache.has(id):
		_cache[id] = PoolDef.from_dict(DEFS[DEFAULT_ID], DEFS[id])
	return _cache[id]
