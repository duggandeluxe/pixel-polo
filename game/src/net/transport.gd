class_name NetTransport
extends RefCounted
## One link layer for multiplayer (Bluetooth LE, Wi-Fi or the online relay). Star topology: the
## host is peer 1, clients only ever talk to the host, and the host relays.
## Subclasses: BleTransport, LanTransport, RelayTransport. Ported from Retro Swim.

signal room_found(room: Dictionary)          # scanning: {"key","name","players","max", ...link fields}
signal connected                             # client: the link to the host is up
signal connect_failed(reason: String)
signal peer_joined(id: int)                  # host: a client link is up
signal peer_left(id: int)
signal lost_host(reason: String)             # client: the link to the host dropped
signal host_failed(reason: String)           # host: the room could not be opened (e.g. no advertising)
signal packet(from: int, data: PackedByteArray)
signal status_changed

const HOST_ID := 1

## "ble", "lan" or "online"
func kind() -> String:
	return ""

## "ready" | "off" | "no_permission" | "location_off" | "unsupported"
func status() -> String:
	return "unsupported"

## Ask the OS for whatever is missing (permissions, turning the radio on).
func request_access() -> void:
	pass

func max_players() -> int:
	return 4

func host(_room_name: String, _max_players: int) -> Error:
	return ERR_UNAVAILABLE

## Host: refresh what scanners see (player count).
func set_room_info(_players: int) -> void:
	pass

func scan_start() -> void:
	pass

func scan_stop() -> void:
	pass

func join(_room: Dictionary) -> Error:
	return ERR_UNAVAILABLE

## to: peer id (host -> one client) or HOST_ID (client -> host).
func send(_to: int, _data: PackedByteArray, _reliable: bool = true) -> void:
	pass

func poll() -> void:
	pass

func close() -> void:
	pass
