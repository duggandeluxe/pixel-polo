extends RefCounted
## LANGUAGE: Settings -> LANGUAGE -> SELECT LANGUAGE -> the game's text in any of the App
## Store's 50 localizations (Loc, res://locale/*.json).
##   godot --headless --path game -- --test language
##   godot --path game --resolution 1440x810 -- --test language_png <dir> [ids,comma,separated]
##   godot --headless --path game -- --test loc_missing <out.json>   (the extraction worklist)

var r

func run(runner) -> void:
	r = runner
	print("language")
	var kept: Dictionary = Game.settings.duplicate(true)
	var kept_career = Game.career
	Game.career = null
	_registry()
	_catalogs()
	_plurals_and_numbers()
	_patterns()
	await _settings_button()
	await _selector()
	await _switching()
	await _every_locale_fits()
	_persistence()
	Loc.apply(Loc.DEFAULT, false)
	Game.settings = kept
	Game.save_settings()
	Loc.apply(Loc.startup_language(), false)
	Game.career = kept_career
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n: int = 3) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _find(name: String) -> Node:
	return Game.current_screen.find_child(name, true, false)

## Inside the page (its logical 480 x 270, however wide the window's aspect makes it).
func _inside(n: Control) -> bool:
	var vr := Game.current_screen.get_viewport_rect()
	return vr.encloses(n.get_global_rect().grow(-0.5))

# ------------------------------------------------------------------ the 50
const APPLE_50 := ["ar", "bn", "ca", "zh-Hans", "zh-Hant", "hr", "cs", "da", "nl", "en-AU", "en-CA",
	"en-GB", "en-US", "fi", "fr", "fr-CA", "de", "el", "gu", "he", "hi", "hu", "id", "it", "ja", "kn",
	"ko", "ms", "ml", "mr", "no", "or", "pl", "pt-BR", "pt-PT", "pa", "ro", "ru", "sk", "sl", "es-MX",
	"es-ES", "sv", "ta", "te", "th", "tr", "uk", "ur", "vi"]

func _registry() -> void:
	var ids: Array = Loc.ids()
	r.check(ids.size() == 50 and ids == APPLE_50, "the App Store's 50 localizations, in its order, by Apple id")
	var natives := {}
	for id in ids:
		natives[Loc.native_name(id)] = true
	r.check(natives.size() == 50, "50 distinct native names")
	r.check(Loc.native_name("ja") == "日本語" and Loc.native_name("zh-Hant") == "繁體中文" and Loc.native_name("pt-BR") == "Português (Brasil)"
		and Loc.native_name("es-MX") == "Español (México)" and Loc.native_name("ar") == "العربية", "native names in their own writing systems")
	r.check(ids.filter(func(i): return Loc.is_rtl(i)) == ["ar", "he", "ur"], "right-to-left text: Arabic, Hebrew, Urdu")
	r.check(Loc.DEFAULT == "en-US" and String(Game._default_settings.get("language", "x")) == "", "a new player: no language picked (the phone's own)")
	# the phone's language, mapped to the nearest of the 50; English when it isn't one of them
	var cases := {"en_US": "en-US", "en_GB": "en-GB", "en_NZ": "en-AU", "en_IN": "en-US", "en-CA": "en-CA",
		"fr_FR": "fr", "fr_CA": "fr-CA", "fr_BE": "fr", "es_ES": "es-ES", "es_MX": "es-MX", "es_419": "es-MX",
		"pt_BR": "pt-BR", "pt_PT": "pt-PT", "pt": "pt-BR", "zh_CN": "zh-Hans", "zh_Hans_CN": "zh-Hans",
		"zh_TW": "zh-Hant", "zh_Hant_HK": "zh-Hant", "zh_HK": "zh-Hant", "nb_NO": "no", "nn": "no",
		"ja_JP": "ja", "de_AT": "de", "ar_EG": "ar", "iw_IL": "he", "in_ID": "id", "ta_IN": "ta",
		"sr_RS": "en-US", "sw_KE": "en-US", "": "en-US"}
	var wrong: Array = []
	for k in cases:
		if Loc.from_device(k) != cases[k]:
			wrong.append("%s->%s" % [k, Loc.from_device(k)])
	r.check(wrong.is_empty(), "the phone's language mapped to the App Store's 50, else English %s" % str(wrong))
	# nothing picked, or a broken pick: the phone's; a pick: kept over the phone's
	var saved = Game.settings.get("language")
	var dev := Loc.device_language()
	var got: Array = []
	for v in [null, "", "xx-NOPE"]:
		if v == null:
			Game.settings.erase("language")
		else:
			Game.settings.language = v
		got.append(Loc.startup_language())
	r.check(got.all(func(x): return x == dev), "no pick: the phone's language (%s) %s" % [dev, str(got)])
	Game.settings.language = "ko" if dev != "ko" else "sv"
	r.check(Loc.startup_language() == Game.settings.language, "a pick in Settings wins over the phone's language")
	Game.settings.language = saved if saved != null else ""
	Loc.apply("en-US", false)

## Every locale has a catalog; every non-English one translates every key, keeps every
## placeholder, and has the plural forms its language needs.
func _catalogs() -> void:
	var src: Dictionary = Loc.read_file("en-US").get("strings", {})
	r.check(src.size() >= 40, "the English source catalog lists the keys (%d)" % src.size())
	var no_file: Array = []
	var gaps: Array = []
	var bad_ph: Array = []
	var stray: Array = []
	for id in Loc.ids():
		if id == "en-US":
			continue
		if Loc.read_file(id).is_empty():
			no_file.append(id)
			continue
		var cat = Loc.load_catalog(id)
		for k in cat.msgs:
			if not src.has(k):
				stray.append("%s:%s" % [id, k])
		if not String(id).begins_with("en-"):
			for k in src:
				if not cat.msgs.has(k):
					gaps.append("%s:%s" % [id, k])
				elif not _slots_ok(k, cat.msgs[k]):
					bad_ph.append("%s:%s" % [id, k])
	r.check(no_file.is_empty(), "every locale has its catalog file %s" % str(no_file))
	r.check(gaps.is_empty(), "every key translated in every non-English locale %s" % str(gaps.slice(0, 6)))
	r.check(bad_ph.is_empty(), "placeholders (%%s, %%d) kept in every translation %s" % str(bad_ph.slice(0, 6)))
	r.check(stray.is_empty(), "no catalog has keys the game doesn't use %s" % str(stray.slice(0, 6)))
	# regional variants differ where the language does
	var pairs := [["en-GB", "en-US"], ["fr-CA", "fr"], ["pt-BR", "pt-PT"], ["es-MX", "es-ES"], ["zh-Hans", "zh-Hant"]]
	for p in pairs:
		var a = Loc.load_catalog(p[0])
		var b = Loc.load_catalog(p[1])
		var differ := false
		for k in src:
			if String(a.msgs.get(k, k)) != String(b.msgs.get(k, k)):
				differ = true
				break
		r.check(differ, "%s and %s are distinct (regional wording)" % p)
	# a broken or missing file: English, never blank
	r.check(Loc.load_catalog("xx-NOPE").msgs.is_empty(), "an unknown locale: nothing loaded (English)")

## A translation keeps the key's placeholders: %x in order (an English plural ending, "GOAL%s",
## may be left out) and every {name}.
func _slots_ok(key: String, tr: String) -> bool:
	var a := _slots(key)
	var b := _slots(tr)
	var without: Array = []
	for i in a[0].size():
		if not i in a[1]:
			without.append(a[0][i])
	return (b[0] == a[0] or b[0] == without) and a[2] == b[2]

## [the %x in order, the indexes of English plural endings, the sorted {names}]
func _slots(s: String) -> Array:
	var re := RegEx.create_from_string("%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[sdif]|%%|\\{[A-Za-z_]+\\}")
	var seq: Array = []
	var suffix: Array = []
	var named: Array = []
	var prev_end := 0
	var prev := ""
	for m in re.search_all(s):
		var t := m.get_string()
		var before := s.substr(m.get_start() - 1, 1) if m.get_start() > prev_end else ""   # (literal text only)
		var joined := m.get_start() == prev_end and prev == "%s"   # ("%s%s": droppable too)
		prev_end = m.get_end()
		prev = t
		if t == "%%":
			continue
		if t.begins_with("{"):
			named.append(t)
			continue
		var after := s.substr(m.get_end(), 1)
		if t == "%s" and ((before.to_upper() != before.to_lower() and not (after.to_upper() != after.to_lower())) or joined):
			suffix.append(seq.size())
		seq.append(t)
	named.sort()
	return [seq, suffix, named]

## Built text: one catalog key with %s / %d translates every string of its shape; names and
## numbers in the slots stay as they are.
func _patterns() -> void:
	var c = Loc.Catalog.new()
	c.msgs = {"%s SCORES!": "¡GOL DE %s!", "WEEK %d": "SEMANA %d", "MEDIUM": "MEDIA",
		"Quick Match is at %s.": "Partido rápido: %s.", "%d-%d WIN (%s)": "VICTORIA %d-%d (%s)", "%s %s": "X"}
	c.compile()
	var got: Array = []
	for t in ["RIVERA SCORES!", "WEEK 12", "Quick Match is at MEDIUM.", "12-9 WIN (OT)", "Rich", "WEEK", "3:45", "Ana Lopez"]:
		got.append(c.lookup(t))
	r.check(got == ["¡GOL DE RIVERA!", "SEMANA 12", "Partido rápido: MEDIA.", "VICTORIA 12-9 (OT)", "", "", "", ""],
		"patterns: built strings translated, names and numbers kept, wordless patterns ignored %s" % str(got))
	c = Loc.Catalog.new()
	c.msgs = {"{name} made {saves} saves.": "{saves} paradas de {name}.", "%d GOAL%s": "GOLES: %d",
		"Goals in a game": "Goles en un partido", "+%d{coin} NOW": "+%d{coin} AHORA", "%+d coach rep": "%+d de reputación",
		"%d player%s healthy again": "%d jugador%s sano%s", "HOT": "EN RACHA", "%s IS %s!": "¡%s ESTÁ %s!",
		"FRESHMAN": "NOVATO", "Center": "Boya", "INCOMING": "LLEGAN", "AWAY": "FUERA", "GAME %d/%d": "PARTIDO %d/%d", "ACTUAL: %d %s%s": "REAL: %d %s", "+%d XP TO %s%s": "+%d XP PARA %s%s", "GOAL": "GOL"}
	c.compile()
	got = []
	for t in ["Ana Rivera made 12 saves.", "3 GOALS", "1 GOAL", "GOALS IN A GAME", "+5{coin} NOW", "+3 coach rep", "-2 coach rep", "RIVERA IS HOT!", "freshman", "center", "ACTUAL: 3 GOALS", "ACTUAL: 1 GOAL", "+40 XP TO RIVERA (TEAM LEADER)", "+40 XP TO RIVERA", "INCOMING 0", "AWAY.", "2026-27  GAME 1/16"]:
		got.append(c.lookup(t))
	r.check(got == ["12 paradas de Ana Rivera.", "GOLES: 3", "GOLES: 1", "GOLES EN UN PARTIDO", "+5{coin} AHORA", "+3 de reputación", "-2 de reputación", "¡RIVERA ESTÁ EN RACHA!", "novato", "Boya", "REAL: 3 GOL", "REAL: 1 GOL", "+40 XP PARA RIVERA (TEAM LEADER)", "+40 XP PARA RIVERA", "LLEGAN 0", "FUERA.", "2026-27  PARTIDO 1/16"],
		"patterns: named slots reordered, English plural endings dropped, capitals, tags, signed numbers %s" % str(got))

func _plurals_and_numbers() -> void:
	r.check(Loc.plural_category("ru", 1) == "one" and Loc.plural_category("ru", 3) == "few" and Loc.plural_category("ru", 5) == "many"
		and Loc.plural_category("ru", 21) == "one" and Loc.plural_category("ru", 11) == "many", "plurals: Russian one/few/many")
	r.check(Loc.plural_category("ar", 0) == "zero" and Loc.plural_category("ar", 2) == "two" and Loc.plural_category("ar", 7) == "few"
		and Loc.plural_category("ar", 50) == "many" and Loc.plural_category("ar", 100) == "other", "plurals: Arabic's six forms")
	r.check(Loc.plural_category("pl", 22) == "few" and Loc.plural_category("pl", 25) == "many" and Loc.plural_category("ja", 1) == "other"
		and Loc.plural_category("fr", 0) == "one" and Loc.plural_category("pt-PT", 0) == "other" and Loc.plural_category("pt-BR", 0) == "one",
		"plurals: Polish, Japanese, French, the two Portugueses")
	r.check(Loc.num(1234567, "en-US") == "1,234,567" and Loc.num(1234567, "de") == "1.234.567" and Loc.num(1234567, "fr") == "1 234 567"
		and Loc.num(1234567, "hi") == "12,34,567" and Loc.num(1234, "es-ES") == "1234" and Loc.num(12345, "es-ES") == "12.345"
		and Loc.num(12345, "es-MX") == "12,345" and Loc.num(-5000, "en-GB") == "-5,000", "numbers grouped the locale's way")
	Loc.apply("ru", false)
	r.check(Loc.tn("%d LANGUAGES", 1) == "1 ЯЗЫК" and Loc.tn("%d LANGUAGES", 3) == "3 ЯЗЫКА" and Loc.tn("%d LANGUAGES", 50) == "50 ЯЗЫКОВ",
		"plural text: 1 ЯЗЫК, 3 ЯЗЫКА, 50 ЯЗЫКОВ (%s / %s / %s)" % [Loc.tn("%d LANGUAGES", 1), Loc.tn("%d LANGUAGES", 3), Loc.tn("%d LANGUAGES", 50)])
	Loc.apply("en-US", false)
	r.check(Loc.tn("%d LANGUAGES", 1, "%d LANGUAGE") == "1 LANGUAGE" and Loc.tn("%d LANGUAGES", 50, "%d LANGUAGE") == "50 LANGUAGES", "English: 1 LANGUAGE, 50 LANGUAGES")

# ------------------------------------------------------------------ Settings -> LANGUAGE
func _settings_button() -> void:
	Loc.apply("en-US", false)
	Game.goto("settings")
	await _frames()
	var b := _find("Language") as Button
	r.check(b != null, "Settings has a LANGUAGE button")
	if b == null:
		return
	var head := b.find_child("Heading", true, false) as Label
	var cur := b.find_child("Current", true, false) as Label
	r.check(head != null and head.text == "LANGUAGE" and cur != null and cur.text == "English (US)", "LANGUAGE, the language now under it (English (US))")
	var t := _find("Tutorials") as Control
	r.check(t != null and absf(t.global_position.y - b.global_position.y) < 1.0 and b.global_position.x > t.global_position.x, "beside TUTORIALS on the bottom row")
	r.check(_inside(b) and _inside(t), "both inside the screen")
	var all_in := true
	for n in Game.current_screen.find_children("*", "Control", true, false):
		if (n as Control).is_visible_in_tree() and (n is Button or n is Label or n is PanelContainer) and not _inside(n):
			all_in = false
	r.check(all_in, "Settings: still everything inside the screen")
	b.pressed.emit()
	await _frames(4)
	r.check(Game.current_name == "language", "LANGUAGE opens SELECT LANGUAGE")

func _selector() -> void:
	var s = Game.current_screen
	r.check(s.title_label.text == "SELECT LANGUAGE", "titled SELECT LANGUAGE")
	var rows: Array = Loc.ids().map(func(id): return _find("Lang_" + id))
	r.check(rows.all(func(x): return x is Button), "all 50 languages in the list")
	var nat := (_find("Lang_ko") as Node).find_child("Native", true, false) as Label
	r.check(nat != null and nat.text == "한국어", "each in its own script (한국어)")
	r.check(_find("Lang_en-US").find_child("Check", true, false) != null and _find("Lang_fr").find_child("Check", true, false) == null, "a check beside the language in use only")
	r.check(_find("Scroller") is ScrollContainer and _find("Search") is LineEdit, "a scrolling list under a search bar")
	var cnt := _find("Count") as Label
	r.check(cnt.text == "50 LANGUAGES", "the count: 50 LANGUAGES (%s)" % cnt.text)
	# search
	var se := _find("Search") as LineEdit
	for q in [["port", ["pt-BR", "pt-PT"]], ["日本", ["ja"]], ["EN-gb", ["en-GB"]], ["español", ["es-MX", "es-ES"]], ["zzz", []]]:
		se.text = q[0]
		se.text_changed.emit(q[0])
		await _frames()
		var shown: Array = Loc.ids().filter(func(id): return _find("Lang_" + id) != null and not _find("Lang_" + id).is_queued_for_deletion())
		r.check(shown == q[1], "search %s -> %s (%s)" % [q[0], str(q[1]), str(shown)])
	r.check(_find("NoMatches") != null, "no match: NO LANGUAGE MATCHES")
	se.text = ""
	se.text_changed.emit("")
	await _frames()
	r.check(Loc.ids().all(func(id): return _find("Lang_" + id) != null), "search cleared: all 50 again")
	# the list scrolls
	var sc := _find("Scroller") as ScrollContainer
	sc.scroll_vertical = 100000
	await _frames()
	r.check(sc.scroll_vertical > 0, "the list scrolls (%d)" % sc.scroll_vertical)
	sc.scroll_vertical = 0

func _switching() -> void:
	Game.goto("language")
	await _frames()
	(_find("Lang_de") as Button).pressed.emit()
	await _frames(4)
	r.check(Loc.current == "de" and Game.settings.language == "de", "a tap: German at once, in the settings")
	r.check(TranslationServer.get_locale().begins_with("de"), "the TranslationServer in German")
	var title: Label = Game.current_screen.title_label
	r.check(title.text == "SELECT LANGUAGE" and tr_of(title) == "SPRACHE WÄHLEN", "this page's title now in German (%s)" % tr_of(title))
	r.check((_find("Count") as Label).text == "50 SPRACHEN", "its count in German (%s)" % (_find("Count") as Label).text)
	r.check(_find("Lang_de").find_child("Check", true, false) != null and _find("Lang_en-US").find_child("Check", true, false) == null, "the check moved to Deutsch")
	# back to Settings: in German
	Game.current_screen.on_back()
	await _frames(4)
	r.check(Game.current_name == "settings", "BACK: Settings")
	var heads: Array = ["Gameplay", "Audio"].map(func(n): return tr_of(_find(n).find_child("Heading", true, false)))
	r.check(heads == ["SPIEL", "AUDIO & FEEDBACK"], "Settings in German %s" % str(heads))
	r.check(tr_of(_find("Language").find_child("Heading", true, false)) == "SPRACHE" and (_find("Current") as Label).text == "Deutsch", "the button: SPRACHE / Deutsch")
	r.check(tr_of(_find("Toggle_sfx")) == "AN", "toggles: AN / AUS")
	r.check(tr_of(_find("QuarterLength")).ends_with("MIN") and tr_of(_find("Diff_easy")) == "LEICHT", "difficulty and quarter length in German")
	# right to left: the text, never the layout
	Game.goto("settings")
	await _frames(4)
	var en_pos := {}
	for n in ["Gameplay", "Audio", "Language", "Tutorials", "DevButton"]:
		en_pos[n] = (_find(n) as Control).global_position
	Loc.set_language("ar")
	Game.goto("settings")
	await _frames(4)
	r.check(not Game.current_screen.is_layout_rtl() and not r.get_tree().root.is_layout_rtl(), "Arabic: the layout stays left to right")
	var g := _find("Gameplay") as Control
	var a := _find("Audio") as Control
	r.check(g.global_position.x < a.global_position.x and (_find("DevButton") as Control).global_position.x > 400,
		"Arabic: GAMEPLAY left, AUDIO right, DEV top right, as in English")
	var same := true
	for n in ["Gameplay", "Audio", "Tutorials"]:
		if absf((_find(n) as Control).global_position.x - en_pos[n].x) > 0.5:
			same = false
	r.check(same, "Arabic: the panels where they are in English")
	r.check(tr_of(g.find_child("Heading", true, false)) == "اللعب", "Arabic text")
	Game.goto("title")
	await _frames(3)
	var icons: Array = Game.current_screen.get_children().filter(func(n): return n is Button)
	r.check(icons.size() >= 2 and icons.all(func(b): return _inside(b)) and icons[0].global_position.x < 60 and icons[1].global_position.x > 400,
		"Arabic title: help top left, gear top right, both on screen")
	Loc.set_language("en-US")
	Game.goto("settings")
	await _frames(4)
	r.check(not Game.current_screen.is_layout_rtl() and tr_of(_find("Gameplay").find_child("Heading", true, false)) == "GAMEPLAY", "back to English: left to right, English text")
	# a gap in a catalog: that string in English, never blank
	Loc.apply("de", false)
	r.check(Loc.t("A STRING NO CATALOG HAS") == "A STRING NO CATALOG HAS" and tr_of_text("A STRING NO CATALOG HAS") == "A STRING NO CATALOG HAS", "an untranslated string shows in English")
	Loc.apply("en-US", false)

## What a Label or Button shows (its text through the TranslationServer, as auto-translate does).
func tr_of(n) -> String:
	return tr_of_text(String(n.text)) if n != null else ""

func tr_of_text(s: String) -> String:
	return String(TranslationServer.translate(s))

## Settings, SELECT LANGUAGE and the title in every language, at their fullest (a dynasty
## loaded, DYNAMIC difficulty: the longest note): nothing past the screen's sides, and no page
## that needs scrolling (a long language draws the page smaller instead: BaseScreen._fit).
func _every_locale_fits() -> void:
	var bad: Array = []
	var scroll: Array = []
	var c := Career.new_game("SJCU", "A", "B", 701)
	c.queue.clear()
	c.difficulty = "dynamic"
	var kept_c = Game.career
	var kept_d = Game.settings.difficulty
	Game.career = c
	Game.settings.difficulty = "dynamic"
	for id in Loc.ids():
		Loc.apply(id, false)
		for scr in ["settings", "language", "title"]:
			Game.goto(scr)
			await _frames(8)
			var s = Game.current_screen
			for n in s.find_children("*", "Control", true, false):
				var ct := n as Control
				if ct.is_visible_in_tree() and (ct is Button or ct is PanelContainer or ct is Label) and not _inside_x(ct) and not _in_list(ct):
					bad.append("%s/%s/%s" % [id, scr, ct.name])
					break
			if s is BaseScreen and s.body != null and s._holder != null and scr != "language":
				var need: float = s._content_size().y * s.fit_scale
				if need > s._holder.size.y + 1.0:
					scroll.append("%s/%s %.0f>%.0f" % [id, scr, need, s._holder.size.y])
	Loc.apply("en-US", false)
	Game.career = kept_c
	Game.settings.difficulty = kept_d
	r.check(bad.is_empty(), "every language: Settings, SELECT LANGUAGE and the title inside the screen %s" % str(bad.slice(0, 8)))
	r.check(scroll.is_empty(), "every language: Settings fits without scrolling %s" % str(scroll.slice(0, 8)))

## In SELECT LANGUAGE's own scrolling list (rows past the bottom are meant to be).
func _in_list(c: Control) -> bool:
	var p := c.get_parent()
	while p != null and p != Game.current_screen:
		if p.name == "Scroller":
			return true
		p = p.get_parent()
	return false

func _inside_x(c: Control) -> bool:
	var vr := Game.current_screen.get_viewport_rect()
	var g := c.get_global_rect()
	return g.position.x >= vr.position.x - 0.5 and g.end.x <= vr.end.x + 0.5

## Saved in settings.cfg, read back on the next launch.
func _persistence() -> void:
	Loc.set_language("pt-BR")
	Game.settings.language = "en-US"
	Game.load_settings()
	r.check(Game.settings.language == "pt-BR", "the pick saved and read back (pt-BR)")
	Loc.apply(String(Game.settings.language), false)
	r.check(Loc.current == "pt-BR" and Loc.t("SETTINGS") != "SETTINGS", "applied from the saved setting on launch")
	Loc.set_language("en-US")

# ------------------------------------------------------------------ screenshots
static func shots(runner, out: String, which: String = "") -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	var kept: Dictionary = Game.settings.duplicate(true)
	var snap := func(name: String) -> void:
		await tree.create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name))
	Game.career = null
	var ids: Array = Array(which.split(",", false)) if which != "" else ["en-US", "de", "ja", "ar"]
	for id in ids:
		Loc.apply(id, false)
		Game.goto("settings")
		await snap.call("%s_1_settings.png" % id)
		Game.goto("language")
		await snap.call("%s_2_language.png" % id)
		Game.goto("title")
		await snap.call("%s_3_title.png" % id)
	Loc.apply("en-US", false)
	Game.goto("language")
	var se: LineEdit = Game.current_screen.find_child("Search", true, false)
	se.text = "port"
	se.text_changed.emit("port")
	await snap.call("search_port.png")
	Game.settings = kept
	Loc.apply(Loc.startup_language(), false)
	print("  shots")

# ------------------------------------------------------------------ the extraction worklist
## Every player-facing screen opened in a translated locale (German), with a dynasty loaded for
## the career ones; every English string shown that the catalog doesn't have is written to
## `out` (JSON: screen -> strings), with a count. What's left to put through Loc.
const PLAYER_SCREENS := ["title", "settings", "language", "careers", "new_career", "howto", "quick_match",
	"multiplayer", "hub", "more", "roster", "recruiting", "schedule", "training", "conference", "top20",
	"news", "program", "coaching", "facilities", "records", "awards", "trophy_room", "store", "visual_shop",
	"matchup", "scout", "roster_set"]

static func missing(runner, out: String) -> void:
	var tree: SceneTree = runner.get_tree()
	var kept: Dictionary = Game.settings.duplicate(true)
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 701)
	c.queue.clear()
	Game.career = c
	Loc.apply("de", false)
	var found := {}
	var all := {}
	var names := {}
	for id in Loc.ids():
		names[Loc.native_name(id)] = true
		names[Loc.english_name(id).to_upper()] = true
	for scr in PLAYER_SCREENS:
		var miss := Loc.collect_missing(true)
		Game.goto(scr)
		for _i in 6:
			await tree.process_frame
		var keep: Array = []
		for k in miss.keys():
			var t := String(k)
			# (numbers, names and single letters aren't text to translate)
			if t.strip_edges().length() < 2 or t.is_valid_float() or not t.to_upper() != t.to_lower():
				continue
			# (already German: a built string's result, asked again by its Label; and the
			# language list's own names)
			if not _ascii(t) or names.has(t):
				continue
			keep.append(t)
			all[t] = true
		keep.sort()
		found[scr] = keep
		Loc.collect_missing(false)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"locale": "de", "distinct": all.size(), "screens": found}, "	"))
	f.close()
	print("  %d distinct untranslated strings across %d screens -> %s" % [all.size(), PLAYER_SCREENS.size(), out])
	Loc.apply("en-US", false)
	Game.settings = kept
	Loc.apply(Loc.startup_language(), false)
	Game.career = null

static func _ascii(t: String) -> bool:
	for i in t.length():
		if t.unicode_at(i) > 126:
			return false
	return true

# ------------------------------------------------------------------ the whole game, every language
## Every player-facing screen in each language of `which` ("all" = the 50), a dynasty loaded:
##   - a page that fits the phone in English must fit in the language (no scrolling because of it)
##   - nothing past the screen's sides
## Prints each problem (language/screen/what) and a count; PNGs to `out` when it's given.
static func fit_survey(runner, which: String, out: String = "") -> void:
	var tree: SceneTree = runner.get_tree()
	var kept: Dictionary = Game.settings.duplicate(true)
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 701)
	c.queue.clear()
	Game.career = c
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	var ids: Array = Loc.ids() if which == "all" else Array(which.split(",", false))
	# English first: which pages fit
	Loc.apply("en-US", false)
	var fits_en := {}
	for scr in PLAYER_SCREENS:
		Game.goto(scr)
		for _i in 8:
			await tree.process_frame
		var sc = Game.current_screen
		if sc is BaseScreen and sc.body != null and sc._holder != null:
			fits_en[scr] = sc._content_size().y <= sc._holder.size.y + 1.0
	var problems: Array = []
	for id in ids:
		Loc.apply(id, false)
		for scr in PLAYER_SCREENS:
			Game.goto(scr)
			for _i in 10:
				await tree.process_frame
			var sc = Game.current_screen
			var vr: Rect2 = sc.get_viewport_rect()
			if fits_en.get(scr, false):
				var need: float = sc._content_size().y * sc.fit_scale
				if need > sc._holder.size.y + 1.0:
					problems.append("%s/%s: scrolls (%.0f > %.0f, at %.2f)" % [id, scr, need, sc._holder.size.y, sc.fit_scale])
			for n in sc.find_children("*", "Control", true, false):
				var ct := n as Control
				if not ct.is_visible_in_tree() or not (ct is Button or ct is Label or ct is PanelContainer):
					continue
				var g := ct.get_global_rect()
				if g.position.x < vr.position.x - 1.0 or g.end.x > vr.end.x + 1.0:
					if not _in_hscroll(ct):
						problems.append("%s/%s: %s past the side (%.0f..%.0f)" % [id, scr, ct.name, g.position.x, g.end.x])
						break
			if out != "":
				await RenderingServer.frame_post_draw
				runner.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [id, scr]))
	for p in problems:
		print("  FIT: " + p)
	print("  fit survey: %d problem(s) in %d language(s) x %d screens" % [problems.size(), ids.size(), PLAYER_SCREENS.size()])
	Loc.apply("en-US", false)
	Game.settings = kept
	Loc.apply(Loc.startup_language(), false)
	Game.career = null

static func _in_hscroll(c: Control) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer and (p as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return true
		p = p.get_parent()
	return false
