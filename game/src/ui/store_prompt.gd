class_name StorePrompt
extends RefCounted
## Store prompts shown in the flow of play:
##   need()        - a coin cost: do it if the coins are there, else say so, with the way to the
##                   Yellow Coin Shop.
##   pro_locked()  - a PRO feature was tapped: show PRO and unlock it on the spot.
##   buy_then()    - buy a product and run a callback when it lands.
## Plus value helpers used by the store screen (what a pack buys, the next upgrade).

static var _waiters: Array = []

## Runs `action` if the Yellow Coins cover `cost`, otherwise says how many it's short.
static func need(c: Career, cost: int, what: String, action: Callable) -> void:
	if Wallet.can_afford_yellow(c, cost):
		action.call()
		return
	var short := cost - c.wallet()
	Game.dialog("NOT ENOUGH YELLOW COINS", "%s costs %s and you have %s: %s short.\n\nYellow Coins come from games, the season's start, achievements and coaching events, or the Yellow Coin Shop." % [
		what, CreditCoin.tag(cost), CreditCoin.tag(c.wallet()), CreditCoin.tag(short)], [
		["YELLOW COIN SHOP", func(): Game.goto("store"), "primary"],
		["OK", Callable(), "ghost"]])

static func pro_locked(feature: String = "") -> void:
	var lead := ("%s is part of PIXEL POLO +, a" % feature) if feature != "" else "PIXEL POLO + is a"
	var body := "%s one-time %s unlock. Yours forever, on every career:\n\n- %s" % [lead, Store.price(Store.PRO_ID), "\n- ".join(Store.pro_perks())]
	Game.dialog("PIXEL POLO +", body, [
		["UNLOCK  %s" % Store.price(Store.PRO_ID), func(): buy_then(Store.PRO_ID, func(): Game.toast("PIXEL POLO + unlocked! Thanks, Coach.", UI.GOLD)), "primary"],
		["NOT NOW", Callable(), "ghost"]])

## Buys `id`; on success runs `on_ok`. Failures and pending purchases are toasted.
static func buy_then(id: String, on_ok: Callable = Callable()) -> void:
	if not Store.available():
		Game.toast("Store unavailable right now", UI.BAD)
		return
	var w := Waiter.new()
	w.id = id
	w.on_ok = on_ok
	_waiters.append(w)
	Store.purchase_finished.connect(w.done)
	Game.toast("Opening the %s..." % ("TEST STORE" if Store.is_test_store() else "store"), UI.ACCENT)
	Store.buy(id)

class Waiter extends RefCounted:
	var id := ""
	var on_ok: Callable
	func done(pid: String, ok: bool, message: String) -> void:
		if pid != id:
			return
		Store.purchase_finished.disconnect(done)
		StorePrompt._waiters.erase(self)
		if ok:
			var p := Store.product(id)
			if p.has("credits"):
				Game.toast("%s Yellow Coins" % CreditCoin.tag(int(p.credits), true), UI.GOLD)
			elif message != "":
				Game.toast(message, UI.GOLD)   # (a restore: what came back)
			if on_ok.is_valid():
				on_ok.call()
		elif message != "":
			Game.toast(message, UI.WARN)

# ------------------------------------------------------------------ value helpers
const SHORT := {"pool": "Pool", "weights": "Weights", "medical": "Medicine", "video": "Video", "recruit": "Recruit Office",
	"offense": "Off Coord", "defense": "Def Coord", "goalie": "GK Coach", "recruiter": "Recruiter"}

## Next facility / staff upgrades, cheapest first: [[label, cost, short label], ...]
static func next_upgrades(c: Career) -> Array:
	var out := []
	var fac := {}
	for k in Career.FAC_ORDER:
		fac[k] = c.fac(k)
	var stf := c.staff.duplicate()
	# walk levels forward so one pack can show several steps of the same facility
	for _i in range(40):
		var best := []
		for k in Career.FAC:
			if fac[k] < 5:
				var cost: int = Career.FAC[k].cost[fac[k]]
				if best.is_empty() or cost < best[1]:
					best = ["%s Lv%d" % [Career.FAC[k].name, fac[k] + 1], cost, "f", k, "%s Lv%d" % [SHORT[k], fac[k] + 1]]
		for k in Career.STAFF:
			if stf[k] < 3:
				var cost: int = Career.STAFF[k].cost[stf[k]]
				if best.is_empty() or cost < best[1]:
					best = ["%s Lv%d" % [Career.STAFF[k].name, stf[k] + 1], cost, "s", k, "%s Lv%d" % [SHORT[k], stf[k] + 1]]
		if best.is_empty():
			break
		out.append([best[0], best[1], best[4]])
		if best[2] == "f":
			fac[best[3]] += 1
		else:
			stf[best[3]] += 1
	return out

## The upgrade worth chasing next: the Aquatic Center while it isn't maxed, otherwise the
## cheapest upgrade the coach can't afford yet. [label, cost] or [].
static func headline_upgrade(c: Career) -> Array:
	var pc := c.facility_cost("pool")
	if pc > 0:
		return ["%s Lv%d" % [Career.FAC.pool.name, c.fac("pool") + 1], pc]
	var ups := next_upgrades(c)
	for u in ups:
		if int(u[1]) > c.wallet():
			return [u[0], u[1]]
	return [] if ups.is_empty() else [ups[0][0], ups[0][1]]
