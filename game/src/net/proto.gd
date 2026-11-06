class_name Proto
extends RefCounted
## Wire format for multiplayer. Two packet kinds:
##   'D' + var_to_bytes(Dictionary)  - lobby and match control messages (rare, reliable)
##   'P' + one frame of a live attack - every body and the ball, ~12 per second, ~120 bytes
## Small on purpose: Bluetooth LE moves ~180 bytes per packet.

const VERSION := 3   # 2: the keeper duel ("duel" event, "kv" verdicts); 3: the sprint from the goal lines
const MSG := 68      # 'D'
const PLAY := 80     # 'P'
const NAME_MAX := 10
const BODY_BYTES := 8
const PLAY_HEADER := 21

static func pack(msg: Dictionary) -> PackedByteArray:
	var out := PackedByteArray([MSG])
	out.append_array(var_to_bytes(msg))
	return out

## Returns {} for anything that is not a well-formed message (never decodes objects).
static func unpack(data: PackedByteArray) -> Dictionary:
	if data.size() < 2 or data[0] != MSG:
		return {}
	var v = bytes_to_var(data.slice(1))
	if typeof(v) != TYPE_DICTIONARY or not v.has("t"):
		return {}
	return v

static func is_play(data: PackedByteArray) -> bool:
	return data.size() >= 2 and data[0] == PLAY

## One frame of the attacking phone's possession. Bodies go in Play.bodies() order.
static func pack_play(seq: int, clock: float, play: Play) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u8(PLAY)
	b.put_u16(seq & 0xffff)
	b.put_float(clock)
	b.put_float(play.shot_clock)
	b.put_u8(clampi(int(ceilf(play.man_up)), 0, 255))
	b.put_u8(1 if play.over else 0)
	b.put_16(_cm(play.ball.pos.x))
	b.put_16(_cm(play.ball.pos.y))
	b.put_u8(clampi(int(play.ball.z * 40.0), 0, 255))
	b.put_u8(play.ball.state)
	var bodies := play.bodies()
	b.put_u8(bodies.find(play.holder) if play.holder != null else 255)
	b.put_u8(bodies.size())
	for s in bodies:
		b.put_16(_cm(s.pos.x))
		b.put_16(_cm(s.pos.y))
		b.put_8(1 if s.facing >= 0.0 else -1)
		b.put_u8(clampi(int(s.arm * 255.0), 0, 255))
		b.put_8(clampi(int(s.dive * 100.0), -100, 100))
		b.put_u8(1 if s.out else 0)
	return b.data_array

## {seq, clock, shot_clock, man_up, over, ball: {pos, z, state}, holder, bodies: [{pos, facing, arm, dive, out}]}
static func unpack_play(data: PackedByteArray) -> Dictionary:
	if data.size() < PLAY_HEADER:
		return {}
	var b := StreamPeerBuffer.new()
	b.data_array = data
	b.seek(1)
	# read field by field, in wire order
	var seq := b.get_u16()
	var clock := b.get_float()
	var shot_clock := b.get_float()
	var man_up := float(b.get_u8())
	var over := b.get_u8() == 1
	var bx := b.get_16() / 100.0
	var by := b.get_16() / 100.0
	var bz := b.get_u8() / 40.0
	var bstate := b.get_u8()
	var holder := b.get_u8()
	var n := b.get_u8()
	if data.size() < PLAY_HEADER + n * BODY_BYTES:
		return {}
	var out := {"seq": seq, "clock": clock, "shot_clock": shot_clock, "man_up": man_up, "over": over,
		"ball": {"pos": Vector2(bx, by), "z": bz, "state": bstate}, "holder": holder}
	var bodies: Array = []
	for _i in n:
		var x := b.get_16() / 100.0
		var y := b.get_16() / 100.0
		var facing := float(b.get_8())
		var arm := b.get_u8() / 255.0
		var dive := b.get_8() / 100.0
		var out_flag := b.get_u8() == 1
		bodies.append({"pos": Vector2(x, y), "facing": facing, "arm": arm, "dive": dive, "out": out_flag})
	out["bodies"] = bodies
	return out

static func _cm(m: float) -> int:
	return clampi(roundi(m * 100.0), -32000, 32000)

static func clean_name(s: String) -> String:
	var out := ""
	for ch in s.strip_edges().to_upper():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) < 127:
			out += ch
	out = out.strip_edges().substr(0, NAME_MAX)
	return out if out != "" else "COACH"
