extends BaseScreen
## Quick match: pick your club and an opponent (or random). Quarters are always 2:00.

var teams: Array[PoloTeam] = []
var mine := 3
var theirs := -1          # -1 = random

func _init() -> void:
	detail = true   # (its team logos: TeamLogo's fine pixels)

func _ready() -> void:
	for i in League.club_count():
		teams.append(League.make_team(i))
	build("QUICK MATCH")
	_refresh()
	Sfx.music("menu")

func _refresh() -> void:
	for c in body.get_children():
		c.queue_free()
	var cols := UI.hbox(6)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	cols.add_child(_column("YOUR CLUB", mine, false, func(i): mine = i))
	cols.add_child(_column("OPPONENT", theirs, true, func(i): theirs = i))
	var bottom := UI.hbox(4)
	body.add_child(bottom)
	bottom.add_child(UI.label("FOUR %d-MINUTE QUARTERS" % MatchState.quarter_min_for(false), 8, UI.DIM, "caps"))
	bottom.add_child(UI.spacer(0, 0, true))
	bottom.add_child(UI.button("PLAY  >", _play, "primary", 110, 20))

func _column(title: String, selected: int, allow_random: bool, pick: Callable) -> Control:
	var p := UI.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(1)
	p.add_child(v)
	v.add_child(UI.label(title, 8, UI.GOLD, "caps"))
	if allow_random:
		var rr := UI.hbox(4)
		rr.add_child(UI.label("?", 8, UI.GOLD, "caps"))
		rr.add_child(UI.label("RANDOM OPPONENT", 8, UI.TEXT))
		v.add_child(row_button(rr, func():
			pick.call(-1)
			_refresh(), selected == -1, 15))
	for i in teams.size():
		var tm := teams[i]
		var r := UI.hbox(4)
		r.add_child(TeamLogo.widget(tm, TeamLogo.SMALL))
		var lbl := UI.label(tm.name.to_upper(), 8, UI.TEXT)
		lbl.custom_minimum_size = Vector2(96, 0)
		r.add_child(lbl)
		r.add_child(UI.label("RTG %d" % roundi(tm.power()), 8, UI.TEXT))
		r.add_child(CreditCoin.rich("OFF %s  DEF %s" % [CreditCoin.STARS % PoloTeam.rating_stars(tm.offense_display()), CreditCoin.STARS % PoloTeam.rating_stars(tm.defense_display())], 8, UI.DIM))
		var ii := i
		v.add_child(row_button(r, func():
			pick.call(ii)
			_refresh(), selected == i, 15))
	return p

func _play() -> void:
	var opp := theirs
	if opp < 0 or opp == mine:
		var options: Array = range(teams.size()).filter(func(i): return i != mine)
		opp = options[randi() % options.size()]
	Game.match_cfg = {"us": teams[mine], "them": teams[opp], "seed": randi(), "minutes": float(MatchState.quarter_min_for(false))}
	Game.goto("match", Game.match_cfg)
