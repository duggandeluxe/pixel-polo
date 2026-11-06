extends BaseScreen
## Multiplayer: pick a link (Online with a room code, Wi-Fi/hotspot, or Bluetooth), host or
## join, then the lobby: each player picks a club, the host sets the quarters and starts.

var mode := "home"          # home | scan | joining | lobby
var link := "online"
var tt := 0.0
var name_edit: LineEdit
var addr_edit: LineEdit
var code_edit: LineEdit
var dots: Label

func _ready() -> void:
	build("MULTIPLAYER", true, false)
	link = Game.settings.get("mp_link", "online")
	if not _links().has(link):
		link = _links()[0]
	if Net.active():
		link = Net.t.kind() if Net.t else link
		mode = "lobby" if Net.my_id != 0 else "joining"
	Net.rooms_changed.connect(_render_if.bind("scan"))
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.room_code_ready.connect(_on_code)
	Net.joined.connect(_on_joined)
	Net.join_failed.connect(_on_join_failed)
	Net.ended.connect(_on_ended)
	Net.ble.status_changed.connect(_render_if.bind("home"))
	_render()
	Sfx.music("menu")

func _exit_tree() -> void:
	for pair in [[Net.joined, _on_joined], [Net.join_failed, _on_join_failed], [Net.ended, _on_ended]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	if Net.role == "":
		Net.stop_scan()

func _links() -> Array:
	var out := ["online"]
	if Net.has_lan():
		out.append("lan")
	if Net.has_bluetooth():
		out.append("ble")
	return out

func on_back() -> void:
	Sfx.play("back")
	match mode:
		"lobby", "joining":
			Net.leave()
			_set_mode("home")
		"scan":
			Net.stop_scan()
			_set_mode("home")
		_:
			_save_name()
			Game.goto("title")

## Quick match can make us the host of a fresh room while we're still "joining".
func _on_lobby_changed() -> void:
	if mode == "joining" and Net.my_id != 0:
		_set_mode("lobby")
	else:
		_render_if("lobby")

func _on_code(_code: String) -> void:
	_render_if("lobby")

func _render_if(m: String) -> void:
	if mode == m and is_inside_tree():
		_render()

func _set_mode(m: String) -> void:
	mode = m
	_render()

func _process(dt: float) -> void:
	tt += dt
	if dots and is_instance_valid(dots):
		dots.text = ".".repeat(int(tt * 2.5) % 4)

func _render() -> void:
	for ch in body.get_children():
		ch.queue_free()
	for ch in header_right.get_children():
		ch.queue_free()
	name_edit = null
	addr_edit = null
	code_edit = null
	dots = null
	match mode:
		"home":
			title_label.text = "MULTIPLAYER"
			_home()
		"scan":
			title_label.text = "JOIN A MATCH"
			_scan()
		"joining":
			title_label.text = "JOIN A MATCH"
			_joining()
		"lobby":
			title_label.text = "ROOM: " + (Net.room_code() if Net.room_code() != "" else Net.room_name)
			_lobby()

# ================================================================== home
func _home() -> void:
	var nh := UI.hbox(4)
	body.add_child(nh)
	nh.add_child(UI.label("YOUR NAME", 8, UI.DIM))
	name_edit = LineEdit.new()
	name_edit.text = Net.my_name()
	name_edit.max_length = Proto.NAME_MAX
	name_edit.custom_minimum_size = Vector2(110, 18)
	name_edit.text_submitted.connect(func(_s): _save_name())
	name_edit.focus_exited.connect(_save_name)
	nh.add_child(name_edit)
	body.add_child(UI.label("PLAY A FRIEND", 8, UI.DIM))
	var cards := UI.hbox(6)
	body.add_child(cards)
	cards.add_child(_link_card("online", "ONLINE", "ANYWHERE", ["A room code for a friend,", "or QUICK MATCH vs anyone."]))
	if Net.has_lan():
		cards.add_child(_link_card("lan", "WI-FI", "SAME NETWORK", ["Same Wi-Fi or a phone hotspot.", "No internet needed."]))
	if Net.has_bluetooth():
		cards.add_child(_link_card("ble", "BLUETOOTH", "NO WI-FI NEEDED", ["Works on a plane.", "Android phones today."]))
	body.add_child(_status_row())
	body.add_child(UI.spacer(0, 0, true))
	var l := UI.label("YOU PLAY YOUR ATTACKS, THEY PLAY THEIRS. EQUAL TEAMS: PURE SKILL.", 8, UI.ACCENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(l)
	body.add_child(UI.spacer(0, 4))
	var bh := UI.hbox(8)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(bh)
	var ready := Net.transport(link).status() == "ready"
	var hb := UI.button("HOST A MATCH", _host, "primary", 140, 24)
	var jb := UI.button("JOIN A MATCH", _join_screen, "normal", 140, 24)
	hb.disabled = not ready
	jb.disabled = not ready
	bh.add_child(hb)
	bh.add_child(jb)
	if link == "online":
		var qb := UI.button("QUICK MATCH", _quick, "good", 110, 24)
		qb.disabled = not ready
		bh.add_child(qb)
	body.add_child(UI.spacer(0, 4))

func _link_card(k: String, title: String, tag: String, lines: Array) -> Control:
	var on := link == k
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 54)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", UI.chunky(UI.PANEL2 if on else UI.PANEL, UI.GOLD if on else UI.BORDER, true, false, 4, 3))
	b.add_theme_stylebox_override("hover", UI.chunky(UI.BG_HI, UI.GOLD if on else UI.BORDER_HI, true, false, 4, 3))
	b.add_theme_stylebox_override("pressed", UI.chunky(UI.PANEL2, UI.GOLD, false, true, 4, 3))
	b.add_theme_stylebox_override("hover_pressed", UI.chunky(UI.PANEL2, UI.GOLD, false, true, 4, 3))
	b.pressed.connect(func():
		Sfx.play("click")
		link = k
		Game.settings.mp_link = k
		Game.save_settings()
		_render())
	var art := UI.canvas(0, 0, func(ci: Control):
		UI.text(ci, Vector2(6, 15), title, 16, UI.GOLD if on else UI.TEXT, "big")
		UI.text(ci, Vector2(6 + UI.text_width(title, 16, "big") + 6, 13), tag, 8, UI.GOOD if on else UI.DIM)
		for i in lines.size():
			UI.text(ci, Vector2(6, 30 + i * 10), lines[i], 8, UI.TEXT if on else UI.DIM)
		if on:
			UI.text(ci, Vector2(ci.size.x - 12, 13), "*", 8, UI.GOLD))
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	return b

func _status_row() -> Control:
	var txt := ""
	var col := UI.GOOD
	var action := ""
	match link:
		"online":
			if Net.has_online():
				txt = "Online: you both need internet. Lag only delays what you see of their attack, never your throws."
			else:
				txt = "Online play isn't switched on in this build yet (the relay server isn't set up)." + (" Use Wi-Fi for now." if Net.has_lan() else "")
				col = UI.WARN
		"lan":
			var ip := LanTransport.local_ip()
			if ip == "":
				txt = "Not on a network. Join Wi-Fi or turn on a phone hotspot."
				col = UI.WARN
			else:
				txt = "On the network as %s." % ip
		"ble":
			match Net.ble.status():
				"ready":
					txt = "Bluetooth is on. Keep the phones close."
				"off":
					txt = "Bluetooth is off. Switch it on - airplane mode can stay on."
					col = UI.WARN
					action = "TURN ON"
				"no_permission":
					txt = "Allow Bluetooth so phones can find each other."
					col = UI.WARN
					action = "ALLOW"
				"location_off":
					txt = "Android 11 and older need Location on to find nearby phones."
					col = UI.WARN
					action = "TURN ON"
				_:
					txt = "This build has no Bluetooth plugin. Wi-Fi works now."
					col = UI.WARN
	var h := UI.hbox(6)
	h.custom_minimum_size = Vector2(0, 20)
	h.add_child(para(txt, col, 300))
	if action != "":
		h.add_child(UI.button(action, func(): Net.ble.request_access(), "good", 70, 18))
	return h

func _save_name() -> void:
	if name_edit == null or not is_instance_valid(name_edit):
		return
	var n := Proto.clean_name(name_edit.text)
	if n != Game.settings.get("mp_name", ""):
		Game.settings.mp_name = n
		Game.save_settings()

func _host() -> void:
	_save_name()
	var err := Net.host(link)
	if err != OK:
		Game.toast("Could not open a room (%s)" % error_string(err), UI.BAD)
		return
	Sfx.play("confirm")
	_set_mode("lobby")

func _quick() -> void:
	_save_name()
	if Net.join({"quick": true}, "online") != OK:
		Game.toast("Can't reach the online server", UI.BAD)
		return
	Sfx.play("confirm")
	_set_mode("joining")

func _join_screen() -> void:
	_save_name()
	if link == "online":
		_set_mode("scan")
		return
	Net.scan(link)
	_set_mode("scan")

# ================================================================== join
func _scan() -> void:
	header_right.add_child(_chip({"online": "ONLINE", "lan": "WI-FI", "ble": "BLUETOOTH"}[link], UI.ACCENT))
	if link == "online":
		body.add_child(UI.label("TYPE YOUR FRIEND'S ROOM CODE", 8, UI.GOLD))
		var ch := UI.hbox(6)
		body.add_child(ch)
		code_edit = LineEdit.new()
		code_edit.placeholder_text = "K7QX"
		code_edit.max_length = 4
		code_edit.custom_minimum_size = Vector2(90, 26)
		code_edit.add_theme_font_size_override("font_size", 20)
		code_edit.text_submitted.connect(func(_s): _join_code())
		ch.add_child(code_edit)
		ch.add_child(UI.button("JOIN", _join_code, "primary", 70, 26))
		body.add_child(para("Your friend taps HOST A MATCH and reads you the 4-letter code.", UI.DIM, 300))
		return
	var sh := UI.hbox(2)
	body.add_child(sh)
	sh.add_child(UI.label("LOOKING FOR MATCHES NEARBY", 8, UI.GOLD))
	dots = UI.label("", 8, UI.GOLD)
	sh.add_child(dots)
	var list := UI.vbox(2)
	var keys: Array = Net.rooms.keys()
	keys.sort()
	for k in keys:
		list.add_child(_room_row(Net.rooms[k]))
	if keys.is_empty():
		list.add_child(UI.label("Ask a friend to tap HOST A MATCH. " + ("Keep the phones close." if link == "ble" else "Be on the same Wi-Fi or hotspot."), 8, UI.DIM))
	body.add_child(UI.scroll(list))
	if link == "lan":
		var ah := UI.hbox(4)
		body.add_child(ah)
		ah.add_child(UI.label("OR TYPE THE HOST'S ADDRESS", 8, UI.DIM))
		addr_edit = LineEdit.new()
		addr_edit.placeholder_text = "192.168.1.20"
		addr_edit.custom_minimum_size = Vector2(110, 18)
		addr_edit.text_submitted.connect(func(_s): _join_addr())
		ah.add_child(addr_edit)
		ah.add_child(UI.button("JOIN", _join_addr, "normal", 50, 18))
		body.add_child(para("iPhones can't see rooms on Wi-Fi: type the address the host's screen shows.", UI.DIM2, 300))

func _room_row(room: Dictionary) -> Control:
	var h := UI.hbox(6)
	var full: bool = int(room.players) >= int(room.max)
	h.add_child(fixed_label(str(room.name) + "'S MATCH", 150, UI.DIM if full else UI.GOLD))
	h.add_child(UI.label("%d/%d" % [int(room.players), int(room.max)], 8, UI.DIM if full else UI.TEXT))
	h.add_child(UI.spacer(0, 0, true))
	h.add_child(UI.label("FULL" if full else "JOIN >", 8, UI.BAD if full else UI.GOOD))
	return row_button(h, func():
		if full:
			Game.toast("That room is full", UI.BAD)
			return
		_join(room), false, 20)

func _join_code() -> void:
	if code_edit == null:
		return
	var code := code_edit.text.strip_edges().to_upper()
	if code.length() != 4:
		Game.toast("Room codes have 4 letters", UI.BAD)
		return
	if Net.join({"code": code}, "online") != OK:
		Game.toast("Can't reach the online server", UI.BAD)
		return
	Sfx.play("confirm")
	_set_mode("joining")

func _join_addr() -> void:
	if addr_edit == null:
		return
	var a := addr_edit.text.strip_edges()
	if not a.is_valid_ip_address():
		Game.toast("That doesn't look like an address", UI.BAD)
		return
	_join({"key": "lan:%s:%d" % [a, LanTransport.PORT], "name": a, "addr": a, "port": LanTransport.PORT})

func _join(room: Dictionary) -> void:
	if Net.join(room) != OK:
		Game.toast("Could not connect", UI.BAD)
		return
	Sfx.play("confirm")
	_set_mode("joining")

func _joining() -> void:
	body.add_child(UI.spacer(0, 0, true))
	var h := UI.hbox(2)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(h)
	h.add_child(UI.label("FINDING A MATCH" if Net.room_name == "" else "JOINING %s" % Net.room_name, 16, UI.GOLD, "big"))
	dots = UI.label("", 16, UI.GOLD, "big")
	h.add_child(dots)
	body.add_child(UI.spacer(0, 0, true))
	var bh := UI.hbox(4)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(bh)
	bh.add_child(UI.button("CANCEL", func():
		Net.leave()
		_set_mode("home"), "ghost", 90, 20))

func _on_joined() -> void:
	Sfx.play("good")
	_set_mode("lobby")

func _on_join_failed(reason: String) -> void:
	Game.toast(reason, UI.BAD)
	Sfx.play("error")
	if link != "online":
		Net.scan(link)
		_set_mode("scan")
	else:
		_set_mode("home")

func _on_ended(reason: String) -> void:
	if not is_inside_tree():
		return
	Game.toast(reason, UI.WARN)
	_set_mode("home")

# ================================================================== lobby
func _lobby() -> void:
	var kind := Net.t.kind() if Net.t else link
	header_right.add_child(_chip({"online": "ONLINE", "lan": "WI-FI", "ble": "BLUETOOTH"}.get(kind, "") + "  %d/2" % Net.order.size(), UI.ACCENT))
	var cols := UI.hbox(8)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var left := UI.vbox(3)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	for i in 2:
		if i < Net.order.size():
			left.add_child(_player_card(Net.players[Net.order[i]], i))
		else:
			var p := UI.panel(Color(0, 0, 0, 0.25), UI.BORDER)
			p.add_child(UI.label("Waiting for a friend to join", 8, UI.DIM))
			left.add_child(p)
	var right := UI.vbox(3)
	right.custom_minimum_size = Vector2(170, 0)
	cols.add_child(right)
	if Net.is_host():
		if kind == "online":
			right.add_child(UI.label("ROOM CODE", 8, UI.DIM))
			var code := Net.room_code()
			right.add_child(UI.label(code if code != "" else "...", 20, UI.GOLD, "big"))
			right.add_child(para("Friend: MULTIPLAYER > ONLINE > JOIN, then this code.", UI.DIM, 160))
		elif kind == "lan":
			right.add_child(para("Friend: JOIN A MATCH, or type %s" % LanTransport.local_ip(), UI.DIM, 160))
		right.add_child(UI.label("%d-MINUTE QUARTERS" % int(Net.cfg.minutes), 8, UI.DIM))
		var eq: bool = Net.cfg.equal
		right.add_child(UI.button("EQUAL TEAMS: %s" % ("ON" if eq else "OFF"), func(): Net.set_cfg("equal", not eq), "tab_on" if eq else "tab", 0, 16))
		right.add_child(para("Equal: both clubs get the same players' ratings, so it's pure skill." if eq else "Off: the clubs' real ratings count.", UI.DIM, 160))
		right.add_child(UI.spacer(0, 0, true))
		var sb := UI.button("START MATCH", _start, "primary", 0, 24)
		sb.disabled = not Net.can_start()
		right.add_child(sb)
	else:
		right.add_child(UI.label("%d-MINUTE QUARTERS" % int(Net.cfg.minutes), 16, UI.GOLD, "big"))
		right.add_child(UI.label("Equal teams: %s" % ("ON" if Net.cfg.equal else "OFF"), 8, UI.TEXT))
		right.add_child(UI.spacer(0, 0, true))
		var wh := UI.hbox(0)
		right.add_child(wh)
		var host_name: String = Net.players[1].name if Net.players.has(1) else "the host"
		wh.add_child(UI.label("Waiting for %s to start" % host_name, 8, UI.DIM))
		dots = UI.label("", 8, UI.DIM)
		wh.add_child(dots)

## A player's slot: name, wins, and their club (yours has arrows to change it).
func _player_card(p: Dictionary, slot: int) -> Control:
	var me := int(p.id) == Net.my_id
	var panel := UI.panel(UI.PANEL2 if me else UI.PANEL, UI.GOLD if me else UI.BORDER)
	var v := UI.vbox(2)
	panel.add_child(v)
	var h := UI.hbox(4)
	v.add_child(h)
	h.add_child(UI.label(str(p.name), 16, UI.GOLD if me else UI.TEXT, "big"))
	h.add_child(UI.label("HOST" if int(p.id) == 1 else ("YOU" if me else ""), 8, UI.ACCENT))
	h.add_child(UI.spacer(0, 0, true))
	h.add_child(UI.label("%d W" % int(p.wins), 8, UI.GOLD if int(p.wins) > 0 else UI.DIM))
	var team := League.make_team(int(p.club))
	var ch := UI.hbox(4)
	v.add_child(ch)
	if me:
		ch.add_child(UI.button("<", func(): Net.set_club((int(p.club) + League.club_count() - 1) % League.club_count()), "ghost", 20, 16))
	ch.add_child(cap_widget(Color("f2f2e9") if slot == 0 else team.c1, team.c1 if slot == 0 else team.c2))
	ch.add_child(fixed_label(team.name.to_upper(), 120))
	ch.add_child(UI.label("RATING %d" % roundi(team.power()), 8, UI.DIM))
	if me:
		ch.add_child(UI.button(">", func(): Net.set_club((int(p.club) + 1) % League.club_count()), "ghost", 20, 16))
	v.add_child(UI.label("White caps" if slot == 0 else "Dark caps", 8, UI.DIM))
	return panel

func _start() -> void:
	if not Net.can_start():
		return
	Sfx.play("whistle")
	Net.start_match()
