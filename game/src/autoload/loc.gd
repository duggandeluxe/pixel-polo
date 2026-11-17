extends Node
## LANGUAGE: the game's text in any of the App Store's 50 localizations (Settings -> LANGUAGE).
##
## HOW IT WORKS: the English (United States) text in the code is the key. A locale's catalog
## (res://locale/<Apple id>.json) maps each English string to its translation; Godot's
## TranslationServer then translates every Label, Button and tooltip on its own as it's shown
## (auto-translate), and UI.text translates what's drawn on a canvas. Text built at run time
## goes through Loc.t / Loc.f / Loc.tn so its pattern ("%d MIN") is the key, not the result.
## Anything a catalog doesn't have stays in English: never a blank, never a key name.
##
## A catalog may name a parent ("inherits"): it's read first and the child's strings laid over
## it, so a regional variant (en-GB, fr-CA, es-MX) lists only the words that differ.
##
##   {"locale": "fr-CA", "inherits": "fr",
##    "strings": {"SETTINGS": "PARAMÈTRES", ...},
##    "plurals": {"%d LANGUAGES": {"one": "%d LANGUE", "other": "%d LANGUES"}}}
##
## The pick is saved in settings.cfg ("language", an Apple id) and applied at once: no restart,
## no save file touched. Right-to-left languages turn the whole layout around.

signal changed(id: String)

const DEFAULT := "en-US"
const DIR := "res://locale/"
const SETTING := "language"

## The 50 App Store localizations: [Apple id, Godot locale, English name, native name, RTL].
## Arabic, Hebrew and Urdu are given neutral Godot codes (zz, zy, zx): Godot turns every Control
## right to left for a right-to-left locale, even ones not yet on screen (whose positions then land
## mirrored, off the screen). Every screen keeps its English layout in every language; their text
## still reads right to left inside each line, from its own letters.
const LOCALES := [
	["ar", "zz", "Arabic", "العربية", true],
	["bn", "bn", "Bangla", "বাংলা", false],
	["ca", "ca", "Catalan", "Català", false],
	["zh-Hans", "zh_Hans", "Chinese (Simplified)", "简体中文", false],
	["zh-Hant", "zh_Hant", "Chinese (Traditional)", "繁體中文", false],
	["hr", "hr", "Croatian", "Hrvatski", false],
	["cs", "cs", "Czech", "Čeština", false],
	["da", "da", "Danish", "Dansk", false],
	["nl", "nl", "Dutch", "Nederlands", false],
	["en-AU", "en_AU", "English (Australia)", "English (Australia)", false],
	["en-CA", "en_CA", "English (Canada)", "English (Canada)", false],
	["en-GB", "en_GB", "English (United Kingdom)", "English (UK)", false],
	["en-US", "en_US", "English (United States)", "English (US)", false],
	["fi", "fi", "Finnish", "Suomi", false],
	["fr", "fr_FR", "French", "Français", false],
	["fr-CA", "fr_CA", "French (Canada)", "Français (Canada)", false],
	["de", "de", "German", "Deutsch", false],
	["el", "el", "Greek", "Ελληνικά", false],
	["gu", "gu", "Gujarati", "ગુજરાતી", false],
	["he", "zy", "Hebrew", "עברית", true],
	["hi", "hi", "Hindi", "हिन्दी", false],
	["hu", "hu", "Hungarian", "Magyar", false],
	["id", "id", "Indonesian", "Bahasa Indonesia", false],
	["it", "it", "Italian", "Italiano", false],
	["ja", "ja", "Japanese", "日本語", false],
	["kn", "kn", "Kannada", "ಕನ್ನಡ", false],
	["ko", "ko", "Korean", "한국어", false],
	["ms", "ms", "Malay", "Bahasa Melayu", false],
	["ml", "ml", "Malayalam", "മലയാളം", false],
	["mr", "mr", "Marathi", "मराठी", false],
	["no", "nb", "Norwegian", "Norsk", false],
	["or", "or", "Odia", "ଓଡ଼ିଆ", false],
	["pl", "pl", "Polish", "Polski", false],
	["pt-BR", "pt_BR", "Portuguese (Brazil)", "Português (Brasil)", false],
	["pt-PT", "pt_PT", "Portuguese (Portugal)", "Português (Portugal)", false],
	["pa", "pa", "Punjabi", "ਪੰਜਾਬੀ", false],
	["ro", "ro", "Romanian", "Română", false],
	["ru", "ru", "Russian", "Русский", false],
	["sk", "sk", "Slovak", "Slovenčina", false],
	["sl", "sl", "Slovenian", "Slovenščina", false],
	["es-MX", "es_MX", "Spanish (Mexico)", "Español (México)", false],
	["es-ES", "es_ES", "Spanish (Spain)", "Español (España)", false],
	["sv", "sv", "Swedish", "Svenska", false],
	["ta", "ta", "Tamil", "தமிழ்", false],
	["te", "te", "Telugu", "తెలుగు", false],
	["th", "th", "Thai", "ไทย", false],
	["tr", "tr", "Turkish", "Türkçe", false],
	["uk", "uk", "Ukrainian", "Українська", false],
	["ur", "zx", "Urdu", "اردو", true],
	["vi", "vi", "Vietnamese", "Tiếng Việt", false],
]

var current := DEFAULT
var _cat: Catalog = null
var _info := {}   # Apple id -> its LOCALES row

## A locale's strings for the TranslationServer: a plain lookup, nothing found -> English.
## `missing`, when a Dictionary, collects every English string asked for that it lacks (the
## extraction harness: what's still untranslated on the screens it walks).
##
## PATTERNS: a key with placeholders also translates every string of its shape the game builds
## at run time, however the code built it (a format or a "+" of pieces):
##   %s %d %+d %.1f ...  in order ("%s SCORES!" -> "RIVERA SCORES!", "WEEK %d" -> "WEEK 3")
##   {name} {line} ...   by name, so a translation may put them in any order
##   GOAL%s              an English plural ending ("" / "s"): a translation may leave it out
##                       and use a form that reads for any number ("GOLES: %d")
## What fills a number stays as it is; what fills a %s or {x} is translated only when it's itself
## text the catalog knows ("MEDIUM"), so player names, school names and mascots never are.
## A key also matches its own text in capitals ("Goals in a game" -> "GOALS IN A GAME").
class Catalog extends Translation:
	var msgs := {}
	var plurals := {}
	var missing = null
	var _pats: Array = []     # [RegEx, translation, anchor, slots, key length], the most specific first
	var _upper := {}          # a key in capitals -> its translation in capitals
	var _fold := {}           # a key in small letters -> a translation (a word dropped into a sentence)
	var _memo := {}           # a string asked before -> its translation ("" = none)
	static var _tok := RegEx.create_from_string("%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?[sdif]|%%|\\{[A-Za-z_]+\\}")
	static var _word := RegEx.create_from_string("[A-Za-z]{2}")
	static var _letter := RegEx.create_from_string("[A-Za-z]")

	func _get_message(src: StringName, _ctx: StringName) -> StringName:
		var r := lookup(String(src))
		return StringName(r) if r != "" else &""

	## `s` translated, or "" when the catalog has nothing for it.
	func lookup(s: String, depth: int = 0) -> String:
		if msgs.has(s):
			return msgs[s]
		if _dirty:
			_build()
		if _memo.has(s):
			return _memo[s]
		var r: String = _upper.get(s, "")
		if r == "" and _fold.has(s.to_lower()) and _letter.search(s):
			# (another case of a key: "freshman", "center" in the middle of a sentence)
			var f: Array = _fold[s.to_lower()]
			r = String(f[0]) if not f[1] or s != s.to_lower() else String(f[0]).to_lower()
			if s == s.to_upper() and s != s.to_lower():
				r = r.to_upper()
		if r == "":
			r = _by_pattern(s, depth)
		if r == "":
			r = _by_pieces(s, depth)
		if r == "" and missing != null and s.strip_edges() != "":
			missing[s] = true
		if _memo.size() > 6000:
			_memo.clear()
		_memo[s] = r
		return r

	## Text the code glued together from pieces the catalog knows, when the whole has no key:
	##   "2026-27  GAME 1/16"   pieces split at a double space, " | " or "  -  "
	##   "INCOMING 0"           a word and a number
	##   "AWAY."                a word and its closing mark
	## Each piece translated on its own (names and numbers pass through); "" if none was.
	static var _seps := RegEx.create_from_string("(\\s{2,}|\\s\\|\\s|\\s+-\\s+)")
	static var _tail_num := RegEx.create_from_string("^(.*[A-Za-z].*?)(\\s+[-+]?[0-9][0-9,./]*)$")
	static var _head_num := RegEx.create_from_string("^([-+]?[0-9][0-9,./]*\\s+)(.*[A-Za-z].*)$")
	static var _tail_mark := RegEx.create_from_string("^(.*[A-Za-z].*?)([.:!?,;]+)$")

	func _by_pieces(s: String, depth: int) -> String:
		if depth > 1 or s.length() > 300:
			return ""
		var parts := _seps.search_all(s)
		if not parts.is_empty():
			var out := ""
			var at := 0
			var any := false
			for m in parts:
				var piece := s.substr(at, m.get_start() - at)
				var t := lookup(piece, depth + 1) if piece.strip_edges() != "" else ""
				any = any or t != ""
				out += (t if t != "" else piece) + m.get_string()
				at = m.get_end()
			var last := s.substr(at)
			var tl := lookup(last, depth + 1) if last.strip_edges() != "" else ""
			any = any or tl != ""
			out += tl if tl != "" else last
			return out if any else ""
		for re in [_tail_num, _tail_mark]:
			var m: RegExMatch = (re as RegEx).search(s)
			if m != null:
				var t := lookup(m.get_string(1), depth + 1)
				if t != "":
					return t + m.get_string(2)
		var h := _head_num.search(s)
		if h != null:
			var t := lookup(h.get_string(2), depth + 1)
			if t != "":
				return h.get_string(1) + t
		return ""

	## Builds the patterns from the keys (once, when the catalog is loaded).
	## The patterns are built the first time something isn't found as it is (most text is), so
	## loading a language stays instant.
	var _dirty := false

	func compile() -> void:
		_dirty = true
		_memo.clear()

	func _build() -> void:
		_dirty = false
		_pats.clear()
		_memo.clear()
		_upper.clear()
		_fold.clear()
		var rows: Array = []
		for k in msgs:
			var key := String(k)
			var tr := String(msgs[k])
			var up := key.to_upper()
			if up != key and not msgs.has(up):
				_upper[up] = tr.to_upper()
			# [translation, it's from an all-capitals key]; a mixed-case key's wording is preferred
			var low := key.to_lower()
			var caps := key == up
			if not _fold.has(low) or (bool(_fold[low][1]) and not caps):
				_fold[low] = [tr, caps]
			for variant in ([key, up] if up != key else [key]):
				var row := _compile_one(variant, tr if variant == key else tr.to_upper())
				if not row.is_empty():
					rows.append(row)
		rows.sort_custom(func(a, b): return a[4] > b[4])
		_pats = rows

	## One key as a pattern: [RegEx, translation, anchor, slots, length], or [] if it has no
	## placeholders or no words of its own to anchor it ("%s %s" would catch anything).
	func _compile_one(key: String, tr: String) -> Array:
		var ms := _tok.search_all(key)
		var slots: Array = []   # per group: "seq", "suffix" or a {name}
		var rx := "^"
		var anchor := ""
		var at := 0
		var prev_tok := ""
		for m in ms:
			var t := m.get_string()
			var lit := key.substr(at, m.get_start() - at)
			at = m.get_end()
			var joined := lit == "" and prev_tok == "%s"   # (right after another %s, nothing between)
			prev_tok = t
			if t == "%%":
				rx += _esc(lit) + "%"
				continue
			rx += _esc(lit)
			if lit.strip_edges().length() > anchor.length():
				anchor = lit.strip_edges()
			var before := lit.right(1)   # (literal text only)
			var after := key.substr(m.get_end(), 1)
			if t == "%s" and _letter.search(before) and not _letter.search(after):
				rx += "((?:es|ES|s|S)?)"
				slots.append("suffix")
			elif t == "%s" and joined:
				# "%s%s": the second is a plural ending ("GOAL" + "S") or a piece joined on
				# (" (TEAM LEADER)"); either way a translation may leave it out
				rx += "((?:es|ES|s|S)?|[ ,(:;/-].*)"
				slots.append("suffix")
			elif t.begins_with("{"):
				rx += "(.+?)"
				slots.append(t.substr(1, t.length() - 2))
			elif t.ends_with("s"):
				rx += "(.+?)"
				slots.append("seq")
			else:
				rx += "([-+]?[0-9][0-9,. ]*)"
				slots.append("seq")
		if slots.is_empty():
			return []
		var tail := key.substr(at)
		rx += _esc(tail) + "$"
		if tail.strip_edges().length() > anchor.length():
			anchor = tail.strip_edges()
		if not _word.search(anchor):
			return []
		var re := RegEx.create_from_string(rx)
		if re == null or not re.is_valid():
			return []
		return [re, tr, anchor, slots, key.length()]

	func _esc(t: String) -> String:
		var out := ""
		for ch in t:
			out += ("\\" + ch) if ch in "\\^$.|?*+()[]{}" else ch
		return out

	func _by_pattern(s: String, depth: int) -> String:
		if _pats.is_empty() or s.length() > 600 or depth > 1 or not _letter.search(s):
			return ""
		for row in _pats:
			if not String(row[2]) in s:
				continue
			var m: RegExMatch = (row[0] as RegEx).search(s)
			if m == null:
				continue
			var slots: Array = row[3]
			var seq: Array = []
			var suffix: Array = []
			var named := {}
			for g in range(1, m.get_group_count() + 1):
				var a := m.get_string(g)
				var kind: String = slots[g - 1]
				if kind == "suffix":
					seq.append(a)
					suffix.append(seq.size() - 1)
					continue
				var tr_a := a
				if _letter.search(a):
					var la := lookup(a, depth + 1)
					if la != "":
						tr_a = la
				if kind == "seq":
					seq.append(tr_a)
				else:
					named[kind] = tr_a
			return Catalog.fill(String(row[1]), seq, named, suffix)
		return ""

	## `pattern` with its placeholders filled: %x in order from `seq`, {name} from `named`. When
	## the translation has fewer %x than `seq` (it dropped the English plural endings), the
	## `suffix` entries are left out.
	static func fill(pattern: String, seq: Array, named: Dictionary = {}, suffix: Array = []) -> String:
		var ms := _tok.search_all(pattern)
		var count := 0
		for m in ms:
			var t := m.get_string()
			if t != "%%" and not t.begins_with("{"):
				count += 1
		var args := seq
		if count < seq.size() and not suffix.is_empty():
			args = []
			for i in seq.size():
				if not i in suffix:
					args.append(seq[i])
		var out := ""
		var at := 0
		var n := 0
		for m in ms:
			out += pattern.substr(at, m.get_start() - at)
			at = m.get_end()
			var t := m.get_string()
			if t == "%%":
				out += "%"
			elif t.begins_with("{"):
				var nm := t.substr(1, t.length() - 2)
				out += String(named[nm]) if named.has(nm) else t
			elif n < args.size():
				out += String(args[n])
				n += 1
		return out + pattern.substr(at)

func _init() -> void:
	for row in LOCALES:
		_info[row[0]] = row

## The game opens in the phone's own language when it's one of the 50 (English (United States)
## when it isn't), until the player picks one in Settings: that pick is remembered from launch to
## launch. Nothing picked yet (the setting ""): the phone's language is looked up every launch, so
## changing the phone's language changes the game's.
func _ready() -> void:
	apply(startup_language(), false)

## The language to open in: the saved pick, else the device's.
func startup_language() -> String:
	var saved := String(Game.settings.get(SETTING, ""))
	return saved if has_locale(saved) else device_language()

## The device's language as one of the 50 (English (United States) when it isn't one).
func device_language() -> String:
	return from_device(OS.get_locale())

## A system locale ("pt_BR", "zh_Hant_TW", "es_419", "nb_NO", "fr-CA") as the nearest of the 50
## App Store localizations, or English (United States).
static func from_device(os_locale: String) -> String:
	var parts := os_locale.replace("-", "_").split("_", false)
	if parts.is_empty():
		return DEFAULT
	var lang := parts[0].to_lower()
	var rest: Array = []
	for i in range(1, parts.size()):
		rest.append(parts[i])
	var region := ""
	var script := ""
	for p in rest:
		var t := String(p)
		if t.length() == 4:
			script = t.capitalize()
		elif region == "":
			region = t.to_upper()
	match lang:
		"en":
			if region in ["AU", "NZ"]: return "en-AU"
			if region == "CA": return "en-CA"
			if region in ["GB", "IE", "UK"]: return "en-GB"
			return "en-US"
		"fr":
			return "fr-CA" if region == "CA" else "fr"
		"es":
			return "es-ES" if region == "ES" else "es-MX"   # (Latin America and the US: Mexican Spanish)
		"pt":
			return "pt-BR" if region in ["", "BR"] else "pt-PT"
		"zh":
			if script == "Hant" or (script == "" and region in ["TW", "HK", "MO"]): return "zh-Hant"
			return "zh-Hans"
		"nb", "nn", "no":
			return "no"
		"iw":
			return "he"
		"in":
			return "id"
	for row in LOCALES:
		if row[0] == lang:
			return lang
	return DEFAULT

# ------------------------------------------------------------------ choosing
## Every Apple id, in the list's order.
func ids() -> Array:
	return LOCALES.map(func(r): return r[0])

func has_locale(id: String) -> bool:
	return _info.has(id)

func native_name(id: String) -> String:
	return _info[id][3] if _info.has(id) else id

func english_name(id: String) -> String:
	return _info[id][2] if _info.has(id) else id

func godot_locale(id: String) -> String:
	return _info[id][1] if _info.has(id) else "en_US"

## Languages whose letters the pixel fonts don't have (they come from the system's fonts):
## their screens are drawn at the display's own resolution (Game.set_detail) so the text is sharp
## and readable at the UI's 8 px, not a blur of 8 screen pixels.
const HIRES := ["ar", "bn", "zh-Hans", "zh-Hant", "gu", "he", "hi", "ja", "kn", "ko", "ml", "mr",
	"or", "pa", "ta", "te", "th", "ur", "vi"]

func hires(id: String = "") -> bool:
	return (current if id == "" else id) in HIRES

func is_rtl(id: String = "") -> bool:
	var k := current if id == "" else id
	return _info.has(k) and bool(_info[k][4])

## The player's pick: applied now, saved for next time.
func set_language(id: String) -> void:
	if not has_locale(id):
		id = DEFAULT
	apply(id, true)
	Game.settings[SETTING] = id
	Game.save_settings()

## Switch the text to `id` (an unknown id: English). Every Label and Button re-translates by
## itself; canvases redraw (UI.DrawBox), and `changed` tells screens with built text to rebuild.
func apply(id: String, notify: bool = true) -> void:
	if not has_locale(id):
		id = DEFAULT
	current = id
	if _cat != null:
		TranslationServer.remove_translation(_cat)
		_cat = null
	if id != DEFAULT:
		_cat = load_catalog(id)
		_cat.locale = godot_locale(id)
		TranslationServer.add_translation(_cat)
	TranslationServer.set_locale(godot_locale(id))
	# every screen keeps its English layout in every language: Arabic, Hebrew and Urdu read right
	# to left inside each line of text, but nothing on the screen moves (left to its own devices,
	# Godot would mirror the whole layout for them)
	if is_inside_tree():
		get_tree().root.set_layout_direction(Window.LAYOUT_DIRECTION_LTR)
	if Game.current_screen != null:
		Game.set_detail(Game.current_screen.get("detail") == true or hires())
	if notify:
		changed.emit(id)

## A locale's catalog, its parents' strings under its own. Missing or broken files leave
## whatever was found (in the end, English).
func load_catalog(id: String) -> Catalog:
	var cat := Catalog.new()
	var chain: Array = []
	var k := id
	while k != "" and not k in chain and chain.size() < 4:
		chain.push_front(k)
		k = String(read_file(k).get("inherits", ""))
	for c in chain:
		var d := read_file(c)
		var s: Dictionary = d.get("strings", {})
		for key in s:
			if String(s[key]) != "":
				cat.msgs[key] = String(s[key])
		var p: Dictionary = d.get("plurals", {})
		for key in p:
			cat.plurals[key] = p[key]
	cat.compile()
	return cat

## A catalog file as it's stored ({} when there's none or it doesn't parse).
func read_file(id: String) -> Dictionary:
	var path := DIR + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

## Collect the English strings the current locale is missing (tests and the extraction tool).
func collect_missing(on: bool) -> Dictionary:
	if _cat == null:
		return {}
	_cat.missing = {} if on else null
	return {} if not on else _cat.missing

# ------------------------------------------------------------------ wrapping by hand
## Languages written without spaces between words: canvas text is wrapped at the breaks the
## text server finds, and its pieces joined with nothing between them.
const NO_SPACES := ["ja", "zh-Hans", "zh-Hant", "th"]

## The space a hand-wrapped line puts between its pieces ("" in Japanese, Chinese, Thai).
func gap() -> String:
	return "" if current in NO_SPACES else " "

## `text` cut into the pieces a line may break between: its words, or (in a language without
## spaces) the text server's word breaks, so Japanese, Chinese and Thai wrap too.
func units(text: String) -> Array:
	if not current in NO_SPACES:
		return Array(text.split(" "))
	var ts := TextServerManager.get_primary_interface()
	var br: PackedInt32Array = ts.string_get_word_breaks(text, godot_locale(current))
	var out: Array = []
	var at := 0
	for i in range(0, br.size(), 2):
		var e := br[i + 1]
		if e > at:
			out.append(text.substr(at, e - at))
			at = e
	if at < text.length():
		out.append(text.substr(at))
	return out if not out.is_empty() else [text]

# ------------------------------------------------------------------ text
## `s` in the current language (English when it has no translation).
func t(s: String) -> String:
	if _cat == null or s == "":
		return s
	var r := _cat.lookup(s)
	return r if r != "" else s

## A pattern translated, then filled: Loc.f("%d MIN", [3]).
func f(pattern: String, args = []) -> String:
	var p := t(pattern)
	if args is Array and args.is_empty():
		return p
	return p % args

## A count in words: the plural form the language uses for `n` ("%d LANGUAGES" -> "1 LANGUAGE",
## "5 ЯЗЫКОВ"), filled with the number in the locale's own style. English keys: the "one" form
## is the key with LANGUAGES -> LANGUAGE given in `one`.
func tn(key: String, n: int, one: String = "") -> String:
	var form := ""
	if _cat != null and _cat.plurals.has(key):
		var forms: Dictionary = _cat.plurals[key]
		var cat := plural_category(current, n)
		form = String(forms.get(cat, forms.get("other", "")))
	if form == "":
		form = one if (n == 1 and one != "") else key
	return form.replace("%d", num(n))

## CLDR plural categories for whole numbers: zero, one, two, few, many, other.
static func plural_category(id: String, n: int) -> String:
	var lang := id.get_slice("-", 0)
	var n10 := n % 10
	var n100 := n % 100
	match lang:
		"zh", "ja", "ko", "th", "vi", "id", "ms":
			return "other"
		"ar":
			if n == 0: return "zero"
			if n == 1: return "one"
			if n == 2: return "two"
			if n100 >= 3 and n100 <= 10: return "few"
			if n100 >= 11: return "many"
			return "other"
		"he":
			if n == 1: return "one"
			if n == 2: return "two"
			return "other"
		"ru", "uk":
			if n10 == 1 and n100 != 11: return "one"
			if n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14): return "few"
			return "many"
		"pl":
			if n == 1: return "one"
			if n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14): return "few"
			return "many"
		"hr":
			if n10 == 1 and n100 != 11: return "one"
			if n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14): return "few"
			return "other"
		"cs", "sk":
			if n == 1: return "one"
			if n >= 2 and n <= 4: return "few"
			return "other"
		"sl":
			if n100 == 1: return "one"
			if n100 == 2: return "two"
			if n100 == 3 or n100 == 4: return "few"
			return "other"
		"ro":
			if n == 1: return "one"
			if n == 0 or (n100 >= 2 and n100 <= 19): return "few"
			return "other"
		"fr", "hi", "bn", "gu", "kn", "pa":
			return "one" if n == 0 or n == 1 else "other"
		"pt":
			if id == "pt-PT":
				return "one" if n == 1 else "other"
			return "one" if n == 0 or n == 1 else "other"
	return "one" if n == 1 else "other"

## A whole number with the locale's digit grouping: 12,345 / 12.345 / 12 345 / 12,345 (and
## India's 1,23,456 for its languages). Spanish groups only from five digits on.
func num(n: int, id: String = "") -> String:
	var k := current if id == "" else id
	var lang := k.get_slice("-", 0)
	var neg := n < 0
	var s := str(absi(n))
	var sep := ","
	match lang:
		"de", "nl", "da", "id", "it", "tr", "el", "ro", "hr", "sl", "vi", "ca":
			sep = "."
		"es":
			sep = "." if k == "es-ES" else ","
		"pt":
			sep = "." if k == "pt-BR" else " "
		"fr", "ru", "uk", "pl", "cs", "sk", "fi", "sv", "no", "hu":
			sep = " "
	if lang == "es" and k == "es-ES" and s.length() <= 4:
		return ("-" if neg else "") + s
	var out := ""
	if lang in ["hi", "bn", "gu", "kn", "ml", "mr", "or", "pa", "ta", "te", "ur"] and s.length() > 3:
		out = s.substr(s.length() - 3)
		var rest := s.substr(0, s.length() - 3)
		while rest.length() > 2:
			out = rest.substr(rest.length() - 2) + sep + out
			rest = rest.substr(0, rest.length() - 2)
		out = rest + sep + out
	else:
		while s.length() > 3:
			out = sep + s.substr(s.length() - 3) + out
			s = s.substr(0, s.length() - 3)
		out = s + out
	return ("-" if neg else "") + out
