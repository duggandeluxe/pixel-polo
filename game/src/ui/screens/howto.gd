extends BaseScreen
## THE GAME GUIDE (the title screen's help button; the old HOW TO PLAY): how the game works now, in three
## tabs, CONTROLS, GAMEPLAY and DYNASTY, and PLAY THE TUTORIAL (the playable drills: DrillScreen).
## Keep it to what's in the game: when a mechanic changes, its entry here changes with it.

const TABS := ["CONTROLS", "GAMEPLAY", "DYNASTY"]
const GUIDE := {
	"CONTROLS": [
		["SHOOTING", "Use the shooting stick at the bottom left: put your finger on it, drag the knob back for power, up to aim low or down to aim high, and let go to shoot. A full pull is the hardest shot but the least accurate. It's the only way to shoot."],
		["PASSING", "Tap anywhere in the water to pass there: on a teammate, or into open water ahead of him to lead his run. A pass through a defender can be picked off."],
		["DRIVING", "Tap DRIVE, on top of the shooting stick, and pick LEFT, MIDDLE or RIGHT: that player swims hard at the goal. Hit him in stride."],
		["DEFENSE", "Your field players mark their men by themselves, pick off passes and strip a man who holds the ball too long. The bar at the bottom switches between PRESS and the drop you picked in COACHING."],
		["GOALKEEPER", "When they shoot, tap high or low and your keeper dives that way. Time it: he's only at full stretch for a moment (longer with strong legs), so too early and he's back down, too late and it's past him."],
	],
	"GAMEPLAY": [
		["THE SPRINT", "Every quarter starts with a sprint for the ball: tap as fast as you can."],
		["THE SHOT CLOCK", "You have 30 seconds to shoot. The last five count down in red."],
		["EXCLUSIONS", "Feed your center on 2 m and he draws fouls: an exclusion sends a defender out for 20 seconds and you play 6 on 5. A player with three personal fouls is out for the game and a sub comes in."],
		["PENALTIES", "Fouled from behind in a scoring position inside 5 m and you get a penalty shot. A free throw inside 6 m has to be a pass."],
		["DEFENSIVE DROPS", "In COACHING, PICK YOUR DEFENSE: M-DROP, 4-5, 5 or 3-4. Every defence starts in your normal defence: tap CALL DROP and that drop's on for the rest of their possession (a 6 on 5 plays its own). You can change the drop once at halftime. A long spell in a drop tires the keeper's legs (less for strong legs): high shots get harder to reach. Theirs too, so work the ball against a drop."],
		["SHOT BLOCKING", "Field defenders get an arm up on shots by themselves: the better their Defense, the more they block."],
		["DIFFICULTY", "EASY, MEDIUM, HARD or DYNAMIC, in Settings: how smart the other team plays, never anybody's ratings. DYNAMIC follows your last few games."],
	],
	"DYNASTY": [
		["RECRUITING", "Eight recruits are on the market, each with his own price in Polo Points. Sign up to four a season; they join next season as freshmen. The first REFRESH of a season is free, and every 2 games you play the market rolls new recruits for free (your pinned ones stay)."],
		["POLO POINTS", "Earned by winning: a regular-season win, beating ranked teams, big wins and shutouts, streaks and titles, and every new season. Each dynasty has its own; purchased Polo Points work in every dynasty. Spent on recruits, refreshes and facilities."],
		["XP & UPGRADES", "Players earn XP in games and in training. Each level brings an upgrade: one box on an attribute, never past his ceiling. Upgrades are spent before the next game."],
		["TRAINING", "Pick a focus and an intensity each week: harder work, more XP, more injury risk. RECOVERY heals every injury but gives no XP."],
		["POSITIONS", "C center, 2MD two-meter defender, ATK attacker, WG wing, UT utility, LFTY a left-handed attacker. Your seven: C, 2MD, two ATK, two WG and a GK. A centre or 2MD plays the two posts (a utility may play 2MD too); attackers, wings and utilities the outside. A lefty plays the right side (ATK/LFTY, WG/LFTY): two at most start."],
		["ROSTER CUTS", "Your roster holds ten. If your signings take it over after the season, you choose who to cut before the next season starts."],
		["CONFERENCE AWARDS", "Every week each conference names its Player, Offensive, Defensive and Rookie of the Week from the week's stats. See them under AWARDS on the home screen."],
	],
}

static var tab := "CONTROLS"

func _ready() -> void:
	build("GAME GUIDE")
	_render()

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	var top := UI.hbox(4)
	top.add_child(tabs(TABS, tab, func(t):
		tab = t
		_render()))
	top.add_child(UI.spacer(0, 0, true))
	var tut := UI.button("PLAY THE TUTORIAL  >", func(): Game.goto("drill"), "primary", 0, 16)
	tut.name = "Tutorial"
	top.add_child(tut)
	body.add_child(top)
	var v := UI.vbox(3)
	v.name = "Guide"
	for s in GUIDE[tab]:
		var p := UI.vbox(1)
		p.add_child(UI.label(String(s[0]), 8, UI.GOLD, "caps"))
		var l := UI.label(String(s[1]), 8, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 440
		p.add_child(l)
		v.add_child(navy_panel(p))
	var sc := UI.scroll(v)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)

func on_back() -> void:
	Sfx.play("back")
	Game.back("title")
