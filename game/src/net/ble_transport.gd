class_name BleTransport
extends NetTransport
## Bluetooth LE link. Works in airplane mode with Bluetooth switched back on: no Wi-Fi, no signal.
## The radio work lives in a native plugin that registers the "RetroPoloBLE" singleton
## (Android: plugins/android-ble). The host is a GATT server that advertises the room;
## joiners are GATT clients. The plugin fragments packets to fit the negotiated MTU.
##
## Plugin contract (same on every platform):
##   methods: getStatus() -> "ready" | "off" | "no_permission" | "location_off" | "unsupported",
##            requestAccess(), hostStart(name: String, maxPlayers: int),
##            setRoomInfo(players: int), scanStart(), scanStop(), join(address: String),
##            send(to: int, data: PackedByteArray), close()
##   signals: status_changed(status), room_found(address, name, players, max_players, rssi),
##            joined(), join_failed(reason), host_lost(reason), host_failed(reason), peer_connected(id),
##            peer_disconnected(id), packet_received(from, data)

const SINGLETON := "RetroPoloBLE"

var ble: Object = null

func _init() -> void:
	if not Engine.has_singleton(SINGLETON):
		return
	ble = Engine.get_singleton(SINGLETON)
	ble.connect("status_changed", func(_s): status_changed.emit())
	ble.connect("room_found", func(addr, nm, players, mx, rssi):
		room_found.emit({"key": "ble:" + str(addr), "addr": str(addr), "name": Proto.clean_name(str(nm)),
			"players": int(players), "max": int(mx), "rssi": int(rssi)}))
	ble.connect("joined", func(): connected.emit())
	ble.connect("join_failed", func(why): connect_failed.emit(str(why)))
	ble.connect("host_lost", func(why): lost_host.emit(str(why)))
	ble.connect("host_failed", func(why): host_failed.emit(str(why)))
	ble.connect("peer_connected", func(id): peer_joined.emit(int(id)))
	ble.connect("peer_disconnected", func(id): peer_left.emit(int(id)))
	ble.connect("packet_received", func(from, data): packet.emit(int(from), data))

func kind() -> String:
	return "ble"

func status() -> String:
	if ble == null:
		return "unsupported"
	return str(ble.getStatus())

func request_access() -> void:
	if ble:
		ble.requestAccess()

func max_players() -> int:
	return 2

func host(room_name: String, p_max: int) -> Error:
	if status() != "ready":
		return ERR_UNAVAILABLE
	ble.hostStart(room_name, p_max)
	return OK

func set_room_info(players: int) -> void:
	if ble:
		ble.setRoomInfo(players)

func scan_start() -> void:
	if status() == "ready":
		ble.scanStart()

func scan_stop() -> void:
	if ble:
		ble.scanStop()

func join(r: Dictionary) -> Error:
	if status() != "ready":
		return ERR_UNAVAILABLE
	ble.join(str(r.get("addr", "")))
	return OK

func send(to: int, data: PackedByteArray, _reliable: bool = true) -> void:
	if ble:
		ble.send(to, data)

func close() -> void:
	if ble:
		ble.close()
