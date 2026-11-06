class_name Caps
## How a cap is drawn. There's no cap shop: every team wears CLASSIC (keepers always wear red, it's
## the rule). The other designs stay only so a multiplayer guest on an older build still draws.
##
## pattern: none | stripe | twin | band | checker | gold | chrome | champs
## base: a cap colour that replaces your team's usual light cap ("" keeps it).

const DEFAULT := "classic"
const DESIGNS := [
	{"id": "classic", "name": "CLASSIC", "base": "", "pattern": "none"},
	{"id": "stripe", "name": "CENTER STRIPE", "base": "", "pattern": "stripe"},
	{"id": "twin", "name": "TWIN STRIPES", "base": "", "pattern": "twin"},
	{"id": "band", "name": "RETRO BAND", "base": "", "pattern": "band"},
	{"id": "checker", "name": "CHECKER GUARDS", "base": "", "pattern": "checker"},
	{"id": "gold", "name": "GOLD TRIM", "base": "", "pattern": "gold"},
	{"id": "chrome", "name": "CHROME", "base": "c9d3dd", "pattern": "chrome"},
	{"id": "champs", "name": "CHAMPIONS", "base": "ffcf3f", "pattern": "champs"},
]

static func design(id: String) -> Dictionary:
	for d in DESIGNS:
		if d.id == id:
			return d
	return DESIGNS[0]

static func selected() -> String:
	return DEFAULT

static func base_color(id: String, team_cap: Color) -> Color:
	var b := String(design(id).base)
	return Color(b) if b != "" else team_cap

static func trim_color(id: String, team_trim: Color) -> Color:
	match String(design(id).pattern):
		"gold":
			return UI.GOLD
		"chrome":
			return Color("3b4a5c")
		"champs":
			return Color("f2f2e9")
	return team_trim
