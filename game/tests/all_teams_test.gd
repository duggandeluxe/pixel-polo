extends RefCounted
## THE ALL-TEAMS UNLOCK: a one-time store purchase (Store.TEAMS_ID) that opens every school on the
## Road to Glory, alongside (never instead of) the achievements; the UNLOCK ALL TEAMS offer on the
## picker gone without a trace once it's owned. The numbered checks follow the spec's REQUIRED
## TESTING list. (The editor's test store stands in for StoreKit / Play.)
##   godot --headless --path game -- --test all_teams

var r   # the test runner

func run(runner) -> void:
	load("res://src/ui/screens/new_career.gd").start_filter = Colleges.D1   # (the Road to Glory's thirty; --test divisions has the rest)
	r = runner
	print("all-teams unlock")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	Game.setup = null
	await _new_player()
	await _purchase()
	await _after()
	_entitlement()
	await _cancel_and_fail()
	Store.reset_for_tests()
	Game.progress = null
	Game.setup = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n: int = 2) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _picker() -> Node:
	Game.goto("new_career")
	await _frames(3)
	return Game.current_screen

func _heads(scr) -> Array:
	return scr.list.get_children().filter(func(n): return n.name.begins_with("Header")).map(func(n):
		return " ".join(n.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)))

# ------------------------------------------------------------------ T1
func _new_player() -> void:
	r.check(Store.product(Store.TEAMS_ID).get("type") == "teams" and Store.TEAMS_ID in Store.NON_CONSUMABLES, "a one-time (non-consumable) store product, not a subscription")
	var scr = await _picker()
	r.check(Game.progress.unlocked.size() == 5 and not Store.all_teams, "T1: a new player: the bottom five open")
	var b: Button = scr.find_child("UnlockAllTeams", true, false)
	r.check(b != null and b.text.begins_with("UNLOCK ALL TEAMS") and b.text.ends_with(Store.price(Store.TEAMS_ID)), "T1: UNLOCK ALL TEAMS, with the store's price (%s)" % (b.text if b != null else "-"))
	r.check(Game.progress.picker_groups().size() == 5, "T10: the locked tiers as before")
	# the confirmation: nothing opens for looking
	scr._offer_unlock()
	await _frames(1)
	var dlg := _dialog_texts()
	r.check(dlg.has("UNLOCK ALL 30 TEAMS!") and dlg.any(func(t): return "ONE-TIME PURCHASE" in t and "for free" in t), "T3: the confirmation says what it is, the price, and that they're free to earn")
	r.check(not Store.all_teams and Game.progress.unlocked.size() == 5, "T3: opening it unlocks nothing")
	_close_dialogs()

func _dialog_texts() -> Array:
	var out: Array = []
	for layer in Game.overlay.get_children():
		if layer is Control and not layer.is_queued_for_deletion():
			out.append_array(layer.find_children("*", "Label", true, false).map(func(l): return (l as Label).text))
			out.append_array(layer.find_children("*", "Button", true, false).map(func(b): return (b as Button).text))
	return out

func _close_dialogs() -> void:
	for layer in Game.overlay.get_children():
		if layer is Control and layer.mouse_filter == Control.MOUSE_FILTER_STOP:
			layer.queue_free()

# ------------------------------------------------------------------ T2, T9, T11
func _purchase() -> void:
	var scr = await _picker()
	var done := {"ok": false}
	StorePrompt.buy_then(Store.TEAMS_ID, func(): done.ok = true)
	r.check(not Store.all_teams, "T2: nothing opens before the store says it's paid")
	await r.get_tree().create_timer(0.6).timeout
	await _frames(2)
	r.check(done.ok and Store.all_teams, "T2: paid and verified: owned")
	scr = Game.current_screen
	r.check(scr.find_child("UnlockAllTeams", true, false) == null and scr.find_child("OfferRow", true, false) == null, "T9: the button and its row are gone")
	var texts: Array = scr.find_children("*", "Label", true, false).map(func(l): return (l as Label).text) + scr.find_children("*", "Button", true, false).map(func(b): return (b as Button).text)
	r.check(not texts.any(func(t): return "OWNED" in t or "PURCHASED" in t or "ALL TEAMS UNLOCKED" in t or Store.price(Store.TEAMS_ID) in t), "T9: no OWNED, no banner, no price left behind")
	r.check(_heads(scr) == ["AVAILABLE TEAMS 30"], "T2/T11: every school in AVAILABLE TEAMS (%s)" % str(_heads(scr)))
	var order: Array = scr.card_order()
	var desc := true
	for i in range(1, order.size()):
		desc = desc and (scr.preview.teams[order[i]] as PoloTeam).team_overall(false) <= (scr.preview.teams[order[i - 1]] as PoloTeam).team_overall(false) + 0.000001
	r.check(order.size() == 30 and desc, "T11: all 30, highest overall first")
	r.check(Game.progress.done.is_empty() and Game.progress.unlocked.size() == 5, "T17: no achievement awarded, the earned list as it was")

# ------------------------------------------------------------------ T3, T4
func _after() -> void:
	var scr = await _picker()
	r.check(scr.find_child("UnlockAllTeams", true, false) == null, "T3: back on the picker: still no button")
	r.check(Game.start_career("CULA", "A", "B", 5) and Game.career.school == "CULA", "T4: a new dynasty at a powerhouse")
	var c := Game.career
	r.check(c.team().roster.size() == 10 and c.team().overall_display() > 80, "T16: its roster and ratings untouched")
	Game.career = null
	Game.goto("title")
	await _frames(1)

# ------------------------------------------------------------------ T5, T6, T14, duplicates
func _entitlement() -> void:
	r.check(FileAccess.get_file_as_string("res://src/autoload/store.gd").contains('set_value("s", "all_teams", all_teams)'), "T5: owned is kept with the store's own record (store.cfg), not a career save")
	# already owned: no second checkout
	var before: String = Store._inflight
	Store.buy(Store.TEAMS_ID)
	r.check(Store._inflight == before, "T6: owned: buying again opens no checkout")
	# a reinstall: the store reports it owned (startup sync or RESTORE PURCHASES)
	Store.all_teams = false
	Store._on_owned(Store.TEAMS_ID)
	r.check(Store.all_teams and Game.progression().is_unlocked("CULA"), "T6: restored: every school open again")
	# a refund: back to what was earned
	Store._on_revoked(Store.TEAMS_ID)
	r.check(not Store.all_teams and not Game.progression().is_unlocked("CULA") and Game.progression().is_unlocked(Game.progression().unlocked[0]), "T14: refunded: back to the earned schools")

# ------------------------------------------------------------------ T7, T8, T10
func _cancel_and_fail() -> void:
	Store.all_teams = false
	var prof := JSON.stringify(Game.progress.to_dict())
	for why in [["", true], ["Purchase failed.", false]]:
		Store._inflight = Store.TEAMS_ID
		Store._on_failed(Store.TEAMS_ID, String(why[0]), bool(why[1]))
		r.check(not Store.all_teams and Store._inflight == "" and JSON.stringify(Game.progress.to_dict()) == prof, "T%d: %s: nothing unlocked, progress as it was" % [7 if why[1] else 8, "cancelled" if why[1] else "failed"])
	var scr = await _picker()
	r.check(scr.find_child("UnlockAllTeams", true, false) != null, "T7/T8: the button is still there to try again")
	# the achievements still open schools for free
	Game.progress.award(["five_wins"])
	r.check(Game.progress.unlocked.size() == 12, "T10: Win 5 games still opens Tier 2")
	# everything earned: nothing left to sell
	for a in ["conf_final", "conf_champ", "nat_champ"]:
		Game.progress.award([a])
	scr = await _picker()
	r.check(scr.find_child("UnlockAllTeams", true, false) == null, "every school earned: no offer")
