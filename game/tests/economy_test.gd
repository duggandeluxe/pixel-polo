extends RefCounted
## One currency: Wallet, CoinVault, VisualUpgrades and the one-time move from Blue Coins
## (EconomyMigration), on disk as well as in memory. (Replaces the coin_wallet and visual_upgrades
## suites, which tested the two-currency rules; the numbered spec checks are in --test refinement.)
##   godot --headless --path game -- --test economy

const DIR := "user://economy_test/"
var r

func run(runner) -> void:
	r = runner
	print("economy")
	Store.reset_for_tests()
	_prices()
	_spending()
	_old_exchange()
	await _old_store_on_disk()
	await _saves_on_disk()
	Store.reset_for_tests()
	Game.career = null

func _prices() -> void:
	for id in ["goal", "crowd", "victory", "pregame"]:
		r.check(VisualUpgrades.top(id) == 4 and VisualUpgrades.category_cost(id) == 875, "%s: 125, 250, 500" % id)
	r.check(VisualUpgrades.category_cost("broadcast") == 375 and VisualUpgrades.category_cost("replay") == 500, "Broadcast 375, Instant Replay 500")
	var c := Career.new_game("GWU", "E", "C", 700)
	c.credits = 100
	var lk := VisualUpgrades.new()
	var v := CoinVault.new()
	r.check(lk.tier_block("goal", c, v) == "NOT ENOUGH YELLOW COINS", "short of coins: says so")
	r.check(lk.buy_tier("goal", c, v) != "" and c.credits == 100 and lk.level("goal") == 1, "...and nothing moves")
	v.credit(25, "t")
	r.check(lk.buy_tier("goal", c, v) == "" and c.credits == 0 and v.balance == 0 and lk.level("goal") == 2 and v.open.is_empty(), "the dynasty's coins first, the shared ones after, final at once")
	r.check(lk.worn("goal") == 2, "buying wears it")
	r.check(not lk.equip("goal", 3), "a level not owned can't be worn")
	r.check(VisualUpgrades.from_dict(lk.to_dict()).level("goal") == 2, "ownership saves")
	var top := VisualUpgrades.from_dict({"unlocked": {"broadcast": 3}})
	r.check(top.tier_block("broadcast", c, v) == "MAX LEVEL UNLOCKED", "Broadcast stops at 3")

func _spending() -> void:
	var c := Career.new_game("GWU", "E", "D", 701)
	c.credits = 10
	var v := CoinVault.new()
	v.credit(100, "t2")
	r.check(Wallet.yellow(c, v) == 110, "one balance: the dynasty's and the shared ones")
	var s := Wallet.spend_yellow(c, 30, "TEST", v)
	r.check(bool(s.ok) and c.credits == 0 and v.balance == 80 and v.open.size() == 1, "journaled against the career")
	r.check(v.reconcile(c.uid) == 20 and v.balance == 100, "the game stopped before the save: refunded")
	s = Wallet.spend_yellow(c, 30, "TEST", v)
	v.commit(c.uid)
	r.check(v.reconcile(c.uid) == 0 and v.balance == 70, "after the save, final")
	r.check(not bool(Wallet.spend_yellow(c, 1000, "TEST", v).ok) and v.balance == 70, "all or nothing")

## An old save behind the old exchange's ledger: what it exchanged doesn't come back.
func _old_exchange() -> void:
	var ledger := CoinVault.new()
	var c := Career.new_game("GWU", "E", "E", 702)
	c.add_credits(100, "WIN")
	ledger.exchanged[c.uid] = 60
	var old := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var had := old.credits
	r.check(Wallet.reconcile_exchanges(old, ledger) == 60 and old.credits == had - 60, "the coins already exchanged come off")
	r.check(Wallet.reconcile_exchanges(old, ledger) == 0 and old.credits == had - 60, "once")

## A real old store.cfg through Store._load, twice, and the save it writes.
func _old_store_on_disk() -> void:
	var kept := FileAccess.get_file_as_string(Store.SAVE_PATH) if FileAccess.file_exists(Store.SAVE_PATH) else ""
	var was_test := Game.test_mode
	Game.test_mode = false
	var cf := ConfigFile.new()
	cf.set_value("s", "pro", true)
	cf.set_value("s", "vault", 40)
	cf.set_value("s", "tokens", ["old-1"])
	cf.set_value("s", "blue", 25)
	cf.set_value("s", "blue_tokens", ["blue-1"])
	cf.set_value("s", "exchanged", {"dyn-x": 30})
	cf.set_value("s", "looks", {"unlocked": {"goal": 3, "replay": 3, "broadcast": 4, "victory": 2}, "equipped": {"goal": 2, "replay": 1, "broadcast": 4},
		"packs": ["chaos", "theme_gold"], "enabled": ["chaos"], "theme": "theme_gold",
		"bought": [{"txn": "a", "what": "broadcast:4", "n": 100}, {"txn": "b", "what": "chaos", "n": 50}, {"txn": "c", "what": "theme_gold", "n": 50}]})
	cf.save(Store.SAVE_PATH)
	Store._load()
	# 40 kept + 25 x 5 + (100 + 50 + 50) x 5
	r.check(Store.vault == 40 + 125 + 1000, "balance + refunds at 5:1: %d" % Store.vault)
	r.check(Store.ledger.balance == 0 and Store.econ_v == EconomyMigration.VERSION, "the old balance is retired, the version marked")
	r.check(Store.looks.level("goal") == 3 and Store.looks.worn("goal") == 2 and Store.looks.level("victory") == 2, "visual upgrades stay as owned and worn")
	r.check(Store.looks.level("replay") == 2 and Store.looks.worn("replay") == 1, "a paid replay owner has the unlock; one who'd switched it off still has it off")
	r.check(Store.looks.level("broadcast") == 3 and Store.looks.worn("broadcast") == 3, "Broadcast Level 4 down to 3")
	r.check(Store.looks.packs.is_empty() and Store.looks.enabled.is_empty() and Store.looks.theme == VisualUpgrades.THEME_DEFAULT and Store.looks.retired_packs.size() == 2, "the packs retired")
	r.check(Store.seen("blue-1") and Store.seen("old-1"), "transactions already delivered stay delivered")
	r.check(Store.pro and Store.pro_coins, "PRO kept, no coins")
	r.check(Store.ledger.exchanged_by("dyn-x") == 30, "the exchange's history kept")
	var coins := Store.vault
	Store._load()
	Store._load()
	r.check(Store.vault == coins and Store.looks.level("broadcast") == 3, "loaded again and again: nothing moves")
	r.check(int(Store.bank.sources.get("migrated", 0)) == 125 and int(Store.bank.sources.get("refund", 0)) == 1000, "the books keep the kinds apart")
	Store.reset_for_tests()
	if kept != "":
		var sf := FileAccess.open(Store.SAVE_PATH, FileAccess.WRITE)
		sf.store_string(kept)
		sf.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.SAVE_PATH))
	Store._load()
	Game.test_mode = was_test
	await r.get_tree().process_frame

## Careers on disk: spends commit, unsaved ones come back, deleting a dynasty keeps the shared coins.
func _saves_on_disk() -> void:
	var kept_dir := Game.save_dir
	var kept_store := FileAccess.get_file_as_string(Store.SAVE_PATH) if FileAccess.file_exists(Store.SAVE_PATH) else ""
	var was_test := Game.test_mode
	DirAccess.make_dir_recursive_absolute(DIR)
	Game.save_dir = DIR
	Game.test_mode = false
	Store.reset_for_tests()
	Store.bank.credit(100, "DISK")
	Game.career = Career.new_game("GWU", "A", "A", 201)
	Game.slot = 1
	Game.save_career()
	var a_uid := Game.career.uid
	var a_saved := FileAccess.get_file_as_string(Game.slot_path(1))
	Game.career = Career.new_game("HURST", "B", "B", 202)
	Game.career.credits = 25
	Game.slot = 2
	Game.save_career()
	Game.load_career(1)
	Game.career.spend_credits(40, "RECRUIT")
	Game.save_career()
	r.check(Store.vault == 75 and Store.bank.open.is_empty(), "the save makes the debit final")
	var f := FileAccess.open(Game.slot_path(1), FileAccess.WRITE)
	f.store_string(a_saved)
	f.close()
	Game.load_career(1)
	r.check(Store.vault == 75 and Game.career.credits == CreditRewards.SEASON_START, "an older save of A: its own coins, nothing shared rolled back")
	Game.career.credits = 0
	Game.career.spend_credits(30, "RECRUIT")
	Store._load()
	Game.load_career(1)
	r.check(Store.vault == 75 and Store.bank.open.is_empty(), "an unsaved spend is refunded on the next load, once")
	# an upgrade bought with the dynasty's coins: both files at once, so a reload can't undo the price
	Game.career.credits = 200
	Game.save_career()
	r.check(Store.buy_tier("goal") == "" and Game.career.credits == 75, "an upgrade paid from the dynasty")
	Store._load()
	Game.load_career(1)
	r.check(Game.career.credits == 75 and Store.looks.level("goal") == 2, "reloading keeps the coins spent and the level owned")
	Game.load_career(2)
	r.check(Game.career.credits == 25 and Wallet.yellow(Game.career) == 100 and Store.looks.level("goal") == 2, "B: its own 25, the shared 75, the same upgrades")
	# bought coins follow you; coins earned in one dynasty stay in it
	Game.career.add_credits(40, "WIN")
	Game.save_career()
	Store.bank.credit(50, "DISK-2")
	Game.load_career(1)
	r.check(Game.career.credits == 75 and Wallet.yellow(Game.career) == 75 + 125, "A: none of B's 40 earned coins, but the 50 bought while B was open")
	Game.load_career(2)
	r.check(Game.career.credits == 65 and Wallet.yellow(Game.career) == 65 + 125, "B: its own earned coins and the same bought ones")
	var fresh := Career.new_game("CULA", "N", "D", 203)
	r.check(Wallet.yellow(fresh) == fresh.credits + 125 and fresh.credits == CreditRewards.SEASON_START, "a brand new dynasty: bought coins there, nobody's earned ones")
	Store.bank.debit(50, "", "TEST")
	Game.delete_slot(2)
	r.check(Store.vault == 75 and not Game.slot_exists(2) and Game.slot_exists(1), "deleting B: its coins gone, the shared ones kept")
	Store._load()
	r.check(Store.vault == 75, "the shared coins live in the store, not a career")
	r.check(Game.load_career(1) and Game.career.uid == a_uid, "A still loads")
	Game.career = null
	Store.reset_for_tests()
	if kept_store != "":
		var sf := FileAccess.open(Store.SAVE_PATH, FileAccess.WRITE)
		sf.store_string(kept_store)
		sf.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.SAVE_PATH))
	Store._load()
	Game.test_mode = was_test
	Game.save_dir = kept_dir
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + fn))
	await r.get_tree().process_frame
