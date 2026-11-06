class_name League
## The fictional clubs and seeded roster generation. All names are invented.

const CLUBS := [
	{"id": "ADR", "name": "Adriatic Orcas", "c1": "1d3b7a", "c2": "f2f2e9", "str": 72},
	{"id": "DAN", "name": "Danube Pike", "c1": "2e7d32", "c2": "f2f2e9", "str": 68},
	{"id": "AEG", "name": "Aegean Tritons", "c1": "00796b", "c2": "ffcf3f", "str": 65},
	{"id": "RIV", "name": "Riviera Marlins", "c1": "0d47a1", "c2": "ffcf3f", "str": 62},
	{"id": "BAL", "name": "Baltic Otters", "c1": "4a148c", "c2": "f2f2e9", "str": 58},
	{"id": "HAR", "name": "Harbor Seals", "c1": "37474f", "c2": "39c2ff", "str": 55},
	{"id": "PAC", "name": "Pacific Breakers", "c1": "e65100", "c2": "1a1206", "str": 52},
	{"id": "ALP", "name": "Alpine Lakers", "c1": "212121", "c2": "ffcf3f", "str": 48},
]

const FIRST := ["Luka", "Marko", "Nikola", "Stefan", "Filip", "Petar", "Ivan", "Dusan", "Milos",
	"Andrija", "Vuk", "Ognjen", "Bence", "Mate", "Adam", "Gergo", "Marco", "Luca", "Matteo",
	"Pablo", "Alvaro", "Sergi", "Kostas", "Nikos", "Dimitris", "Ben", "Max", "Ryan", "Jake",
	"Tomas", "Viktor", "Zoltan", "Dario", "Ante", "Josip", "Lovro", "Emil", "Oscar", "Hugo", "Leo"]
const LAST := ["Novak", "Horvat", "Kovac", "Babic", "Maric", "Petrov", "Ilic", "Pavlov", "Radic",
	"Kiss", "Toth", "Szabo", "Varga", "Molnar", "Rossi", "Bianchi", "Greco", "Conti", "Ferri",
	"Garcia", "Lopez", "Moreno", "Navarro", "Georgiou", "Karras", "Doukas", "Walker", "Hayes",
	"Brooks", "Keller", "Weber", "Berg", "Lind", "Duval", "Moreau", "Vidal", "Sokol", "Zeller",
	"Barros", "Castel", "Dragan", "Lukic", "Obrad", "Terzic", "Varda", "Hollo", "Palmer", "Reyes"]

const ROSTER_POS := [
	PoloPlayer.Pos.GK, PoloPlayer.Pos.GK, PoloPlayer.Pos.CENTER, PoloPlayer.Pos.CENTER,
	PoloPlayer.Pos.DRIVER, PoloPlayer.Pos.DRIVER, PoloPlayer.Pos.DRIVER, PoloPlayer.Pos.WING,
	PoloPlayer.Pos.WING, PoloPlayer.Pos.UTILITY, PoloPlayer.Pos.UTILITY,
	PoloPlayer.Pos.DEFENDER, PoloPlayer.Pos.DEFENDER,
]

static func club_count() -> int:
	return CLUBS.size()

static func make_team(index: int, seed_value: int = 0) -> PoloTeam:
	var info: Dictionary = CLUBS[index]
	var t := PoloTeam.new()
	t.id = info.id
	t.name = info.name
	t.c1 = Color(info.c1)
	t.c2 = Color(info.c2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(info.id) + seed_value
	var used := {}
	var numbers := [1, 13, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
	for i in ROSTER_POS.size():
		var p := _make_player(ROSTER_POS[i], float(info.str), rng, used)
		p.number = numbers[i]
		# a hometown from his own dice (the club's draws stay as they were)
		var hr := RandomNumberGenerator.new()
		hr.seed = hash([info.id, seed_value, i, "home"])
		p.home = Hometowns.pick(hr)
		# an id of his own, unique across the clubs: a match counts personal fouls by id
		# (MatchState.pf), and with every club player at 0 they all landed on one man
		p.id = (index + 1) * 100 + i + 1
		t.roster.append(p)
	# every club has a lefty (an attacker, LFTY) on the right side of the attack
	for p in t.roster:
		if p.pos == PoloPlayer.Pos.DRIVER:
			p.lefty = true
			break
	for p in t.roster:
		# his four attributes, from the ratings he was made with; a club rated above the college
		# scale keeps those ratings and the traits they earned (PoloPlayer.pro)
		p.pro = true
		PlayerForm.rate_new(p)
		p.trait_id = Traits.best_for(p)
	return t

## Every player is a star, a starter or a role player. Stars stand out everywhere; role
## players are specialists, strong at their position's main skill and weaker at the rest.
const TIERS := [[0.12, 11.0], [0.38, 2.0], [0.50, -5.0]]   # [share, rating offset]
const ROLE_MAIN := 6.0
const ROLE_REST := -3.0
## What each position is good at (and not), on top of the player's level.
const POS_PROFILE := {
	PoloPlayer.Pos.GK: {"keeping": 4.0, "shoot": -30.0},
	PoloPlayer.Pos.CENTER: {"strength": 14.0, "speed": -10.0},
	PoloPlayer.Pos.DRIVER: {"speed": 12.0, "shoot": 4.0},
	PoloPlayer.Pos.WING: {"shoot": 12.0, "strength": -8.0},
	PoloPlayer.Pos.UTILITY: {"passing": 10.0, "defense": 5.0},
	PoloPlayer.Pos.DEFENDER: {"defense": 14.0, "strength": 9.0, "shoot": -10.0},
}
## Each position's main skill (by PoloPlayer.Pos).
const MAIN_RATING := ["keeping", "strength", "speed", "shoot", "passing", "defense"]

static func _make_player(pos: int, strength: float, rng: RandomNumberGenerator, used: Dictionary) -> PoloPlayer:
	var p := PoloPlayer.new()
	p.pos = pos
	var name := ""
	for _i in 20:
		p.first = FIRST[rng.randi() % FIRST.size()]
		p.last = LAST[rng.randi() % LAST.size()]
		name = p.last
		if not used.has(name):
			break
	used[name] = true
	p.age = rng.randi_range(19, 33)
	p.skin = PoloPlayer.random_skin(rng)   # (one draw, as the old even pick was: nothing after it moves)
	var roll := rng.randf()
	var tier := TIERS.size() - 1
	for i in TIERS.size():
		roll -= float(TIERS[i][0])
		if roll < 0.0:
			tier = i
			break
	var role := tier == TIERS.size() - 1
	var base := strength + float(TIERS[tier][1]) + rng.randf_range(-5.0, 5.0)
	var profile: Dictionary = POS_PROFILE[pos]
	var main: String = MAIN_RATING[pos]
	var keys := ["shoot", "passing", "speed", "strength", "defense"]
	if pos == PoloPlayer.Pos.GK:
		keys.append("keeping")
	for k in keys:
		var bias := float(profile.get(k, 0.0))
		if k in ["strength", "defense"] and not profile.has(k):
			bias -= 4.0
		if role:
			bias += ROLE_MAIN if k == main else ROLE_REST
		p.set(k, clampi(roundi(base + bias + rng.randf_range(-6.0, 6.0)), 20, 99))
	return p
