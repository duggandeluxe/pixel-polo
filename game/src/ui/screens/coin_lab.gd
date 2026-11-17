extends BaseScreen
## Developer Mode's COIN WALLET TESTING (Settings > Developer Mode): the one currency worked through
## on demand with the game's own code (Wallet, CoinVault, EconomyMigration, Career.to_dict /
## from_dict). Everything happens in a SANDBOX: its own shared-coin vault and two scratch dynasties,
## A and B (Career.new_game, never saved). Test credits are labelled TEST and can't reach the real
## vault, a real purchase record or a career save; leaving the lab throws the sandbox away.
##   +10 DYNASTY / +100 SHARED     test coins (the active dynasty's, the shared vault)
##   PURCHASE      sign a 40-coin recruit: the dynasty's own first, then shared
##   CAREER SWITCH / SAVE/LOAD / DYNASTY DELETION   each dynasty its own coins, one shared vault
##   REQUIRED TEST 10 coins and nothing shared, a 40-coin recruit: refused, nothing moved
##   MIGRATE       a sample old account (Blue Coins, a pack, Broadcast Level 4) through the migration, twice
##   BUY UPGRADE   Goal Celebrations' next tier in the sandbox
##   RESET TEST WALLET a fresh sandbox

var legacy: CoinVault         # sandbox: the shared coins
var looks: VisualUpgrades     # sandbox: visual upgrades (never Store.looks)
var dyn: Array = []           # [A, B]
var active := 0
var log_lines: Array = []
var info_cv: Control
var log_cv: Control
var _test_n := 0

func _ready() -> void:
	build("COIN WALLET TESTING")
	var top := UI.hbox(4)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(top)
	info_cv = UI.canvas(210, 0, _draw_info)
	info_cv.name = "WalletInfo"
	info_cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_child(info_cv)
	log_cv = UI.canvas(0, 0, _draw_log)
	log_cv.name = "WalletLog"
	log_cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_child(log_cv)
	var row := UI.hbox(3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	for b in [["+10 DYNASTY", grant_yellow, "GrantYellow"], ["+100 SHARED", grant_shared, "GrantShared"],
			["PURCHASE", test_yellow_purchase, "YellowPurchase"], ["BUY UPGRADE", test_upgrade, "TestUpgrade"],
			["RESET TEST WALLET", reset_sandbox, "ResetSandbox"]]:
		row.add_child(_btn(b[0], b[1], b[2]))
	var row2 := UI.hbox(3)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row2)
	for b in [["CAREER SWITCH", test_switch, "TestSwitch"], ["SAVE/LOAD", test_save_load, "TestSaveLoad"],
			["DYNASTY DELETION", test_deletion, "TestDeletion"], ["REQUIRED TEST", run_required, "RunRequired"],
			["MIGRATE", test_migrate, "TestMigrate"]]:
		row2.add_child(_btn(b[0], b[1], b[2]))
	reset_sandbox()

func _btn(text: String, cb: Callable, n: String) -> Button:
	var b := UI.button(text, cb, "ghost" if n == "ResetSandbox" else "normal", 0, 18)
	b.name = n
	return b

func on_back() -> void:
	Sfx.play("back")
	Game.back("dev_settings")

func cur() -> Career:
	return dyn[active]

# ------------------------------------------------------------------ actions
func reset_sandbox() -> void:
	legacy = CoinVault.new()
	looks = VisualUpgrades.new()
	dyn = [Career.new_game("GWU", "Test", "Alpha", 501), Career.new_game("HURST", "Test", "Bravo", 502)]
	for c: Career in dyn:
		c.credits = 0
	active = 0
	log_lines.clear()
	_log("SANDBOX READY: TWO DYNASTIES, EMPTY TEST VAULT", UI.ACCENT)

func grant_yellow() -> void:
	Wallet.grant_yellow(cur(), 10, "TEST GRANT")
	_log("+10 TO %s" % _name(active), UI.GOLD)

func grant_shared() -> void:
	_test_n += 1
	legacy.credit(100, "TEST-%d-%d" % [Time.get_ticks_msec(), _test_n], "TEST CREDIT (NOT A PURCHASE)", "test")
	_log("+100 TEST SHARED COINS (SANDBOX ONLY)", UI.GOLD)

## A 40-coin recruit on the scratch dynasty's market, paid the way Recruiting.sign pays (through
## Career.spend_credits: Wallet.spend_yellow), with the sandbox's vault.
func test_yellow_purchase() -> Dictionary:
	var c := cur()
	var p: PoloPlayer = c.team().roster[c.team().roster.size() - 1]
	var r := {"p": p, "price": 40}
	c.market.append(r)
	c.phase = "season"
	var y_before := Wallet.yellow(c, legacy)
	var why := ""
	if not Wallet.can_afford_yellow(c, 40, legacy):
		why = "NOT ENOUGH POLO POINTS"
	elif not bool(Wallet.spend_yellow(c, 40, "TEST RECRUIT", legacy).ok):
		why = "REFUSED"
	else:
		c.market.erase(r)
		c.incoming.append(r)
	var signed := c.incoming.has(r)
	c.market.erase(r)
	c.incoming.erase(r)
	_log("SIGN 40-COIN RECRUIT: %s" % ("SIGNED" if signed else why), UI.GOOD if signed else UI.WARN)
	return {"signed": signed, "why": why, "yellow_spent": y_before - Wallet.yellow(c, legacy)}

## A <-> B: each its own coins, one shared vault.
func test_switch() -> bool:
	var mine := cur().credits
	var b := legacy.balance
	active = 1 - active
	_log("SWITCHED TO %s: DYNASTY %d, SHARED %d" % [_name(active), cur().credits, legacy.balance], UI.ACCENT)
	active = 1 - active
	var ok: bool = cur().credits == mine and legacy.balance == b
	active = 1 - active
	_log("CAREER SWITCH: OWN COINS, SHARED VAULT  %s" % ("PASS" if ok else "FAIL"), UI.GOOD if ok else UI.BAD)
	return ok

## Save, load: the dynasty's coins come back as saved; the shared ones aren't in the save at all.
func test_save_load() -> bool:
	var c := cur()
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var b := legacy.balance
	var back := Career.from_dict(d)
	dyn[active] = back
	var ok: bool = back.credits == int(d.credits) and back.uid == c.uid and legacy.balance == b
	_log("SAVE/LOAD: %d KEPT, SHARED %d NOT IN THE SAVE  %s" % [back.credits, b, "PASS" if ok else "FAIL"], UI.GOOD if ok else UI.BAD)
	return ok

## Deleting B: its coins go with it; the shared ones and A untouched.
func test_deletion() -> bool:
	var a_coins := (dyn[0] as Career).credits
	var b := legacy.balance
	dyn[1] = Career.new_game("HURST", "Test", "Bravo", 503 + _test_n)
	dyn[1].credits = 0
	var ok: bool = (dyn[0] as Career).credits == a_coins and legacy.balance == b and (dyn[1] as Career).credits == 0
	_log("DYNASTY B DELETED (A NEW B STARTS AT 0): A %d, SHARED %d  %s" % [a_coins, legacy.balance, "PASS" if ok else "FAIL"], UI.GOOD if ok else UI.BAD)
	return ok

## Ten coins can't sign a 40-coin recruit.
func run_required() -> bool:
	reset_sandbox()
	Wallet.grant_yellow(dyn[0], 10, "TEST GRANT")
	var r := test_yellow_purchase()
	var ok: bool = not r.signed and r.why == "NOT ENOUGH POLO POINTS" and dyn[0].credits == 10
	_log("REQUIRED: %s, NOT SIGNED  %s" % [r.why, "PASS" if ok else "FAIL"], UI.GOOD if ok else UI.BAD)
	return ok

## A sample old account through the migration, then through it again: credited once.
func test_migrate() -> bool:
	var old := CoinVault.new()
	old.balance = 100
	var lk := VisualUpgrades.new()
	lk.unlocked = {"broadcast": 4}
	lk.packs = ["chaos"]
	lk.bought = [{"txn": "a", "what": "broadcast:4", "n": 100}, {"txn": "b", "what": "chaos", "n": 50}]
	var bank := CoinVault.new()
	var s := {"v": 0, "bank": bank, "old": old, "looks": lk, "pro": false, "pro_coins": false}
	var once := EconomyMigration.run(s)
	var after := bank.balance
	EconomyMigration.run(s)
	var ok: bool = after == 100 * 5 + 100 * 5 + 50 * 5 and bank.balance == after and old.balance == 0 and lk.level("broadcast") == 3 and lk.packs.is_empty()
	_log("MIGRATE: %d BLUE > %d COINS, TWICE = ONCE  %s" % [int(once.blue), after, "PASS" if ok else "FAIL"], UI.GOOD if ok else UI.BAD)
	return ok

## Buys Crowd Atmosphere's next tier in the sandbox (built or not: it's only a test).
func test_upgrade() -> String:
	var why := looks.buy_tier("crowd", cur(), legacy, false)
	_log("BUY CROWD TIER: %s" % ("LEVEL %d" % looks.level("crowd") if why == "" else why), UI.GOLD if why == "" else UI.WARN)
	return why

# ------------------------------------------------------------------ the readout
func _name(i: int) -> String:
	return "DYNASTY " + ["A", "B"][i]

func _log(t: String, col: Color) -> void:
	log_lines.append([t, col])
	while log_lines.size() > 14:
		log_lines.pop_front()
	if log_cv != null:
		log_cv.queue_redraw()
	if info_cv != null:
		info_cv.queue_redraw()

func rows() -> Array:
	var c := cur()
	var lt: Dictionary = Wallet.last
	var last := "-" if lt.is_empty() else ("%s %d %s %s" % [String(lt.k).to_upper(), int(lt.n), String(lt.get("cur", "")).to_upper(), String(lt.get("what", ""))])
	return [["ACTIVE", "%s  %s" % [_name(active), c.uid]],
		["POLO POINTS", str(Wallet.yellow(c, legacy))],
		["...DYNASTY", str(Wallet.dynasty_yellow(c))],
		["...SHARED", "%d (TEST VAULT)" % legacy.balance],
		["OWNED", "%d TIERS" % looks.bought.size()],
		["OTHER DYNASTY", "%s: %d" % [_name(1 - active), Wallet.dynasty_yellow(dyn[1 - active])]],
		["LAST", last],
		["STORAGE", "SANDBOX: NOTHING SAVED"],
		["REAL SHARED", "%d, %s" % [Store.vault, Store.backend_name.to_upper()]]]

func _draw_info(ci: Control) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	Deck.frame(ci, r, Deck.NAVY)
	var y := 8.0
	for row: Array in rows():
		Deck.text(ci, 5, y, String(row[0]), 8, UI.ACCENT)
		Deck.rtext(ci, r.size.x - 5, y, Deck.fit(String(row[1]), r.size.x - 92), 8, UI.TEXT)
		y += 10.0

func _draw_log(ci: Control) -> void:
	var r := Rect2(Vector2.ZERO, ci.size)
	Deck.frame(ci, r, Deck.NAVY)
	var y := 8.0
	for ln: Array in log_lines:
		Deck.text(ci, 5, y, Deck.fit(String(ln[0]), r.size.x - 10), 8, ln[1])
		y += 10.0
