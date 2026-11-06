extends RefCounted
## DEVELOPMENT TOOL, not a test: wrote RecordBook.EXPANSION (src/data/record_book_data.gd), the 24
## expansion schools' fixed books, by the same rule as the thirty's. Nothing reads it at runtime.
##   godot --headless --path game -- --test record_book_expansion_gen
const NCSA := {"game_goals": 6, "game_saves": 14, "game_team_goals": 16, "game_margin": 11,
	"season_goals": 62, "season_assists": 33, "season_saves": 185, "season_wins": 21,
	"career_goals": 180, "career_saves": 630, "career_assists": 120, "career_steals": 26, "career_blocks": 44}

func run(_runner) -> void:
	var out := PackedStringArray()
	out.append("## The Division II and III schools' books: the same shape, fixed the same way")
	out.append("## (tests/record_book_expansion_gen.gd).")
	out.append("const EXPANSION := {")
	for s in Colleges.EXPANSION_SCHOOLS:
		var id := String(s.short)
		var r := RandomNumberGenerator.new()
		r.seed = id.hash() + 79
		var row := PackedStringArray()
		for k in NCSA:
			var v := maxi(1, roundi(float(NCSA[k]) * (0.62 + float(s.prestige) / 300.0) * r.randf_range(0.9, 1.0)))
			var nm := CollegeGen.random_name(r)
			row.append("\"%s\": [%d, \"%s. %s\", %d]" % [k, v, String(nm[0]).substr(0, 1), nm[1], r.randi_range(1984, 2024)])
		out.append("\t\"%s\": {%s}," % [id, ", ".join(row)])
	out.append("}")
	print("<<<BOOK")
	print("\n".join(out))
	print("BOOK>>>")
