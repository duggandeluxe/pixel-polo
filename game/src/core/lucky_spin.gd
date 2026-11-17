class_name LuckySpin
extends RefCounted
## LUCKY SPIN (the Polo Points Economy update): watch a rewarded ad, spin an 11-segment wheel,
## win Polo Points. This is the rules and the state only. The ad is Ads, the coins go into
## Store.bank, the wheel is LuckySpinPanel.
##
##   THE WHEEL       SEGMENTS: 11 equal slices, 8 x 5 PP, 2 x 10 PP, 1 x 15 PP. pick() draws one
##                   SLICE uniformly (1 in 11 each), so the odds are exactly what the wheel shows
##                   (5 PP 8/11, 10 PP 2/11, 15 PP 1/11). Expected value 75/11, about 6.82 PP.
##   THE ALLOWANCE   PER_WINDOW (2) spins. The first spin taken from a full allowance starts the
##                   COOLDOWN (6 real hours, `refill_at`). When that time comes, both spins are back
##                   together. Spins never stack above 2. Dynasty weeks, seasons, saves, reloads and
##                   restarts don't touch it, because it's one per account (Store keeps it in
##                   user://store.cfg, never in a career save).
##   A CLAIM         claim(txn): one rewarded-ad completion (its transaction id) is one spin, once.
##                   The same id again pays nothing. The result is decided here, before the wheel
##                   moves, and the wheel only shows it.
##
## Honest limits: this is client-side state. `last_t` stops the clock running backwards from
## refilling early or from pushing refill_at out, but a device clock set FORWARD can't be caught
## from the device alone. Production needs the server's time and claim ledger (docs/SPEC.md, 4b).

const SEGMENTS := [5, 10, 5, 5, 5, 15, 5, 5, 10, 5, 5]   # clockwise from the top; 8 / 2 / 1
const PER_WINDOW := 2
const COOLDOWN := 6 * 3600          # seconds
const CLAIMS_MAX := 200

var used := 0                       # spins taken from this allowance (0..PER_WINDOW)
var refill_at := 0                  # unix time both spins come back (0: the allowance is full)
var last_t := 0                     # the newest clock reading seen (the clock never runs backwards here)
var claims: Array = []              # ad transaction ids already spun (newest last)
var pending := {}                   # the last result, credited but not yet shown: {txn, seg, pp}
var total_pp := 0                   # every PP this wheel has paid (the books)
var spins := 0                      # every spin taken

static func count(pp: int) -> int:
	return SEGMENTS.count(pp)

static func probability(pp: int) -> float:
	return float(count(pp)) / SEGMENTS.size()

static func expected() -> float:
	var s := 0
	for v in SEGMENTS:
		s += int(v)
	return float(s) / SEGMENTS.size()

## One slice, uniformly: what the wheel will land on.
static func pick(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, SEGMENTS.size() - 1)

## The clock as this state sees it: never earlier than a reading it has already seen.
func _now(t: int) -> int:
	last_t = maxi(last_t, t)
	return last_t

## Brings the allowance up to date: both spins back once refill_at has passed.
func tick(t: int) -> void:
	var now := _now(t)
	if refill_at > 0 and now >= refill_at:
		used = 0
		refill_at = 0
	elif refill_at > now + COOLDOWN:
		refill_at = now + COOLDOWN   # (an edited file or a clock set back: never longer than one cooldown)

func available(t: int) -> int:
	tick(t)
	return PER_WINDOW - used

## Seconds until both spins come back (0: nothing to wait for).
func seconds_left(t: int) -> int:
	tick(t)
	return maxi(0, refill_at - last_t) if refill_at > 0 else 0

func claimed(txn: String) -> bool:
	return txn in claims

## One rewarded ad completed (`txn`, its id): takes a spin and decides the slice (`seg` >= 0 forces
## one, for Developer Mode's test spins only). {} when nothing is paid: no id, the same id again,
## or no spins left. The caller credits result.pp.
func claim(txn: String, t: int, rng: RandomNumberGenerator, seg: int = -1) -> Dictionary:
	if txn == "" or claimed(txn) or available(t) <= 0:
		return {}
	if used == 0:
		refill_at = last_t + COOLDOWN   # (the first spin of a full allowance starts the clock)
	used += 1
	claims.append(txn)
	if claims.size() > CLAIMS_MAX:
		claims = claims.slice(claims.size() - CLAIMS_MAX)
	var s := seg if seg >= 0 and seg < SEGMENTS.size() else pick(rng)
	var out := {"txn": txn, "seg": s, "pp": int(SEGMENTS[s])}
	pending = out.duplicate()
	total_pp += int(out.pp)
	spins += 1
	return out

## "05:59:59".
static func clock(secs: int) -> String:
	secs = maxi(0, secs)
	return "%02d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]

## The counter line: "SPINS AVAILABLE: 2/2", or "NEXT SPINS IN: 05:59:59" when both are used.
func status_text(t: int) -> String:
	var n := available(t)
	if n > 0:
		return "SPINS AVAILABLE: %d/%d" % [n, PER_WINDOW]
	return "NEXT SPINS IN: %s" % clock(seconds_left(t))

func to_dict() -> Dictionary:
	return {"used": used, "refill_at": refill_at, "last_t": last_t, "claims": claims.duplicate(),
		"pending": pending.duplicate(), "total_pp": total_pp, "spins": spins}

static func from_dict(d: Dictionary) -> LuckySpin:
	var s := LuckySpin.new()
	s.used = clampi(int(d.get("used", 0)), 0, PER_WINDOW)
	s.refill_at = maxi(0, int(d.get("refill_at", 0)))
	s.last_t = maxi(0, int(d.get("last_t", 0)))
	s.claims = (d.get("claims", []) as Array).map(func(x): return String(x))
	var p = d.get("pending", {})
	s.pending = (p as Dictionary).duplicate() if p is Dictionary else {}
	s.total_pp = maxi(0, int(d.get("total_pp", 0)))
	s.spins = maxi(0, int(d.get("spins", 0)))
	if s.used == 0:
		s.refill_at = 0
	elif s.refill_at == 0:
		s.refill_at = s.last_t + COOLDOWN   # (spins used with no clock: wait one cooldown)
	return s
