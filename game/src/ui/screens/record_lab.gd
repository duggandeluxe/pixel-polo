extends BaseScreen
## Developer Mode's RECORD ROOM ANIMATIONS (Settings > Developer Mode): every record celebration
## (RecordShow, exactly as the game summary plays it) and the Trophy Room in every arrangement,
## on demand, nothing to unlock first.
##   RECORD CELEBRATIONS  each record (Records.KEYS), as a new NCSA record or a new school record,
##                        made-up numbers just past its usual mark; TWO AT ONCE plays a school
##                        and an NCSA record back to back, as one game can; REPLAY the last
##   TROPHY ROOM          the room (trophy_room) for a made-up player with no honours, weekly
##                        plaques only, one major award, every national award, a full room, a
##                        maxed-out room (scrolling board and cabinet, every trophy, x3s), a
##                        keeper's, and an older save's season awards
## Isolated: the celebrations only draw what they're given; the Trophy Room gets its own
## throwaway career (Career.new_game, made here, never Game.career, never saved). No record,
## award, stat or save is touched. Motion plays even with Settings > Reduce motion on.

const KEY_VALUES := {"game_goals": [6, 8], "game_saves": [14, 17], "game_team_goals": [16, 19], "game_margin": [11, 14],
	"season_goals": [62, 66], "season_assists": [33, 37], "season_saves": [185, 192], "season_wins": [21, 23],
	"career_goals": [180, 187], "career_saves": [630, 644], "career_assists": [0, 96], "career_steals": [0, 71], "career_blocks": [0, 48]}
const TEAM_KEYS := ["game_team_goals", "game_margin", "season_wins"]
const ROOMS := [["NO AWARDS", "empty"], ["WEEKLY ONLY", "weekly"], ["ONE MAJOR", "one"], ["ALL NATIONAL", "national"],
	["FULL ROOM", "full"], ["MAXED OUT", "max"], ["GOALKEEPER", "keeper"], ["OLDER SAVE", "legacy"]]

static var _room: Career = null   # (the throwaway career, made once a session)
var last: Array = []

func _ready() -> void:
	build("RECORD ROOM ANIMATIONS")
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := UI.scroll(v)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	# the celebrations
	var head := UI.hbox(6)
	head.add_child(UI.label("RECORD CELEBRATIONS", 16, UI.GOLD, "big"))
	head.add_child(UI.spacer(0, 0, true))
	head.add_child(UI.button("TWO AT ONCE", func(): _play([_entry("game_goals", "school"), _entry("game_goals", "ncsa")]), "ghost", 90, 18))
	var rp := UI.button("REPLAY", func():
		if not last.is_empty():
			_play(last), "primary", 70, 18)
	rp.name = "Replay"
	head.add_child(rp)
	v.add_child(head)
	var grid := GridContainer.new()
	grid.name = "Records"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	for key in Records.KEYS:
		var l := UI.label(String(Records.NAMES[key]).to_upper(), 8, UI.TEXT, "caps")
		l.custom_minimum_size = Vector2(122, 0)
		l.clip_text = true
		grid.add_child(l)
		for lv in ["ncsa", "school"]:
			var b := UI.button(lv.to_upper(), func(): _play([_entry(key, lv)]), "ghost", 46, 16)
			b.name = "Play_%s_%s" % [key, lv]
			grid.add_child(b)
	v.add_child(grid)
	# the Trophy Room
	v.add_child(UI.spacer(0, 4))
	v.add_child(UI.label("TROPHY ROOM", 16, UI.GOLD, "big"))
	var rooms := GridContainer.new()
	rooms.name = "Rooms"
	rooms.columns = 4
	rooms.add_theme_constant_override("h_separation", 4)
	rooms.add_theme_constant_override("v_separation", 3)
	for r in ROOMS:
		var b := UI.button(String(r[0]), func(): open_room(String(r[1])), "ghost", 108, 18)
		b.name = "Room_" + String(r[1])
		rooms.add_child(b)
	v.add_child(rooms)
	v.add_child(UI.label("NOTHING HERE IS SAVED: MADE-UP PLAYERS AND NUMBERS, YOUR CAREER UNTOUCHED.", 8, UI.DIM, "caps"))

func on_back() -> void:
	Sfx.play("back")
	Game.back("settings")   # (as every Developer Mode lab: by the history, so Settings' own Back still leads out)

# ------------------------------------------------------------------ the celebrations
## A made-up record broken (the shape Records.breaks gives the summary): just past its usual mark.
static func _entry(key: String, level: String) -> Dictionary:
	var vals: Array = KEY_VALUES.get(key, [5, 6])
	var team := Colleges.display_name(Game.career.team().name) if Game.career != null else "PIXEL POLO U"
	var holder := team if key in TEAM_KEYS else ("R. GARZA" if not key.contains("saves") else "M. TOMIC")
	var prev := {"v": int(vals[0]), "name": "J. HALVORSEN" if level == "ncsa" else "D. OKAFOR", "year": 2014 if level == "ncsa" else 2009}
	if int(vals[0]) <= 0:
		prev = {"v": 0, "name": "", "year": ""}
	elif level == "school":
		prev.v = maxi(1, roundi(int(vals[0]) * 0.8))
	return {"level": level, "key": key, "name": Records.NAMES[key], "value": int(vals[1]), "holder": holder, "team": team, "prev": prev}

func _play(items: Array) -> void:
	for ch in get_children():
		if ch is RecordShow:
			ch.queue_free()
	last = items
	RecordShow.play(self, items, Callable(), true)

# ------------------------------------------------------------------ the Trophy Room
static func room_career() -> Career:
	if _room == null:
		_room = Career.new_game("SJCU", "DEV", "LAB", 4242)
		_room.queue.clear()
	return _room

## The room in arrangement `kind`, for a made-up player of the throwaway career.
func open_room(kind: String) -> void:
	var c2 := room_career()
	var p := arrange(c2, kind)
	Game.goto("trophy_room", {"id": p.id, "preview": c2, "back_to": "record_lab"})

## Gives the throwaway career's player exactly arrangement `kind`'s honours (and nobody else any).
## Returns him.
static func arrange(c2: Career, kind: String) -> PoloPlayer:
	var t := c2.team()
	var p: PoloPlayer = t.starters()[0] if kind == "keeper" else t.starters()[2]
	c2.conf_awards = []
	c2.tourney_awards = []
	c2.awards = []
	for q in t.roster:
		q.awards = []
	var weekly := func(n: int, cats: Array) -> void:
		for k in n:
			var season: String = ["2026-27", "2027-28", "2028-29", "2029-30"][mini(3, k / 6)]
			c2.conf_awards.append({"year": NationalAwards.earned_year(season) - 1, "season": season, "week": k % 12, "label": "WEEK %d" % (k % 12 + 1),
				"conf": "WCC" if k % 5 == 3 else t.conf, "cat": cats[k % cats.size()], "pid": p.id, "team": c2.school, "name": p.short_name(),
				"pos": p.pos, "cls": 2, "stars": 3.0, "line": {"g": 5, "a": 3, "gp": 1, "sv": 14}, "score": 30.0})
	var nat := func(list: Array) -> void:
		for a in list:
			c2.awards.append({"year": a[1], "award": a[0], "name": p.short_name(), "team": c2.school, "pid": p.id, "pos": p.pos,
				"conf": t.conf, "line": {"gp": 21, "g": 71, "a": 37, "st": 19, "bl": 9, "sv": 205, "ga": 140},
				"slot": ("GK" if p.is_keeper() else "ATK") if a[0] in ["first", "second"] else ""})
	var tourney := func(list: Array) -> void:
		for a in list:
			c2.tourney_awards.append({"year": NationalAwards.earned_year(a[2]) - 1, "season": a[2], "tid": a[1], "conf": t.conf, "cat": a[0],
				"pid": p.id, "team": c2.school, "name": p.short_name(), "pos": p.pos, "cls": 2, "stars": 3.0, "line": {"gp": 3, "g": 12, "a": 6, "sv": 30}, "score": 30.0})
	match kind:
		"weekly":
			weekly.call(5, ["opotw", "potw", "rotw"])
		"one":
			nat.call([["poy", "2027-28"]])
		"national":
			nat.call([["poy", "2028-29"], ["dpoy", "2027-28"], ["foy", "2026-27"], ["arm", "2028-29"], ["wall", "2027-28"], ["first", "2028-29"], ["second", "2027-28"]])
		"full":
			weekly.call(6, ["opotw", "potw", "dpotw", "rotw"])
			nat.call([["poy", "2027-28"], ["dpoy", "2026-27"], ["foy", "2025-26"], ["arm", "2027-28"], ["first", "2026-27"], ["first", "2027-28"], ["second", "2025-26"]])
			tourney.call([["pot", "conf:" + t.conf, "2027-28"], ["opot", "nat", "2027-28"], ["dpot", "conf:" + t.conf, "2026-27"]])
		"max":
			weekly.call(24, ["opotw", "potw", "dpotw", "rotw"])
			nat.call([["poy", "2027-28"], ["poy", "2028-29"], ["poy", "2029-30"], ["dpoy", "2026-27"], ["foy", "2025-26"], ["arm", "2027-28"], ["arm", "2028-29"],
				["wall", "2027-28"], ["first", "2026-27"], ["first", "2027-28"], ["first", "2028-29"], ["second", "2025-26"]])
			tourney.call([["pot", "conf:" + t.conf, "2027-28"], ["pot", "nat", "2028-29"], ["opot", "nat", "2027-28"], ["opot", "conf:" + t.conf, "2026-27"],
				["dpot", "conf:" + t.conf, "2026-27"], ["dpot", "nat", "2029-30"]])
		"keeper":
			weekly.call(4, ["dpotw", "potw"])
			nat.call([["dpoy", "2027-28"], ["wall", "2026-27"], ["wall", "2027-28"], ["first", "2027-28"]])
			tourney.call([["dpot", "nat", "2027-28"]])
		"legacy":
			p.awards = ["2024-25 All-Conference", "2025-26 Golden Cap (top scorer)", "2025-26 NCSA Player of the Year"]
	return p
