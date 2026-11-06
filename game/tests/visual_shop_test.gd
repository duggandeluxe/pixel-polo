extends RefCounted
## The Dynasty Hub's VISUAL UPGRADES screen (visual_shop.gd): Game Guide replaced, three tabs moved
## out of the store, the same wallets. Numbers are the spec's Developer Mode checks.
##   godot --headless --path game -- --test visual_shop
## Screenshots (needs a window): --test shop_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("visual shop")
	var win: Window = r.get_window()
	var was_size := win.size
	win.size = Vector2i(480, 270)   # (the game's real page: fits and scrolls are measured on it)
	await _frames()
	print("  page: ", r.get_viewport().get_visible_rect().size)
	await _hub()
	await _upgrades()
	await _store()
	await _dynasties()
	await _dev_tools()
	Store.reset_for_tests()
	Game.career = null
	win.size = was_size
	Game.goto("title")
	await _frames(2)

func _frames(n: int = 3) -> void:
	for i in n:
		await r.get_tree().process_frame

func _node(name: String) -> Node:
	return Game.current_screen.find_child(name, true, false)

func _career(seed_n: int, earned: int = 0) -> Career:
	var c := Career.new_game("GWU", "S", "H", seed_n)
	c.queue.clear()
	if earned > 0:
		c.add_credits(earned, "WIN")
	return c

## A live button by its text.
func _button(text: String) -> Button:
	for b in Game.current_screen.find_children("*", "Button", true, false):
		if String(b.text) == text and not b.is_queued_for_deletion():
			return b
	return null

func _press(b: BaseButton) -> void:
	b.pressed.emit()
	await _frames()

func _labels() -> String:
	var out := ""
	for n in Game.current_screen.find_children("*", "Label", true, false):
		out += String(n.text) + "\n"
	return out

## Through the hub's card.
func _open(_area: String = "") -> void:
	Game.goto("more")
	await _frames()
	await _press(_node("Card_visual_shop"))

func _hub() -> void:
	Store.reset_for_tests()
	Game.career = _career(801)
	Game.goto("more")
	await _frames()
	var s = Game.current_screen
	var grid: GridContainer = _node("Cards")
	r.check(grid.get_child_count() == 8 and grid.get_child(6).name == "Card_visual_shop", "1: VISUAL UPGRADES has Game Guide's place in the 2x4")
	r.check(_node("Card_howto") == null and not JSON.stringify(s.CARDS).contains("GAME GUIDE"), "1: no Game Guide in the Dynasty Hub")
	var names := []
	for ch in grid.get_children():
		names.append(String(ch.name))
	r.check(names == ["Card_program", "Card_news", "Card_team_trophies", "Card_records", "Card_store", "Card_settings", "Card_visual_shop", "Card_recruiting"], "1: the other cards are where they were")
	var card_w: float = (grid.get_child(6) as Control).size.x - 15
	r.check(Deck.fit("VISUAL UPGRADES", card_w, 16, "big") == "VISUAL UPGRADES", "the card's title isn't cut short")
	await _press(_node("Card_visual_shop"))
	r.check(Game.current_name == "visual_shop", "2: the card opens the screen")
	Game.goto("title")
	await _frames()
	var help_goes := FileAccess.get_file_as_string("res://src/ui/screens/title.gd").contains('Game.goto("howto")')
	r.check(help_goes, "the Game Guide is still on the title screen's help button")

const NAMES := ["GOAL CELEBRATIONS", "INSTANT REPLAY", "CROWD ATMOSPHERE", "BROADCAST PRESENTATION", "VICTORY PRESENTATION", "PREGAME PRESENTATION"]

## A category's page, through its gallery card.
func _page(id: String) -> void:
	await _open("VISUAL UPGRADES")
	await _press(_node("Upgrade_" + id))

## Answers the open dialog.
func _answer(text: String) -> void:
	for n in Game.overlay.find_children("*", "Button", true, false):
		if String(n.text) == text and not n.is_queued_for_deletion():
			n.pressed.emit()
			await _frames()
			return
	r.check(false, "no %s in the dialog" % text)

func _dialog() -> String:
	var out := ""
	for n in Game.overlay.find_children("*", "Button", true, false) + Game.overlay.find_children("*", "Label", true, false):
		if not n.is_queued_for_deletion():
			out += String(n.text) + "\n"
	return out

func _upgrades() -> void:
	Store.reset_for_tests()
	var c := _career(802)
	Game.career = c
	Store.bank.credit(875, "T-UP")
	await _open("VISUAL UPGRADES")
	var s = Game.current_screen
	r.check(s.title_label.text == "VISUAL UPGRADES", "the screen's title")
	r.check(_button("COSMETIC PACKS") == null and _button("COIN EXCHANGE") == null and _node("GetCoins") != null, "no tabs left, GET YELLOW COINS in the header")
	var grid: GridContainer = _node("UpgradeGrid")
	r.check(grid != null and grid.columns == 2 and grid.get_child_count() == 6, "1: six cards, two columns")
	var names := []
	for cd in VisualUpgrades.CATS:
		names.append(String(cd.name))
	r.check(names == NAMES, "1: the six, in order")
	r.check(_node("Buy_goal") == null and _node("Equip_goal_1") == null and _node("Preview_goal") == null, "no tier buttons, buying or previews on the gallery")
	# 26-28: laid out, nothing clipped, all reachable
	var rects := []
	for ch: Control in grid.get_children():
		for o: Rect2 in rects:
			r.check(not o.intersects(ch.get_global_rect()), "26: no two cards overlap")
		rects.append(ch.get_global_rect())
	var card_w: float = (grid.get_child(0) as Control).size.x
	var text_w: float = card_w - 1 - (6 + s.ART_W + 7) - 6
	for cd in VisualUpgrades.CATS:
		r.check(Deck.fit(String(cd.name), card_w - 15, 16, "big") == String(cd.name), "27: %s fits its card" % cd.name)
		r.check(s._lines(String(UpgradeArt.TAGS[cd.id]).to_upper(), text_w).size() <= 2, "27: %s's line is two lines at most" % cd.name)
	r.check(Deck.text_w("LEVEL 4 / 4 UNLOCKED") <= text_w, "27: the progress line fits")
	var sc: ScrollContainer = s.body.get_child(s.body.get_child_count() - 1)
	sc.scroll_vertical = 100000
	await _frames()
	r.check(sc.scroll_vertical > 0 and sc.get_global_rect().encloses((grid.get_child(5) as Control).get_global_rect()), "28: scrolled down, the last card is on the page (%s in %s, at %d)" % [(grid.get_child(5) as Control).get_global_rect(), sc.get_global_rect(), sc.scroll_vertical])
	r.check(grid.get_combined_minimum_size().x <= sc.size.x, "no sideways scrolling")
	# 2-9: every card, every level
	var coins: int = Wallet.yellow(c)
	for cd in VisualUpgrades.CATS:
		if String(cd.id) != "replay":
			await _category(cd)
	r.check(Wallet.yellow(c) == coins and Store.looks.level("goal") == 1, "10: all those previews cost nothing and own nothing")
	await _buying()

func _category(cd: Dictionary) -> void:
	var id := String(cd.id)
	await _page(id)
	var d = Game.current_screen
	r.check(Game.current_name == "upgrade_detail" and d.cat_id() == id and d.title_label.text == String(cd.name), "2, 3: %s opens its page" % cd.name)
	r.check(_node("Tiers").get_child_count() == VisualUpgrades.top(id), "6: %s: its levels" % id)
	var body_h: float = d.body.get_combined_minimum_size().y
	r.check(body_h <= d.body.size.y, "26: the page fits (%d of %d)" % [body_h, d.body.size.y])
	for n in range(1, VisualUpgrades.top(id) + 1):
		await _press(_node("Tier_%d" % n))
		var tier: Array = cd.tiers[n - 1]
		r.check(d.sel == n and String(_node("LevelDesc").text) == String(tier[1]), "7: %s level %d: its description (sel %d, \"%s\", screen %s)" % [id, n, d.sel, String(_node("LevelDesc").text), Game.current_name])
		r.check(not _labels().contains(String(cd.tiers[n % cd.tiers.size()][1])), "only the selected level's description")
		var tw: float = (_node("Tier_%d" % n) as Control).size.x - 12
		var short: String = tier[2] if tier.size() > 2 else tier[0]
		r.check(Deck.fit(short, tw) == short, "27: %s fits its level card" % short)
		r.check(_node("LevelInfo").get_parent().get_combined_minimum_size().y <= (_node("PreviewWindow") as Control).size.y, "27: %s level %d's panel fits" % [id, n])
		await _press(_node("DetailPreview"))
		for i in 400:
			if d.status.contains(String(tier[0])):
				break
			d._process(1.0 / 30.0)
		r.check(d.lv == n and d.status.contains(String(tier[0])), "8, 9: %s level %d previews itself, owned or not (%s)" % [id, n, d.status])
		if id == "goal":
			r.check(d.lab_goal_level() == n, "9: the goal show at level %d" % n)
		if id == "crowd":
			r.check(int(d.lab_style().get("lv", 1)) == n and (n == 1 or bool(d.lab_style().big)), "9: the stands at level %d" % n)
	r.check(String(_node("DetailPreview").text) == "REPLAY PREVIEW", "a level that's played offers REPLAY PREVIEW")
	await _press(_node("Tier_%d" % VisualUpgrades.top(id)))
	r.check(String(_node("DetailAction").text) == "UNLOCK LEVEL 2 FIRST" and (_node("DetailAction") as Button).disabled and _labels().contains("PREVIEW AVAILABLE"), "14: the top level says to unlock level 2 first")
	d.on_back()
	await _frames()
	r.check(Game.current_name == "visual_shop", "4: back is the gallery")
	Game.current_screen.on_back()
	await _frames()
	r.check(Game.current_name == "more", "5: and the gallery's back is the Dynasty Hub")

func _buying() -> void:
	await _page("goal")
	var was: int = Wallet.yellow(Game.career)
	for row in [[2, 125], [3, 250], [4, 500]]:
		var n: int = row[0]
		var price: int = row[1]
		await _press(_node("Tier_%d" % n))
		r.check(_node("Tier_%d" % n).get_meta("state") == "AVAILABLE", "level %d is the next to buy" % n)
		await _press(_node("DetailAction"))
		var text := _dialog()
		r.check(text.contains("UNLOCK GOAL CELEBRATIONS LEVEL %d?" % n), "11-13: the confirmation: level %d, %d" % [n, price])
		if n == 2:
			await _answer("CANCEL")
			r.check(Wallet.yellow(Game.career) == was and Store.looks.level("goal") == 1, "CANCEL buys nothing")
			await _press(_node("DetailAction"))
		await _answer("CONFIRM")
		was -= price
		r.check(Wallet.yellow(Game.career) == was and Store.looks.level("goal") == n, "11-13, 15: level %d took %d, once" % [n, price])
		r.check(String(_node("YellowChip").text).contains(str(was)), "24: the chip moves at once")
		r.check(_node("Tier_%d" % n).get_meta("state") == "EQUIPPED", "buying wears it, as ever, and it shows at once")
	r.check(Store.looks.worn("goal") == 4 and (_node("DetailAction") as Button).disabled and String(_node("DetailAction").text) == "EQUIPPED", "the worn level says so")
	await _press(_node("Tier_2"))
	await _press(_node("DetailAction"))
	r.check(Store.looks.worn("goal") == 2 and Wallet.yellow(Game.career) == was and _node("Tier_4").get_meta("state") == "UNLOCKED", "17: any lower level, free")
	# not enough: the existing message, nothing moves
	await _page("crowd")
	var kept_coins: int = Game.career.credits
	Game.career.credits = 0
	Store.bank = CoinVault.new()
	await _press(_node("Tier_2"))
	await _press(_node("DetailAction"))
	r.check(_dialog().find("CONFIRM") == -1 and _dialog().contains("NOT ENOUGH YELLOW COINS") and _dialog().contains("YELLOW COIN SHOP") and Store.looks.level("crowd") == 1, "not enough: says so and offers the shop, nothing bought")
	await _answer("OK")
	Game.career.credits = kept_coins
	# 16, 18, 20, 21: on the gallery
	await _open("VISUAL UPGRADES")
	r.check(Store.looks.level("goal") == 4 and Store.looks.worn("goal") == 2, "16, 18: bought and worn levels stay")
	var s = Game.current_screen
	r.check(s.progress("goal") == "LEVEL 4 / 4 UNLOCKED" and s.cue("goal") == "MAXED OUT", "20, 21: level 4 reads as maxed out")
	r.check(s.progress("replay") == "ONE-TIME UNLOCK" and s.cue("replay") == "VIEW UNLOCK", "20: the others as they stand")
	# the store's detour keeps the page
	await _page("victory")
	await _press(_node("YellowChip"))
	r.check(Game.current_name == "store", "the chip opens the shop")
	Game.current_screen.on_back()
	await _frames()
	r.check(Game.current_name == "upgrade_detail" and Game.current_screen.cat_id() == "victory", "back from the store: the same page")
	# skip, and Reduce Motion
	var d = Game.current_screen
	await _press(_node("DetailPreview"))
	r.check(d.cine != null, "a victory preview runs")
	d.skip_preview()
	r.check(d.cine == null and not d.status.contains("LAB"), "TAP TO SKIP stops it")
	var t0 := Time.get_ticks_usec()
	await _page("goal")
	d = Game.current_screen
	await _press(_node("DetailPreview"))
	t0 = Time.get_ticks_usec()
	for i in 90:
		d._process(1.0 / 30.0)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 90.0
	r.check(ms < 8.0, "30: a preview frame stays cheap (%.2f ms)" % ms)
	await _open("VISUAL UPGRADES")
	s = Game.current_screen
	var real_test: bool = Game.test_mode
	Game.test_mode = false
	Game.settings.reduce_motion = true
	var a0: float = s.art_t
	s._process(0.5)
	r.check(s.art_t == a0 and HotFire.calm(), "29: Reduce Motion: the cards hold still, previews calm")
	Game.settings.reduce_motion = false
	s._process(0.5)
	r.check(s.art_t > a0, "the cards move otherwise")
	Game.test_mode = real_test

func _store() -> void:
	Store.reset_for_tests()
	Game.career = _career(804)
	Game.goto("more")
	await _frames()
	await _press(_node("Card_store"))
	for gone in ["VISUAL UPGRADES", "COSMETIC PACKS", "COIN EXCHANGE", "CAP SHOP"]:
		r.check(_button(gone) == null, "no %s tab in the store" % gone)
	r.check(_node("CoinPacks") != null and _node("CoinPacks").get_child_count() == Store.PACK_IDS.size(), "the Yellow Coin packs")
	r.check(_node("UpgradeGrid") == null, "nothing left behind")
	# no cap shop anywhere: nothing to buy, wear or win
	r.check(Caps.selected() == Caps.DEFAULT, "everybody wears the classic cap")
	Store.cap_selected = "chrome"
	Store.caps_owned = ["chrome"]
	r.check(Caps.selected() == Caps.DEFAULT, "an old purchase changes nothing")
	r.check(not FileAccess.get_file_as_string("res://src/core/career.gd").contains("Caps."), "an NCSA title awards no cap")
	# GET YELLOW COINS: the packs; back comes back
	await _open("VISUAL UPGRADES")
	await _press(_node("GetCoins"))
	r.check(Game.current_name == "store" and _node("CoinPacks") != null, "25: GET YELLOW COINS opens the packs")
	Game.current_screen.on_back()
	await _frames()
	r.check(Game.current_name == "visual_shop", "back from the store to the screen")
	Game.current_screen.on_back()
	await _frames()
	r.check(Game.current_name == "more", "and back to the hub")

func _dynasties() -> void:
	Store.reset_for_tests()
	var a := _career(808, 150)
	var b := _career(809, 30)
	Game.career = a
	await _page("goal")
	await _press(_node("Tier_2"))
	await _press(_node("DetailAction"))
	await _answer("CONFIRM")
	r.check(Store.looks.level("goal") == 2, "bought in dynasty A")
	var dict_a := JSON.stringify(a.to_dict())
	Game.career = b
	await _page("goal")
	r.check(_node("Tier_2").get_meta("state") != "AVAILABLE" and _node("Tier_2").get_meta("state") != "LOCKED", "19: the level is owned in dynasty B too")
	r.check(JSON.stringify(a.to_dict()) == dict_a, "22: browsing writes nothing to a dynasty")

func _dev_tools() -> void:
	Store.reset_for_tests()
	Game.settings.dev_mode = true
	Game.goto("settings")
	await _frames()
	for lab in [["CoinLab", "coin_lab"], ["VisualLab", "visual_lab"], ["RefineLab", "refine_lab"]]:
		r.check(_node(lab[0]) != null, "25: %s in Developer Mode" % lab[1])
	for scr in ["coin_lab", "visual_lab", "refine_lab"]:
		Game.goto(scr)
		await _frames()
		r.check(Game.current_name == scr, "25: %s opens" % scr)
	Game.settings.dev_mode = false
