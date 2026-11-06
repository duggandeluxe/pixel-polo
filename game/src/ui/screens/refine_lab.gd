extends BaseScreen
## Developer Mode's DYNASTY REFINEMENT TESTS (Settings > Developer Mode): the update's numbered
## checks (RefinementChecks: sandboxed, nothing real is touched), group by group. LOOK marks the
## ones that need eyes or a screen: tap the group's OPEN button to go and see. RUN ALL re-runs them.
## Everything here is also `--test refinement`, where the screens are checked too.

const OPEN := {"A": ["DYNASTY HUB", "more"], "C": ["VISUAL UPGRADES", "visual_shop"], "D": ["VISUAL UPGRADES", "visual_shop"],
	"E": ["VISUAL LAB", "visual_lab"], "F": ["COIN LAB", "coin_lab"], "G": ["SHOP", "store"], "I": ["RECRUITING", "recruiting"], "J": ["DEFENSE LAB", "defense_lab"]}

static var group := "A"
var results: Array = []
var list: VBoxContainer
var summary: Label

func _ready() -> void:
	build("DYNASTY REFINEMENT TESTS")
	var top := UI.hbox(2)
	top.name = "Groups"
	body.add_child(top)
	for g in RefinementChecks.GROUPS:
		var b := UI.button(g, func():
			group = g
			_show(), "ghost", 20, 16)
		b.name = "Group_" + g
		top.add_child(b)
	top.add_child(UI.spacer(0, 0, true))
	var run := UI.button("RUN ALL", run_all, "primary", 60, 16)
	run.name = "RunAll"
	top.add_child(run)
	summary = UI.label("", 8, UI.ACCENT, "caps")
	summary.name = "Summary"
	body.add_child(summary)
	list = UI.vbox(1)
	list.name = "Checks"
	body.add_child(UI.scroll(list))
	run_all()

func on_back() -> void:
	Sfx.play("back")
	Game.back("settings")

func run_all() -> void:
	results = RefinementChecks.run_all(12)
	_show()

func _show() -> void:
	for ch in list.get_children():
		list.remove_child(ch)
		ch.queue_free()
	var fails := results.filter(func(r): return not r.ok).size()
	var looks := results.filter(func(r): return r.look).size()
	summary.text = "%s  %s: %d CHECKS, %d FAILED, %d TO LOOK AT" % [group, RefinementChecks.GROUPS[group], results.size(), fails, looks]
	summary.add_theme_color_override("font_color", UI.BAD if fails > 0 else UI.GOOD)
	if OPEN.has(group) and (Game.career != null or OPEN[group][1] in ["store", "visual_lab", "coin_lab", "defense_lab"]):
		var to: String = OPEN[group][1]
		var open := UI.button("OPEN %s" % OPEN[group][0], func(): Game.goto(to), "ghost", 0, 14)
		open.name = "OpenScreen"
		list.add_child(open)
	for r in results:
		if r.group != group:
			continue
		var h := UI.hbox(4)
		var tag := UI.label("LOOK" if r.look else ("PASS" if r.ok else "FAIL"), 8, UI.ACCENT if r.look else (UI.GOOD if r.ok else UI.BAD), "caps")
		tag.custom_minimum_size = Vector2(28, 0)
		h.add_child(tag)
		var n := UI.label("%d" % int(r.n), 8, UI.DIM, "caps")
		n.custom_minimum_size = Vector2(18, 0)
		h.add_child(n)
		var t := UI.label(String(r.text), 8, UI.TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size = Vector2(380, 0)
		h.add_child(t)
		list.add_child(h)
