extends RefCounted
## DEVELOPMENT TOOL, not a test: wrote src/data/record_book_data.gd, the permanent book every new
## dynasty starts from, and is kept so you can see how it was made. Running it again prints the
## file; nothing reads it at runtime (a book that came out of a generator at load time is what
## the Dynasty Refinement update replaced):
##   godot --headless --path game -- --test record_book_gen
## Same dice as the old Records.school_book / ncsa_book, so every value and name a save already
## has for the ten seeded records matches. career_assists / steals / blocks come after them, off
## their own dice.

const OLD_NCSA := {"game_goals": 6, "game_saves": 14, "game_team_goals": 16, "game_margin": 11,
	"season_goals": 62, "season_assists": 33, "season_saves": 185, "season_wins": 21,
	"career_goals": 180, "career_saves": 630}
const NEW_NCSA := {"career_assists": 120, "career_steals": 26, "career_blocks": 44}
const OLD_KEYS := ["game_goals", "game_saves", "game_team_goals", "game_margin",
	"season_goals", "season_assists", "season_saves", "season_wins", "career_goals", "career_saves"]

func run(_runner) -> void:
	var out := PackedStringArray()
	out.append("class_name RecordBook")
	out.append("## THE CANONICAL HISTORICAL RECORDS: every school's book and the NCSA's as they stand before any")
	out.append("## dynasty begins, the same in every save. Fixed data, generated once during development")
	out.append("## (tests/record_book_gen.gd), never at runtime. A record is [value, holder, year]. Records copies")
	out.append("## a book into a career on first use; breaking a record only ever touches that career's copy.")
	out.append("")
	out.append("const SCHOOLS := {")
	for s in Colleges.SCHOOLS:
		var id := String(s.short)
		var r := RandomNumberGenerator.new()
		r.seed = hash(id) + 77
		var row := PackedStringArray()
		for k in OLD_KEYS:
			var v := maxi(1, roundi(float(OLD_NCSA[k]) * (0.62 + float(s.prestige) / 300.0) * r.randf_range(0.9, 1.0)))
			var nm := CollegeGen.random_name(r)
			row.append(_rec(k, v, "%s. %s" % [String(nm[0]).substr(0, 1), nm[1]], r.randi_range(1984, 2024)))
		var r2 := RandomNumberGenerator.new()
		r2.seed = hash(id) + 78
		for k in NEW_NCSA:
			var v := maxi(1, roundi(float(NEW_NCSA[k]) * (0.62 + float(s.prestige) / 300.0) * r2.randf_range(0.9, 1.0)))
			var nm := CollegeGen.random_name(r2)
			row.append(_rec(k, v, "%s. %s" % [String(nm[0]).substr(0, 1), nm[1]], r2.randi_range(1984, 2024)))
		out.append("\t\"%s\": {%s}," % [id, ", ".join(row)])
	out.append("}")
	out.append("## Each is [value, holder, team, year].")
	out.append("const NCSA := {")
	var r := RandomNumberGenerator.new()
	r.seed = 4040
	var ids: Array = Colleges.SCHOOLS.map(func(s): return String(s.short))
	ids.sort()
	for k in OLD_KEYS:
		var nm := CollegeGen.random_name(r)
		var team: String = ids[r.randi() % ids.size()]
		out.append("\t\"%s\": [%d, \"%s. %s\", \"%s\", %d]," % [k, OLD_NCSA[k], String(nm[0]).substr(0, 1), nm[1], team, r.randi_range(1990, 2025)])
	var r3 := RandomNumberGenerator.new()
	r3.seed = 4041
	for k in NEW_NCSA:
		var nm := CollegeGen.random_name(r3)
		var team: String = ids[r3.randi() % ids.size()]
		out.append("\t\"%s\": [%d, \"%s. %s\", \"%s\", %d]," % [k, NEW_NCSA[k], String(nm[0]).substr(0, 1), nm[1], team, r3.randi_range(1990, 2025)])
	out.append("}")
	print("<<<BOOK")
	print("\n".join(out))
	print("BOOK>>>")

static func _rec(k: String, v: int, name: String, year: int) -> String:
	return "\"%s\": [%d, \"%s\", %d]" % [k, v, name, year]
