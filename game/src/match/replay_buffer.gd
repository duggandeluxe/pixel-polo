class_name ReplayBuffer
extends RefCounted
## THE REPLAY'S RECORDER (the Premium Visual Upgrades update, Instant Replay): the last few seconds
## of what was really on the water, RATE frames a second in a ring. Each frame is copies of plain
## values: where every man and the ball were and how each was drawn, and where the camera was.
## It only ever reads. No physics is run again and no flight is made up: a replay shows these
## frames and nothing else (ReplayShow).

const RATE := 30.0
const SECONDS := 9.0
const LEAD := 1.3             # a clip starts this long before the release
const TAIL := 0.9             # ...and ends this long after the ball's in
const CATCH_UP := 6           # frames one slow tick can stand for at most

## One man: [source Swimmer, pos, speed vector, facing, anim, arm, dive, hop, cheer, block_arm,
## block hand, snap, grip, hook, out, slump, dive pose, its clock].
var frames: Array = []
var _acc := 0.0

func clear() -> void:
	frames.clear()
	_acc = 0.0

## Time passed on the water (hit-stops and slow goal shows pass less), and what's there now.
## `ball`: {at, shot, dir, power, fire, flown, net, bar_text, bar_hit}.
func tick(dt: float, bodies: Array, ball: Dictionary, view: PoolView) -> void:
	_acc += dt
	if _acc < 1.0 / RATE:
		return
	# (a slow device: as many frames as the time that passed, so a clip keeps the real clock)
	var n := mini(int(_acc * RATE), CATCH_UP)
	_acc = fmod(_acc, 1.0 / RATE)
	var men: Array = []
	for s: Swimmer in bodies:
		men.append([s, s.pos, s.vel, s.facing, s.anim, s.arm, s.dive, s.hop, s.cheer, maxf(s.block_arm, s.zreach), PoolArt.block_hand(s), s.snap, s.grip, s.hook, s.out, s.slump,
			s.pose, s.pose.t if s.pose != null else 0.0, s.cheer_style])
	for i in n:
		frames.append({"men": men, "ball": ball, "cam": view.cam, "zoom": view.zoom, "mirror": view.mirror})
	while frames.size() > int(SECONDS * RATE):
		frames.pop_front()

## A live ball as a frame records it.
static func ball_of(b: Ball, net: Dictionary) -> Dictionary:
	var shot := b.state == Ball.State.SHOT and b.shooter != null and b.shooter.player != null
	return {"at": b.look(), "shot": shot, "dir": b.to - b.from, "power": PoolArt.shooter_power(Attributes.shot_pace(b.shooter.player)) if shot else 0.0,
		"fire": HotFire.level_of(b.shooter) if shot else 0, "flown": b.t * b.dur, "net": net,
		"bar_hit": b.bar_t >= 0.0, "bar_text": String(b.bar.get("text", ""))}

## The goal just scored as a clip: {frames, shot (its release, an index), net (the ball crossing),
## bar (the frame it hit the frame, or -1), bar_text}. Empty if there's no shot to show.
func clip() -> Dictionary:
	var last := -1
	for i in range(frames.size() - 1, -1, -1):
		if bool(frames[i].ball.shot):
			last = i
			break
	if last < 0:
		return {}
	var first := last
	while first > 0 and bool(frames[first - 1].ball.shot):
		first -= 1
	var from := maxi(0, first - int(LEAD * RATE))
	var to := mini(frames.size() - 1, last + int(TAIL * RATE))
	var out: Array = frames.slice(from, to + 1)
	var bar := -1
	var text := ""
	for i in out.size():
		if bool(out[i].ball.get("bar_hit", false)):
			bar = i
			text = String(out[i].ball.get("bar_text", ""))
			break
	return {"frames": out, "shot": first - from, "net": last - from, "bar": bar, "bar_text": text}
