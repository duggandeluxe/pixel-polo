class_name DevRecruits
## DEV RECRUITS (the Secret Admin Recruits update, the CPU Recruitment & Permanent Uniqueness
## update, and the DEV Recruit Overhaul, which renamed them from Admin Recruits): two
## developer-inspired prospects with attributes past the normal ten (Attributes.cap: up to DEV_MAX
## for them, MAX for everyone else) and a light-blue card (DevArt).
##
##   GENERATED ONCE  each is made at most ONCE in a dynasty, ever: the moment he's made (a roll, the
##             CPU pool's roll, or Developer Mode's force spawn) his flag (FLAGS: "blake_duggan_generated")
##             is set in the save, and nothing ever clears it: not signing, a transfer, graduating,
##             going unsigned, a new season, a refresh or the dev reset. Blake and Logan each his own.
##   SPAWNING  every market refresh (Recruiting.new_market with `roll`: the season's new market and
##             REFRESH RECRUITS, free or paid) rolls each one not yet generated, 1 in ODDS. Never on
##             opening the market, loading a save or viewing a recruit; no pity, no guarantee. One
##             that comes up takes an ordinary, unpinned prospect's place (the market never grows).
##             The dice are their own (seeded from the career's state, never drawing from it), so an
##             ordinary prospect is made exactly as he would have been without them.
##   THE SHARED POOL  the market is the one recruiting pool everyone draws from: one player, one
##             id, never a copy. Pin him and he stays on it through refreshes like any pinned
##             prospect. Leave him unpinned and the next refresh ROTATES HIM OUT (rotate_out): one
##             roll, PICKUP_CHANCE, that a CPU program signs him (he commits to it, and joins its
##             roster with the class: cpu_recruit), else he's gone from recruiting for good. When
##             the class closes (the off-season's AI rosters: cpu_recruit) the CPU programs go
##             after whoever's still unsigned on the market, pinned or not. That's also the CPU
##             programs' one recruiting opportunity a season: ONE central roll each (1 in CPU_ODDS, never one per school) that
##             can generate a recruit straight into their pool. Whoever is in it signs with one
##             school with room, picked by chance weighted on what he's worth to it
##             (Offseason.pickup_value: its need at his position, his real attributes and
##             potential): never just the top program, never guaranteed to be yours.
##   PRICE     PRICE Polo Points, fixed (Recruiting.price_of / from_save), for your school. The CPU
##             programs have no wallets: they sign the way they always fill places.
##   PLAY      everything else is the ordinary game: pins (PIN_MAX, as anyone), signing, XP and upgrades (never past his
##             own ceilings), any roster (yours or a CPU's), cuts and transfers, graduation. No
##             trait, no special ability: only his attributes, read by the same formulas as anyone's.
##
## The career keeps Career.dev_recruits: {generated: {flag: true}, log: [{key, how ("roll" |
## "forced" | "cpu" | "rotated"), year, pid, swapped?, outcome? ("cpu" | "unsigned"), team?}],
## signed: [keys], commits: [{key, team, p}] (rotated out and signed by a CPU program, joining it
## with the class)}. A save from before the rename keeps it as "admin_recruits" (Career.from_dict). Developer Mode's DEV RECRUITS
## (dev_lab) previews (always), force-spawns (free, and only one never generated: he still costs
## PRICE to sign) and clears its own test data (reset_test_state: never a flag).

## The recruiting screen's roll, each one on his own: 1 in 1,000 a refresh (so about 1 in 500
## that one of the two shows up).
const ODDS := 1000
## The CPU programs' one central off-season roll (cpu_recruit): 1 in this many, each.
const CPU_ODDS := 2000
## His fixed price: past the ordinary prospects' Recruiting.ORDINARY_MAX, which never applies to him.
const PRICE := 200   # (the DEV Recruit Update: was 125; before the Recruiting Price Rebalance, 95)
## An unpinned one rotated out of your market by a refresh: the chance a CPU program signs him.
const PICKUP_CHANCE := 0.75
## His development profile (PoloPlayer.dev; an older save's "admin" is read as this).
const DEV_PROFILE := "dev_recruit"
const ORDER := ["blake", "logan"]
## Each one: who he is, and his four attributes now and their ceilings (pas, sho, str, dfn).
const DEFS := {
	"blake": {"first": "Blake", "last": "Duggan", "home": "San Antonio, Texas", "pos": PoloPlayer.Pos.DEFENDER,
		"role": "2-Meter Defender / Utility", "skin": 0, "speed": 60,
		"attrs": {"pas": 3.0, "sho": 2.0, "str": 8.0, "dfn": 15.0},
		"pot": {"pas": 4.0, "sho": 6.0, "str": 8.0, "dfn": 15.0}},
	"logan": {"first": "Logan", "last": "Baumann", "home": "Thousand Oaks, California", "pos": PoloPlayer.Pos.DRIVER,
		"role": "ATK", "skin": 0, "speed": 68,
		"attrs": {"pas": 6.0, "sho": 14.0, "str": 4.0, "dfn": 4.0},
		"pot": {"pas": 8.0, "sho": 14.0, "str": 5.0, "dfn": 5.0}},
}

## Each one's own cap number: on any roster he wears it, and whoever had it moves to the nearest
## free cap (fix_numbers). Not while PIXEL POLO + is unlocked: then caps are the coach's to edit.
const NUMBERS := {"blake": 11, "logan": 8}

## Each one's permanent generation flag in the save.
const FLAGS := {"blake": "blake_duggan_generated", "logan": "logan_baumann_generated"}

## Tests only: 1 in this many instead of ODDS (0: ODDS). The game never sets it.
static var test_odds := 0
## Tests only: rotate_out's chance instead of PICKUP_CHANCE (negative: PICKUP_CHANCE).
static var test_pickup := -1.0

static func is_dev(p: PoloPlayer) -> bool:
	return p != null and p.dev_recruit != ""

static func full_name(key: String) -> String:
	var d: Dictionary = DEFS.get(key, {})
	return ("%s %s" % [d.first, d.last]).to_upper() if not d.is_empty() else key.to_upper()

## His position as the dev cards and his profile spell it out ("2-Meter Defender / Utility").
static func role(p: PoloPlayer) -> String:
	return String(DEFS.get(p.dev_recruit, {}).get("role", p.pos_long())) if p != null else ""

# ------------------------------------------------------------------ cap numbers
## Are their caps fixed (NUMBERS)? Yes, unless PIXEL POLO + is unlocked.
static func numbers_locked() -> bool:
	return not Store.pro

## On `t`: each DEV Recruit wears his own cap (NUMBERS); a teammate who had it moves to the free cap
## nearest it (never a keeper's cap for a field player, never the other one's). Does nothing while
## PIXEL POLO + is unlocked.
static func fix_numbers(t: PoloTeam) -> void:
	if t == null or not numbers_locked():
		return
	var reserved := {}
	for p: PoloPlayer in t.roster:
		if NUMBERS.has(p.dev_recruit):
			reserved[int(NUMBERS[p.dev_recruit])] = true
	for p: PoloPlayer in t.roster:
		if not NUMBERS.has(p.dev_recruit) or p.number == int(NUMBERS[p.dev_recruit]):
			continue
		var n := int(NUMBERS[p.dev_recruit])
		p.number = n
		for q: PoloPlayer in t.roster:
			if q != p and q.number == n:
				q.number = _nearest_free(t, q, n, reserved)

static func _nearest_free(t: PoloTeam, q: PoloPlayer, n: int, reserved: Dictionary) -> int:
	var used := {}
	for o: PoloPlayer in t.roster:
		if o != q:
			used[o.number] = true
	for d in range(1, 99):
		for m in [n - d, n + d]:
			if m < PlayerEdit.NUMBER_RANGE.x or m > PlayerEdit.NUMBER_RANGE.y or used.has(m) or reserved.has(m):
				continue
			if (m in PlayerEdit.KEEPER_CAPS) != q.is_keeper():
				continue
			return m
	return t.free_number(q.is_keeper())

# ------------------------------------------------------------------ making him
## A fresh copy of `key` exactly as defined: a freshman prospect, no XP, no trait. `id` his
## career id (-1: a preview nobody owns).
static func make(key: String, id: int = -1) -> PoloPlayer:
	var d: Dictionary = DEFS[key]
	var p := PoloPlayer.new()
	p.dev_recruit = key
	p.first = String(d.first)
	p.last = String(d.last)
	p.pos = int(d.pos)
	p.lefty = false
	p.age = 18
	p.year = 1
	p.skin = int(d.skin)
	p.home = String(d.home)
	p.region = "US"
	p.speed = int(d.speed)
	p.keeping = 20
	p.dev = DEV_PROFILE
	p.id = id
	p.attrs = {}
	p.attr_pot = {}
	for k in Attributes.FIELD:
		p.attrs[k] = float(d.attrs[k])
		p.attr_pot[k] = float(d.pot[k])
	Attributes.sync(p)
	Development.ensure(p)
	p.star_base = snappedf(p.overall(), 0.0001)
	p.stars_locked = p.stars
	p.trait_id = ""
	if numbers_locked():
		p.number = int(NUMBERS.get(key, 0))
	return p

## His market record: the ordinary {p, price, legacy} with the fixed PRICE.
static func make_recruit(c: Career, key: String) -> Dictionary:
	return {"p": make(key, c.new_id()), "price": PRICE, "legacy": false}

# ------------------------------------------------------------------ where he is
## Where `key` is in this dynasty right now: "market", "incoming", "roster:<team id>", "pool",
## "commit:<team id>" (rotated out, signed by a CPU program, joining it with the class), or "".
static func where(c: Career, key: String) -> String:
	if c == null:
		return ""
	for r in c.market:
		if (r.p as PoloPlayer).dev_recruit == key:
			return "market"
	for r in c.incoming:
		if (r.p as PoloPlayer).dev_recruit == key:
			return "incoming"
	for id in c.teams:
		for p: PoloPlayer in (c.teams[id] as PoloTeam).roster:
			if p.dev_recruit == key:
				return "roster:%s" % id
	for e in c.cut_pool:
		if e.p != null and (e.p as PoloPlayer).dev_recruit == key:
			return "pool"
	for e in commits(c):
		if String(e.key) == key:
			return "commit:%s" % e.team
	return ""

static func state(c: Career) -> Dictionary:
	if not c.dev_recruits.has("log"):
		c.dev_recruits["log"] = []
	if not c.dev_recruits.has("signed"):
		c.dev_recruits["signed"] = []
	if not c.dev_recruits.has("generated"):
		c.dev_recruits["generated"] = {}
	if not c.dev_recruits.has("commits"):
		c.dev_recruits["commits"] = []
	return c.dev_recruits

## The CPU commitments made when one rotated out (rotate_out): [{key, team, p}].
static func commits(c: Career) -> Array:
	return c.dev_recruits.get("commits", []) if c != null else []

static func was_signed(c: Career, key: String) -> bool:
	return c != null and key in (c.dev_recruits.get("signed", []) as Array)

## Has `key` ever been made in this dynasty (his permanent flag).
static func generated(c: Career, key: String) -> bool:
	return c != null and bool((c.dev_recruits.get("generated", {}) as Dictionary).get(FLAGS.get(key, ""), false))

static func mark_generated(c: Career, key: String) -> void:
	(state(c).generated as Dictionary)[FLAGS[key]] = true

## Can `key` come up in this dynasty: never generated in it (and, for an older save, nowhere in it).
static func eligible(c: Career, key: String) -> bool:
	return DEFS.has(key) and not generated(c, key) and not was_signed(c, key) and where(c, key) == ""

## An older save (from before the flags): whoever is already somewhere in the dynasty, was signed
## or was logged is marked generated. Never clears one. (Career.from_dict)
static func migrate(c: Career) -> void:
	for key in ORDER:
		if generated(c, key):
			continue
		var logged := (state(c).log as Array).any(func(e): return String(e.key) == key)
		if where(c, key) != "" or was_signed(c, key) or logged:
			mark_generated(c, key)

## The school he's with now ("": none): your signed incoming recruits count as yours.
static func school_of(c: Career, key: String) -> String:
	var at := where(c, key)
	if at == "incoming":
		return c.school
	if at.begins_with("roster:") or at.begins_with("commit:"):
		return at.substr(7)
	return ""

## Developer Mode's generation status: NOT GENERATED, AVAILABLE — UNSIGNED, SIGNED — SCHOOL, or
## NO LONGER ACTIVE (graduated, gone unsigned, out of the game).
static func status(c: Career, key: String) -> String:
	if c == null or not generated(c, key):
		return "NOT GENERATED"
	var at := where(c, key)
	if at == "market" or at == "pool":
		return "AVAILABLE — UNSIGNED"
	var id := school_of(c, key)
	if id != "" and c.teams.has(id):
		return "SIGNED — %s" % Colleges.short_name(c.teams[id]).to_upper()
	return "NO LONGER ACTIVE"

## Why `key` can't be force-spawned, in words ("" if he can).
static func present_text(c: Career, key: String) -> String:
	var at := where(c, key)
	if at == "" and not was_signed(c, key) and not generated(c, key):
		return ""
	var now := "He is no longer active."
	if at == "market":
		now = "He is on the Recruiting Market."
	elif at == "incoming":
		now = "He is signed: he joins your roster next season."
	elif at.begins_with("roster:"):
		var id := at.substr(7)
		now = "He is on %s." % ("your roster" if id == c.school else "the %s roster" % Colleges.short_name(c.teams[id]))
	elif at == "pool":
		now = "He is in this off-season's transfer pool."
	elif at.begins_with("commit:"):
		var id := at.substr(7)
		now = "He has signed with %s and joins its roster next season." % (Colleges.short_name(c.teams[id]) if c.teams.has(id) else id)
	return "%s has already been generated in this dynasty. Each DEV Recruit is generated only once per save. %s" % [full_name(key), now]

# ------------------------------------------------------------------ spawning
## The market's refresh roll (Recruiting.new_market): each eligible one, independently, 1 in ODDS.
## Returns the keys that came up (and are on the market now).
static func roll(c: Career) -> Array:
	var out: Array = []
	var odds := test_odds if test_odds > 0 else ODDS
	for key in ORDER:
		if not eligible(c, key):
			continue
		if hit(c, key, odds) and not place(c, key, "roll").is_empty():
			out.append(key)
	return out

## This refresh's die for `key`: 1 in `odds`, its own (seeded from where the career is, never
## drawing from its dice, so the ordinary prospects are made exactly as without it).
static func hit(c: Career, key: String, odds: int = ODDS) -> bool:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([str(c.rng.state), c.year, c.week, c.refreshes, key, "admin"])
	return dice.randf() < 1.0 / float(maxi(1, odds))

## Puts `key` on the market in an ordinary prospect's place (the last unpinned one that isn't an
## DEV Recruit), or in an empty place if the market is short. Logs it. Returns his record, or {}
## with no place for him.
static func place(c: Career, key: String, how: String) -> Dictionary:
	var at := -1
	for i in range(c.market.size() - 1, -1, -1):
		var r: Dictionary = c.market[i]
		if not Recruiting.is_pinned(r) and (r.p as PoloPlayer).dev_recruit == "":
			at = i
			break
	var short := c.market.size() < Recruiting.MARKET_SIZE
	if at < 0 and not short:
		return {}
	var rec := make_recruit(c, key)
	mark_generated(c, key)   # (for good, the moment he exists)
	var entry := {"key": key, "how": how, "year": c.year, "pid": (rec.p as PoloPlayer).id}
	if short:
		c.market.append(rec)
	else:
		if how == "forced":
			entry["swapped"] = Recruiting.to_save([c.market[at]])[0]   # (reset_test_state puts him back)
		c.market[at] = rec
	(state(c).log as Array).append(entry)
	return rec

## Developer Mode's FORCE SPAWN: `key` onto the current market, no roll and free (signing him still
## costs PRICE). Never a second copy, never the whole market remade. Returns "" or why not.
static func force_spawn(c: Career, key: String) -> String:
	if c == null:
		return "Load a career first: he joins its Recruiting Market."
	if not DEFS.has(key):
		return "No such DEV Recruit."
	var dup := present_text(c, key)
	if dup != "":
		return dup
	if c.phase == "cuts":
		return "The market opens again with the new season."
	if place(c, key, "forced").is_empty():
		return "Every place on the market is pinned: unpin a recruit first."
	return ""

# ------------------------------------------------------------------ the CPU programs
## The recruiting class closes (Offseason._ai_rosters, before the AI programs' freshmen): the CPU
## programs' one central roll (each not yet generated: 1 in CPU_ODDS, once for all of them), then
## everyone in the pool, the unsigned DEV Recruits on the market and that roll's, signs with a CPU
## school (sign_cpu). Returns news lines.
static func cpu_recruit(c: Career) -> Array:
	var lines: Array = []
	# the ones who signed with a CPU program when they rotated out join it now (the same player); a
	# program with no place left for him after all: another with room, as any unsigned one
	for e in commits(c).duplicate():
		var p: PoloPlayer = e.p
		commits(c).erase(e)
		var id := String(e.team)
		if c.teams.has(id) and id != c.school and Offseason.has_place(c, c.teams[id], p):
			_join_cpu(c, c.teams[id], p)
		else:
			id = sign_cpu(c, p)
		if id != "":
			lines.append("%s (DEV RECRUIT) joins %s" % [p.short_name(), Colleges.short_name(c.teams[id])])
	var pool: Array = []
	for r in c.market.duplicate():
		if (r.p as PoloPlayer).dev_recruit != "":
			c.market.erase(r)
			pool.append(r.p)
	var odds := test_odds if test_odds > 0 else CPU_ODDS
	for key in ORDER:
		if eligible(c, key) and cpu_hit(c, key, odds):
			var p := make(key, c.new_id())
			mark_generated(c, key)
			(state(c).log as Array).append({"key": key, "how": "cpu", "year": c.year, "pid": p.id})
			pool.append(p)
	for p: PoloPlayer in pool:
		var id := sign_cpu(c, p)
		if id != "":
			lines.append("%s (DEV RECRUIT) signs with %s" % [p.short_name(), Colleges.short_name(c.teams[id])])
	return lines

## The CPU pool's die this off-season (its own, as hit's).
static func cpu_hit(c: Career, key: String, odds: int = CPU_ODDS) -> bool:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([str(c.rng.state), c.year, key, "admin_cpu"])
	return dice.randf() < 1.0 / float(maxi(1, odds))

## `p` (the same player, never a copy) signs with one CPU school that has a place for him: chosen
## by chance, each school weighted by what he's worth to it (Offseason.pickup_value, never below a
## small floor, so it's never simply the top program). Returns its id ("" if none had room).
static func sign_cpu(c: Career, p: PoloPlayer) -> String:
	var ids: Array = c.teams.keys().filter(func(id): return id != c.school and Offseason.has_place(c, c.teams[id], p))
	ids.sort()
	if ids.is_empty():
		return ""
	var weights: Array = ids.map(func(id): return maxf(0.05, Offseason.pickup_value(c, c.teams[id], p)))
	var total := 0.0
	for w in weights:
		total += float(w)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([c.year, p.id, p.dev_recruit, "admin_sign"])
	var x := dice.randf() * total
	var pick: String = ids[ids.size() - 1]
	for i in ids.size():
		x -= float(weights[i])
		if x < 0.0:
			pick = ids[i]
			break
	_join_cpu(c, c.teams[pick], p)
	return pick

## `p` joins CPU program `t` as a freshman (a scholarship if it has one left).
static func _join_cpu(c: Career, t: PoloTeam, p: PoloPlayer) -> void:
	p.year = 1
	p.schol = t.roster.filter(func(q: PoloPlayer): return q.schol).size() < Career.SCHOL_MAX
	Offseason.join(c, t, p)

## The CPU program `p` commits to when he rotates out: chosen by chance, each weighted by what he's
## worth to it (Offseason.pickup_value: its need at his position, his attributes and potential;
## never below a small floor), never your school. Programs with a place for him now are preferred
## (none has one: every CPU program). The dice are his own. "" if there's no CPU program at all.
static func pick_cpu(c: Career, p: PoloPlayer, salt: String) -> String:
	var all: Array = c.teams.keys().filter(func(id): return id != c.school)
	var ids: Array = all.filter(func(id): return Offseason.has_place(c, c.teams[id], p))
	if ids.is_empty():
		ids = all
	ids.sort()
	if ids.is_empty():
		return ""
	var weights: Array = ids.map(func(id): return maxf(0.05, Offseason.pickup_value(c, c.teams[id], p)))
	var total := 0.0
	for w in weights:
		total += float(w)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([c.year, p.id, p.dev_recruit, salt])
	var x := dice.randf() * total
	for i in ids.size():
		x -= float(weights[i])
		if x < 0.0:
			return ids[i]
	return ids[ids.size() - 1]

# ------------------------------------------------------------------ rotated out
## A refresh took `r`, an unsigned, unpinned DEV Recruit, off your market (Recruiting.new_market):
## his one roll. PICKUP_CHANCE: a CPU program signs him (pick_cpu; the same player, never a copy),
## committed to it until he joins its roster with the class (cpu_recruit), and the news says so.
## Otherwise he leaves recruiting unsigned, for good (his flag keeps him from ever coming back).
## Logged either way. Returns the CPU program's id ("" unsigned). Nothing else calls it: opening the
## market, a pin, a preview, saving or loading never rolls.
static func rotate_out(c: Career, r: Dictionary) -> String:
	var p: PoloPlayer = r.get("p")
	if p == null or p.dev_recruit == "" or r in c.market or where(c, p.dev_recruit) != "":
		return ""   # (not one, still on the market, or already somewhere: no roll)
	if (state(c).log as Array).any(func(e): return String(e.get("how", "")) == "rotated" and int(e.get("pid", -1)) == p.id):
		return ""   # (his one roll is spent: never a second)
	var id := pick_cpu(c, p, "dev_rotate_school") if pickup_hit(c, p) else ""
	var entry := {"key": p.dev_recruit, "how": "rotated", "year": c.year, "pid": p.id, "outcome": "cpu" if id != "" else "unsigned"}
	if id != "":
		entry["team"] = id
		(state(c).commits as Array).append({"key": p.dev_recruit, "team": id, "p": p})
		c.add_news("DEV RECRUIT SIGNED: %s %s has committed to %s!" % [p.first, p.last, Colleges.short_name(c.teams[id])])
	(state(c).log as Array).append(entry)
	return id

## rotate_out's die for `p` at this refresh: PICKUP_CHANCE (test_pickup in the tests), its own
## (seeded from where the career is, never drawing from its dice).
static func pickup_hit(c: Career, p: PoloPlayer) -> bool:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([str(c.rng.state), c.year, c.week, c.refreshes, p.id, p.dev_recruit, "dev_rotate"])
	return dice.randf() < (test_pickup if test_pickup >= 0.0 else PICKUP_CHANCE)

## SIGN RECRUIT took him (Recruiting.sign): never again in this dynasty.
static func on_signed(c: Career, p: PoloPlayer) -> void:
	if p == null or p.dev_recruit == "":
		return
	var signed: Array = state(c).signed
	if not p.dev_recruit in signed:
		signed.append(p.dev_recruit)

# ------------------------------------------------------------------ Developer Mode
## RESET DEV RECRUIT TEST STATE: only what force-spawning left behind. A force-spawned recruit
## still unsigned on the market goes, and the prospect he replaced comes back as he was; a forced
## spawn's log entry goes once its recruit is off the market unsigned. A signed one, a natural
## spawn and everything else (rosters, history, the rest of the market) stay exactly as they are.
## Returns what it did, line by line.
static func reset_test_state(c: Career) -> Array:
	var lines: Array = []
	if c == null:
		return ["No career is loaded: there's nothing to reset."]
	var st := state(c)
	var keep: Array = []
	for e in st.log:
		var key := String(e.get("key", ""))
		var who := full_name(key)
		if String(e.get("how", "")) != "forced":
			keep.append(e)
			continue
		var at := where(c, key)
		var pid := int(e.get("pid", -1))
		if at == "market":
			var i := -1
			for j in c.market.size():
				if (c.market[j].p as PoloPlayer).id == pid:
					i = j
			if i < 0:
				keep.append(e)
				lines.append("%s: on the market from another spawn, left as is." % who)
				continue
			var back: Array = Recruiting.from_save([e.swapped]) if e.get("swapped") is Dictionary else []
			if not back.is_empty() and Recruiting.find(c, (back[0].p as PoloPlayer).id).is_empty():
				c.market[i] = back[0]
				lines.append("%s removed from the market; the recruit he replaced is back." % who)
			else:
				c.market.remove_at(i)
				lines.append("%s removed from the market." % who)
		elif at != "" or was_signed(c, key):
			keep.append(e)
			lines.append("%s is signed or on a roster: signed players are never removed, so he stays." % who)
		else:
			keep.append(e)
			lines.append("%s is no longer active." % who)
	st.log = keep
	if lines.is_empty():
		lines.append("No DEV Recruit test data to clear.")
	if ORDER.any(func(k): return generated(c, k)):
		lines.append("Generation is permanent: a DEV Recruit already generated in this dynasty is never generated again.")
	if st.log.any(func(e): return String(e.get("how", "")) == "roll"):
		lines.append("Natural spawns are part of this dynasty's history and are kept.")
	return lines

# ------------------------------------------------------------------ saving
## Always the same shape and order (from_save's), so a save loads and saves again byte for byte.
static func to_save(d: Dictionary) -> Dictionary:
	var v := d.duplicate(true)
	v["commits"] = (d.get("commits", []) as Array).map(func(e): return {"key": e.key, "team": e.team,
		"p": (e.p as PoloPlayer).to_dict() if e.p is PoloPlayer else e.p})
	var out := from_save(v)
	out.commits = (out.commits as Array).map(func(e): return {"key": e.key, "team": e.team, "p": (e.p as PoloPlayer).to_dict()})
	return out

## A saved state, checked: only known keys, whole numbers whole. An older save: {}.
static func from_save(v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {}
	var out := {"log": [], "signed": [], "generated": {}, "commits": []}
	if v.get("generated") is Dictionary:
		for k in ORDER:
			if bool(v.generated.get(FLAGS[k], false)):
				out.generated[FLAGS[k]] = true
	for e in (v.get("log", []) if v.get("log") is Array else []):
		if e is Dictionary and DEFS.has(String(e.get("key", ""))):
			var x := {"key": String(e.key), "how": String(e.get("how", "roll")), "year": int(e.get("year", 0)), "pid": int(e.get("pid", -1))}
			if e.get("swapped") is Dictionary:
				x["swapped"] = e.swapped
			if e.has("outcome"):
				x["outcome"] = String(e.outcome)
			if e.has("team"):
				x["team"] = String(e.team)
			out.log.append(x)
	for k in (v.get("signed", []) if v.get("signed") is Array else []):
		if DEFS.has(String(k)) and not String(k) in out.signed:
			out.signed.append(String(k))
	for e in (v.get("commits", []) if v.get("commits") is Array else []):
		if not e is Dictionary or not DEFS.has(String(e.get("key", ""))):
			continue
		var p: Variant = e.get("p")
		if p is Dictionary:
			p = PoloPlayer.from_dict(p)
		if p is PoloPlayer and not out.commits.any(func(x): return x.key == String(e.key)):
			out.commits.append({"key": String(e.key), "team": String(e.get("team", "")), "p": p})
	return out
