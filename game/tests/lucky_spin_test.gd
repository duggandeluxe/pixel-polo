extends RefCounted
## THE POLO POINTS ECONOMY UPDATE: the rebalanced packs, Pixel Polo +'s 200 PP, LUCKY SPIN (LuckySpin,
## Store.claim_spin, Ads, LuckyWheel, LuckySpinPanel).
##   godot --headless --path game -- --test lucky_spin
##   godot --path game --resolution 480x270 -- --test lucky_spin_png <dir>   (screenshots: needs a window)

var r

func run(runner) -> void:
	r = runner
	print("polo points economy & lucky spin")
	Game.test_mode = true
	Store.reset_for_tests()
	_packs()
	_pro()
	_wheel_odds()
	await _wheel_lands()
	_cooldown()
	_claims()
	await _ads()
	await _screens()
	Store.reset_for_tests()
	Ads.test_next = "reward"
	Game.career = null

# ------------------------------------------------------------------ 1, 2: the shop
func _packs() -> void:
	var want := {"blue_100": [60, 1.99, "STARTER PACK"], "blue_350": [180, 5.99, "GAMEDAY PACK"], "blue_650": [350, 9.99, "ALL-STAR PACK"], "blue_1400": [800, 19.99, "LEGENDARY PACK"]}
	r.check(Store.PACK_IDS == ["blue_100", "blue_350", "blue_650", "blue_1400"], "the same four product ids are on sale")
	for id in want:
		var p := Store.product(id)
		r.check(int(p.credits) == int(want[id][0]) and is_equal_approx(float(p.usd), float(want[id][1])) and String(p.title) == String(want[id][2]),
			"%s: %d PP for $%.2f (%s)" % [id, want[id][0], want[id][1], p])
		r.check(Store.price(id) == "$%.2f" % float(want[id][1]), "%s shows %s before the store answers" % [id, Store.price(id)])
		# what a purchase actually pays
		Store.reset_for_tests()
		Store._inflight = id
		Store._on_purchased(id, "txn-" + id)
		Store._on_purchased(id, "txn-" + id)   # (the same transaction again)
		r.check(Store.vault == int(want[id][0]), "buying %s pays %d PP, once (%d)" % [id, want[id][0], Store.vault])
	Store.reset_for_tests()
	Store.bank.credit(1234, "earlier")
	Store._inflight = "blue_350"
	Store._on_purchased("blue_350", "txn-x")
	r.check(Store.vault == 1234 + 180, "a balance from before stays: the new pack adds on top")
	Store.reset_for_tests()

func _pro() -> void:
	r.check(Store.PRO_COINS == 200 and is_equal_approx(float(Store.product(Store.PRO_ID).usd), 7.99) and Store.PRO_ID in Store.NON_CONSUMABLES, "Pixel Polo +: $7.99, one-time, 200 PP")
	r.check(String(Store.PRO_PERKS[0]) == "200 Polo Points" and Store.PRO_PERKS.has("Player Name & Number Customization"), "its perks: 200 PP, names and numbers, the rest kept")
	Store._inflight = Store.PRO_ID
	Store._on_purchased(Store.PRO_ID, "pro-1")
	r.check(Store.pro and Store.vault == 200 and Store.pro_coins, "a new purchase: Pixel Polo + and 200 PP")
	Store._on_purchased(Store.PRO_ID, "pro-1")
	Store._on_owned(Store.PRO_ID)
	r.check(Store.vault == 200, "...once")
	# an owner from before (paid 500 back then): nothing more, ever
	Store.reset_for_tests()
	Store.pro = true
	Store.pro_coins = true
	Store.bank.credit(500, "old-pro", "PIXEL POLO +", "entitlement")
	Store._on_owned(Store.PRO_ID)
	Store._inflight = Store.PRO_ID
	Store._on_purchased(Store.PRO_ID, "pro-again")
	r.check(Store.vault == 500 and Store.pro, "an existing owner keeps what they have and gets no second bonus")
	# restoring still works: the unlock back, no coins
	Store.reset_for_tests()
	Store._on_owned(Store.PRO_ID)
	r.check(Store.pro and Store.vault == 0, "RESTORE PURCHASES brings Pixel Polo + back (no coins)")
	Store.reset_for_tests()

# ------------------------------------------------------------------ 4: the wheel
func _wheel_odds() -> void:
	var seg := LuckySpin.SEGMENTS
	r.check(seg.size() == 11 and LuckySpin.count(5) == 8 and LuckySpin.count(10) == 2 and LuckySpin.count(15) == 1, "11 slices: 8 x 5, 2 x 10, 1 x 15")
	r.check(absf(LuckySpin.expected() - 6.818) < 0.001, "expected value %.3f PP a spin" % LuckySpin.expected())
	r.check(absf(LuckySpin.probability(5) - 0.7273) < 0.0001 and absf(LuckySpin.probability(10) - 0.1818) < 0.0001 and absf(LuckySpin.probability(15) - 0.0909) < 0.0001, "72.73% / 18.18% / 9.09%")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var hits := []
	hits.resize(11)
	hits.fill(0)
	var n := 110000
	for i in n:
		hits[LuckySpin.pick(rng)] += 1
	var worst := 0.0
	for h in hits:
		worst = maxf(worst, absf(float(h) / n - 1.0 / 11.0))
	r.check(worst < 0.004, "every slice 1 in 11 (worst off by %.4f over %d draws)" % [worst, n])
	var pp := {5: 0, 10: 0, 15: 0}
	for i in 11:
		pp[int(seg[i])] += hits[i]
	print("  %d spins: 5 PP %.2f%%, 10 PP %.2f%%, 15 PP %.2f%%" % [n, pp[5] * 100.0 / n, pp[10] * 100.0 / n, pp[15] * 100.0 / n])
	r.check(absf(pp[15] * 1.0 / n - 1.0 / 11.0) < 0.004 and absf(pp[5] * 1.0 / n - 8.0 / 11.0) < 0.006, "the prizes come up as the wheel shows them")

func _wheel_lands() -> void:
	var w := LuckyWheel.new(56)
	Game.overlay.add_child(w)
	var landed := []
	w.landed.connect(func(s): landed.append(s))
	var bad := 0
	for k in 11:
		for off in [-0.45, 0.0, 0.45]:
			if LuckyWheel.slice_at_top(LuckyWheel.rot_for(k, off)) != k:
				bad += 1
	r.check(bad == 0, "every slice's stopping turn puts it under the pointer")
	var wrong := []
	for trial in 33:
		var k := trial % 11
		w.rot = randf() * 40.0
		w.spin_to(k, trial % 3 == 0)
		var steps := 0
		while w.spinning() and steps < 400:
			w._process(1.0 / 30.0)
			steps += 1
		if landed.back() != k or LuckyWheel.slice_at_top(w.rot) != k or w.win != k:
			wrong.append([k, landed.back(), LuckyWheel.slice_at_top(w.rot)])
	r.check(wrong.is_empty() and landed.size() == 33, "the wheel always stops on the slice it was given, landing once (%s)" % [wrong])
	w._render()
	var img := w._img
	r.check(img.get_pixel(56, 56 - 30).a == 1.0 and img.get_pixel(0, 0).a == 0.0, "the wheel is drawn, round")
	var cols := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and c.a < 1.0:
				cols["soft"] = true
	r.check(not cols.has("soft"), "no soft edges: every pixel solid or empty")
	w.queue_free()
	await r.get_tree().process_frame

# ------------------------------------------------------------------ 5: two spins every six hours
func _cooldown() -> void:
	var s := LuckySpin.new()
	var rng := RandomNumberGenerator.new()
	var t0 := 1_800_000_000
	r.check(s.available(t0) == 2 and s.status_text(t0) == "SPINS AVAILABLE: 2/2", "two spins to start")
	r.check(not s.claim("a", t0, rng).is_empty() and s.status_text(t0 + 5) == "SPINS AVAILABLE: 1/2", "one used: 1/2")
	r.check(not s.claim("b", t0 + 60, rng).is_empty() and s.available(t0 + 60) == 0, "both used")
	r.check(s.claim("c", t0 + 61, rng).is_empty(), "no third spin before the refresh")
	var fresh := LuckySpin.new()
	fresh.claim("f1", t0, rng)
	fresh.claim("f2", t0, rng)
	r.check(fresh.status_text(t0 + 1) == "NEXT SPINS IN: 05:59:59", "the countdown: %s" % fresh.status_text(t0 + 1))
	r.check(s.available(t0 + LuckySpin.COOLDOWN - 1) == 0 and s.available(t0 + LuckySpin.COOLDOWN) == 2, "both back together after 6 hours, not before")
	r.check(s.available(t0 + LuckySpin.COOLDOWN * 5) == 2, "never more than 2, however long you wait")
	# the clock starts with the first spin of a full allowance, not with opening the shop
	var q := LuckySpin.new()
	for i in 30:
		q.status_text(t0 + i * 3600)   # (looking at it doesn't start or restart anything)
	r.check(q.refill_at == 0 and q.available(t0 + 30 * 3600) == 2, "opening the shop never starts or restarts the clock")
	q = LuckySpin.new()
	q.claim("q1", t0, rng)
	q.status_text(t0 + 3 * 3600)
	q.claim("q2", t0 + 3 * 3600, rng)
	r.check(q.seconds_left(t0 + 3 * 3600) == 3 * 3600, "the second spin doesn't push the refresh out")
	# saved and loaded (a restart, another dynasty): the same allowance
	var back := LuckySpin.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	var s2 := LuckySpin.new()
	s2.claim("x", t0, rng)
	s2.claim("y", t0, rng)
	var b2 := LuckySpin.from_dict(JSON.parse_string(JSON.stringify(s2.to_dict())))
	r.check(b2.available(t0 + 10) == 0 and b2.seconds_left(t0 + 10) == LuckySpin.COOLDOWN - 10 and back.claims == s.claims, "a restart keeps the allowance and the countdown")
	# a clock set back: no early refill, no longer wait
	var s3 := LuckySpin.new()
	s3.claim("m", t0, rng)
	s3.claim("n", t0, rng)
	r.check(s3.available(t0 - 86400) == 0 and s3.seconds_left(t0 - 86400) == LuckySpin.COOLDOWN, "a clock set back changes nothing")
	var edited := LuckySpin.from_dict({"used": 9, "refill_at": t0 + 999999, "last_t": t0})
	r.check(edited.used == 2 and edited.seconds_left(t0) == LuckySpin.COOLDOWN, "a bad saved state is clamped (2 used, one cooldown at most)")
	# it's the account's, not the dynasty's
	Store.reset_for_tests()
	Store.claim_spin("acct-1", false)
	var c := Career.new_game("CULA", "A", "B", 77)
	Game.career = c
	c.year += 1
	c.start_season()
	r.check(Store.spin.used == 1 and not c.to_dict().has("spin") and not JSON.stringify(c.to_dict()).contains("acct-1"), "a new season and a dynasty save don't touch it (it isn't in the save)")
	Store.reset_all()
	r.check(Store.spin.used == 1, "RESET GAME doesn't hand out spins")
	Store.reset_for_tests()
	Game.career = null

# ------------------------------------------------------------------ 12: claims
func _claims() -> void:
	Store.reset_for_tests()
	Store.bank.credit(40, "before")
	var a := Store.claim_spin("ad-1", false)
	r.check(not a.is_empty() and Store.vault == 40 + int(a.pp) and LuckySpin.SEGMENTS[a.seg] == a.pp, "a spin pays its slice into the shared wallet (+%d)" % int(a.get("pp", 0)))
	r.check(Store.claim_spin("ad-1", false).is_empty() and Store.vault == 40 + int(a.pp), "the same ad pays once")
	r.check(Store.claim_spin("", false).is_empty(), "no transaction, no spin")
	r.check(Store.spin.pending.get("txn", "") == "ad-1", "paid before the wheel moves (shown later if the app stops mid-spin)")
	var b := Store.claim_spin("ad-2", false)
	r.check(not b.is_empty() and Store.claim_spin("ad-3", false).is_empty(), "the third ad in a window pays nothing")
	r.check(Store.vault == 40 + int(a.pp) + int(b.pp) and Store.spin.total_pp == int(a.pp) + int(b.pp), "exactly what the two spins won")
	# the test wheel: its own allowance, its own wallet
	var before := Store.vault
	Store.spin_test_force = LuckySpin.SEGMENTS.find(15)
	var t := Store.claim_spin("test-1", true, Store.spin_test_force)
	r.check(int(t.get("pp", 0)) == 15 and Store.spin_test_bank.balance == 15 and Store.vault == before, "a test spin: the test wallet, never the real Polo Points")
	r.check(Store.spin_test.used == 1 and Store.spin.used == 2, "and its own allowance")
	Store.spin_test_force = -1
	Store.spin_test_skip = LuckySpin.COOLDOWN
	r.check(Store.spin_test.available(Store.spin_now(true)) == 2 and Store.spin.available(Store.spin_now(false)) == 0, "the test clock runs ahead; the real one doesn't")
	Store.reset_for_tests()

# ------------------------------------------------------------------ 11: the ads
func _ads() -> void:
	r.check(Ads.backend_name == "test" and Store.spin_testing(), "the editor: test ads (TEST AD & SPIN)")
	r.check(Ads.PROD_UNITS.android == "" and Ads.PROD_UNITS.ios == "", "no production unit configured: no real ads can run")
	Store.reset_for_tests()
	var got := []
	var fin := []
	var on_claim := func(res): got.append(res)
	var on_fin := func(ok, msg): fin.append([ok, msg])
	Store.spin_claimed.connect(on_claim)
	Ads.ad_finished.connect(on_fin)
	# a callback with no ad open pays nothing
	Ads._on_earned()
	r.check(got.is_empty(), "a reward with no ad open: nothing")
	for mode in ["cancel", "fail"]:
		Ads.test_next = mode
		r.check(Ads.show_rewarded(), "a test ad starts (%s)" % mode)
		r.check(not Ads.show_rewarded(), "never two at once")
		await _until(func(): return not Ads.busy())
		r.check(got.is_empty() and Store.spin_test.available(Store.spin_now(true)) == 2 and fin.back()[0] == false, "%s: no reward, no spin used" % mode)
	Ads.test_next = "none"
	r.check(not Ads.ad_ready() and not Ads.show_rewarded(), "no ad loaded: nothing to show")
	Ads.test_next = "reward"
	Ads.show_rewarded()
	await _until(func(): return not Ads.busy())
	r.check(got.size() == 1 and Store.spin_test.used == 1 and Store.spin_test_bank.balance == int(got[0].pp), "a completed ad: one spin, paid once (the test ad repeats its callback)")
	Ads._on_earned()
	Ads._on_closed()
	r.check(got.size() == 1, "late repeats pay nothing")
	Store.spin_claimed.disconnect(on_claim)
	Ads.ad_finished.disconnect(on_fin)
	Store.reset_for_tests()

func _until(cond: Callable, limit: int = 300) -> void:
	for i in limit:
		if cond.call():
			return
		await r.get_tree().process_frame

# ------------------------------------------------------------------ 9, 16: the screens
func _screens() -> void:
	var win: Window = r.get_window()
	var was := win.size
	win.size = Vector2i(480, 270)
	Store.reset_for_tests()
	Game.career = Career.new_game("CULA", "A", "B", 91)
	Game.career.queue.clear()
	Game.goto("store")
	await _frames()
	var sc = Game.current_screen
	r.check(sc.find_child("LuckySpinCard", true, false) != null and sc.find_child("OpenSpin", true, false) != null, "the shop has its LUCKY SPIN section")
	r.check(sc.find_child("CoinPacks", true, false).get_child_count() == 4 and sc.find_child("ProCard", true, false) != null, "the packs and Pixel Polo + are still there")
	r.check(String((sc.find_child("SpinLine", true, false) as Label).text) == "SPINS AVAILABLE: 2/2", "the card shows the allowance")
	var pack := sc.find_child("Pack_blue_1400", true, false) as Control
	r.check(int(pack.get_meta("coins")) == 800, "the Legendary card is 800 PP")
	(sc.find_child("OpenSpin", true, false) as Button).pressed.emit()
	await _frames()
	var p: LuckySpinPanel = Game.overlay.get_child(Game.overlay.get_child_count() - 1)
	r.check(p is LuckySpinPanel, "SPIN THE WHEEL opens the wheel")
	var btn := p.find_child("SpinButton", true, false) as Button
	r.check(btn.text == "TEST AD & SPIN" and not btn.disabled, "the editor: TEST AD & SPIN")
	r.check(p.find_child("SpinOdds", true, false).get_child_count() == 12 and p.find_child("SpinDev", true, false) != null, "the odds and the Developer row")
	var box := p.find_child("LuckySpinPopup", true, false) as Control
	var vr := Rect2(Vector2.ZERO, r.get_viewport().get_visible_rect().size)
	r.check(vr.encloses(box.get_global_rect()), "the wheel's panel fits the page (%s in %s)" % [box.get_global_rect(), vr])
	r.check(_overflow(box).is_empty(), "no text runs out of its box (%s)" % [_overflow(box)])
	# the jackpot, through the real button
	Store.spin_test_force = LuckySpin.SEGMENTS.find(15)
	var real := Store.vault
	btn.pressed.emit()
	await _until(func(): return p.wheel.spinning())
	r.check(p.wheel.spinning() and btn.disabled, "the ad pays, the wheel spins, the button waits")
	while p.wheel.spinning():
		p.wheel._process(1.0 / 30.0)
	await _frames()
	var won := p.find_child("SpinWinText", true, false) as Label
	r.check(won != null and won.text == "JACKPOT! +15 PP!", "JACKPOT! +15 PP! (%s)" % (won.text if won else "none"))
	r.check(LuckyWheel.slice_at_top(p.wheel.rot) == Store.spin_test_force, "it stopped on the gold slice")
	r.check(Store.spin_test_bank.balance == 15 and Store.vault == real, "the test wallet +15; the real Polo Points untouched")
	r.check(String((p.find_child("SpinStatus", true, false) as Label).text) == "SPINS AVAILABLE: 1/2", "1/2 left")
	Store.spin_test_force = LuckySpin.SEGMENTS.find(5)
	btn.pressed.emit()
	await _until(func(): return p.wheel.spinning())
	while p.wheel.spinning():
		p.wheel._process(1.0 / 30.0)
	await _frames()
	won = p.find_child("SpinWinText", true, false) as Label
	r.check(won != null and won.text == "YOU WON +5 PP!", "YOU WON +5 PP!")
	p._refresh()
	r.check(btn.disabled and String((p.find_child("SpinStatus", true, false) as Label).text).begins_with("NEXT SPINS IN: 0"), "both used: the countdown, no button")
	for i in 6:
		(p.find_child("DevHour", true, false) as Button).pressed.emit()
	p._refresh()
	r.check(not btn.disabled and String((p.find_child("SpinStatus", true, false) as Label).text) == "SPINS AVAILABLE: 2/2", "six test hours later: 2/2")
	p.close()
	await _frames()
	Store.spin_test_force = -1
	win.size = was
	Game.goto("title")
	await _frames()

## Labels and buttons whose text is wider than they are.
func _overflow(n: Node) -> Array:
	var out := []
	for ch in n.find_children("*", "Label", true, false):
		var l := ch as Label
		if l.visible and l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text != "":
			var f := l.get_theme_font("font")
			var w := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
			if w > l.size.x + 1.0:
				out.append(l.text)
	return out

func _frames(n: int = 3) -> void:
	for i in n:
		await r.get_tree().process_frame

# ------------------------------------------------------------------ screenshots
static func shots(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Game.test_mode = true
	Store.reset_for_tests()
	var c := Career.new_game("CULA", "S", "H", 640)
	c.queue.clear()
	Game.career = c
	Store.bank.credit(240, "T-SHOT")
	Game.goto("store")
	await _snap(runner, dir, "SHOP_TOP")
	var sc: ScrollContainer = Game.current_screen.body.get_child(Game.current_screen.body.get_child_count() - 1)
	sc.scroll_vertical = 100000
	await _snap(runner, dir, "SHOP_END")
	var p := LuckySpinPanel.open()
	await _snap(runner, dir, "SPIN_OPEN")
	for row in [[15, "SPIN_JACKPOT"], [10, "SPIN_10"]]:
		Store.spin_test_force = LuckySpin.SEGMENTS.find(int(row[0]))
		p._spin()
		for i in 120:
			await runner.get_tree().process_frame
			if p.wheel.spinning():
				break
		var mid := 0
		while p.wheel.spinning():
			p.wheel._process(1.0 / 30.0)
			mid += 1
			if mid == 20:
				await _snap(runner, dir, row[1] + "_MID")
		p._process(0.4)
		await _snap(runner, dir, row[1])
	p._refresh()
	await _snap(runner, dir, "SPIN_DEPLETED")
	Ads.test_next = "none"
	Store.spin_test_skip += LuckySpin.COOLDOWN
	p._note.text = ""
	p._refresh()
	await _snap(runner, dir, "SPIN_NO_AD")
	Ads.test_next = "reward"
	p.queue_free()
	Store.spin_test_force = -1
	Store.reset_for_tests()
	Game.career = null

static func _snap(runner, dir: String, name: String) -> void:
	for i in 3:
		await runner.get_tree().process_frame
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
