extends "res://src/ui/screens/roster.gd"
## Developer Mode's VIEW IN ROSTER (DEV RECRUITS > a DEV Recruit > ROSTER PREVIEW): the real Roster
## screen (roster.gd, its read-only scouting path: the same board, the same cards, nothing to drag)
## showing a COPY of your team (PoloTeam.from_dict of its save record) with a fresh copy of the DEV
## Recruit (DevRecruits.make) in the starting place he fits best, taking that man's place and cap
## number, so he sits among ordinary players exactly as his card would. With no career loaded, a
## League club stands in. The copy lives on this screen only: your roster, lineup, recruiting,
## ownership and save are never touched. His card opens his DEV PREVIEW profile; anyone else's
## does nothing (they're copies).

const DEV_ID := 990001          # the preview copy's id: nobody's (well clear of every career id)

var dev_key := "blake"
var preview_team: PoloTeam = null
var dev_spot := -1             # the lineup place he took

func setup(params: Dictionary) -> void:
	dev_key = String(params.get("key", "blake"))
	if not DevRecruits.DEFS.has(dev_key):
		dev_key = "blake"

func scouted() -> PoloTeam:
	return preview_team

func _ready() -> void:
	var made := make_preview(Game.career, dev_key)
	preview_team = made.team
	dev_spot = int(made.spot)
	scout_team = preview_team
	scout_lineup = preview_team.lineup.duplicate()
	back_target = "dev_lab"
	build_compact("VIEW IN ROSTER  %s" % String(DevRecruits.DEFS[dev_key].last).to_upper())
	_render()

func on_back() -> void:
	Sfx.play("back")
	Game.goto("dev_lab", {"keep": true}, false)

## {team: a copy of `car`'s team (or a League club with no career) with DEV Recruit `key` put in
## the starting place he fits best, spot: that place}. Never `car`'s own team or players.
static func make_preview(car: Career, key: String) -> Dictionary:
	var t: PoloTeam
	if car != null and car.team() != null:
		t = PoloTeam.from_dict(car.team().to_dict())
	else:
		t = League.make_team(2, 1)
	if not t.has_lineup():
		t.lineup = _drafted(t)
	var p := DevRecruits.make(key, DEV_ID)
	var spot := -1
	for rank in [0, 1]:
		for i in PoloTeam.STARTERS:
			if spot == -1 and PoloTeam.fit_rank(p, i) <= rank:
				spot = i
	if spot == -1:
		spot = 1
	var old := t.find_id(int(t.lineup[spot]))
	p.number = old.number if old != null else t.free_number(false)
	if old != null:
		t.roster[t.roster.find(old)] = p
	else:
		t.roster.append(p)
	t.lineup[spot] = p.id
	DevRecruits.fix_numbers(t)
	return {"team": t, "spot": spot, "p": p}

## His card: his DEV PREVIEW profile. The others are copies: nothing to open.
func _open(pid: int, _ids: Array) -> void:
	if pid == DEV_ID:
		Sfx.play("click")
		Game.goto("player", {"dev_preview": dev_key})
	else:
		Game.toast("READ-ONLY PREVIEW", UI.DIM)

## The two places beside the keeper: what this is, in place of a scouted team's details.
func _scout_head(on: Control, _t: PoloTeam) -> void:
	var y := LABEL_H + 2.0 * (CARD.y + ROW_GAP)
	var note := UI.canvas(int(CARD.x), int(CARD.y), func(ci: Control):
		_head_panel(ci)
		Deck.text(ci, 5, 9, "DEV PREVIEW", 8, DevArt.CYAN)
		Deck.text(ci, 5, 22, "READ ONLY", 8, UI.TEXT)
		Deck.text(ci, 5, 33, "A COPY OF", 8, UI.DIM)
		Deck.text(ci, 5, 43, "YOUR TEAM", 8, UI.DIM)
		Deck.text(ci, 5, 55, "NOTHING SAVED", 8, UI.GOLD))
	note.name = "PreviewNote"
	note.position = Vector2(0, y)
	on.add_child(note)
	var who := UI.canvas(int(CARD.x), int(CARD.y), func(ci: Control):
		_head_panel(ci)
		Deck.text(ci, 5, 9, DevRecruits.full_name(dev_key).split(" ")[0], 8, DevArt.CYAN)
		Deck.text(ci, 5, 18, DevRecruits.full_name(dev_key).split(" ")[1], 8, DevArt.CYAN)
		_head_kv(ci, 31, "PLACE", team().slot_name(dev_spot) if dev_spot >= 0 else "-")
		_head_kv(ci, 41, "REPLACES", "A COPY")
		_head_kv(ci, 51, "ROSTER", "UNCHANGED"))
	who.name = "PreviewWho"
	who.position = Vector2(2.0 * (CARD.x + GAP), y)
	on.add_child(who)
