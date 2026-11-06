extends BaseScreen
## A COACHING EVENT (CoachEvents), on its own screen after the POSTGAME REVIEW, filling the page:
##   THE STORY      his own portrait (Portrait: skin, cap, face, as everywhere) or, for a team
##                  event, the school's logo; the headline, who it's about, 3-5 sentences told
##                  from the game's own numbers, and what the game recorded for him
##   THE DECISION   two big panels: each answer, what it means, and every reward (yellow) and
##                  setback (red) it carries, now and riding on the next game; one you can't
##                  afford (or that can't legally happen) can't be picked, and says why
##   THE BOTTOM     what's already riding on your next game, and CONFIRM
## Tap one, then CONFIRM: it's applied, the event cleared and the game saved at once, so it can
## never pay twice (a reload before answering shows the same event again, from
## Career.pending_event). CONTINUE goes back to the season.
## DEVELOPER MODE (coach_lab): PREVIEW shows an event on a copy of the career (or a labelled mock
## one) and applies nothing (pick either answer to look at it; CLOSE PREVIEW); a TRIGGERED event
## (ev.dev) is real, marked as changing the save, and answering it doesn't end a postgame.
## CHALLENGE RESULTS FIRST: a statistical challenge settled by the game (CoachEvents.is_stat_result)
## plays its CHALLENGE RESULT popup (ChallengeShow) over everything, one at a time, each saved as
## shown when it's closed; then the others' panels.
## RESULTS FIRST: anything the game just played settled (Career.coach_results not yet shown) comes
## before the new event, each on its own panel (PROVE ME WRONG with its own drama: HE PROVED YOU
## RIGHT! / THE GAMBLE BACKFIRED), its numbers from what was really applied. Shown once.

const PORTRAIT := Vector2i(64, 72)
const RED := Color("ff5a5a")

var ev: Dictionary = {}
var sc: Dictionary = {}
var pick := -1
var result: Array = []
var answered := false
var results: Array = []        # settled consequences to show first (then the event, if any)
var pops: Array = []           # ...the statistical challenges among them: their CHALLENGE RESULT popup (ChallengeShow) first
var from_review := true        # reached from the postgame (else the hub, after a reload)
var preview := false           # Developer Mode's PREVIEW: nothing is ever applied
var mock := false              # ...on made-up data
var pv_career: Career = null
var pv_ev: Dictionary = {}
var back_to := ""              # Developer Mode: the lab to go back to

func setup(params: Dictionary) -> void:
	from_review = bool(params.get("review", true))
	back_to = String(params.get("back_to", ""))
	if params.has("preview") and bool(Game.settings.get("dev_mode", false)):
		preview = true
		pv_ev = params.preview
		pv_career = params.get("career")
		mock = bool(params.get("mock", false))

func _ready() -> void:
	if preview:
		build("COACHING EVENT", true, false)
		c = pv_career
		ev = pv_ev
		sc = CoachEvents.scenario(String(ev.get("id", "")))
		_render()
		return
	c = Game.career
	if c == null:
		Game.goto("title")
		return
	results = CoachEvents.unshown(c)
	ev = c.pending_event
	sc = CoachEvents.scenario(String(ev.get("id", ""))) if not ev.is_empty() else {}
	if sc.is_empty() and not ev.is_empty():
		c.pending_event = {}   # (a scenario that no longer exists: nothing to ask)
		ev = {}
	pops = results.filter(func(r): return CoachEvents.is_stat_result(r))
	results = results.filter(func(r): return not CoachEvents.is_stat_result(r))
	if results.is_empty() and ev.is_empty() and pops.is_empty():
		_finish()
		return
	build("COACHING EVENT", false, true)
	_render()
	Sfx.music("menu")
	if not pops.is_empty():
		var show := ChallengeShow.play(self, c, pops, _after_pops)
		show.dismissed.connect(func(r: Dictionary):
			r["shown"] = true   # (one at a time, saved as it's closed: never shown twice, resumed if the app closes)
			Game.save_career())

func on_back() -> void:
	if preview:
		_close_preview()
		return
	if answered or (ev.is_empty() and not results.is_empty()):
		_leave()

func _clear() -> void:
	for ch in body.get_children():
		ch.queue_free()

func _render() -> void:
	_clear()
	var page := UI.vbox(4)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc_box := UI.scroll(page)
	sc_box.name = "Page"
	sc_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc_box)
	if preview or bool(ev.get("dev", false)):
		page.add_child(_dev_banner())
	if not results.is_empty():
		_render_results(page)
	elif ev.is_empty():
		pass   # (only challenge results, shown by their popup)
	elif not answered:
		_render_event(page)
	else:
		_render_answer(page)

# ------------------------------------------------------------------ the event
func _render_event(page: VBoxContainer) -> void:
	page.add_child(_story_panel())
	var row := UI.hbox(6)
	row.name = "Choices"
	page.add_child(row)
	var chs: Array = CoachEvents.choices_for(ev)
	for i in chs.size():
		row.add_child(_choice(i, chs[i]))
	var bottom := UI.hbox(6)
	bottom.name = "Bottom"
	page.add_child(bottom)
	bottom.add_child(_active_box())
	if preview:
		var cl := Deck.button("CLOSE PREVIEW", _close_preview, "primary", 150, 26)
		cl.name = "ClosePreview"
		cl.add_theme_font_override("font", UI.font_big)
		cl.add_theme_font_size_override("font_size", 16)
		cl.size_flags_vertical = Control.SIZE_SHRINK_END
		bottom.add_child(cl)
		return
	var ok := Deck.button("CONFIRM  >", _confirm, "primary" if pick >= 0 else "ghost", 150, 26)
	ok.name = "Confirm"
	ok.add_theme_font_override("font", UI.font_big)
	ok.add_theme_font_size_override("font_size", 16)
	ok.disabled = pick < 0
	ok.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(ok)

## Developer Mode's mark: a PREVIEW changes nothing; a TRIGGERED event changes the save.
func _dev_banner() -> Control:
	var t := "DEVELOPER PREVIEW - NOTHING IS APPLIED" + ("  |  MOCK DATA, NOT YOUR TEAM" if mock else "")
	if not preview:
		t = "DEVELOPER TRIGGER - THIS DECISION CHANGES YOUR SAVE"
	var l := UI.label(t, 8, UI.GOLD if preview else RED, "caps")
	l.name = "DevBanner"
	return l

func _close_preview() -> void:
	Sfx.play("back")
	Game.back(back_to if back_to != "" else "settings")

## The story: the portrait (or logo) on the left; headline, who, the story and his record on the right.
func _story_panel() -> Control:
	var h := UI.hbox(8)
	h.add_child(_face(int(ev.get("pid", 0)), String(sc.get("subject", "player")) == "team"))
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var head := UI.label(String(sc.headline), 16, UI.GOLD, "big")
	head.name = "Headline"
	v.add_child(head)
	if CoachEvents.is_special(ev):
		v.add_child(special_tag())
	var who := _who()
	if who != "":
		v.add_child(UI.label(who, 8, UI.ACCENT, "caps"))
	var d := para(fill(_story()), UI.TEXT, 360)
	d.name = "Description"
	v.add_child(d)
	var rec := _record_line()
	if rec != "":
		var r := UI.label(rec, 8, UI.ACCENT, "caps")
		r.name = "Recorded"
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(r)
	var p := navy_panel(h)
	p.name = "Story"
	return p

## The rare special variant's small gold mark: SPECIAL CHALLENGE - 3X GAME XP.
static func special_tag() -> Control:
	var l := UI.label("SPECIAL CHALLENGE - 3X GAME XP", 8, UI.GOLD, "caps")
	l.name = "Special"
	return l

func _story() -> String:
	if CoachEvents.is_special(ev) and sc.has("special_story"):
		return String(sc.special_story)
	var stories: Array = sc.get("stories", [""])
	return String(stories[clampi(int(ev.get("story", 0)), 0, stories.size() - 1)])

## His portrait, big, in a frame (the real one: Portrait); a team event's logo instead.
func _face(pid: int, team: bool) -> Control:
	var p := c.team().find_id(pid)
	var cv := UI.canvas(PORTRAIT.x, PORTRAIT.y, func(ci: Control):
		var r := Rect2(Vector2.ZERO, Vector2(PORTRAIT))
		ci.draw_rect(r, Color("0b1d5c"))
		if team or p == null:
			var tex := TeamLogo.art_within(c.team(), Vector2i(PORTRAIT.x - 8, PORTRAIT.y - 8))
			if tex != null:
				var sz := tex.get_size()
				ci.draw_texture_rect(tex, Rect2(((Vector2(PORTRAIT) - sz) * 0.5).floor(), sz), false)
		else:
			ci.draw_rect(Rect2(1, PORTRAIT.y - 18, PORTRAIT.x - 2, 17), Color(UI.WATER, 0.9))
			Portrait.draw_ours(ci, Vector2(PORTRAIT.x * 0.5, PORTRAIT.y - 1), p, c.team(), 2)
		ci.draw_rect(r, UI.BORDER, false, 1.0))
	cv.name = "Logo" if team or p == null else "Portrait"
	cv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if p != null and not team:
		cv.set_meta("pid", p.id)
	return cv

## One answer, big: its name, what it means, every reward (yellow) and setback (red) it carries.
func _choice(i: int, ch: Dictionary) -> Control:
	var why := CoachEvents.blocked(c, ev, i)
	var box := UI.vbox(1)
	var special := i == 1 and CoachEvents.is_special(ev)
	var lab := UI.label(String(ch.label), 16, UI.GOLD if pick == i or special else UI.TEXT, "big")
	box.add_child(lab)
	if special:
		box.add_child(special_tag())
	if String(ch.text) != "":
		box.add_child(para(fill(String(ch.text)), UI.DIM, 200))
	box.add_child(UI.spacer(0, 2))
	for s in CoachEvents.stakes(c, ev, i):
		var l := para(String(s[0]), _kind_col(String(s[1])), 200)
		l.add_theme_font_override("font", UI.font_caps)
		box.add_child(l)
	if why != "":
		var w := para(why, RED, 200)
		w.name = "Blocked"
		box.add_child(w)
	var b := row_button(box, func():
		if why != "":
			Sfx.play("error")
			return
		pick = i
		_render(), pick == i, 92)
	b.name = "Choice%d" % i
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("blocked", why)
	if pick == i:
		var sel := UI.sb(Deck.NAVY.lerp(UI.GOLD, 0.12), UI.GOLD, 2, 4, 3)   # (opaque: the red lines stay readable)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sel)
	else:
		var edge := Color(UI.GOLD, 0.7) if special else UI.BORDER
		b.add_theme_stylebox_override("normal", UI.sb(Deck.NAVY, edge if why == "" else Color(UI.BORDER, 0.3), 1, 4, 3))
	if why != "":
		b.modulate = Color(1, 1, 1, 0.6)
	return b

func _kind_col(k: String) -> Color:
	match k:
		"good": return UI.GOLD
		"bad": return RED
	return UI.ACCENT

## What's already riding on your next game (CoachEvents' pending consequences), or the event's
## own reminder that nothing is.
func _active_box() -> Control:
	var v := UI.vbox(0)
	v.name = "Active"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label("ACTIVE COACHING CHALLENGES", 8, UI.GOLD, "caps"))
	var lines := pending_lines(c)
	if lines.is_empty():
		v.add_child(UI.label("NONE YET: PICK AN ANSWER, THEN CONFIRM", 8, UI.DIM, "caps"))
	for ln in lines:
		var l := UI.label(String(ln), 8, UI.ACCENT, "caps")
		l.clip_text = true
		v.add_child(l)
	return v

## The pending consequences, one line each: "HEGEDUS 3 GOALS + ASSISTS - 2X GAME XP".
static func pending_lines(car: Career) -> Array:
	var out: Array = []
	for e in car.coach_pending:
		out.append("%s - %s" % [String(e.label), String(e.reward)])
	for p in car.team().roster:
		if p.is_suspended():
			out.append("%s SUSPENDED - %d GAME%s" % [p.short_name().to_upper(), p.susp, "" if p.susp == 1 else "S"])
	return out

func _who() -> String:
	var p := c.team().find_id(int(ev.get("pid", 0)))
	if p == null or String(sc.get("subject", "player")) == "team":
		var lead := "" if p == null else "  -  LEADER %s" % p.short_name().to_upper()
		return Colleges.display_name(c.team().name).to_upper() + lead
	return "#%d %s  |  %s  |  %s" % [p.number, p.short_name().to_upper(), Deck.pos_tag(p), ["", "FRESHMAN", "SOPHOMORE", "JUNIOR", "SENIOR"][clampi(p.year, 0, 4)]]

## What the game recorded for him (never anything it didn't): "THE GAME: 2 GOALS AND 4 ASSISTS".
func _record_line() -> String:
	var v: Dictionary = ev.get("vars", {})
	if String(ev.id) == "practice_discipline":
		return "A PRACTICE-WEEK MATTER: NOTHING HAPPENED IN A GAME"
	if v.has("line") and String(sc.get("subject", "player")) == "player":
		return "LAST GAME: %s" % String(v.line).to_upper()
	return ""

## The scenario's words with this game's numbers in them ({name}, {saves}...).
func fill(t: String) -> String:
	for k in ev.get("vars", {}):
		t = t.replace("{%s}" % k, str(ev.vars[k]))
	return t

func _confirm() -> void:
	if preview or answered or pick < 0 or CoachEvents.blocked(c, ev, pick) != "":
		return
	answered = true
	var p := c.team().find_id(int(ev.get("pid", -1)))
	var before := {"wallet": c.wallet(), "xp": CoachEvents.xp_sum(c.team()), "susp": p.susp if p != null else 0}
	result = CoachEvents.apply(c, ev, pick)
	if result.is_empty():
		result = [["DONE.", "info"]]
	CoachEvents.note_decision(c, ev, pick, result, before)
	if bool(ev.get("dev", false)):
		c.pending_event = {}   # (a developer's event: answered once, saved now; no postgame to close)
	else:
		c.close_postgame()   # (clears the event: answered once, saved now)
	Game.save_career()
	Sfx.play("confirm")
	_render()

# ------------------------------------------------------------------ the answer
func _render_answer(page: VBoxContainer) -> void:
	page.add_child(_story_panel())
	var v := UI.vbox(2)
	v.name = "Result"
	var ch: Dictionary = CoachEvents.choices_for(ev)[pick]
	v.add_child(UI.label("YOUR DECISION: %s" % String(ch.label), 16, UI.GOLD, "big"))
	for ln in result:
		if String(ln[0]) == "":
			continue
		var l := para(String(ln[0]).to_upper(), _kind_col(String(ln[1])), 440)
		l.add_theme_font_override("font", UI.font_caps)
		v.add_child(l)
	page.add_child(navy_panel(v))
	page.add_child(_continue_row())

func _continue_row() -> Control:
	var bottom := UI.hbox(4)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	var cont := Deck.button("CONTINUE  >", _leave, "primary", 150, 26)
	cont.name = "Continue"
	cont.add_theme_font_override("font", UI.font_big)
	cont.add_theme_font_size_override("font_size", 16)
	bottom.add_child(cont)
	return bottom

# ------------------------------------------------------------------ the results first
func _render_results(page: VBoxContainer) -> void:
	for r in results:
		page.add_child(_result_panel(r))
	page.add_child(_continue_row())

## One settled consequence: its verdict (PROVE ME WRONG's in its own words), whose it was, what
## the game decided, and exactly what was applied.
func _result_panel(r: Dictionary) -> Control:
	var ok: bool = r.outcome == "ok"
	var void_ := String(r.outcome) == "void"
	var head := ""
	var col := UI.GOLD if ok else RED
	var quote := ""
	var name := CoachEvents._name(c, int(r.pid))
	match String(r.k):
		"pmw":
			head = "HE PROVED YOU RIGHT!" if ok else ("PROVE ME WRONG: VOID" if void_ else "THE GAMBLE BACKFIRED")
			quote = ("%s answered the challenge and helped the team secure a victory." % name) if ok else \
				("" if void_ else "Giving %s the start did not produce the result the team needed." % name)
		"chal", "learn":
			head = ("SPECIAL CHALLENGE COMPLETE!" if bool(r.get("special", false)) else "COACHING CHALLENGE COMPLETE") if ok else "CHALLENGE FAILED"
		"result":
			head = ("LEGENDARY!" if bool(r.get("special", false)) else "%s: BONUS EARNED" % String(r.title)) if ok else "%s: NO BONUS" % String(r.title)
		"team":
			head = "THE TEAM BACKED IT UP" if ok else "THE TEAM CAME UP SHORT"
		"invest":
			head = "THE INVESTMENT PAID OFF" if ok else "THE INVESTMENT IS LOST"
		"susp":
			head = "SUSPENSION SERVED"
			col = UI.GOLD
	if String(r.outcome) == "even":
		head = "%s: NORMAL GAME XP" % String(r.title)
		col = UI.ACCENT
	if void_:
		col = UI.DIM
	var h := UI.hbox(8)
	h.add_child(_face(int(r.pid), String(r.k) == "invest"))
	var v := UI.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var hl := UI.label(head, 16, col, "big")
	hl.name = "Verdict"
	v.add_child(hl)
	v.add_child(UI.label("%s  -  %s" % [String(r.title), String(r.label)], 8, UI.ACCENT, "caps"))
	if quote != "":
		v.add_child(para("\"%s\"" % quote, UI.TEXT, 360))
	if String(r.note) != "":
		v.add_child(UI.label(String(r.note).to_upper(), 8, UI.DIM, "caps"))
	for ln in r.get("lines", []):
		var l := para(String(ln[0]).to_upper(), _kind_col(String(ln[1])), 360)
		l.add_theme_font_override("font", UI.font_caps)
		v.add_child(l)
	var p := navy_panel(h)
	p.name = "Settled_%d" % int(r.eid)
	p.set_meta("result", r)
	return p

## The challenge results are all closed: the rest of the screen (other results, the event), or
## nothing left to show.
func _after_pops() -> void:
	pops = []
	if results.is_empty() and ev.is_empty():
		_finish()

func _leave() -> void:
	if not results.is_empty():
		# the settled consequences have been shown (once): now the event, if there is one
		CoachEvents.mark_shown(c)
		results = []
		Game.save_career()
		if not ev.is_empty() and not answered:
			_render()
			return
		if not answered:
			_finish()
			return
	if back_to != "":
		Game.back(back_to)
		return
	Game.goto("hub")

## Nothing (more) to ask: the postgame is over, if this screen was its end.
func _finish() -> void:
	CoachEvents.mark_shown(c)
	if from_review and c.pending_event.is_empty():
		c.close_postgame()
	Game.save_career()
	Game.goto("hub")
