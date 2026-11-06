extends RefCounted
## The Dynasty Refinement update: its numbered tests (RefinementChecks) and the ones that need the
## real Store or a real screen.
##   godot --headless --path game -- --test refinement

var r

func run(runner) -> void:
	r = runner
	Store.reset_for_tests()
	for x in RefinementChecks.run_all(40):
		if not x.look:
			r.check(bool(x.ok), "%d (%s): %s" % [int(x.n), String(x.group), String(x.text)])
	_pro_grant()
	await _screens()
	Store.reset_for_tests()
	Game.career = null

## 59, 60: the real Store's grant, through its backend callbacks.
func _pro_grant() -> void:
	Store.reset_for_tests()
	Store._inflight = Store.PRO_ID
	Store._on_purchased(Store.PRO_ID, "txn-pro")
	r.check(Store.pro and Store.vault == 500, "59: a new purchase grants 500")
	Store._on_purchased(Store.PRO_ID, "txn-pro")
	Store._on_owned(Store.PRO_ID)
	r.check(Store.vault == 500, "...once")
	# a reinstall: the store file's gone, and it's a restore
	Store.reset_for_tests()
	Store._on_owned(Store.PRO_ID)
	r.check(Store.pro and Store.vault == 0 and Store.pro_coins, "60: restoring grants nothing")
	Store.pro = false
	Store._inflight = Store.PRO_ID
	Store._on_purchased(Store.PRO_ID, "txn-2")
	r.check(Store.pro and Store.vault == 0, "...nor does buying again after it")
	# RESET GAME
	Store.reset_for_tests()
	Store._inflight = Store.PRO_ID
	Store._on_purchased(Store.PRO_ID, "txn-3")
	Store.reset_all()
	Store.hold_owned = false
	Store._inflight = Store.PRO_ID
	Store._on_purchased(Store.PRO_ID, "txn-4")
	r.check(Store.vault == 500, "a reset and a re-purchase don't pay again")
	# owners before this update (no coins, flagged)
	var s := {"v": 0, "bank": CoinVault.new(), "old": CoinVault.new(), "looks": VisualUpgrades.new(), "pro": true, "pro_coins": false}
	EconomyMigration.run(s)
	r.check(bool(s.pro_coins) and (s.bank as CoinVault).balance == 0, "an owner from before this update: no coins, and none later")
	Store.reset_for_tests()
	# the coin packs: into the shared vault
	Store._inflight = "blue_100"
	Store._on_purchased("blue_100", "txn-5")
	r.check(Store.vault == 500, "43: the old 100 pack lands as 500 Yellow Coins")
	Store._on_purchased("blue_100", "txn-5")
	r.check(Store.vault == 500, "...once")
	Store.reset_for_tests()

func _text(n: Node) -> String:
	var out := ""
	if n is Label or n is Button:
		out += String(n.text) + "\n"
	if n.has_meta("text"):
		out += str(n.get_meta("text")) + "\n"
	for ch in n.get_children():
		out += _text(ch)
	return out

func _frames(n := 3) -> void:
	for i in n:
		await r.get_tree().process_frame

func _screens() -> void:
	var win: Window = r.get_window()
	var size: Vector2i = win.size
	win.size = Vector2i(480, 270)
	Game.test_mode = true
	Game.career = Career.new_game("CULA", "A", "B", 950)
	var c: Career = Game.career
	Game.goto("program", {}, false)
	await _frames()
	var page := _text(Game.current_screen)
	r.check(not page.to_upper().contains("SCHOOL RATING") and page.to_upper().contains("HOME POOL"), "1, 3: no School Rating on the Hub's PROGRAM page; the rest stands")
	Game.goto("more", {}, false)
	await _frames()
	var hub := _text(Game.current_screen).to_upper()
	r.check(Game.current_screen.find_child("Cards", true, false).get_child_count() == 8, "4: the Hub's eight cards")
	# the lower divisions hibernated (Colleges.ENABLE_LOWER_DIVISIONS): no pack in the shop at all
	Game.goto("store", {}, false)
	await _frames()
	var hid := _text(Game.current_screen).to_upper()
	r.check(Game.current_screen.find_child("Divisions", true, false) == null and not hid.contains("DIVISION"), "hibernated: the shop lists no division pack, nor mentions one")
	# ...and with them back, the shop as it was
	Colleges.lower_divisions = true
	Game.goto("store", {}, false)
	await _frames()
	var shop := _text(Game.current_screen)
	r.check(Game.current_screen.find_child("CoinPacks", true, false).get_child_count() == 4, "48: four coin packs")
	r.check(Game.current_screen.find_child("Division_div2", true, false) != null and Game.current_screen.find_child("Division_div3", true, false) != null, "50, 51: both division cards")
	r.check(not shop.to_upper().contains("BLUE") and not shop.to_upper().contains("BUY NOW"), "37, 53: no Blue Coins, nothing to buy on them")
	for id in ["Division_div2", "Division_div3"]:
		r.check(_buttons(Game.current_screen.find_child(id, true, false)) == 0, "53: %s has no button" % id)
	Colleges.lower_divisions = Colleges.ENABLE_LOWER_DIVISIONS
	Game.goto("visual_shop", {}, false)
	await _frames()
	var vs := _text(Game.current_screen).to_upper()
	r.check(not vs.contains("COSMETIC") and not vs.contains("EXCHANGE") and not vs.contains("BLUE"), "38: no Cosmetic Packs or Coin Exchange tabs")
	Game.goto("upgrade_detail", {"cat": "replay"}, false)
	await _frames(4)
	var rp := _text(Game.current_screen)
	r.check(rp.contains("PREVIEW REPLAY") and rp.contains("UNLOCK INSTANT REPLAY") and Game.current_screen.find_child("Tier_1", true, false) == null, "17: one purchase card, PREVIEW REPLAY")
	Game.goto("upgrade_detail", {"cat": "broadcast"}, false)
	await _frames(4)
	r.check(Game.current_screen.find_child("Tier_3", true, false) != null and Game.current_screen.find_child("Tier_4", true, false) == null, "22: no Level 4 card")
	Game.goto("upgrade_detail", {"cat": "victory"}, false)
	await _frames(4)
	r.check(Game.current_screen.find_child("Tier_4", true, false) != null, "34: all four victories on the page")
	Game.goto("recruiting", {}, false)
	await _frames()
	r.check(Game.current_screen.find_child("RosterNeeds", true, false) == null and not _text(Game.current_screen).contains("TEAM NEEDS"),
		"68-71: the recruiting screen has no TEAM NEEDS strip (removed)")
	Game.goto("new_career", {}, false)
	await _frames()
	var nc := _text(Game.current_screen).to_upper()
	r.check(not nc.contains("DIVISION") and Game.current_screen.find_child("DivisionFilters", true, false) == null,
		"hibernated: New Dynasty is Division I's alone, no division filter or mention")
	Colleges.lower_divisions = true
	Game.goto("new_career", {}, false)
	await _frames()
	r.check(_text(Game.current_screen).to_upper().contains("DIVISION II"), "56: New Dynasty offers the divisions (with them back)")
	Colleges.lower_divisions = Colleges.ENABLE_LOWER_DIVISIONS
	win.size = size
	Game.career = null

func _buttons(n: Node) -> int:
	var k := 1 if n is BaseButton else 0
	for ch in n.get_children():
		k += _buttons(ch)
	return k
