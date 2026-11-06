class_name PoolDef
extends RefCounted
## One venue's look, read by PoolArt. Built from a Pools.DEFS entry.

var id := ""
var name := ""
var indoor := true
var deck := Color("e5e0d1")
var deck_dark := Color("c9c2ae")
var water := Color("0869f5")
var water_deep := Color("075ddc")
var water_shine := Color("1688ff")
var tile_line := Color("0751bd")
var stands := Color("141c36")
var stands_rail := Color("8b9bc2")
var stands_edge := Color("3b5a9a")
var roof := Color("141c36")
var rows := 4

const COLOR_KEYS := ["deck", "deck_dark", "water", "water_deep", "water_shine", "tile_line",
	"stands", "stands_rail", "stands_edge", "roof"]

## `base` fills in anything `d` leaves out.
static func from_dict(base: Dictionary, d: Dictionary) -> PoolDef:
	var p := PoolDef.new()
	var merged := base.duplicate()
	merged.merge(d, true)
	p.id = String(merged.get("id", ""))
	p.name = String(merged.get("name", ""))
	p.indoor = bool(merged.get("indoor", true))
	p.rows = clampi(int(merged.get("rows", 4)), 1, 6)
	for k in COLOR_KEYS:
		if merged.has(k):
			p.set(k, Color(String(merged[k])))
	return p
