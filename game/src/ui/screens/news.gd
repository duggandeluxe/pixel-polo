extends BaseScreen
## LEAGUE NEWS (the Dynasty Hub; LeagueNews): the league's stories, newest first, each a
## headline card: the team's logo, the headline, the season and week, a line of what happened.
## YOUR PROGRAM: your own program's running news (Career.news: results, signings, injuries...).

const TABS := ["LEAGUE", "YOUR PROGRAM"]
const CARD_H := 34

static var tab := "LEAGUE"

func _init() -> void:
	detail = true   # (its team logos: TeamLogo's fine pixels)

func _ready() -> void:
	back_target = "more"
	build("LEAGUE NEWS", true, true)
	_render()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	body.add_child(tabs(TABS, tab, func(t):
		tab = t
		_render()))
	var list := UI.vbox(3)
	list.name = "Stories"
	if tab == "LEAGUE":
		for n in c.league_news:
			list.add_child(_story(n))
		if c.league_news.is_empty():
			list.add_child(para("No stories yet: the news is written from each week's results, once its games are played.", UI.DIM, 440))
	else:
		for n in c.news:
			var l := CreditCoin.rich("WEEK %d  -  %s" % [int(n.get("w", 0)) + 1, String(n.t)], 8, UI.TEXT, "body", 440)
			list.add_child(l)
		if c.news.is_empty():
			list.add_child(para("Nothing yet. Go make some.", UI.DIM, 440))
	var sc := UI.scroll(list)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)

## One story's card: logo, headline, when, summary.
func _story(n: Dictionary) -> Control:
	var t: PoloTeam = c.teams.get(String(n.get("team", "")))
	var mine: bool = String(n.get("team", "")) == c.school
	var cv := UI.canvas(0, CARD_H, func(ci: Control):
		var w := ci.size.x
		Deck.frame(ci, Rect2(0, 0, w, CARD_H), Deck.NAVY, UI.GOLD if mine else UI.BORDER)
		var x := 36.0 if t != null else 8.0
		Deck.text(ci, x, 9, Deck.fit(String(n.head), w - x - 110), 8, UI.GOLD)
		Deck.rtext(ci, w - 6, 9, String(n.label), 8, UI.DIM)
		Deck.text(ci, x, 23, Deck.fit(String(n.text).to_upper(), w - x - 8), 8, UI.TEXT))
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if t != null:
		var logo := TeamLogo.widget(t, TeamLogo.SMALL)
		logo.position = Vector2(8, 7)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(logo)
	return cv

func on_back() -> void:
	Sfx.play("back")
	Game.goto("more")
