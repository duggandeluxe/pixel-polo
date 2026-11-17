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
	await _team_previews()
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

const NAMES := ["GOAL CELEBRATIONS", "CROWD ATMOSPHERE", "BROADCAST PRESENTATION", "PREGAME PRESENTATION", "SCOREBOARD"]

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
	r.check(_button("COSMETIC PACKS") == null and _button("COIN EXCHANGE") == null and _node("StoreButton") != null, "no tabs left, STORE in the header")
	var bal: Control = _node("PoloBalance")
	var store_b: Control = _node("StoreButton")
	r.check(_button("GET POLO POINTS") == null and bal != null and not (bal is BaseButton) and bal.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and bal.find_children("*", "BaseButton", true, false).is_empty(), "the balance box is only a display, never a button")
	r.check(String(bal.find_child("Amount", true, false).text) == str(Wallet.yellow(c)), "the balance box shows the Polo Points")
	r.check(bal.get_parent() == store_b.get_parent() and bal.get_index() < store_b.get_index(), "the balance on the left, STORE on the far right")
	r.check(String((store_b as Button).text) == "STORE" and (store_b as Button).icon != null, "STORE with its coin")
	Wallet.grant_yellow(c, 7, "T-BAL")
	await _frames()
	r.check(String(_node("PoloBalance").find_child("Amount", true, false).text) == str(Wallet.yellow(c)), "the balance moves as Polo Points are earned")
	Wallet.spend_yellow(c, 7, "T-BAL")
	await _frames()
	r.check(String(_node("PoloBalance").find_child("Amount", true, false).text) == str(Wallet.yellow(c)), "...and spent")
	var grid: VBoxContainer = _node("UpgradeGrid")
	var order := []
	for row: Control in grid.get_children():
		order.append(row.get_children().map(func(ch): return String(ch.name)))
	r.check(order == [["Upgrade_goal", "Upgrade_crowd"], ["Upgrade_broadcast", "Upgrade_pregame"], ["Upgrade_scoreboard"]],
		"1: five cards: two rows of two, SCOREBOARD across the bottom (%s)" % str(order))
	var names := []
	for cd in VisualUpgrades.CATS:
		names.append(String(cd.name))
	r.check(names == NAMES and not names.has("VICTORY PRESENTATION") and not names.has("INSTANT REPLAY"), "1: the five, in order (no Instant Replay, no Victory Presentation)")
	r.check(_node("Upgrade_replay") == null and _node("ReplayBuy") == null and not _labels().contains("REPLAY"), "Instant Replay is nowhere on the gallery")
	r.check(_node("Buy_goal") == null and _node("Equip_goal_1") == null and _node("Preview_goal") == null, "no tier buttons, buying or previews on the gallery")
	# 26-28: laid out, nothing clipped, all reachable
	var rects := []
	for ch: Control in grid.get_children():
		for o: Rect2 in rects:
			r.check(not o.intersects(ch.get_global_rect()), "26: no two cards overlap")
		rects.append(ch.get_global_rect())
	var cards: Array = []
	for row: Control in grid.get_children():
		cards.append_array(row.get_children())
	rects = []
	for ch: Control in cards:
		for o: Rect2 in rects:
			r.check(not o.intersects(ch.get_global_rect()), "26: no two cards overlap")
		rects.append(ch.get_global_rect())
	var half: Control = _node("Upgrade_goal")
	var wide: Control = _node("Upgrade_scoreboard")
	var text_w: float = half.size.x - 1 - (6 + s.ART_W + 7) - 7
	for cd in VisualUpgrades.CATS:
		for w in String(cd.name).split(" "):
			r.check(Deck.fit(w, text_w, 16, "big") == w, "27: %s fits its card (two lines at most)" % cd.name)
	r.check(Deck.text_w("LEVEL 4 / 4 UNLOCKED") <= text_w and Deck.text_w("VIEW CELEBRATIONS") + 16 <= text_w, "27: the progress line and the cue fit")
	r.check(half.size.y >= s.CARD_H and wide.size.y >= s.CARD_H and absf(wide.size.y - half.size.y) <= 1.0, "27: every row the same height, the scenes fit (%s, %s)" % [half.size, wide.size])
	r.check(absf(wide.get_global_rect().position.x - half.get_global_rect().position.x) <= 1.0 and absf(wide.get_global_rect().end.x - _node("Upgrade_crowd").get_global_rect().end.x) <= 1.0,
		"SCOREBOARD spans both columns")
	# 28: all five on the screen at once, nothing to scroll
	var page: Rect2 = s.get_viewport_rect()
	for ch: Control in cards:
		r.check(page.encloses(ch.get_global_rect()), "28: %s is on the screen without scrolling (%s in %s)" % [ch.name, ch.get_global_rect(), page])
	var sc: ScrollContainer = s.body.get_parent() as ScrollContainer
	r.check(sc == null or (s.body.get_combined_minimum_size().y <= sc.size.y and s.body.get_combined_minimum_size().x <= sc.size.x), "28: nothing to scroll, either way")
	r.check(s.find_children("*", "ScrollContainer", true, false).all(func(n): return not s.body.is_ancestor_of(n)), "28: no scroll box of its own")
	# 2-9: every card, every level
	var coins: int = Wallet.yellow(c)
	for cd in VisualUpgrades.CATS:
		await _category(cd)
	r.check(Wallet.yellow(c) == coins and Store.looks.celebs.is_empty(), "10: all those previews cost nothing and own nothing")
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
		var tw: float = (_node("Tier_%d" % n) as Control).size.x - (43 if id == "goal" else 12)   # (a celebration card's icon)
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
			r.check(d.lab_goal_level() == n - 1, "9: the goal show with celebration LEVEL %d" % (n - 1))
		if id == "crowd":
			r.check(int(d.lab_style().get("lv", 1)) == n and (n == 1 or bool(d.lab_style().big)), "9: the stands at level %d" % n)
	r.check(String(_node("DetailPreview").text) == "PREVIEW AGAIN", "a level that's played offers PREVIEW AGAIN")
	await _press(_node("Tier_%d" % VisualUpgrades.top(id)))
	if id == "goal":
		r.check(String(_node("DetailAction").text).begins_with("PURCHASE") and not (_node("DetailAction") as Button).disabled and _node("Tier_4").get_meta("state") == "PURCHASE",
			"14: GOALPOST FIREWORKS is on sale from the start: nothing to unlock first")
		r.check(_node("Tier_1").get_meta("state") == "EQUIPPED" and _node("Tier_2").get_meta("state") == "PURCHASE" and _node("Tier_3").get_meta("state") == "PURCHASE",
			"CLASSIC owned and equipped; the other three for sale")
	else:
		r.check(String(_node("DetailAction").text) == "UNLOCK LEVEL 2 FIRST" and (_node("DetailAction") as Button).disabled and _labels().contains("PREVIEW AVAILABLE"), "14: the top level says to unlock level 2 first")
	d.on_back()
	await _frames()
	r.check(Game.current_name == "visual_shop", "4: back is the gallery")
	Game.current_screen.on_back()
	await _frames()
	r.check(Game.current_name == "more", "5: and the gallery's back is the Dynasty Hub")

## The previews star your own program: its copy at home, a real rival (your next opponent first),
## never the lab's made-up clubs; nothing they do reaches the save; another career shows at once.
func _team_previews() -> void:
	Store.reset_for_tests()
	var c := _career(803)
	Game.career = c
	var nxt := c.next_game()
	var rival := VisualUpgrades.preview_rival_id(c)
	r.check(nxt.has("opp") and rival == String(nxt.opp), "T1: the rival is your next opponent (%s, next %s)" % [rival, nxt])
	var saved := JSON.stringify(c.team().to_dict()) + JSON.stringify((c.teams[rival] as PoloTeam).to_dict())
	await _open("VISUAL UPGRADES")
	var s = Game.current_screen
	r.check(s.rival == c.teams[rival], "T2: the gallery's cards draw the real rival")
	for id in ["goal", "crowd", "broadcast", "pregame", "scoreboard"]:
		await _page(id)
		var d = Game.current_screen
		r.check(d.us.id == c.school and d.us.name == c.team().name and d.us.c1 == c.team().c1 and d.us.c2 == c.team().c2, "T3: %s previews your program (%s)" % [id, d.us.id])
		r.check(d.them.id == rival and d.us != c.team() and d.them != c.teams[rival], "T4: %s: against the real rival, both copies of the save's teams" % id)
		await _press(_node("DetailPreview"))
		for i in 300:
			d._process(1.0 / 30.0)
		d.on_back()
		await _frames()
	r.check(saved == JSON.stringify(c.team().to_dict()) + JSON.stringify((c.teams[rival] as PoloTeam).to_dict()), "T5: the previews changed nothing in the save's teams")
	# a different program (another save): the very next page shows it
	var c2 := Career.new_game("BROW", "S", "H", 804)
	c2.queue.clear()
	Game.career = c2
	await _page("scoreboard")
	r.check(Game.current_screen.us.id == "BROW" and Game.current_screen.them.id == VisualUpgrades.preview_rival_id(c2), "T6: another career's program shows at once")
	Game.current_screen.on_back()
	await _frames()
	# no games left or played: a real school from your conference
	c2.schedule = []
	var fallback := VisualUpgrades.preview_rival_id(c2)
	r.check(fallback != "" and fallback != "BROW" and c2.teams[fallback].conf == c2.team().conf, "T7: no schedule: a conference rival (%s)" % fallback)
	# Developer Mode's lab: your program first, NEXT SCHOOL still goes round all 30
	Game.settings.dev_mode = true
	Game.goto("visual_lab")
	await _frames()
	var lab = Game.current_screen
	r.check(lab.us.id == "BROW" and lab.us != c2.team(), "T8: VISUAL UPGRADE TESTING starts on your program (a copy)")
	lab.next_school()
	r.check(lab.us.id != "BROW" and c2.school == "BROW", "T9: NEXT SCHOOL still overrides, your program untouched")
	Game.settings.dev_mode = false
	Game.career = c
	Game.goto("more")
	await _frames()

func _buying() -> void:
	await _page("goal")
	var was: int = Wallet.yellow(Game.career)
	# any one first, in any order: GOALPOST FIREWORKS straight from CLASSIC, then CONFETTI POPPERS
	for row in [[4, 150, "GOALPOST FIREWORKS"], [2, 50, "CONFETTI POPPERS"]]:
		var n: int = row[0]
		var price: int = row[1]
		await _press(_node("Tier_%d" % n))
		r.check(_node("Tier_%d" % n).get_meta("state") == "PURCHASE", "%s is for sale" % row[2])
		await _press(_node("DetailAction"))
		var text := _dialog()
		r.check(text.contains("BUY %s?" % row[2]), "11-13: the confirmation: %s (its %d checked off the wallet below)" % [row[2], price])
		if n == 4:
			await _answer("CANCEL")
			r.check(Wallet.yellow(Game.career) == was and Store.looks.celebs.is_empty(), "CANCEL buys nothing")
			await _press(_node("DetailAction"))
		await _answer("CONFIRM")
		was -= price
		r.check(Wallet.yellow(Game.career) == was and Store.looks.owns_celeb(n - 1), "11-13, 15: %s took %d, once" % [row[2], price])
		r.check(String(_node("YellowChip").text).contains(str(was)), "24: the chip moves at once")
		r.check(_node("Tier_%d" % n).get_meta("state") == "EQUIPPED", "buying equips it, and it shows at once")
		if n == 4:
			r.check(_node("Tier_2").get_meta("state") == "PURCHASE" and _node("Tier_3").get_meta("state") == "PURCHASE", "the ones below it aren't unlocked with it")
	r.check(Store.looks.celebs == [1, 3] and _node("Tier_3").get_meta("state") == "PURCHASE" and _node("Tier_4").get_meta("state") == "OWNED", "owned: CONFETTI and FIREWORKS; WATER still for sale")
	r.check((_node("DetailAction") as Button).disabled and String(_node("DetailAction").text) == "EQUIPPED", "the equipped one says so")
	await _press(_node("Tier_4"))
	await _press(_node("DetailAction"))
	r.check(Store.looks.worn_celeb() == VisualUpgrades.FIREWORKS and Wallet.yellow(Game.career) == was and _node("Tier_2").get_meta("state") == "OWNED", "17: EQUIP an owned one, free")
	await _press(_node("Tier_1"))
	await _press(_node("DetailAction"))
	r.check(Store.looks.worn_celeb() == VisualUpgrades.CLASSIC and _node("Tier_1").get_meta("state") == "EQUIPPED" and Wallet.yellow(Game.career) == was, "...CLASSIC too")
	await _press(_node("Tier_4"))
	await _press(_node("DetailAction"))
	# not enough: the existing message, nothing moves
	await _page("crowd")
	var kept_coins: int = Game.career.credits
	Game.career.credits = 0
	Store.bank = CoinVault.new()
	await _press(_node("Tier_2"))
	await _press(_node("DetailAction"))
	r.check(_dialog().find("CONFIRM") == -1 and _dialog().contains("NOT ENOUGH POLO POINTS") and _dialog().contains("POLO POINTS SHOP") and Store.looks.level("crowd") == 1, "not enough: says so and offers the shop, nothing bought")
	await _answer("OK")
	Game.career.credits = kept_coins
	# 16, 18, 20, 21: on the gallery
	await _open("VISUAL UPGRADES")
	r.check(Store.looks.celebs == [1, 3] and Store.looks.worn_celeb() == VisualUpgrades.FIREWORKS, "16, 18: bought and equipped celebrations stay")
	var s = Game.current_screen
	r.check(s.progress("goal") == "2 / 3 OWNED" and s.cue("goal") == "VIEW CELEBRATIONS", "20, 21: two of three celebrations owned")
	r.check(s.progress("crowd") == "LEVEL 1 / 3 UNLOCKED" and s.cue("crowd") == "VIEW UPGRADES", "20: the others as they stand")
	# the store's detour keeps the page
	await _page("pregame")
	await _press(_node("YellowChip"))
	r.check(Game.current_name == "store", "the chip opens the shop")
	Game.current_screen.on_back()
	await _frames()
	r.check(Game.current_name == "upgrade_detail" and Game.current_screen.cat_id() == "pregame", "back from the store: the same page")
	# skip, and Reduce Motion
	var d = Game.current_screen
	await _press(_node("DetailPreview"))
	r.check(d.cine != null, "a pregame preview runs")
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
	r.check(_node("CoinPacks") != null and _node("CoinPacks").get_child_count() == Store.PACK_IDS.size(), "the Polo Points packs")
	r.check(_node("UpgradeGrid") == null, "nothing left behind")
	# no cap shop anywhere: nothing to buy, wear or win
	r.check(Caps.selected() == Caps.DEFAULT, "everybody wears the classic cap")
	Store.cap_selected = "chrome"
	Store.caps_owned = ["chrome"]
	r.check(Caps.selected() == Caps.DEFAULT, "an old purchase changes nothing")
	r.check(not FileAccess.get_file_as_string("res://src/core/career.gd").contains("Caps."), "an NCSA title awards no cap")
	# STORE: the packs; back comes back
	await _open("VISUAL UPGRADES")
	await _press(_node("StoreButton"))
	r.check(Game.current_name == "store" and _node("CoinPacks") != null, "25: STORE opens the packs")
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
	r.check(Store.looks.owns_celeb(VisualUpgrades.CONFETTI), "bought in dynasty A")
	var dict_a := JSON.stringify(a.to_dict())
	Game.career = b
	await _page("goal")
	r.check(_node("Tier_2").get_meta("state") != "PURCHASE", "19: the celebration is owned in dynasty B too")
	r.check(JSON.stringify(a.to_dict()) == dict_a, "22: browsing writes nothing to a dynasty")

func _dev_tools() -> void:
	Store.reset_for_tests()
	Game.settings.dev_mode = true
	DevGate.try_unlock("8008")   # (the developer tools: the DEV screen, behind its code)
	Game.goto("dev_settings")
	await _frames()
	for lab in [["CoinLab", "coin_lab"], ["VisualLab", "visual_lab"], ["RefineLab", "refine_lab"]]:
		r.check(_node(lab[0]) != null, "25: %s in Developer Mode" % lab[1])
	for scr in ["coin_lab", "visual_lab", "refine_lab"]:
		Game.goto(scr)
		await _frames()
		r.check(Game.current_name == scr, "25: %s opens" % scr)
	Game.settings.dev_mode = false
