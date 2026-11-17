class_name Play
extends RefCounted
## One attacking possession. Pure logic in metres, always attacking the goal at x = 30:
## Side.US is the attacking team. MatchScreen draws it and feeds touch input, tests drive it
## with PlayBot.
##
## Your attack: you decide when and where to pass and shoot; everything else (drives,
## marking, fouls, exclusions, the keeper) runs by itself. Their attack (`defending`): their
## throws come from PlayBot, the AI plays your defenders too, and you are the keeper (see
## PlayDefense).

enum Kind { HALF_COURT, COUNTER, PENALTY }

const SHOT_CLOCK := 30.0
const MAN_UP_TIME := 20.0
const PASS_SPEED := 14.0
const ASSIST_R := 2.0          # aim this close to a teammate and the pass finds him
const WALL_BONUS := 6.0        # a WALL keeper plays this much better
const PLAYMAKER_PASS := 1.15   # a PLAYMAKER's passes are this much faster...
                              # ...and harder to pick off (DefenseFormation.tip_chance: +1.5 Passing)
const HAWK_REACH := 0.15       # a BALL HAWK reaches this much further for a pass...
const HAWK_PICK := 1.5         # ...and picks it off this much more often
const WRESTLER_EDGE := 0.1     # a WRESTLER center draws (or his guard concedes) exclusions this much more
## Your play call (DRIVE▾): who drives on each side, first choice first. "left" is the
## attack's left, the top of the screen; "right" the bottom; "middle" the point, so it's off
## while he has the ball.
const DRIVE_CALLS := {"left": ["4", "5"], "middle": ["3"], "right": ["2", "1"]}
const CALLED_DRIVE := 2.6      # seconds a called drive lasts
const CALLED_BURST := 1.0      # ...the first of them flat out, with his marker a step slow
const MIN_PASS := 1.0          # a tap this close to the man with the ball is no pass
const CATCH_R := 1.1
const PICKUP_R := 0.55
const SHOT_ZONE_X := 29.0     # aim past this line and the throw is a shot
const SHOT_WIDE := 0.9        # ...crossing the goal line up to this far past a post, a shot (wide or in)
const PRESSURE_R := 1.15
## Steals are the exception, not the rule. A pass is only at risk from a defender close to its
## line (INTERCEPT_LINE: right through him is the full chance, at the edge of his reach a
## fraction of it; the chance and what comes of it are DefenseFormation's tips). The man on the
## ball strips it only from in front of him, rarely, unless the holder dawdles under pressure
## (past PRESS_DAWDLE seconds it climbs).
## A SWING on the power play (swing_pass): a pass across the top or round the 4-2 from a perimeter
## man to another, SWING_MIN or more across the pool. It's a safe way to move a man-down defence,
## so it's stolen only by somebody really contesting it, the same for both teams: no bonus for your
## defence (_steal_edge). The keeper takes it only if it's thrown right at him (SWING_KEEPER_R, and
## SWING_KEEPER at dead centre, the passer's Passing moving it): he doesn't get the flat claim a
## ball through his box gets just for going near him. A defender who wasn't in the lane when it
## left the hand (swing_lane) is reaching for it late: SWING_LATE of his chance. One who was has
## seen it coming with his hands up: SWING_REACH_Z high (over him it isn't), SWING_CONTEST his chance.
const SWING_MIN := 3.0
const SWING_KEEPER := 0.35
const SWING_KEEPER_PASS := 0.04
const SWING_KEEPER_R := 0.55
const SWING_LATE := 0.4
const SWING_REACH_Z := 1.6
const SWING_CONTEST := 1.3
const KEEPER_CLAIM := 0.8      # any other pass he gets a hand to
const INTERCEPT_LINE := 0.15   # within this of the pass's line it's going right through him
const INTERCEPT_EDGE := 0.2    # ...at the edge of his reach, this share of the chance
const STRIP_RATE := 0.006      # per second, pressed from in front
const STRIP_SKILL := 0.025     # ...plus this per point of defence over passing (/100)
const PRESS_DAWDLE := 3.0
const DAWDLE_RATE := 0.04      # ...plus this per second held past PRESS_DAWDLE
## Your defence (their attack, `defending`) is all AI, and it steals this many times as often
## as theirs: it stands in for the steals you'd make yourself, so a stop still comes along.
const YOUR_DEFENCE_STEALS := 2.0
const LOOSE_GIVE_UP := 5.0
const BLOCK_SKIP := 0.25      # a blocked shot skips off the hand: nobody gathers it this soon
const BLOCK_SHOW := 0.15      # a blocker's arm stays up this long after the ball is past him
const BOT_SHOT_SPEED := 13.0  # the bots judge a blocker in the lane against a shot this fast
## The man on the ball only gets to block a shot once he's pressed the shooter, unbroken, for
## GUARD_TIME: within GUARD_R and not behind him. Catch and shoot and he can't get a hand up
## (the help, in the lane, still can). The centre's guard is wrestling him all along: no wait.
const GUARD_R := 1.6
const GUARD_TIME := 2.0
const ON_BALL_R := 3.0        # his marker further off than this isn't guarding him at all
## The man guarding the centre doesn't block shots (he's wrestling the centre, not watching the
## ball). Switched off for now; true puts him back in the lane like everybody else. (In front of the
## shooter he still smothers the chance: close_chance, contact_on.)
const CENTER_DEFENDER_BLOCKS := false
## The 2 m spot: the centre shooting from within this of it gets ShotModel's power shot.
const CENTER_SPOT_R := 2.0
## Counterattacks. The carrier swims it in to COUNTER_STOP from the goal (shooting on the way if
## it's on), then the attack sets up: he rotates out to the perimeter and everybody takes their
## spot. The break also ends once the defence has numbers back (BREAK_CHECK), or after COUNTER_MAX.
const COUNTER_STOP := 3.0
const COUNTER_MAX := 9.0
const BREAK_CHECK := 0.5
const BREAK_TRAIL := 1.5      # an attacker this far behind the ball is still in the break
const BREAK_BACK := 1.5       # a defender this far behind the ball (alongside him) or goal side of it is back
const BREAK_FRONT := 3        # a break is counted by its front: at most this many attackers (the rest trail)
## While the counter's on (carry), every attacking field player swimming forward in it goes this much
## faster than he would in a settled possession (Swimmer.surge, on top of his own boost and pace).
const COUNTER_SURGE := 1.25
## THEIR counter (OffenseAI, attacking you): no ball back while any of their field players is still
## in his own half. A pass is "back" when it lands more than this behind the man throwing it
## (along the attack: x, in the possession's frame); square and forward balls are fine.
const BACK_PASS_SLACK := 0.5
## The breakout: the ball changed hands in live play, and while the result banner is up the
## team that won it turns and swims at the other goal (fanning into lanes) and the team that lost
## it turns and gets back (PlayAI._breakout). Then the next possession picks up: a counter if the
## numbers make one, otherwise the normal set-up. Never on a penalty.
const BREAKOUT_OUTCOMES := ["steal", "turnover", "save", "miss", "shotclock"]
const BREAKOUT_LOSER_TURN := 0.4   # the man who lost it turns this much later than the rest
## Feeding the centre (center_entry). What decides it is where his guard actually is against the
## line the pass comes in on: standing in that lane on the ball side of the centre (within
## ENTRY_LANE_R of it), he's fronting the entry and the pass is his, every time (_entry_stolen):
## nothing goes through him. Off the lane (behind the centre, goal side, or beside him with the
## ball coming from the other side) the centre has it. So swing it round to an angle he isn't on.
const CENTER_GUARD_R := 1.6    # a guard further off than this isn't on him at all
const CENTER_HOLD_Y := 0.35    # ...and one less than this across from him is behind him: no side
const ENTRY_LANE_R := 0.5      # the guard this close to the line of the entry is in the lane
## The first pass of a possession, in to the centre, straight through his guard (_first_entry_plan):
## a man properly set on him (ball side of him, within FIRST_GUARD_R, not on his way round) who the
## ball actually passes within his reach (DefenseFormation.TIP_REACH across, FIRST_REACH_Z up: a set
## man rising out of the water, more with Defense) with time to see it (FIRST_REACT) never lets it
## through: he takes it (FIRST_CLEAN: square through him and a good defender holds it) or knocks it
## loose. Only the first pass: once it's been thrown (caught, picked off, knocked loose and won back)
## the rest are the ordinary pick-offs and the fronting rule (_entry_stolen). Around him, over him,
## or with him out of position, it's a normal ball. Only the centre's own man: never the keeper.
const FIRST_GUARD_R := 1.9
const FIRST_REACH_Z := Vector2(1.4, 1.65)   # m up, Defense 0 .. 10
const FIRST_REACT := Vector2(0.2, 0.1)      # s he needs to get a hand there, Defense 0 .. 10
const FIRST_CLEAN := Vector3(0.25, 0.5, 0.4) # clean pick: base, + squarely through him, +- his Defense off 5
## FEEDING THE CENTRE AGAINST A DROP (_drop_entry_plan): decided as it's thrown, from where they
## are, instead of a guaranteed first-pass steal. `control` is how much of the lane the dropper owns
## (all of it within DROP_LINE of the line, nothing past his reach and DROP_ARM more: he's set and
## facing it, with an arm to stretch; DROP_UNSET of that if he's still on his way to his
## spot). DROP_FULL or more: he has it, it's a steal or
## knocked loose, however good the ball. Below that it's a contest: DROP_BLOCK of his control, less
## for a good ball (DROP_PER_QUALITY: Passing, and how true it's thrown) and a centre with
## separation (DROP_PER_SEP: his Strength against the dropper's Defense, and the water
## between them). A ball that gets through a contested lane is a catch, or DROP_FOUL of the time an
## ordinary foul on the catch, from the dropper in front of him, Strength shifting it; through a
## free lane it's just a catch. Swing the ball and he has to move: that's the way in.
const DROP_FULL := 0.9
const DROP_LINE := 0.2
const DROP_ARM := 0.25
const DROP_UNSET := 0.55
const DROP_BLOCK := 0.8
const DROP_PER_QUALITY := 0.6
const DROP_PER_SEP := 0.4
const DROP_BLOCK_RANGE := Vector2(0.1, 0.9)
const DROP_CLEAN := 0.45       # of the balls he stops, this many are clean (more with Defense)
const DROP_FOUL := 0.3
const DROP_FOUL_EDGE := 0.04   # ...a point of the centre's Strength over the dropper's Defense
## CALLING A DROP: the man with the ball is fouled first, an ordinary foul, by the defender who's
## on him (DROP_FOUL_R, never from where a foul would be a penalty), and the drop forms in that
## stoppage: everybody swims for it at their normal speed through DROP_FOUL_FREEZE (a little longer
## than a foul's usual 0.7 s), a head start on the free throw. A call while the whistle's
## already gone needs no second foul. One call, one foul; the formation's lock stops the rest.
const DROP_FOUL_R := 1.4
const DROP_FOUL_FREEZE := 1.5
const DROP_CATCH_WAIT := 0.25  # he's had it this long: nobody's fouled in the same frame he catches it
## The centre who caught a real entry (center_fed) is held by his beaten man: an exclusion this
## often (a WRESTLER either side shifting it), whistled CENTER_FOUL_T after the catch (as he turns
## with it: before anybody can get up to shoot) while he still has the ball down (_center_hold_foul).
## Up to shoot (or rid of it) before the whistle and it's just a shot: nothing that happens on or
## after a shot is ever an exclusion.
const CENTER_EXCL := 0.8
const CENTER_FOUL_T := 0.1
## The centre still swimming in (a counter, the swim-in: not on his spot yet) with his man on his
## back (PlayAI._center_trail), between him and the ball, within TRAIL_CONTEST_R: a ball in to
## him is "trailed" (center_entry), and his man gets a hand to it this often at full contact
## (TRAIL_PICK, less the further off him he is: nothing at TRAIL_CONTEST_R), his defence against
## the centre's strength shifting it. Get a step on him and it's his.
const TRAIL_CONTEST_R := 1.3
const TRAIL_PICK := 0.55
## An entry thrown past the centre (_keeper_reads): the keeper reads it and comes out for it,
## if he gets there first and nobody of theirs can. Only a ball landing within KEEPER_OUT_R of
## him and at least KEEPER_OUT_MIN past where the centre could catch it; the further past him
## (to KEEPER_OUT_SURE), the more likely (KEEPER_OUT_BASE .. always). He sees it KEEPER_READ after
## the release, swims out flat out (KEEPER_RUSH), and takes it within KEEPER_GRAB_R: in the air
## late in its flight, or on the water up to KEEPER_LATE after it lands.
const KEEPER_OUT_R := 4.0
const KEEPER_OUT_MIN := 0.3
const KEEPER_OUT_SURE := 2.5
const KEEPER_OUT_BASE := 0.35
const KEEPER_READ := 0.15
const KEEPER_RUSH := 2.2
const KEEPER_GRAB_R := 0.9
const KEEPER_LATE := 0.4
## A penalty: a defender beaten for inside water decides to pull the shooter back as he goes up
## (CenterDefense: DESPERATE) and stops a probable goal: in the goalie box (inside 5 m, within
## GOALIE_BOX_HALF of the middle), a good enough chance. Inside water on its own never draws one.
## It comes before any exclusion, and one play never draws both.
const FOUL_REACH := 1.4
const RESTART_DELAY := 5.0   # live s a free throw may be held, clock stopped, before it lapses (no stalling)
const INSIDE_WATER_COS := 0.64     # (his man within about 50 degrees of straight behind him)
const GOALIE_BOX_HALF := 4.0
## A scoring chance (close_chance): how close in, from what angle, and the man on him. The same
## for anybody who gets there: it's the water he's in, not the position he plays.
const CLOSE_FROM := 5.5        # m from the goal: no close-range chance out here...
const CLOSE_FULL := 2.5        # ...a full one in here
const CLOSE_ANGLE := Vector2(40.0, 35.0)   # degrees off straight on where it starts to fade, and over how many
const CLOSE_MARK_R := 1.4      # his man this close counts: in front of him (smothered), beside, behind
const CLOSE_MARK := {PlayDefense.Zone.FRONT: 0.35, PlayDefense.Zone.SIDE: 0.75, PlayDefense.Zone.BEHIND: 0.95}
## Aiming from a strong close-range chance: a pull just wide of the post (within CLOSE_TOL at a full
## chance, nothing below CLOSE_TOL_FROM) is tucked CLOSE_TUCK inside it. The reticle shows where it
## goes, so it still goes where you see; anything wider is still wide.
const CLOSE_TOL := 0.25
const CLOSE_TOL_FROM := 0.45
const CLOSE_TUCK := 0.12
## Contact on the shooter (contact_on, ShotModel.CONTACT_SLOW): a defender this close, how squarely
## (in front of him most), and the two men's Strength (Attributes.FOUL_PER_POINT a point).
const CONTACT_R := 1.0
const CONTACT_FULL := 0.4
const CONTACT_ZONE := {PlayDefense.Zone.FRONT: 1.0, PlayDefense.Zone.SIDE: 0.8, PlayDefense.Zone.BEHIND: 0.5}
const CATCH_EXCL := 0.17       # a man caught inside the box with his man behind him, on the catch
## Fouled from behind on a clear scoring chance (penalty_foul): every defensive foul goes through
## _ordinary_foul, and one that's from behind (behind: the defender at least BEHIND_MIN back from the
## man along his line to the goal, and within the inside-water cone, INSIDE_WATER_COS, of straight
## behind him: the man has inside water on him; beside him, or holding his shoulder, isn't) on a
## clear chance is a penalty,
## never an ordinary foul. A clear chance is in the goalie box (the penalty area), and either a
## probable goal (CenterDefense.probable) or any look at the goal (close_chance) with nobody
## else in his way to the goal (within OPEN_LANE of his line to it: a breakaway). The geometry is his own
## attack's: Play always attacks x = 30, whichever end of the pool the screen shows it at.
const BEHIND_MIN := 0.25
const OPEN_LANE := 0.9
## (The press on the ball, ordinary fouls: DefenseFormation's CONTACT_R, FOUL_SETTLE and FOUL_RATE,
## times foul_pressure: the defender's Defense against his Strength.)

var kind: int = Kind.HALF_COURT
var us: PoloTeam
var them: PoloTeam
var rng: RandomNumberGenerator
var attackers: Array[Swimmer] = []
var defenders: Array[Swimmer] = []
var keeper: Swimmer
var holder: Swimmer = null
var ball := Ball.new()
var shot_clock := SHOT_CLOCK
var shot_start := SHOT_CLOCK # what it started from (less than SHOT_CLOCK after a transition: start_shot_clock)
var elapsed := 0.0           # live seconds (the game clock runs with these)
var freeze := 0.0            # whistle: play stops, bodies reset
var man_up := 0.0
## The 6 on 5's clock waits for the power play's first pass (or a shot straight off the free
## throw): until then it holds at what it was given. Every exclusion starts it waiting again.
var man_up_live := false
var excluded: Swimmer = null
var excl_player: PoloPlayer = null   # who the 6 on 5 is against (kept after he's back in: carry-over)
var pressure := 0.0
var free_throw := false      # after a foul inside 6 m the ball must be passed first
## A FOUL RESTART: every whistle (an ordinary foul, an exclusion) stops the shot clock and keeps
## it stopped until the free throw is released (a pass, or a legal shot from outside 6 m); while
## it's on, the man taking it can't be fouled, stripped or challenged again. `pass_first`: he was
## fouled inside 6 m, so his team can't shoot until he's passed it, wherever he swims meanwhile
## (shot_barred). Both end on the release, never on time or position (but see RESTART_DELAY).
var restart := false
var pass_first := false
var restart_t := 0.0         # live seconds since the whistle's freeze ended, the ball still held
var carry := false           # counterattack: the break is on (no set drives until it's over)
var raised := false          # the holder has the ball up to throw (you're pulling back)
var counter_t := 0.0
var break_n := Vector2i.ZERO # the counter at the start: attackers in the break, defenders back
var break_t := 0.0           # seconds to the next look at the numbers
var rotating: Swimmer = null # the counter's carrier, swimming the ball back out to his spot
var lanes := {}              # the break: each man in it -> his lane, -1 top, 0 middle, +1 bottom (PlayAI.assign_lanes)
var lane_key := ""           # ...who they were given out to
## The counter's rotation (CounterCurl): how a counter that's already on is swum. Never whether there is one.
var curl_mode: int = 0       # CounterCurl.Mode: OFF until a confirmed counter (kind COUNTER, carry) starts it
var rot: RefCounted = null   # ...its state (CounterCurl.Rotation): who's on which spot, who's coming for it
var marks_t := 0.0           # the break: seconds since the defence last sorted out who takes whom (PlayAI.counter_marks)
var marks_ball: Swimmer = null   # ...and who had the ball then
var catch_t := INF           # seconds since the man with the ball caught a pass (INF: he didn't)
var cs_k := 1.0              # the catch-and-shoot window's share at this difficulty (Difficulty.catch_shoot_k; MatchFlow sets it on your attack)
var release_t := INF         # seconds since a catch-and-shoot left the hand (INF: none); the screen's white ring
var release_by: Swimmer = null   # ...and who threw it
var drive_timer := 2.5
var zone_set := false        # man-down: the zone's lanes handed out (ManDownZone; an exclusion starts it again)
var zone_ball: Swimmer = null    # ...the man it's playing as having the ball...
var zone_primary: Swimmer = null # ...and the defender stepped out on him
var loose_t := 0.0
var loose_skip := 0.0        # nobody can gather the loose ball before this (a deflection)
var frame_rebound := false   # the loose ball came off the post or the bar (_center_rebound_foul)
var over := false
var result: Dictionary = {}
var events: Array[Dictionary] = []
var level := Difficulty.BASELINE   # the defending team's AI (its defenders and keeper): Difficulty, 0..1
var cpu_level := Difficulty.BASELINE   # the other team's level whichever end it's at (its shots' pace: Difficulty.cpu_shot_speed)
var ai_rng := RandomNumberGenerator.new()   # ...its own dice for its choices, so the game's rng is untouched
var gk_memory := Vector3.ZERO   # where this attack's shots have gone today: near post, middle, far post (KeeperAI)
var gk_state: int = KeeperAI.State.READY   # their keeper's state (KeeperAI.state_of), for the screen and tests
var err_t := 0.0                # seconds until the defenders' positioning errors are rolled again
var raise_t := 0.0              # seconds the man with the ball has had it up (their keeper watches the wind-up)
var hold_t := 0.0               # seconds the man with the ball has had it in shooting range (KeeperAI's anticipation)
var gk_read: int = KeeperAI.NO_READ   # their keeper's read of this man's shot (KeeperAI: LEFT / UP / RIGHT), once he's had a look
var gk_lean_y := NAN            # ...and where he'd set before he leaned on it
var clutch := false          # the last minute of the game (MatchFlow sets it): ICE shooters step up
## Multiplayer: their keeper is a person on the other phone. A shot that gets past the
## defenders waits at the goal line for their verdict (set_verdict) instead of ShotModel's.
var remote_keeper := false
## The match screen shows goals tight to the frame as BAR-IN! / BAR-DOWN! (BarHit): picked here at
## the release of a shot that's already a goal, on its own dice, for the drawing only.
var bar_fx := false
var bar_mode: int = BarHit.Override.NORMAL   # ...Developer Mode's override of its die (BarHit.override)
var home_keeper := false     # the keeper in this goal is the home team's: he dives faster (ShotModel.HOME_DIVE)
var verdict := ""
var waiting_t := 0.0
var shot_n := 0              # multiplayer: which shot of this possession the verdict is for
## Single player, their attack: `us` is them and `them` is your team. You only keep goal.
var defending := false
## A shootout penalty: only the shooter and the keeper are in the water (PlaySetup._penalty).
var shootout := false
## A tutorial drill with no keeper (Drill.strip): he's out of the water, so nothing of his
## (catching, picking off, coming out) happens. Always true in a match.
var keeper_in := true
## The shooting drill's keeper: where across his goal he sets (NAN: he shades to the ball, as in
## a match; PlayAI._keeper), and how much later than his rating he reacts to a shot. Never set in a match.
var keeper_spot := NAN
var keeper_late := 0.0
## A tutorial drill's keeper: the way he always dives (KeeperDive.LEFT / CENTRE / RIGHT), so the
## lesson is the same every time; NO_DIVE: he picks it himself (KeeperAI), as in a match.
const NO_DIVE := -99
var keeper_dive := NO_DIVE
var taker: Swimmer = null    # a penalty: the man on the 5 m line
var breakout := false         # the ball's changed hands: everybody's turned for the other goal (PlayAI._breakout)
var handover: Dictionary = {} # snapshot() the moment it changed hands, for the next possession
var breakout_centre: Swimmer = null   # the breakout: the next possession's centre...
var breakout_guard: Swimmer = null    # ...and his man, on his back down the pool (PlayAI._breakout)
var entry := ""               # a ball on its way into the centre: center_entry as it was thrown
var center_fed: Swimmer = null   # the centre with a real entry in his hands (_center_hold_foul)
var center_foul := false      # ...and his man's going to be whistled for holding him (CENTER_EXCL)
var entry_pick := 0.0         # a "trailed" entry: the chance his man gets a hand to it (TRAIL_PICK)
var keeper_rush := false      # the keeper's coming out for a ball thrown past the centre (_keeper_reads)
var first_pass := true        # this possession hasn't thrown its first pass yet (FIRST_GUARD_R)
var first_entry: Dictionary = {}   # ...and it went in to the centre through his man: {g, u, at, clean, major}
var drop_entry: Dictionary = {}    # ...or through a drop (_drop_entry_plan): {outcome, by, control, ...}
var drop_catch_foul: Swimmer = null   # the dropper who fouls the centre as he catches it
var swing_lane: Array = []         # a SWING's defenders in the lane as it left the hand
var drop_pending := -1             # a drop called, its foul still to come (DefenseFormation.F, -1: none)
var drop_fouler: Swimmer = null    # ...and the man going to make it
var drop_fouled := false           # this possession's drop has had its foul
## Labs and tests that want a formation in place at once, no foul (off: the game's own rule).
static var instant_drops := false
var steal_line := ""          # a counter: where the ball was won ("top", "bottom", "" not a steal; PlaySetup.steal_line)
## The 2 m battle (PlayAI._center_battle): where it's at (PlayAI.Fight), seconds left of it (-1:
## not started), and its own dice, so the game's rng is untouched.
var cfight := 0
var cfight_t := -1.0
var fight_rng := RandomNumberGenerator.new()
## The defence's formation for this possession (DefenseFormation): PRESS until somebody picks one,
## and one pick locks it until the ball changes hands (a new Play). The state its defenders run on:
var formation: int = DefenseFormation.F.PRESS
var formation_locked := false
var f_active := false           # the formation's running (the settled 6 on 6)
var f_holder: Swimmer = null    # who it last saw with the ball (decisions are made on the catch)
var f_closer: Swimmer = null    # M-DROP: the splitter closing out on A3
var f_helper: Swimmer = null    # 5 DROP: the man helping on A5...
var f_recover: Swimmer = null   # ...and the one swimming back to his own man
var f_help_t := 0.0
var f_in: Swimmer = null        # a piston formation: the piston who's dropped in...
var f_want_in: Swimmer = null   # ...and who the last catch says should be
var f_commit := 0.0             # ...seconds before the pistons may change again
var f_dropper: Swimmer = null   # whoever's in front of the centre this frame
var f_crash_t := 0.0            # seconds the centre's had the ball (the dropper's reaction)
var f_hold_t := 0.0             # seconds the man with the ball has had it (a splitter tightens up)
## The computer's defence (DropCall): its game-planned drop for this half (-1: not the computer's
## defence, the formation is picked: select_formation), the match's personal fouls (MatchState.pf,
## by player id: how protective of its 2MD it is) and where its call stands this possession.
var ai_drop := -1
var pf: Dictionary = {}
var dc_t := 0.0                 # seconds the centre's had his position on the 2MD (the call's clock)...
var dc_wait := -1.0             # ...how long it takes the defence to call the drop (-1: no threat yet)
var dc_lost := 0.0              # ...seconds since the centre lost it again (the pending call goes)
var dc_in := 0.0                # in the drop: seconds since it was called...
var dc_off := 0.0               # ...and seconds the centre's been off his spot (the threat's over)
## The keeper's legs in a drop (KeeperLegs): seconds of drop in them now, seconds spent in a drop
## this possession, and what they'd taken off his top-corner reach when the last shot went.
var gk_strain := 0.0
var drop_t := 0.0
var shot_strain := 0.0
var last_shot: Dictionary = {}  # the last shot of this possession: {tag, f, height, strain}
## The press (DefenseFormation.press): who's shoving whom, from where, for how long.
var push_by: Swimmer = null
var push_on: Swimmer = null
var push_from := Vector2.ZERO
var push_t := 0.0
var foul_t := 0.0               # seconds of contact on the man with the ball (ordinary fouls: _pressure)
var center_foul_excl := true    # the fed centre's whistle: an exclusion (true) or an ordinary foul (a poor ball)
var center_foul_by: Swimmer = null   # ...made by this man, not his guard (a drop's entry)

## `snap`: where everybody was when the ball changed hands (Play.snapshot of the last
## possession), so a counter picks up from there; {} makes one up.
func _init(p_us: PoloTeam, p_them: PoloTeam, p_kind: int, p_rng: RandomNumberGenerator, snap: Dictionary = {}) -> void:
	us = p_us
	them = p_them
	kind = p_kind
	rng = p_rng
	if kind == Kind.COUNTER:
		counter_t = 5.0
	fight_rng.seed = hash([rng.state, kind])
	ai_rng.seed = hash([rng.state, kind, "ai"])
	PlaySetup.build(self, snap)
	keeper.facing = -1.0

## The defending team's AI level (Difficulty): how well its defenders and keeper choose.
func set_level(l: float) -> void:
	level = clampf(l, 0.0, 1.0)

## The CPU keeper's reaction-delay multiplier (Difficulty.cpu_keeper_react): theirs when you're
## attacking; your own keeper is never touched.
func gk_k() -> float:
	return 1.0 if defending else Difficulty.cpu_keeper_react(level)

## The CPU keeper's dive-speed multiplier (Difficulty.cpu_keeper_dive): theirs only.
func gk_dive_k() -> float:
	return 1.0 if defending else Difficulty.cpu_keeper_dive(level)

## How early in the shot clock it is for the CPU keeper's wing read: 1 with WING_EARLY.y s or more
## left, 0 by WING_EARLY.x.
const WING_EARLY := Vector2(14.0, 20.0)
func wing_early() -> float:
	return smoothstep(WING_EARLY.x, WING_EARLY.y, shot_clock)

## The CPU keeper's reaction multiplier for this shooter's shot: gk_k, and quicker again for a
## wing ("1", "5") shooting early in the shot clock (Difficulty.cpu_keeper_wing).
func gk_shot_k(shooter: Swimmer) -> float:
	if defending or shooter == null or not shooter.tag in ["1", "5"]:
		return gk_k()
	return gk_k() * Difficulty.cpu_keeper_wing(level, wing_early())

## The CPU defenders' arm-raise-delay multiplier (Difficulty.cpu_arm_delay): theirs when you're
## attacking; your own defenders are never touched.
func arm_k() -> float:
	return 1.0 if defending else Difficulty.cpu_arm_delay(level)

## The CPU's shot-speed multiplier for a shot pulled to `power` (Difficulty.cpu_shot_speed): only
## their attack, at your goal; your own shots are never touched.
func cpu_speed_k(power: float) -> float:
	return Difficulty.cpu_shot_speed(cpu_level, power) if defending else 1.0

## A hold as the CPU keeper reads it: a sharper one sees the shot coming sooner (hold / gk_k).
func gk_hold() -> float:
	return hold_t / gk_k()

## The defence picks its formation for this possession (DefenseFormation.F): once. The pick is
## locked until the ball changes hands; false if it's already locked (or there's no such thing).
func select_formation(f: int) -> bool:
	if formation_locked or not DefenseFormation.valid(f) or kind == Kind.PENALTY:
		return false
	formation_locked = true
	if DefenseFormation.is_drop(f) and not instant_drops:
		begin_drop(f)
	else:
		form_up(f)
	return true

## A formation on at once. (select_formation, a drop's foul, and going back to PRESS.)
func form_up(f: int, extra: Dictionary = {}) -> void:
	formation = f
	drop_pending = -1
	drop_fouler = null
	f_active = false   # (the formation sets itself up again from where everybody is)
	var e := {"k": "formation", "f": f, "name": DefenseFormation.NAMES[f]}
	e.merge(extra)
	events.append(e)

## A drop is called, by either bench: the ball handler's fouled first (_drop_step), then it forms.
## With the whistle already gone there's a foul to organise behind: it forms now.
func begin_drop(f: int, extra: Dictionary = {}) -> void:
	if restart or freeze > 0.0:
		form_up(f, extra)
		return
	drop_pending = f
	drop_extra = extra
	events.append({"k": "drop_called", "f": f})

var drop_extra := {}

## The called drop, a frame on: the on-ball man gets to him and it's a foul. A shot, a pass or a
## bad angle just means he goes after whoever has it next; a whistle in the meantime is the foul.
func _drop_step() -> void:
	if drop_pending < 0 or over:
		return
	if restart or (freeze > 0.0 and man_up <= 0.0):
		form_up(drop_pending, drop_extra)
		return
	if not DefenseFormation.active(self):
		return
	var h := DefenseFormation._ball_man(self)
	if h == null:
		drop_fouler = null
		return
	drop_fouler = _on_ball_man(h)
	if drop_fouler == null or catch_t < DROP_CATCH_WAIT:
		return
	if drop_fouler.pos.distance_to(h.pos) <= DROP_FOUL_R and not penalty_foul(h, drop_fouler):
		var f := drop_pending
		var by := drop_fouler
		drop_fouled = true
		_ordinary_foul(h, by)
		freeze = DROP_FOUL_FREEZE
		events.append({"k": "drop_foul", "f": f, "by": by.player})
		form_up(f, drop_extra)

## Who's on the man with the ball: his marker, or failing that the nearest defender.
func _on_ball_man(h: Swimmer) -> Swimmer:
	var d := _marker(h)
	return d if d != null and not d.out else _nearest_defender(h.pos)

## Labs and tests: `f` in place now, picked, with no foul.
func instant_drop(f: int) -> void:
	formation_locked = true
	form_up(f)

## The possession starts with `secs` on the shot clock (a transition took the rest).
func start_shot_clock(secs: float) -> void:
	shot_clock = clampf(secs, 0.0, SHOT_CLOCK)
	shot_start = shot_clock

func bodies() -> Array[Swimmer]:
	var out: Array[Swimmer] = []
	if shootout and taker != null:
		out.append(taker)
		out.append(keeper)
		return out
	out.append_array(attackers)
	out.append_array(defenders)
	if keeper_in:
		out.append(keeper)
	return out

func give_ball(s: Swimmer) -> void:
	holder = s
	ball.state = Ball.State.HELD
	s.arm = 0.0
	raised = false
	pressure = 0.0
	catch_t = INF
	hold_t = 0.0
	gk_read = KeeperAI.NO_READ
	center_fed = null
	center_foul = false
	keeper_rush = false
	foul_t = 0.0
	ball.tipped_by = null
	if rotating != s:
		rotating = null
	_hold_ball()

## Ball up to throw (true), or back down on the water (false). The screen calls this every
## frame from the aim: pull back and he lifts it, ease off and he puts it down again.
func raise_ball(on: bool) -> void:
	if holder == null or over:
		raised = false
		return
	if on == raised:
		return
	raised = on
	raise_t = 0.0
	if not on:
		events.append({"k": "ball_down"})

## Is a pull aimed at `target` a pull back to shoot (so he stops and lifts it)? On the break only
## one aimed forward, at their goal, is: a stray drag isn't a shot, and the carrier keeps swimming.
## Let go of it, or ease it off, and he swims on.
func shooting_pull(target: Vector2) -> bool:
	return not carry or (holder != null and target.x > holder.pos.x)

# ------------------------------------------------------------------ loop
func step(dt: float) -> void:
	release_t += dt
	ball.secure_t += dt
	if keeper.pose != null and not defending:
		keeper.pose.advance(dt)
		if keeper.pose.done():
			keeper.pose = null
		else:
			# mid-dive he can't swim anywhere: where you see him is where his dive has him (after the
			# shot too, a parry, a rebound)
			keeper.pos.y = keeper.pose.body_y()
			keeper.vel = Vector2.ZERO
	if over:
		PlayAI.update(self, dt)
		_move(dt)
		if ball.state == Ball.State.DEAD and holder != null:
			_hold_ball()
		if ball.step_net(dt):
			events.append({"k": "net", "at": ball.pos})
		return
	if freeze > 0.0:
		freeze -= dt
		DefenseFormation.end_push(self)   # (a whistle: nobody shoves through it)
		PlayAI.update(self, dt)
		_move(dt)
		_ease_arm(dt)
		_hold_ball()
		return
	elapsed += dt
	if restart:
		restart_t += dt
		if restart_t >= RESTART_DELAY:
			_lapse_restart()   # held far too long: the referee's patience runs out (see RESTART_DELAY)
	if not restart:
		shot_clock = maxf(0.0, shot_clock - dt * MatchState.CLOCK_SPEED)   # (with the game clock)
	counter_t = maxf(0.0, counter_t - dt)
	if ball.state == Ball.State.HELD:
		catch_t += dt
		if raised:
			raise_t += dt
		if holder != null and Geo.in_shot_range(holder.pos):
			hold_t += dt
	if carry:
		_watch_break(dt)
	if man_up > 0.0 and man_up_live:
		man_up -= dt
		if man_up <= 0.0:
			_end_man_up()
	DropCall.step(self, dt)     # (the computer's defence: PRESS, or its drop once the centre has position)
	KeeperLegs.step(self, dt)   # (the keeper's legs in a drop)
	PlayAI.update(self, dt)
	_move(dt)
	_drop_step()
	if freeze > 0.0:
		return   # (the drop's whistle: nothing else happens this frame)
	DefenseFormation.press(self, dt)
	_ease_arm(dt)
	_update_ball(dt)
	if over:
		return
	_center_hold_foul()
	_guard_clock(dt)
	if ball.state == Ball.State.HELD:
		_pressure(dt)
		CenterDefense.challenges(self)
		if not over and DefenseFormation.interference(self):
			return
		if not over and DefenseFormation.piston_contact(self):
			return
	if shot_clock <= 0.0 and ball.state != Ball.State.SHOT and not over:
		if kind == Kind.PENALTY and holder != null:
			_shoot(Geo.GOAL_Y + rng.randf_range(-1.0, 1.0), 0.4)
		else:
			_finish("shotclock", "SHOT CLOCK")

## The game clock ran out with the ball not in the air.
func buzzer() -> void:
	if not over and ball.state != Ball.State.SHOT:
		_finish("buzzer", "END OF QUARTER")

# ------------------------------------------------------------------ input
func can_throw() -> bool:
	return not over and freeze <= 0.0 and ball.state == Ball.State.HELD and holder != null \
		and holder.side == Swimmer.Side.US

## What a throw at `target` would do, for the aim guide:
## {mode: "shot" | "pass" | "no_shot" | "none", point, cross_y, receiver}
func aim_info(target: Vector2) -> Dictionary:
	var info := {"mode": "none", "point": target, "cross_y": Geo.GOAL_Y, "receiver": null}
	if holder == null:
		return info
	var from := holder.pos
	var d := target - from
	var wants_shot := target.x >= SHOT_ZONE_X or kind == Kind.PENALTY
	if wants_shot and d.x > 0.3:
		var cy := from.y + d.y * (Geo.GOAL_X - from.x) / d.x
		if absf(cy - Geo.GOAL_Y) <= Geo.GOAL_HALF + SHOT_WIDE:
			# exactly where the line crosses the goal line: an aim just wide goes just wide, unless he's
			# in close with a real chance (close_tuck)
			info.cross_y = close_tuck(cy, close_chance(holder))
			info.point = Vector2(Geo.GOAL_X, info.cross_y)
			info.mode = "no_shot" if shot_barred() else "shot"
			return info
	if kind == Kind.PENALTY:
		return info
	var p := Geo.clamp_in_pool(target)
	var mate := _receiver_for(p, ASSIST_R)
	if mate != null:
		p = lead_point(mate)
	info.point = p
	info.receiver = mate if mate != null else receiver_at(p)
	info.mode = "pass"
	return info

func throw(target: Vector2, power: float) -> String:
	if not can_throw():
		return "none"
	var info := aim_info(target)
	match String(info.mode):
		"shot":
			_shoot(info.cross_y, power)
		"pass":
			_pass(info.point, info.receiver)
	return info.mode

## A shot crossing at `cy` from a close-range chance `q` (close_chance): just wide of a post (within
## CLOSE_TOL, scaled by how good a chance it is) goes in just inside it. Anything else, as aimed.
static func close_tuck(cy: float, q: float) -> float:
	var off := absf(cy - Geo.GOAL_Y) - Geo.GOAL_HALF
	var tol := CLOSE_TOL * clampf((q - CLOSE_TOL_FROM) / (1.0 - CLOSE_TOL_FROM), 0.0, 1.0)
	if off <= 0.0 or off > tol:
		return cy
	return Geo.GOAL_Y + signf(cy - Geo.GOAL_Y) * (Geo.GOAL_HALF - CLOSE_TUCK)

## How good a scoring chance `s` has where he is (or at `at`), 0..1, from what anybody can see:
## the range, the angle, and his man (in front of him, between him and the goal, he's shooting
## through him; beside him; behind him, inside water). Whoever he is: never his position's name.
func close_chance(s: Swimmer, at := Vector2.INF) -> float:
	var pos := s.pos if at == Vector2.INF else at
	var q := clampf((CLOSE_FROM - pos.distance_to(Geo.goal_center())) / (CLOSE_FROM - CLOSE_FULL), 0.0, 1.0)
	var ang := rad_to_deg(atan2(absf(pos.y - Geo.GOAL_Y), maxf(Geo.GOAL_X - pos.x, 0.2)))
	q *= 1.0 - clampf((ang - CLOSE_ANGLE.x) / CLOSE_ANGLE.y, 0.0, 0.8)
	if q <= 0.0:
		return 0.0
	var g := _marker(s)
	if g != null and not g.out and g.pos.distance_to(pos) < CLOSE_MARK_R:
		q *= float(CLOSE_MARK.get(PlayDefense.side_of(g, s), 1.0))
	return q

## Contact on `s` as he shoots, 0..1 (ShotModel.CONTACT_SLOW): the nearest defender within CONTACT_R,
## how squarely he's on him, and his Strength against the shooter's.
func contact_on(s: Swimmer) -> float:
	var d := _nearest_defender(s.pos)
	if d == null or kind == Kind.PENALTY:
		return 0.0
	var dist := d.pos.distance_to(s.pos)
	if dist >= CONTACT_R:
		return 0.0
	var c := clampf((CONTACT_R - dist) / (CONTACT_R - CONTACT_FULL), 0.0, 1.0) * float(CONTACT_ZONE.get(PlayDefense.side_of(d, s), 0.5))
	c *= clampf(1.0 + (Attributes.strength(d.player) - Attributes.strength(s.player)) * Attributes.FOUL_PER_POINT, 0.5, 1.5)
	return clampf(c, 0.0, 1.0)

## Where a pass to `mate` should land: where he'll be when it gets there.
func lead_point(mate: Swimmer) -> Vector2:
	var flight := holder.pos.distance_to(mate.pos) / pass_speed(holder)
	return Geo.clamp_in_pool(mate.pos + mate.vel * flight)

## Whether a tap at `to` (pool metres) can be passed to right now: in the water, clear of the
## man with the ball, and not on a penalty.
func can_pass_at(to: Vector2) -> bool:
	return can_throw() and kind != Kind.PENALTY and Geo.in_pool(to) and holder.pos.distance_to(to) >= MIN_PASS

## Tap to pass into open water: the ball goes where you tapped, nowhere else. The nearest
## teammate goes for it; if nobody's there when it lands it's a loose ball for whoever gets to it
## first. It can still be picked off on the way. (A tap on a teammate is pass_to.)
func pass_at(to: Vector2) -> bool:
	if not can_pass_at(to):
		return false
	to = Geo.clamp_in_pool(to)
	_pass(to, receiver_at(to))
	return true

## Who a ball into open water at `to` is for. On the break, the man swimming at it: a ball in
## front of him, near his line, out to LEAD_REACH, is his to run onto (PlayAI.run_onto), however
## far that is from where he is now; the one who'd have to come least off his line. Otherwise
## (or nobody's swimming at it), the nearest man.
const LEAD_REACH := 7.0
const LEAD_WIDE := 2.0
func receiver_at(to: Vector2) -> Swimmer:
	if carry:
		var best: Swimmer = null
		var bd := INF
		for a in attackers:
			if a == holder or a.out or not a.is_swimming():
				continue
			var dir := a.vel.normalized()
			var rel := to - a.pos
			var along := rel.dot(dir)
			var wide := absf(rel.cross(dir))
			if along < 0.0 or along > LEAD_REACH or wide > LEAD_WIDE:
				continue
			var d := wide + along * 0.1
			if d < bd:
				bd = d
				best = a
		if best != null:
			return best
	return _receiver_for(to)

## Tap on a teammate: the ball goes to him, leading him if he's swimming, wherever he is: any man
## to any man, right across the pool. Nothing but a defender in the lane stops it (it can still be
## picked off on the way, and a ball into the centre is still his guard's if he's fronting him).
func pass_to(mate: Swimmer) -> bool:
	if not can_throw() or kind == Kind.PENALTY or mate == null or mate == holder or mate.out or not attackers.has(mate):
		return false
	_pass(lead_point(mate), mate)
	return true

## Pull back to shoot: throws only if the aim lands in the goal; anything else throws nothing.
## This is your own aim, so the ball flies exactly along it (ShotModel's `exact`): no spread.
func shoot_at(target: Vector2, power: float) -> String:
	if not can_throw():
		return "none"
	var info := aim_info(target)
	if info.mode == "shot":
		_shoot(info.cross_y, power, true)
	return info.mode

# ------------------------------------------------------------------ ball
func _hand(s: Swimmer) -> Vector2:
	return s.pos + Vector2(0.2 * s.facing, -0.05)

## The ball goes where the man with it has it (held_at), every frame.
func _hold_ball() -> void:
	if holder != null:
		ball.put(held_at(holder))

## Where the ball is in `s`'s hands (x, y, height). Down, it sits on the water in front of his
## head; up, it's overhead in his hand: a lefty's left, behind his head where his art has it
## (PoolArt.arm_px; LEFT_HAND_X). A keeper in a dive, or getting back up from one, has it where
## his art has his hands (KeeperDive.held).
const LEFT_HAND_X := -0.17
static func held_at(s: Swimmer) -> Vector3:
	var up := LEFT_HAND_X if s.player != null and s.player.is_lefty() and not s.keeper else 0.2
	var rest := Vector3(lerpf(0.35, up, s.arm), -0.05, lerpf(0.02, 0.9, s.arm))
	if s.keeper and s.pose != null and not s.pose.done():
		rest = s.pose.held(rest)
	return Vector3(s.pos.x + rest.x * s.facing, s.pos.y + rest.y, rest.z)

## The ball goes up as fast as his release (Attributes.release_mult: SHOOTING), and down again.
func _ease_arm(dt: float) -> void:
	if holder != null and not over:
		var rate := 14.0 / Attributes.release_mult(holder.player) if raised else 14.0
		holder.arm = move_toward(holder.arm, 1.0 if raised else 0.0, dt * rate)

func _pass(to: Vector2, receiver: Swimmer) -> void:
	var dist := holder.pos.distance_to(to)
	ball.launch(_hand(holder), to, dist / pass_speed(holder), peak_for(_hand(holder), to, holder, receiver), Ball.State.PASS)
	ball.receiver = receiver
	ball.passer = holder
	entry = center_entry(ball.from, receiver)   # (decided as it's thrown: what you saw is what it is)
	entry_pick = trail_pick(receiver) if entry == "trailed" else 0.0
	first_entry = {}
	drop_entry = {}
	drop_catch_foul = null
	swing_lane = _lane_men() if swing_pass() else []
	var first_entry_was := first_pass
	var in_drop := DefenseFormation.active(self) and DefenseFormation.is_drop(formation)
	if first_pass:
		first_pass = false   # (the first attempt, however it turns out: the next one's an ordinary pass)
		if not in_drop:
			first_entry = _first_entry_plan(receiver)
	if in_drop:
		_drop_entry_plan(receiver)
	keeper_rush = _keeper_reads(receiver)
	holder.arm = 0.95
	holder.snap = Swimmer.SNAP_TIME
	if not carry:
		holder.drive_t = 0.0   # a drive with the ball is over once he gives it up: back to his spot
	holder = null
	raised = false
	pressure = 0.0
	free_throw = false
	_end_restart()   # the free throw's released: the shot clock runs again, contact is back
	man_up_live = true   # (a 6 on 5's clock runs from its first pass)
	events.append({"k": "pass", "to": receiver.tag if receiver != null else "", "first": first_entry_was,
		"through": not first_entry.is_empty()})   # (a counter goes on: whoever catches it carries the break)

## Every defender in the water, as ShotModel blockers for a shot by `shooter`. Whether one
## gets a hand to it is down to where he is and the ball's path; the shooter's own guard also
## needs his GUARD_TIME of pressure first (`on_ball`, `ready`).
func _blockers(shooter: Swimmer) -> Array:
	var guard := on_ball_guard(shooter)
	var out: Array = []
	if kind == Kind.PENALTY:
		return out   # a penalty is the shooter and the keeper: nobody else may touch it
	for i in defenders.size():
		var d := defenders[i]
		if not d.out and (CENTER_DEFENDER_BLOCKS or not is_center_defender(d)):
			out.append(ShotModel.blocker(d.pos, d.player, i, d == guard, d == guard and guard_ready(d, shooter)))
	return out

## The defender on the centre (the 2 m defender): whoever is marking the man in the C spot.
func is_center_defender(d: Swimmer) -> bool:
	return d != null and d.mark != null and d.mark.tag == "C"

## The defender guarding `s`: his marker; null if that man is out of the water or too far
## off to be guarding anybody. A defender who just happens to be near him isn't his guard.
func on_ball_guard(s: Swimmer) -> Swimmer:
	if s == null:
		return null
	var g: Swimmer = null
	for d in defenders:
		if d.mark == s and not d.out:
			g = d
			break
	if g == null or g.pos.distance_to(s.pos) > ON_BALL_R:
		return null
	return g

## Has guard `d` pressed `s` long enough to get a hand up to his shot?
func guard_ready(d: Swimmer, s: Swimmer) -> bool:
	if s != null and s.tag == "C":
		return true
	return d != null and d.guard_on == s and d.guard_t >= GUARD_TIME

## The pressure clock: the man guarding the ball counts unbroken seconds close to him and not
## behind him. It starts over when he drops off or switches, and whenever the ball leaves the
## hand (a pass, a shot, a loose ball): nobody carries time over to the next man with it.
func _guard_clock(dt: float) -> void:
	var held := ball.state == Ball.State.HELD and holder != null
	var guard := on_ball_guard(holder) if held else null
	for d in defenders:
		var pressing := d == guard and d.pos.distance_to(holder.pos) <= GUARD_R \
			and PlayDefense.side_of(d, holder) != PlayDefense.Zone.BEHIND
		if not pressing:
			d.guard_on = null
			d.guard_t = 0.0
		elif d.guard_on != holder:
			d.guard_on = holder
			d.guard_t = dt
		else:
			d.guard_t += dt

## A defender is standing in the lane from the man with the ball to `target` (for the bots:
## nobody shoots into a raised hand).
func lane_blocked(target: Vector2) -> bool:
	if holder == null:
		return false
	for b in _blockers(holder):
		if ShotModel.lane_reach(holder.pos, target, BOT_SHOT_SPEED, b):
			return true
	for arm: Dictionary in _arms(holder):
		if not ShotModel.arm_contact(holder.pos, target - holder.pos, BOT_SHOT_SPEED, arm).is_empty():
			return true
	return false

## `exact`: you aimed it (shoot_at), so it goes exactly there; the bots' throws keep ShotModel's
## spread. Either way the ball leaves his hand on the line it flies along, so what you see and what
## the blocks and the keeper are decided on are the same line.
func _shoot(cross_y: float, power: float, exact: bool = false) -> void:
	var shooter := holder
	if CenterDefense.foul_on_shot(self, shooter):
		return   # pulled back going up: the whistle (a penalty, if it stopped a probable goal)
	var blockers := _blockers(shooter)
	var nearest := INF
	for d in defenders:
		if not d.out:
			nearest = minf(nearest, d.pos.distance_to(shooter.pos))
	var mods := shot_mods(shooter)
	# attributes (Attributes): the passer's catch-and-shoot edge (only on a catch and shoot: ShotModel
	# scales it by the bonus), the shooter's release, the keeper's four
	var passer: Swimmer = ball.passer if ball.passer != shooter else null
	var skill := shot_skill(shooter, mods)
	# the keeper's body is his attributes' and his form's (a WALL's reach), whatever the difficulty;
	# the difficulty is only how he reads it (iq), from what he can see (KeeperAI)
	var keeping := keeper.player.live("keeping") + (WALL_BONUS if Traits.has(keeper.player, "wall") else 0.0)
	var ctx := {"catch_t": catch_t, "cs_k": cs_k, "home_keeper": home_keeper, "exact": exact,
		"pass_mod": Attributes.pass_mod(passer.player) if passer != null and catch_t < INF else 0.0,
		"release": Attributes.release_read(shooter.player) + keeper_late,
		"lunge": Attributes.lunge_mult(keeper.player), "leg": Attributes.leg_reach(keeper.player),
		"lunge_k": Attributes.keeper_skill(keeper.player, "lun"), "leg_k": Attributes.keeper_skill(keeper.player, "leg"),
		"block": Attributes.block_mod(keeper.player), "window": Attributes.dive_window(keeper.player),
		"wall": Traits.has(keeper.player, "wall"),
		"iq": level, "memory": gk_memory, "close": close_chance(shooter), "contact": contact_on(shooter),
		"pace": shot_pace(shooter), "skill_top": Attributes.rating_top(shooter.player),
		"seen": raise_t if raised else 0.0, "hold": gk_hold() if not defending else 0.0, "arms": _arms(shooter),
		"gk_k": gk_shot_k(shooter), "gk_dive": gk_dive_k(),
		# the CPU's shot (their attack, at your goal): its pace at the difficulty, fixed here at the release
		"speed_k": cpu_speed_k(power)}
	if gk_read != KeeperAI.NO_READ and not defending:
		ctx["read_side"] = gk_read   # (the read he made watching him: KeeperAI, the lean you saw)
		ctx["lean_y"] = gk_lean_y if not is_nan(gk_lean_y) else keeper.pos.y
	if keeper_dive != NO_DIVE:
		ctx["dive_side"] = keeper_dive   # (a drill's keeper: the same way every time)
	if keeper.pose != null and not keeper.pose.done():
		ctx["busy"] = {"side": keeper.pose.side, "t": keeper.pose.t, "base_y": keeper.pose.base_y}   # (still in his last dive)
	shot_strain = KeeperLegs.loss(self)   # (his legs after the drop so far: his reach up high)
	ctx["strain"] = shot_strain
	var res := ShotModel.resolve(shooter.pos, cross_y, power, skill, nearest,
		blockers, keeper.pos.y, keeping, rng, kind == Kind.PENALTY, mods, ctx)
	last_shot = {"tag": shooter.tag, "f": formation, "height": float(res.get("height", 0.5)), "strain": shot_strain}
	gk_memory = KeeperAI.remember(gk_memory, KeeperAI.zone_of(float(res.cross_y), keeper.pos.y), shooter.pos)
	if remote_keeper:
		_pend_for_keeper(shooter, res)
	_launch(shooter, res, power)

## Past the defenders, with your keeper (or the other phone's) in goal: the shot waits for his dive
## (`pending`, the duel). On target, the dive decides it; heading wide or at the frame, he can
## still go for it, but the miss (or the post or bar) stands: set_verdict keeps it (no ball to touch).
func _pend_for_keeper(shooter: Swimmer, res: Dictionary) -> void:
	if not String(res.outcome) in ["goal", "save", "parry", "miss", "post"]:
		return
	res["auto"] = res.outcome
	res.outcome = "pending"
	var line := Vector2(Geo.GOAL_X, float(res.cross_y))
	if String(res.auto) == "miss":
		res["line_flight"] = shooter.pos.distance_to(line) / float(res.speed)   # (it flies on past the line as before)
	else:
		res.end = line
		res.flight = shooter.pos.distance_to(res.end) / float(res.speed)
	verdict = ""
	waiting_t = 0.0
	shot_n += 1

## The shot `res` (ShotModel's result) leaves `shooter`'s hand: the flight, the BAR-IN! pick for a
## goal, the event. `bar_roll` >= 0 forces the pick's die (Developer Mode: dev_goal, BarHit.override).
func _launch(shooter: Swimmer, res: Dictionary, power: float, bar_roll: float = -1.0) -> void:
	# it's drawn from his hand (release_point), a hand's length down the line it's been flying since
	# he let go of it: `lead` seconds of it are behind it, so every frame it moves at res.speed
	var rel := release_point(shooter.pos, res.end)
	var lead := shooter.pos.distance_to(rel) / float(res.speed)
	if String(res.outcome) == "pending":
		events.append({"k": "duel", "from": rel, "cross_y": float(res.cross_y), "flight": float(res.get("line_flight", res.flight)) - lead,
			"on_target": String(res.get("auto", "")) in ["goal", "save", "parry"],
			"keeper_y": keeper.pos.y, "n": shot_n, "height": float(res.get("height", 0.5)), "strain": shot_strain})
	res["keeper_start_y"] = keeper.pos.y
	# the assist goes to whoever passed to the shooter; a rebound starts over
	res["assist"] = ball.passer if ball.passer != shooter else null
	ball.passer = null
	ball.launch(rel, res.end, float(res.flight) - lead, 0.0, Ball.State.SHOT)
	ball.lead = lead
	ball.shot = res
	ball.shooter = shooter
	if bar_fx and String(res.outcome) == "goal" and bar_mode != BarHit.Override.NEVER:
		if bar_mode == BarHit.Override.ALWAYS and bar_roll < 0.0:
			bar_roll = 0.0   # (still only off a shot in tight enough to the frame: BarHit.pick)
		ball.bar = BarHit.pick(res, rel, bar_roll)
	if float(res.get("catch_shoot", 0.0)) > 0.0:
		release_t = 0.0
		release_by = shooter
	shooter.arm = 0.95
	shooter.snap = Swimmer.SNAP_TIME
	shooter.drive_t = 0.0   # (a drive with the ball is over once he's let it go, as with a pass)
	holder = null
	raised = false
	pressure = 0.0
	carry = false
	_end_restart()   # (a free throw from outside 6 m may go straight at goal: released all the same)
	man_up_live = true   # (...and a 6 on 5 shot straight off it has started its clock all the same)
	events.append({"k": "shot", "by": shooter.player, "power": power, "range": Geo.range_to_goal(shooter.pos),
		"catch_shoot": res.get("catch_shoot", 0.0), "cross": res.get("cross", 0.0), "power_shot": res.get("power_shot", false)})

## Developer Mode's SPECIAL GOAL EFFECTS: the man with the ball puts one in, crossing the line at
## (`cross_y`, `height`): a shot ShotModel already made a goal, launched exactly as one (_launch),
## its BAR-IN! / BAR-DOWN! picked the normal way (BarHit.pick) with only the die forced. Everything
## after the release (the flight, the frame, the net, the show) is the game's own. False: he can't throw.
func dev_goal(cross_y: float, height: float, speed: float = 14.0) -> bool:
	if not can_throw():
		return false
	var end := Vector2(Geo.GOAL_X, cross_y)
	var res := {"outcome": "goal", "cross_y": cross_y, "height": height, "speed": speed, "end": end,
		"flight": holder.pos.distance_to(end) / speed, "exact": true, "attempts": [], "blocker": -1,
		"deflect": Vector2.ZERO, "catch_shoot": 0.0, "cross": 0.0, "power_shot": false, "dev": true}
	_launch(holder, res, 0.7, 0.0)
	return true

func shot_mods(shooter: Swimmer) -> Dictionary:
	return Traits.shot_mods(shooter.player, shooter.pos, clutch or shot_clock < 6.0)

## The shot's pace rating: the shooter's own SHOOTING as he plays it, Hot Stars and all
## (Attributes.shot_pace); the same for you and the CPU, never his team's overall or form.
func shot_pace(shooter: Swimmer) -> float:
	return Attributes.shot_pace(shooter.player)

## The shooter's rating for this shot (its accuracy): form (HOT) moves it for this game (PoloPlayer.live), and
## his trait.
func shot_skill(shooter: Swimmer, mods: Dictionary) -> float:
	return shooter.player.live("shoot") + float(mods.skill)

## The raised arms out on `shooter` (a piston's pressure: DefenseFormation.arm_zone), as ShotModel
## takes them: a ball through one is blocked, no dice. None on a penalty.
func _arms(shooter: Swimmer) -> Array:
	var out: Array = []
	if kind == Kind.PENALTY or shooter == null:
		return out
	for i in defenders.size():
		var d := defenders[i]
		if d.press_on == shooter:
			var z := DefenseFormation.arm_zone(d, i, arm_k())
			if not z.is_empty():
				out.append(z)
	return out

## The aim guide's red X: would the man with the ball's shot crossing at `cross_y`, pulled to
## `power`, go through a raised arm (the very test ShotModel blocks it on, at the pace it would
## fly: a shot you aim goes exactly there)? {at (pool metres), i} where, or {}.
func arm_block(cross_y: float, power: float) -> Dictionary:
	if holder == null or kind == Kind.PENALTY:
		return {}
	var arms := _arms(holder)
	if arms.is_empty():
		return {}
	var mods := shot_mods(holder)
	var speed := ShotModel.shot_speed(power, shot_pace(holder), mods, contact_on(holder), Attributes.rating_top(holder.player))
	var dir := Vector2(Geo.GOAL_X, cross_y) - holder.pos
	var best := {}
	for arm: Dictionary in arms:
		var c := ShotModel.arm_contact(holder.pos, dir, speed, arm)
		if not c.is_empty() and (best.is_empty() or float(c.along) < float(best.along)):
			best = {"at": c.at, "along": c.along, "i": int(arm.i)}
	return best

## THE AIM GUIDE'S RED X, against every field defender whatever the formation (a press, any drop, the
## 6 on 5, a man recovering or switching): would your shot crossing at `cross_y`, pulled to `power`,
## be stopped for certain (ShotModel.sure_block: a raised arm in its way, or a man it reaches whose
## block can't miss)? Built from exactly what _shoot would hand ShotModel now (the same blockers,
## arms, release and pace), so the X is what that shot does. {at, along, i} or {}. Never the keeper.
func sure_block(cross_y: float, power: float) -> Dictionary:
	if holder == null or kind == Kind.PENALTY:
		return {}
	var mods := shot_mods(holder)
	var speed := ShotModel.shot_speed(power, shot_pace(holder), mods, contact_on(holder), Attributes.rating_top(holder.player)) * cpu_speed_k(power)
	var dir := Vector2(Geo.GOAL_X, cross_y) - holder.pos
	var late := Attributes.release_read(holder.player) + keeper_late
	return ShotModel.sure_block(holder.pos, dir, speed, _blockers(holder), late, _arms(holder))

## The aim across the goal mouth (the cross_y) a raised arm in the way blocks, the middle of what it
## covers at `power`, or NAN: no aim at the goal goes through it. (Developer Mode's DEFENSIVE TESTING
## sets your aim there; the tests too.)
func blocked_aim(power: float) -> float:
	var hits: Array[float] = []
	for k in 61:
		var cy := lerpf(Geo.GOAL_Y - Geo.GOAL_HALF + 0.05, Geo.GOAL_Y + Geo.GOAL_HALF - 0.05, k / 60.0)
		if not arm_block(cy, power).is_empty():
			hits.append(cy)
	return NAN if hits.is_empty() else (hits[0] + hits[hits.size() - 1]) * 0.5

## Where a shot from a man at `from` towards `end` leaves his hand: on that very line, a hand's
## length out (so the flight, the blocks and the keeper all share one straight line).
static func release_point(from: Vector2, end: Vector2) -> Vector2:
	var dir := end - from
	if dir.length() < 0.5:
		return from
	return from + dir.normalized() * 0.2

func _update_ball(dt: float) -> void:
	match ball.state:
		Ball.State.HELD:
			_hold_ball()
		Ball.State.PASS:
			_fly_pass(dt)
		Ball.State.SHOT:
			_fly_shot(dt)
		Ball.State.LOOSE:
			_loose(dt)

func _fly_pass(dt: float) -> void:
	var u0 := ball.t
	ball.t = minf(1.0, ball.t + dt / ball.dur)
	var u := ball.t
	ball.pos = ball.from.lerp(ball.to, u)
	# a dry pass is caught above the head, so it lands high
	ball.z = pass_z(u, ball.peak)
	# the first pass in to the centre, through his man: it gets to his hand and goes no further
	if not first_entry.is_empty() and u >= float(first_entry.u):
		_first_entry_hit()
		return
	# a keeper out for a ball thrown past the centre takes it as it comes down to him
	if u > 0.5 and _keeper_claims():
		return
	# the release is overhead and quick: only the middle of the flight can be picked off. A hand
	# gets to it only where the ball actually passes him: the closest point of this frame's stretch
	# of its flight (so it's the same at any frame rate), low enough, inside his reach. One go each.
	if u > 0.2 and u0 < 0.9:
		var a := ball.from.lerp(ball.to, maxf(u0, 0.2))
		var b := ball.from.lerp(ball.to, minf(u, 0.9))
		for d in _pickers():
			if ball.checked.has(d) or _entry_guard(d):
				continue
			var hawk := Traits.has(d.player, "ball_hawk")
			if d == drop_entry.get("by"):
				continue   # (the drop's man: already decided, _drop_entry_plan)
			var swing := swing_pass()
			var reach_z := 1.9 if d.keeper else (SWING_REACH_Z if swing and d in swing_lane else 1.35)
			var reach_r := ((SWING_KEEPER_R if swing else 0.9) if d.keeper else DefenseFormation.TIP_REACH) + (HAWK_REACH if hawk else 0.0)
			var at := Geometry2D.get_closest_point_to_segment(d.pos, a, b)
			var dd := d.pos.distance_to(at)
			var ua := ball.from.distance_to(at) / maxf(0.01, ball.from.distance_to(ball.to))
			if dd > reach_r or pass_z(ua, ball.peak) > reach_z:
				continue
			# a defender behind the receiver can't reach round him
			if ball.receiver != null and ball.receiver.pos.distance_to(at) < dd:
				continue
			ball.checked.append(d)
			if d.keeper:
				if rng.randf() < _keeper_pick(dd, reach_r):
					_turnover(d, "KEEPER CLAIMS IT", "steal")
					return
				continue
			if rng.randf() < _intercept_chance(d, reach_r):
				ball.pos = at
				if DefenseFormation.tip_outcome(rng) == DefenseFormation.Tip.CLEAN:
					_turnover(d, "PICKED OFF!", "steal")
				else:
					_deflect(d, rng.randf() < DefenseFormation.TIP_OUTCOMES[1] / (DefenseFormation.TIP_OUTCOMES[0] + DefenseFormation.TIP_OUTCOMES[1]))
				return
	if ball.t >= 1.0:
		var catcher := _catcher_near(ball.to)
		if catcher != null and catcher.tag == "C" and _entry_stolen(catcher):
			return
		if catcher != null:
			_catch(catcher, true)
		elif not _keeper_claims():
			_go_loose(Vector2.ZERO)

## A pass's height `u` of the way along a flight that loops `peak` (the flight, the pick-offs and
## pass_risk share it): a dry pass is caught above the head, so it lands high.
static func pass_z(u: float, peak: float) -> float:
	return lerpf(0.9, 1.1, u) + 4.0 * peak * u * (1.0 - u)

## A field player's chance to get a hand to the pass in the air as it reaches him
## (DefenseFormation.tip_chance: his Defense, his keeper's organising in it, against the passer's
## Passing; a ball into the centre through an established dropper, entry_block), and how
## squarely the pass goes through him (its line's distance from him, so it doesn't depend on the
## frame rate). Whether it's a clean pick or a deflection is DefenseFormation.tip_outcome's.
func _intercept_chance(d: Swimmer, reach_r: float) -> float:
	var passer: PoloPlayer = ball.passer.player if ball.passer != null else null
	var maker := passer != null and Traits.has(passer, "playmaker")
	var chance := DefenseFormation.tip_chance(d.player, passer, comm(), maker)
	var line_d := d.pos.distance_to(Geometry2D.get_closest_point_to_segment(d.pos, ball.from, ball.to))
	var off := clampf((line_d - INTERCEPT_LINE) / maxf(0.01, reach_r - INTERCEPT_LINE), 0.0, 1.0)
	chance *= lerpf(1.0, INTERCEPT_EDGE, off)
	if swing_pass():
		chance *= SWING_CONTEST if d in swing_lane else SWING_LATE   # (the same rule for both teams)
	else:
		chance *= _steal_edge()
	if Traits.has(d.player, "ball_hawk"):
		chance *= HAWK_PICK
	return chance

## A SWING, thrown now: on the power play, one perimeter man to another across the pool.
func swing_pass() -> bool:
	return is_swing(ball.from, ball.to, ball.passer, ball.receiver)

func is_swing(from: Vector2, to: Vector2, passer: Swimmer, receiver: Swimmer) -> bool:
	return man_up > 0.0 and passer != null and receiver != null and passer.tag != "C" and receiver.tag != "C" \
		and passer.tag != "GK" and absf(from.y - to.y) >= SWING_MIN

## Who's in the lane of the ball just thrown.
func _lane_men() -> Array:
	var out: Array = []
	for d in defenders:
		if not d.out and d.pos.distance_to(Geometry2D.get_closest_point_to_segment(d.pos, ball.from, ball.to)) <= DefenseFormation.TIP_REACH:
			out.append(d)
	return out

## The keeper's chance on a ball he's got a hand near, `dd` from him (`reach_r` his reach).
func _keeper_pick(dd: float, reach_r: float) -> float:
	if not swing_pass():
		return KEEPER_CLAIM
	var pas := DefenseFormation.passing(ball.passer.player)
	return clampf(SWING_KEEPER - SWING_KEEPER_PASS * (pas - 5.0), 0.05, 0.6) * (1.0 - dd / maxf(0.01, reach_r))

# ------------------------------------------------------------------ the centre
## Which side of `c` (the centre) a ball at `from` comes from: -1 up the screen, +1 down it, 0
## straight down at him (within PlayAI.CENTER_MID across).
static func entry_side(from: Vector2, c: Swimmer) -> int:
	var dy := from.y - c.pos.y
	return 0 if absf(dy) < PlayAI.CENTER_MID else int(signf(dy))

## Which side of the centre `g` is holding where he is right now: -1 / +1, or 0 when he's
## behind him (going round) or not on him at all, so neither lane is covered.
static func center_side_held(g: Swimmer, c: Swimmer) -> int:
	if g == null or g.out or g.pos.distance_to(c.pos) > CENTER_GUARD_R:
		return 0
	var dy := g.pos.y - c.pos.y
	return 0 if absf(dy) < CENTER_HOLD_Y else int(signf(dy))

## A ball into the centre `c` from `from`, the way it stands right now: "fronted" (his guard is
## in the passing lane, between the ball and the centre: it's his), "open" (he's off the lane: behind
## the centre, or on the other side of him), "straight" (down from the point, his guard beside
## him but off the lane), "trailed" (still swimming in to 2 m, or on a counter, with his man on his
## back, ball side: TRAIL_PICK), or "" (a power play, nobody on him).
func center_entry(from: Vector2, c: Swimmer) -> String:
	if c == null or c.tag != "C" or man_up > 0.0 or kind == Kind.PENALTY:
		return ""
	if carry or c.pos.distance_to(c.home) > CENTER_SPOT_R:
		return "trailed" if _trailer(c, from) != null else ""
	var g := _center_guard(c)
	if g == null:
		return ""
	if in_entry_lane(g, from, c.pos):
		return "fronted"
	if center_side_held(g, c) != 0 and entry_side(from, c) == 0:
		return "straight"
	return "open"

## Is `g` standing in the lane of a pass from `from` to a man at `to`: within ENTRY_LANE_R of
## its line, and on the ball side of the man (not behind him, where the ball's already past)?
static func in_entry_lane(g: Swimmer, from: Vector2, to: Vector2) -> bool:
	var lane := from - to
	if lane.length() < 0.5:
		return false
	var off := g.pos - to
	if off.dot(lane) <= 0.0:
		return false   # behind him, as the ball comes
	return g.pos.distance_to(Geometry2D.get_closest_point_to_segment(g.pos, from, to)) <= ENTRY_LANE_R

## The centre's guard is going round (or just about to): an open entry now won't be for long.
## The AIs, who wind up before they throw, leave it alone; you can still beat him to it.
const ENTRY_CLOSING := 0.5
func entry_closing(c: Swimmer) -> bool:
	var g := _center_guard(c)
	if g == null:
		return false
	match cfight:
		PlayAI.Fight.SEALED:
			return cfight_t < ENTRY_CLOSING   # his man's about to fight back round
		PlayAI.Fight.ROUND:
			return true
		PlayAI.Fight.SPIN:
			return false
	return g.cswitch > 0.0 or g.cside_t >= PlayAI.center_switch_wait(g, comm(), level) - ENTRY_CLOSING

func _center_guard(c: Swimmer) -> Swimmer:
	for d in defenders:
		if d.mark == c and not d.out and d.pos.distance_to(c.pos) <= CENTER_GUARD_R:
			return d
	return null

## The man on the back of the centre `c` as he swims in: his marker, within TRAIL_CONTEST_R of
## him and on the side a ball from `from` comes in on (not goal side of him, where it's past him).
func _trailer(c: Swimmer, from: Vector2) -> Swimmer:
	for d in defenders:
		if d.mark == c and not d.out and d.pos.distance_to(c.pos) <= TRAIL_CONTEST_R \
				and (d.pos - c.pos).dot(from - c.pos) > 0.0:
			return d
	return null

## The chance the man on the centre's back gets a hand to a ball in to him right now: TRAIL_PICK
## right on him, nothing at TRAIL_CONTEST_R, his defence against the centre's strength.
func trail_pick(c: Swimmer) -> float:
	var d := _trailer(c, ball.from if ball.in_flight() else (holder.pos if holder != null else ball.pos))
	if d == null:
		return 0.0
	var close := 1.0 - clampf((d.pos.distance_to(c.pos) - PlayAI.CENTER_TRAIL) / (TRAIL_CONTEST_R - PlayAI.CENTER_TRAIL), 0.0, 1.0)
	return clampf(TRAIL_PICK + (Attributes.eff_defense_legacy(d.player, comm()) - c.player.strength) * 0.004, 0.2, 0.8) * close

## A ball fed in to the centre is decided by his guard (center_entry), not the ordinary pick-off
## in the air. From the open side (the angle a swing buys) it goes round the passer's own man
## too; straight down from the point it goes right past him, and he can still get a hand to it,
## as can a help defender sagging into the hole.
func _entry_guard(d: Swimmer) -> bool:
	var c := ball.receiver
	if c == null or c.tag != "C" or entry == "" or d.mark == null:
		return false
	return d.mark == c or (entry == "open" and d.mark == ball.passer)

## The ball's reached the centre: thrown with his guard in the lane, it was never getting past
## him. His. No dice. (Decided where everybody was at the release, like the green ring.) Thrown to
## him swimming in with his man on his back, his man gets a hand to it entry_pick of the time.
func _entry_stolen(c: Swimmer) -> bool:
	if c != ball.receiver:
		return false
	var g: Swimmer = null
	if entry == "fronted":
		g = _center_guard(c)
	elif entry == "trailed" and entry_pick > 0.0:
		for d in defenders:
			if d.mark == c and not d.out and d.pos.distance_to(c.pos) <= TRAIL_CONTEST_R + 0.3:
				g = d
		if g != null and rng.randf() >= entry_pick:
			g = null
	if g == null:
		return false
	if entry == "fronted" and rng.randf() < DefenseFormation.FRONT_LOOSE:
		_deflect(g, false)   # his hands on it, but not cleanly: it's loose under his nose
		return true
	_turnover(g, "PICKED OFF!", "steal")
	return true

## The possession's first pass, just thrown at `c`: is it in to the centre straight through a
## guard who's properly on him and can get a hand to it (FIRST_GUARD_R)? Where the ball actually
## passes him (the stretch of its flight that can be picked off, as in _fly_pass), how high it is
## there, and whether he has time: {} if not, else where he takes it and whether cleanly.
func _first_entry_plan(c: Swimmer) -> Dictionary:
	if c == null or c.tag != "C" or kind == Kind.PENALTY or man_up > 0.0 or ball.passer == null:
		return {}
	if carry or entry == "trailed" or c.pos.distance_to(c.home) > CENTER_SPOT_R:
		return {}   # he's still swimming in: his man's chasing him, not set on him (TRAIL_PICK)
	if entry == "fronted":
		return {}   # right in the lane: that's already his every time (_entry_stolen)
	var g: Swimmer = null
	for d in defenders:
		if d.mark == c and not d.out:
			g = d
	if g == null or g.pos.distance_to(c.pos) > FIRST_GUARD_R or g.cswitch > 0.0:
		return {}
	if (g.pos - c.pos).dot(ball.from - c.pos) <= 0.0:
		return {}   # behind him, or level with him: the ball's past him before he's in it
	var span := ball.from.distance_to(ball.to)
	if span < 0.5:
		return {}
	var at := Geometry2D.get_closest_point_to_segment(g.pos, ball.from.lerp(ball.to, 0.2), ball.from.lerp(ball.to, 0.95))
	var u := ball.from.distance_to(at) / span
	var dfn := Attributes.unit(Attributes.eff_defense(g.player, comm()))
	var reach_r := DefenseFormation.TIP_REACH + (HAWK_REACH if Traits.has(g.player, "ball_hawk") else 0.0)
	var perp := g.pos.distance_to(at)
	if perp > reach_r or pass_z(u, ball.peak) > lerpf(FIRST_REACH_Z.x, FIRST_REACH_Z.y, dfn):
		return {}   # round him, or over his hands
	if u * ball.dur < lerpf(FIRST_REACT.x, FIRST_REACT.y, dfn):
		return {}   # on him before he could see it
	var q := 1.0 - perp / reach_r
	var clean := rng.randf() < clampf(FIRST_CLEAN.x + FIRST_CLEAN.y * q + (dfn - 0.5) * FIRST_CLEAN.z, 0.1, 0.9)
	return {"g": g, "u": u, "at": at, "clean": clean, "major": q < 0.5}

## A ball just thrown in to the centre `c` against a drop (the numbers: DROP_FULL and on): what comes
## of it, from how much of the lane the dropper really has. Sets first_entry to stop it at his hand,
## or drop_catch_foul for the foul on the catch; drop_entry says what was decided.
func _drop_entry_plan(c: Swimmer) -> void:
	if c == null or c.tag != "C" or kind == Kind.PENALTY or man_up > 0.0 or ball.passer == null or carry:
		return
	if entry == "trailed" or entry == "fronted" or c.pos.distance_to(c.home) > CENTER_SPOT_R:
		return   # (his own man's business: _entry_stolen)
	var dr := f_dropper
	if dr == null or dr.out or dr.duty == DefenseFormation.Duty.RECOVER:
		return
	var span := ball.from.distance_to(ball.to)
	if span < 0.5 or (dr.pos - c.pos).dot(ball.from - c.pos) <= 0.0:
		return   # he's behind the centre: the ball's past him
	var at := Geometry2D.get_closest_point_to_segment(dr.pos, ball.from.lerp(ball.to, 0.2), ball.from.lerp(ball.to, 0.95))
	var u := ball.from.distance_to(at) / span
	var perp := dr.pos.distance_to(at)
	var dfn := Attributes.unit(Attributes.eff_defense(dr.player, comm()))
	var reach_r := DefenseFormation.TIP_REACH + (HAWK_REACH if Traits.has(dr.player, "ball_hawk") else 0.0)
	var arm := reach_r + DROP_ARM
	var control := 1.0 - clampf((perp - DROP_LINE) / maxf(0.01, arm - DROP_LINE), 0.0, 1.0)
	if perp > arm or pass_z(u, ball.peak) > lerpf(FIRST_REACH_Z.x, FIRST_REACH_Z.y, dfn):
		control = 0.0   # round him, or over his hands
	var spot := c.pos + (ball.from - c.pos).normalized() * DefenseFormation.DROP_FRONT
	if dr.pos.distance_to(spot) > DefenseFormation.DROP_SET_R:
		control *= DROP_UNSET   # still getting there
	if u * ball.dur < lerpf(FIRST_REACT.x, FIRST_REACT.y, dfn):
		control *= DROP_UNSET   # on him before he could see it
	var passing := DefenseFormation.passing(ball.passer.player) / Attributes.MAX
	var true_ball := 1.0 - clampf(ball.to.distance_to(c.pos) / 1.2, 0.0, 1.0)
	var quality := passing * 0.7 + true_ball * 0.3
	var edge := Attributes.value(c.player, "str") - Attributes.eff_defense(dr.player, comm())
	var sep := clampf(0.5 + edge * 0.05 + (dr.pos.distance_to(c.pos) - DefenseFormation.DROP_FRONT) * 0.4, 0.0, 1.0)
	var block := clampf(DROP_BLOCK - DROP_PER_QUALITY * (quality - 0.5) - DROP_PER_SEP * (sep - 0.5), DROP_BLOCK_RANGE.x, DROP_BLOCK_RANGE.y) * control
	var stopped := control >= DROP_FULL or rng.randf() < block
	drop_entry = {"by": dr, "control": control, "quality": quality, "sep": sep, "block": block, "outcome": "catch"}
	if stopped:
		var clean := rng.randf() < clampf(DROP_CLEAN + (dfn - 0.5) * 0.4, 0.1, 0.9)
		first_entry = {"g": dr, "u": u, "at": at, "clean": clean, "major": control < 0.5}
		drop_entry.outcome = "steal" if clean else "tip"
	elif control > 0.0 and rng.randf() < clampf(DROP_FOUL + DROP_FOUL_EDGE * edge, 0.05, 0.8):
		drop_catch_foul = dr
		drop_entry.outcome = "foul"
	events.append({"k": "drop_entry", "outcome": drop_entry.outcome, "control": control})

## It's at his hand (_first_entry_plan, _drop_entry_plan): his arm's up for it, and he takes it or knocks it loose.
func _first_entry_hit() -> void:
	var g: Swimmer = first_entry.g
	var at: Vector2 = first_entry.at
	var clean := bool(first_entry.clean)
	var major := bool(first_entry.major)
	first_entry = {}
	ball.pos = at
	ball.checked.append(g)
	g.dive = 1.0 if at.y >= g.pos.y else -1.0   # (the arm up: PoolArt._block_arms)
	events.append({"k": "first_entry", "by": g.player, "clean": clean, "at": at})
	if clean:
		_turnover(g, "PICKED OFF!", "steal")
	else:
		_deflect(g, major)

## A defender got a hand to the pass but didn't hold it: it's knocked off its line (a little, or
## hard: DefenseFormation.deflect_drift) and loose on the water, for whoever gets there first.
func _deflect(d: Swimmer, major: bool) -> void:
	var drift := DefenseFormation.deflect_drift(ball.to - ball.from, major, rng)
	ball.receiver = null
	events.append({"k": "tip", "by": d.player, "major": major, "at": ball.pos})
	var thrower := ball.passer
	_go_loose(drift, DefenseFormation.TIP_SKIP)
	ball.tipped_by = d
	ball.tipped_from = thrower

# ------------------------------------------------------------------ the keeper comes out
## A ball into the centre `c`, thrown as it is now (ball.to, ball.dur): does the keeper read it and
## come out for it? Only if he can get there in time, the centre (and anybody else of theirs)
## can't, and it's at least KEEPER_OUT_MIN past where the centre could take it; the further past
## him, the more likely. A ball right to the centre never brings him out.
func _keeper_reads(c: Swimmer) -> bool:
	if c == null or c.tag != "C" or kind == Kind.PENALTY or keeper.pose != null or not keeper_in:
		return false
	var to := ball.to
	var flight := ball.dur
	if keeper.pos.distance_to(to) > KEEPER_OUT_R:
		return false
	var k_t := KEEPER_READ + time_to(keeper, to, KEEPER_GRAB_R, KEEPER_RUSH, 0.0)
	if k_t > flight + KEEPER_LATE:
		return false
	var past := INF   # how far past the centre's reach it lands
	for a in attackers:
		if a.out or a == holder:
			continue
		if time_to(a, to, CATCH_R, 1.2) <= flight:
			return false   # he's there as it lands
		if time_to(a, to, PICKUP_R, 1.25) <= k_t + 0.15:
			return false   # ...or on it before the keeper is
		if a == c:
			past = a.pos.distance_to(to) - CATCH_R - reach(a, flight, 1.2, (to - a.pos).normalized())
	if past < KEEPER_OUT_MIN:
		return false
	var chance := lerpf(KEEPER_OUT_BASE, 1.0, clampf((past - KEEPER_OUT_MIN) / (KEEPER_OUT_SURE - KEEPER_OUT_MIN), 0.0, 1.0))
	return rng.randf() < chance

## How far `s` can swim in `secs` going flat out (at `boost`) for one spot, from the way he's
## moving now: Swimmer.step's acceleration, then his top speed.
static func reach(s: Swimmer, secs: float, boost: float, dir := Vector2.ZERO) -> float:
	var vmax := s.top_speed * boost * s.surge
	var acc := s.accel * boost
	var v0 := clampf(s.vel.dot(dir), 0.0, vmax) if dir != Vector2.ZERO else 0.0
	var tv := (vmax - v0) / acc
	if secs <= tv:
		return v0 * secs + 0.5 * acc * secs * secs
	return v0 * tv + 0.5 * acc * tv * tv + vmax * (secs - tv)

## Seconds for `s` to get within `r` of `to` swimming flat out at `boost` (his way on counting
## unless `carry_on` is 0: a keeper sitting on his line starts from nothing).
static func time_to(s: Swimmer, to: Vector2, r: float, boost: float, carry_on := 1.0) -> float:
	var d := s.pos.distance_to(to) - r
	if d <= 0.0:
		return 0.0
	var dir := (to - s.pos).normalized() * carry_on
	var t := 0.0
	while t < 5.0 and reach(s, t, boost, dir) < d:
		t += 0.02
	return t

## The keeper's out for it and has it in reach: his ball, and theirs (possession changes at once).
func _keeper_claims() -> bool:
	if not keeper_rush or keeper.pos.distance_to(ball.pos) > KEEPER_GRAB_R:
		return false
	keeper_rush = false
	_turnover(keeper, "KEEPER CLAIMS IT", "steal")
	return true

func _fly_shot(dt: float) -> void:
	var sh := ball.shot
	if String(sh.outcome) == "pending":
		_fly_pending(dt)
		return
	ball.t = minf(1.0, ball.t + dt / ball.dur)
	var u := ball.t
	var flown := ball.lead + u * ball.dur   # seconds since it left his hand
	ball.pos = ball.from.lerp(ball.to, u)
	ball.z = shot_z(sh, u)
	_reach_for_shot(flown, dt)
	if not defending and sh.has("dive") and flown >= float(sh.keeper_go) and not sh.get("posed", false):
		# their keeper goes: the very dive ShotModel decided the shot with (what he read, what he saw,
		# a panic and all: KeeperDive.to_dict), from the moment it says he set off, so what you see is
		# what saved it (or didn't)
		sh["posed"] = true
		keeper.pose = KeeperDive.from_dict(sh.dive)
		keeper.pose.t = flown - float(sh.keeper_go)
	if not defending and sh.has("redive") and flown >= float(sh.redive_go) and not sh.get("reposed", false):
		# a lean the wrong way, corrected: the new dive takes over from where he'd got to
		sh["reposed"] = true
		keeper.pose = KeeperDive.from_dict(sh.redive)
		keeper.pose.t = flown - float(sh.redive_go)
	if not defending and sh.get("posed", false) and keeper.pose != null:
		keeper.pos.y = keeper.pose.body_y()
	keeper.vel = Vector2.ZERO
	keeper.target = keeper.pos
	# a goal counts the moment it's over the line, then carries on into the net
	if ball.t >= 1.0 or (String(sh.outcome) == "goal" and ball.pos.x >= Geo.GOAL_X):
		_resolve_shot()

## A shot's height off the water, `u` of the way along: from his hand down (or up) to where it
## crosses the line (ShotModel's `height`, drawn as KeeperDuel.LINE_Z).
static func shot_z(sh: Dictionary, u: float) -> float:
	var h := float(sh.get("height", 0.5))
	return lerpf(0.9, lerpf(KeeperDuel.LINE_Z.x, KeeperDuel.LINE_Z.y, h), u)

## The defenders going for the shot (ShotModel's attempts): from when each one sees it, his
## arm goes up towards where it will pass him and he leans into it, until just after it's
## by him or off his hand. A miss is a hand up that the ball goes past.
func _reach_for_shot(flown: float, dt: float) -> void:
	for a: Dictionary in ball.shot.get("attempts", []):
		var i := int(a.i)
		if i < 0 or i >= defenders.size() or flown < float(a.t0) or flown > float(a.t1) + BLOCK_SHOW:
			continue
		var d := defenders[i]
		var at: Vector2 = a.at
		d.dive = (1.0 if at.y >= d.pos.y else -1.0) * lerpf(0.3, 1.0, float(a.lean))
		var lean := at - d.pos
		if lean.length() > 0.05:
			d.vel = d.vel.move_toward(lean.normalized() * 1.6, 14.0 * dt)

## Multiplayer: the ball flies to the line, then hangs there (it's the other phone's save to
## make) until set_verdict(), or VERDICT_WAIT seconds, whichever comes first.
const VERDICT_WAIT := 2.5

func _fly_pending(dt: float) -> void:
	ball.t = minf(0.97, ball.t + dt / ball.dur)
	ball.pos = ball.from.lerp(ball.to, ball.t)
	ball.z = shot_z(ball.shot, ball.t)
	_reach_for_shot(ball.lead + ball.t * ball.dur, dt)
	keeper.vel = Vector2.ZERO
	keeper.target = keeper.pos
	if ball.t < 0.97:
		return
	waiting_t += dt
	if verdict == "" and waiting_t < VERDICT_WAIT:
		return
	var sh := ball.shot
	var v := verdict if verdict != "" else String(sh.auto)
	sh.outcome = v
	var cy := float(sh.cross_y)
	if defending:
		pass   # your keeper: he's wherever your dive took him (MatchFlow's duel)
	elif v == "save" or v == "parry":
		keeper.dive = clampf((cy - keeper.pos.y) / 1.2, -1.0, 1.0)
		keeper.pos.y = cy
	else:
		keeper.dive = -signf(cy - keeper.pos.y) * 0.6
	_resolve_shot()

## The other phone's keeper: "goal", "save" or "parry", for shot `n` of this possession. A shot
## that was going wide or at the frame keeps that ("miss", "post"), whatever the dive.
func set_verdict(v: String, n: int = -1) -> void:
	if n >= 0 and n != shot_n:
		return
	if ball.state == Ball.State.SHOT and String(ball.shot.get("auto", "")) in ["miss", "post"]:
		verdict = String(ball.shot.auto)
		return
	if v in ["goal", "save", "parry"]:
		verdict = v

func waiting_for_verdict() -> bool:
	return ball.state == Ball.State.SHOT and String(ball.shot.get("outcome", "")) == "pending"

func _resolve_shot() -> void:
	var sh := ball.shot
	var shooter := ball.shooter
	var outcome := String(sh.outcome)
	if kind == Kind.PENALTY and outcome in ["parry", "post", "block"]:
		outcome = "save" if outcome == "parry" else "miss"
	if outcome in ["save", "parry"] and not defending:
		if keeper.pose == null or keeper.pose.phase() in [KeeperDive.Phase.REACT, KeeperDive.Phase.RECOVER, KeeperDive.Phase.READY]:
			# on him before he'd set off (or once he was back down): the body block, up out of the water
			keeper.pose = KeeperDive.from_body(KeeperDive.body_of(keeper.player, home_keeper), KeeperDive.CENTRE, keeper.pos.y)
			keeper.pose.t = keeper.pose.extend_time()
		keeper.pose.hit(float(sh.cross_y))
	match outcome:
		"goal":
			ball.state = Ball.State.DEAD
			ball.into_net((ball.to - ball.from) / ball.dur, Geo.GOAL_X, 1.0)
			var extra := {"scorer": shooter.player}
			if sh.get("assist") != null:
				extra["assist"] = (sh.assist as Swimmer).player
			_finish("goal", "GOAL!", extra)
		"save":
			ball.state = Ball.State.DEAD
			holder = keeper
			keeper.arm = 1.0
			ball.secure()   # (from where it met his hand into his hands: never a jump, never left hanging)
			_hold_ball()
			events.append({"k": "save"})
			_finish("save", "SAVED!", {"shooter": shooter.player})
		"parry":
			events.append({"k": "save"})
			events.append({"k": "rebound", "text": "PARRIED!"})
			shot_clock = maxf(shot_clock, 20.0)
			_go_loose(Vector2(-rng.randf_range(2.5, 4.0), rng.randf_range(-2.5, 2.5)))
		"post":
			events.append({"k": "rebound", "text": "OFF THE POST!"})
			shot_clock = maxf(shot_clock, 20.0)
			_go_loose(Vector2(-rng.randf_range(2.0, 3.5), rng.randf_range(-2.0, 2.0)))
			frame_rebound = true   # (off a post or the bar: the centre who gathers it is fouled)
		"block":
			var bi := int(sh.get("blocker", -1))
			var by: Swimmer = defenders[bi] if bi >= 0 and bi < defenders.size() else null
			events.append({"k": "block", "by": by.player if by != null else null, "at": ball.pos})
			var drift: Vector2 = sh.get("deflect", Vector2.ZERO)
			if drift == Vector2.ZERO:
				drift = Vector2(-rng.randf_range(0.5, 2.0), rng.randf_range(-2.0, 2.0))
			_go_loose(drift, BLOCK_SKIP)
		_:
			ball.state = Ball.State.DEAD
			_finish("miss", "WIDE!", {"shooter": shooter.player})

func _go_loose(drift: Vector2, skip: float = 0.0) -> void:
	frame_rebound = false
	ball.passer = null
	ball.state = Ball.State.LOOSE
	ball.z = 0.0
	ball.drift = drift
	loose_t = 0.0
	loose_skip = skip

func _loose(dt: float) -> void:
	loose_t += dt
	ball.pos = Geo.clamp_in_pool(ball.pos + ball.drift * dt)
	ball.drift = ball.drift.move_toward(Vector2.ZERO, dt * 3.0)
	ball.z = 0.0
	if loose_t < loose_skip:
		return
	if keeper_rush:
		if _keeper_claims():
			return
		if loose_t > KEEPER_LATE:
			keeper_rush = false   # beaten to it after all: back to his goal
	var best: Swimmer = null
	var bd := PICKUP_R
	for s in bodies():
		if s.out:
			continue
		var dd := s.pos.distance_to(ball.pos)
		if dd < bd:
			bd = dd
			best = s
	if best == null:
		if loose_t > LOOSE_GIVE_UP:
			_finish("turnover", "TURNOVER")
		return
	var off_frame := frame_rebound
	frame_rebound = false   # (one rebound, one gather: whoever it is)
	if best.side == Swimmer.Side.US:
		events.append({"k": "recover"})
		_catch(best, false)
		if off_frame and best.tag == "C":
			_center_rebound_foul(best)
	elif ball.tipped_by != null and not best.keeper:
		_turnover(best, "TIPPED!", "steal")   # (a deflection won back: the defence's steal)
	else:
		_turnover(best, "KEEPER'S BALL" if best.keeper else "THEIR BALL", "turnover")

## The centre has gathered a rebound off the post or the bar, at 2 m with his guard (or the dropper)
## right on him: he's fouled, at once, an ordinary foul (never a penalty or an exclusion from this
## alone). The free throw is his team's, with the usual restart; and because the whistle comes
## before anything else this frame, no strip, challenge or dropper's crash can take it off him
## (they all stand down for a restart). It isn't a pass in to him either: no entry dice are rolled.
func _center_rebound_foul(c: Swimmer) -> void:
	var d := _marker(c)
	if d == null or over:
		return
	events.append({"k": "center_rebound", "by": d.player})
	_ordinary_foul(c, d, false)

func _catch(s: Swimmer, from_pass: bool) -> void:
	give_ball(s)
	events.append({"k": "catch", "tag": s.tag, "f": formation, "pass": from_pass})
	if from_pass:
		catch_t = 0.0
	if from_pass and kind != Kind.PENALTY:
		_catch_foul(s)

# ------------------------------------------------------------------ fouls
## Catching near the goal draws contact. The centre with a real entry in his hands (from the open
## side, or straight down from the point) is held by his beaten man: that's the exclusion he lives
## on, whistled before he can shoot (_center_hold_foul). Anybody else caught in the box with his
## man behind him can draw one on the catch. Penalties only come on the shot (CenterDefense.foul_on_shot).
func _catch_foul(s: Swimmer) -> void:
	if s.tag == "C" and s == ball.receiver and drop_catch_foul != null:
		# through a contested drop, with the dropper on him as he catches it: an ordinary foul
		center_fed = s
		center_foul = true
		center_foul_excl = false
		center_foul_by = drop_catch_foul
		drop_catch_foul = null
		return
	if s.tag == "C" and s == ball.receiver and entry in ["open", "straight"]:
		center_fed = s
		_roll_center_foul(s)
		return
	var d := _marker(s)
	if d == null or d.pos.distance_to(s.pos) > FOUL_REACH or man_up > 0.0:
		return
	if in_goalie_box(s.pos) and d.pos.x < s.pos.x and rng.randf() < CATCH_EXCL:
		_exclusion(d, s)

## The goalie box: inside the 5 m line, in front of the goal.
static func in_goalie_box(at: Vector2) -> bool:
	return at.x >= Geo.FIVE_M and absf(at.y - Geo.GOAL_Y) <= GOALIE_BOX_HALF

## His own man (his marker, or the nearest defender if nobody's on him), if he's close enough
## to foul him.
func _fouler(s: Swimmer) -> Swimmer:
	var d := _marker(s)
	if d == null or d.pos.distance_to(s.pos) > FOUL_REACH:
		return null
	return d

## Inside water: `s` is between his own man and the goal, that man behind him (the far side from
## the goal: Play.behind, the same water a foul from him is judged on) and close enough to foul
## him. Beside him or goal side of him (ball side) isn't.
func has_inside_water(s: Swimmer) -> bool:
	var d := _fouler(s)
	return d != null and behind(s.pos, d.pos, Geo.goal_center())

## The fed centre catches it and his beaten man hangs on (CENTER_EXCL, a WRESTLER either side
## shifting it): decided on the catch, whistled CENTER_FOUL_T later (_center_hold_foul).
func _roll_center_foul(s: Swimmer) -> void:
	var d := _center_guard(s)
	if d == null or man_up > 0.0 or kind == Kind.PENALTY:
		return
	if entry == "straight":
		# a poor ball, in beside his man: he catches it, his man's on him, and fouls him as he turns
		# (an ordinary foul: he has to pass it, DefenseFormation.POOR_FOUL)
		center_foul_excl = false
		center_foul = rng.randf() < DefenseFormation.POOR_FOUL
		return
	if DefenseFormation.dropper_near(self, s):
		return   # the dropper's there to get to him: no exclusion (DefenseFormation.interference)
	center_foul_excl = true
	var chance := CENTER_EXCL
	if Traits.has(s.player, "wrestler"):
		chance += WRESTLER_EDGE
	if Traits.has(d.player, "wrestler"):
		chance -= WRESTLER_EDGE
	center_foul = rng.randf() < chance

## The whistle on the fed centre's man: only while the centre still has the ball down in his
## hands. Once he's up to shoot it's gone (a foul on the shot never sends anybody out), and so it
## is once the ball's left his hand (give_ball, a new holder, clears it).
func _center_hold_foul() -> void:
	if not center_foul:
		return
	if holder == null or holder != center_fed or ball.state != Ball.State.HELD or raised or man_up > 0.0:
		center_foul = false
		return
	if catch_t < CENTER_FOUL_T or freeze > 0.0 or restart:
		return
	center_foul = false
	var d := _center_guard(holder)
	if center_foul_by != null:
		d = center_foul_by   # (the dropper, in front of him: never one from behind)
		center_foul_by = null
	if d != null and center_foul_excl:
		_exclusion(d, holder)
	elif d != null:
		_ordinary_foul(holder, d)

func _pressure(dt: float) -> void:
	if kind == Kind.PENALTY or holder == null:
		return
	if restart:
		# the free throw's taker is protected until he lets it go: no contact building up, no
		# second whistle, no strip
		foul_t = 0.0
		pressure = 0.0
		return
	# an ordinary foul only comes from contact, held (DefenseFormation.contact_defender: his own man,
	# there, not behind him): FOUL_SETTLE s of it before the whistle can go at all, so a catch is
	# never fouled at once and a man still swimming to him has to get there first
	var c := DefenseFormation.contact_defender(self, holder)
	if c != null:
		foul_t += dt
	else:
		foul_t = maxf(0.0, foul_t - dt * DefenseFormation.FOUL_DECAY)
	var d := _nearest_defender(holder.pos)
	if d == null:
		return
	if d.pos.distance_to(holder.pos) < PRESSURE_R:
		pressure += dt
	else:
		pressure = maxf(0.0, pressure - dt * 2.0)
	if pressure >= 0.7 and d.back_off <= 0.0:
		var gap := (Attributes.eff_defense_legacy(d.player, comm()) - holder.player.live("passing")) / 100.0
		# holding the ball up is safe for a while; dawdle and the press gets a hand on it. Only a
		# man set in front of him can take it: from his side or behind, it's a foul at most.
		var steal_rate := clampf(STRIP_RATE + STRIP_SKILL * gap + DAWDLE_RATE * maxf(0.0, pressure - PRESS_DAWDLE), 0.002, 0.3) * _steal_edge()
		if PlayDefense.side_of(d, holder) == PlayDefense.Zone.FRONT and rng.randf() < steal_rate * dt:
			_turnover(d, "STOLEN!", "steal")
			return
	# (a closely guarded wing against PRESS or M-DROP: whistled sooner and more often, DefenseFormation.wing_pressure)
	var wing := DefenseFormation.wing_pressure(self, holder)
	var settle := DefenseFormation.WING_SETTLE if wing else DefenseFormation.FOUL_SETTLE
	var rate := DefenseFormation.FOUL_RATE * (DefenseFormation.WING_FOUL_MULT if wing else 1.0)
	if c != null and c.back_off <= 0.0 and foul_t >= settle \
			and rng.randf() < rate * foul_pressure(c, holder) * dt:
		_ordinary_foul(holder, c)

## How much more (less) often `d`'s press forces an ordinary foul on `s` than an even match-up:
## his effective Defense against `s`'s Strength (Attributes.foul_mult: (D - S) x 4%).
func foul_pressure(d: Swimmer, s: Swimmer) -> float:
	return Attributes.foul_mult(Attributes.eff_defense(d.player, comm()), s.player)

## The defence's organising from its keeper (Attributes.comm_bonus: COMMUNICATION), while he's in
## the water: added to each defender's effective Defense, once, by each calculation that uses it.
func comm() -> float:
	return Attributes.comm_bonus(keeper.player) if keeper_in and keeper != null and not keeper.out else 0.0

func _steal_edge() -> float:
	return YOUR_DEFENCE_STEALS if defending else 1.0

## Every defensive foul's whistle: from behind on a clear scoring chance it's a penalty (penalty_foul),
## whoever fouled and however (a press, a challenge, a pull, a piston's contact); otherwise an
## ordinary foul, a free throw.
## `may_penalty` false: an ordinary foul whatever (the centre's rebound: _center_rebound_foul).
func _ordinary_foul(s: Swimmer, d: Swimmer, may_penalty: bool = true) -> void:
	if may_penalty and penalty_foul(s, d):
		events.append({"k": "behind_penalty", "by": d.player})
		_penalty(s, d)
		return
	freeze = 0.7
	pressure = 0.0
	foul_t = 0.0
	DefenseFormation.end_push(self)
	catch_t = INF   # after the whistle it's a free throw, not a catch and shoot
	center_fed = null
	d.back_off = 1.6
	free_throw = s.pos.x >= Geo.SIX_M
	_start_restart(free_throw)
	events.append({"k": "foul"})

## A whistle's restart: the shot clock stops (it keeps whatever the foul left it: an exclusion's
## reset to 20 s stays), the taker is protected, and `inside` (fouled inside 6 m) means a pass
## first. Called once per whistle; a second one can't come while it's on.
func _start_restart(inside: bool) -> void:
	restart = true
	restart_t = 0.0
	pass_first = inside
	foul_t = 0.0
	pressure = 0.0

## The free throw's away: the shot clock runs on from where it stopped and play is live again.
func _end_restart() -> void:
	restart = false
	restart_t = 0.0
	pass_first = false

## RESTART_DELAY live seconds holding the free throw (stalling, the clock stopped): the restart
## lapses, so the shot clock runs again and he can be played; a pass inside 6 m is still owed
## (pass_first stays until he passes).
func _lapse_restart() -> void:
	restart = false
	restart_t = 0.0
	events.append({"k": "restart_delay"})

## No shot allowed right now: a free throw inside 6 m being taken, or one awarded inside 6 m not
## yet passed (pass_first, wherever he's swum to). A penalty is never barred.
func shot_barred() -> bool:
	if kind == Kind.PENALTY:
		return false
	return pass_first or (free_throw and holder != null and holder.pos.x >= Geo.SIX_M)

## `d` is sent out; `drawn` is the attacker who drew it (credited with it in the box score).
func _exclusion(d: Swimmer, drawn: Swimmer = null) -> void:
	excluded = d
	excl_player = d.player
	d.out = true
	d.rejoin = false
	man_up = MAN_UP_TIME
	man_up_live = false   # (it starts on the power play's first pass)
	shot_clock = maxf(shot_clock, 20.0)
	freeze = 1.2
	catch_t = INF
	free_throw = holder != null and holder.pos.x >= Geo.SIX_M
	_start_restart(free_throw)
	if carry:
		end_counter()   # the whistle: it's a power play now
	PlaySetup.apply_formation(self, true)
	zone_set = false
	for a in attackers:
		a.drive_t = 0.0
		a.called = 0.0
	events.append({"k": "exclusion", "text": "EXCLUSION  %s" % d.player.tag(),
		"drawn_by": drawn.player if drawn != null else null, "by": d.player})

## A 6 on 5 left over from the end of the last period (MatchFlow.carry_man_up): the team that had
## it won the sprint, so this possession opens with it, already set up in the 4-2 and the same man
## (`who`, if he's in the water; else one of theirs) in the box. `secs` is the time it had left;
## its clock waits for the first pass, as any 6 on 5's does.
func open_man_up(secs: float, who: PoloPlayer) -> void:
	if secs <= 0.0 or kind == Kind.PENALTY:
		return
	var d: Swimmer = null
	for s in defenders:
		if s.out:
			continue
		if s.player == who:
			d = s
			break
		if d == null or s.dtag != "C":
			d = s   # (failing him: anyone but the centre's guard, if there's anyone else)
	if d == null:
		return
	excluded = d
	excl_player = d.player
	d.out = true
	d.rejoin = false
	d.pos = Geo.REENTRY
	man_up = secs
	man_up_live = false
	PlaySetup.apply_formation(self, true)
	zone_set = false
	for a in attackers:
		if not a.out:
			a.pos = a.home
			a.vel = Vector2.ZERO
	for s in defenders:
		if not s.out and s.mark != null:
			s.pos = s.mark.pos + Vector2(1.0, 0.0)   # (goal side of his man; the zone sorts itself out)
			s.vel = Vector2.ZERO
	for s in bodies():
		s.target = s.pos
	if holder != null:
		_hold_ball()
	events.append({"k": "man_up_carry", "secs": secs, "by": d.player})

func _end_man_up() -> void:
	if excluded != null:
		if excluded.player.rolled:
			# ROLLED on that exclusion: his replacement comes in now, when the rules let him (never
			# sooner); with nobody left to come in, the place stays empty
			var sub := _roll_sub(excluded)
			if sub != null:
				excluded.player = sub
				excluded.out = false
				excluded.rejoin = true
		else:
			excluded.out = false
			excluded.rejoin = true
		excluded = null
	PlaySetup.apply_formation(self, false)
	PlayAI.restore_marks(self)
	_reopen_call()
	events.append({"k": "even"})

## Your defence back to even strength (CALL DROP, FormationBar): the 6 on 5 overrode any drop you'd
## called, so you're back in your normal defence with the call open again, to make again if you want
## it. The computer's defence (and yours in SIM, ai_drop) runs its own call (DropCall), untouched.
func _reopen_call() -> void:
	if not defending or ai_drop >= 0 or kind == Kind.PENALTY:
		return
	formation_locked = false
	if formation != DefenseFormation.F.PRESS or drop_pending >= 0:
		form_up(DefenseFormation.F.PRESS)

## Who takes a ROLLED defender's place: the first of his team's starters (PoloTeam.starters:
## the rolled one swapped out) not already in the water; null if there's nobody.
func _roll_sub(d: Swimmer) -> PoloPlayer:
	var team: PoloTeam = them
	var on := {}
	for s in defenders + [keeper]:
		on[s.player] = true
	for p in team.starters():
		if not on.has(p) and p.is_available():
			return p
	return null

## `d` fouling `s` is a penalty: from behind him (fouled_from_behind) on a clear chance (clear_chance).
## No dice.
func penalty_foul(s: Swimmer, d: Swimmer) -> bool:
	return kind != Kind.PENALTY and fouled_from_behind(s, d) and clear_chance(s, d)

func fouled_from_behind(s: Swimmer, d: Swimmer) -> bool:
	if s == null or d == null:
		return false
	return behind(s.pos, d.pos, Geo.goal_center())

## Is a defender at `d` behind a man at `a` attacking `goal`, beaten (`a` has inside water on him):
## at least BEHIND_MIN back from him along his line to it, and within the inside-water cone
## (INSIDE_WATER_COS, about 50 degrees) of straight behind? From the real positions only, whichever
## way he's attacking, whatever the formation. The one test of "beaten": inside water
## (has_inside_water) and a foul from behind (fouled_from_behind) can never disagree, so a man
## with inside water fouled by the man he has it on, on a clear chance, is a penalty.
static func behind(a: Vector2, d: Vector2, goal: Vector2) -> bool:
	var g := goal - a
	var v := a - d   # (from the defender to the man)
	if g.length() < 0.01 or v.length() < 0.01:
		return false
	var gn := g.normalized()
	return v.dot(gn) >= BEHIND_MIN and v.normalized().dot(gn) >= INSIDE_WATER_COS

## A clear scoring chance for `s` (fouled by `d`): in the goalie box, and a probable goal or a look
## at the goal with his way to it open (nobody but `d` and the keeper in it).
func clear_chance(s: Swimmer, d: Swimmer = null) -> bool:
	if s == null or not in_goalie_box(s.pos):
		return false
	if CenterDefense.probable(self, s):
		return true
	return close_chance(s) > 0.0 and open_path(s, d)

func open_path(s: Swimmer, d: Swimmer = null) -> bool:
	var to := Geo.goal_center() - s.pos
	var span2 := to.length_squared()
	if span2 < 0.01:
		return true
	for e in defenders:
		if e == d or e.out:
			continue
		var u := (e.pos - s.pos).dot(to) / span2
		if u > 0.0 and u < 1.0 and (s.pos + to * u).distance_to(e.pos) < OPEN_LANE:
			return false
	return true

## A 5 m penalty for `s`, fouled by `by` (his personal foul: MatchFlow).
func _penalty(s: Swimmer, by: Swimmer = null) -> void:
	events.append({"k": "penalty"})
	_finish("penalty", "PENALTY!", {"fouled": s.player, "fouled_by": by.player if by != null else null})

func _turnover(s: Swimmer, text: String, why: String) -> void:
	var lost := holder   # stripped of it (a pass picked off in the air beats nobody in particular)
	# the box score's turnover: the man stripped, else the passer whose pass was picked off (or
	# tipped loose and won)
	# (lost_by stays as it was: it only shapes the breakout)
	var gave: Swimmer = lost if lost != null else (ball.passer if ball.state == Ball.State.PASS else (ball.tipped_from if ball.tipped_by != null else null))
	ball.state = Ball.State.DEAD
	holder = s
	s.arm = 1.0
	if s.keeper:
		ball.secure()   # (the keeper out for it gathers it in)
	_hold_ball()
	_finish(why, text, {"by": s.player, "lost_by": lost.player if lost != null else null,
		"turnover_by": gave.player if gave != null and gave.side != s.side else null})

## The catch-and-shoot bonus the man with the ball has right now, 0..1 (ShotModel.catch_shoot):
## full just after he catches a pass, fading to nothing; 0 once it's thrown, whistled or held.
## The screen draws it as the gold glow.
func catch_glow() -> float:
	if over or holder == null or ball.state != Ball.State.HELD or freeze > 0.0 or kind == Kind.PENALTY:
		return 0.0
	return ShotModel.catch_shoot(catch_t, cs_k)

# ------------------------------------------------------------------ counterattacks
## Where everybody is right now, for the next possession (the other team's, attacking the
## other way): {pos: {PoloPlayer: Vector2}, vel, holder, lost_by}, positions and speeds turned
## round into that possession's frame (it attacks x = 30 too). See PlaySetup._counter.
## Taken the moment the ball changed hands (the breakout that follows doesn't move it on).
func snapshot() -> Dictionary:
	if not handover.is_empty():
		return handover
	var pos := {}
	var vel := {}
	for s in bodies():
		pos[s.player] = Vector2(Geo.LENGTH - s.pos.x, s.pos.y)
		vel[s.player] = Vector2(-s.vel.x, s.vel.y)
	return {"pos": pos, "vel": vel, "holder": holder.player if holder != null else null,
		"lost_by": result.get("lost_by"), "why": result.get("outcome", ""),
		"at": Vector2(Geo.LENGTH - ball.pos.x, ball.pos.y)}

## The break right now: (attackers level with the ball or close behind it, at most
## BREAK_FRONT; defenders alongside the ball or goal side of it). The centre's man swimming in on
## his back (PlayAI._center_trail) is busy with him, not back stopping the break.
func break_numbers() -> Vector2i:
	var bx := holder.pos.x if holder != null else ball.pos.x
	var n := Vector2i.ZERO
	for a in attackers:
		if not a.out and a.pos.x >= bx - BREAK_TRAIL:
			n.x += 1
	var on_centre := PlayAI.center_pair(self)
	if on_centre != null and (on_centre.mark == null or on_centre.mark.tag != "C" \
			or on_centre.pos.distance_to(on_centre.mark.pos) > PlayAI.CENTER_STICK_R):
		on_centre = null
	for d in defenders:
		if not d.out and d.pos.x >= bx - BREAK_BACK and d != on_centre:
			n.y += 1
	n.x = mini(n.x, BREAK_FRONT)
	return n

## Is it a break at all? Only with more attackers in it than defenders back (2 on 1, 3 on 2,
## 3 on 0...); level numbers (1 on 1, 2 on 2, 3 on 3) are a normal possession.
func is_break() -> bool:
	var n := break_numbers()
	return n.x > n.y

## The counter's on: every BREAK_CHECK the numbers are looked at again. Once the defence is back
## in numbers (or it's gone on too long), the attack sets up. The carrier swimming it in to
## COUNTER_STOP ends it too (PlayAI._carry).
func _watch_break(dt: float) -> void:
	break_t -= dt
	if ball.state != Ball.State.HELD:
		return   # (decided with the ball in a man's hands, so he knows to take it back out)
	if elapsed >= COUNTER_MAX:
		end_counter()
		return
	if break_t > 0.0:
		return
	break_t = BREAK_CHECK
	# the defence has caught up (it was 3 on 2, now it's 3 on 3): the advantage is gone
	if not is_break():
		end_counter()

## `s`'s counter speed this frame (Swimmer.surge): COUNTER_SURGE for an attacking field player in
## the counter (carry) swimming forward or across, 1.0 for everybody else: the defence getting back,
## the keepers, a man excluded or swimming back in, and everybody once the counter's over.
func counter_surge(s: Swimmer) -> float:
	if not carry or over or s.keeper or s.out or s.rejoin or not attackers.has(s):
		return 1.0
	var to := s.target - s.pos
	if to.x < -0.25 * to.length():
		return 1.0   # (going back the way he came: not part of the break)
	return COUNTER_SURGE

## Every attacking field player still in the water (not excluded, not on his way back in) is over
## halfway. The keepers don't count.
func attack_over_half() -> bool:
	for a in attackers:
		if a.out or a.rejoin or a.keeper:
			continue
		if a.pos.x <= Geo.HALF:
			return false
	return true

## THEIR counter (you defending it, OffenseAI choosing): no backward passes yet, while any of their
## field players is still in his own half. Never on your attack, never in a settled possession.
func back_pass_barred() -> bool:
	return defending and carry and not over and not attack_over_half()

## A ball from `from` to `to` goes backwards (towards the attack's own end) by more than BACK_PASS_SLACK.
static func is_back_pass(from: Vector2, to: Vector2) -> bool:
	return to.x < from.x - BACK_PASS_SLACK

## The counter's over without a shot: the carrier takes it back out to his spot (if he's in
## front of it), the centre goes to 2 m, everybody else to theirs, the defence picks up its men.
func end_counter() -> void:
	if not carry:
		return
	carry = false
	counter_t = 0.0
	lanes.clear()
	lane_key = ""
	if holder != null and holder.tag != "C":
		var goal := Geo.goal_center()
		if holder.pos.distance_to(goal) < holder.home.distance_to(goal) - 0.3:
			rotating = holder
	drive_timer = maxf(drive_timer, 2.0)
	if man_up <= 0.0:
		PlayAI.restore_marks(self)
	events.append({"k": "settle"})

func _finish(outcome: String, text: String, extra: Dictionary = {}) -> void:
	over = true
	result = {"outcome": outcome, "text": text, "elapsed": elapsed}
	result.merge(extra)
	events.append({"k": "end", "outcome": outcome, "text": text})
	if outcome in BREAKOUT_OUTCOMES and kind != Kind.PENALTY:
		handover = snapshot()
		_start_breakout()

## The ball's changed hands: nobody carries on with the old play. The team that won it turns
## at once (nobody drifts back towards his own goal) and goes, the man with it first; the team
## that lost it takes a moment to turn (DEFENCE_TURN, the man who lost it a little more), then
## gets back. Its own dice, so the game's rng (and what the next possession makes of it) is
## untouched.
func _start_breakout() -> void:
	breakout = true
	raised = false
	var r := RandomNumberGenerator.new()
	r.seed = hash([elapsed, ball.pos, attackers.size()])
	var lost_by: Variant = result.get("lost_by")
	if excluded != null:
		excluded.out = false   # his team has the ball: an excluded man comes straight back in
		excluded.rejoin = true
		excluded = null
	for d in defenders:
		d.react = 0.0 if d == holder else r.randf_range(PlaySetup.ATTACK_REACT.x, PlaySetup.ATTACK_REACT.y)
		d.facing = -1.0
		d.vel.x = minf(d.vel.x, 0.0)
		d.drive_t = 0.0
		if d == holder:
			d.arm = 0.95   # (eases down: he swims it, rather than holding it up)
	for a in attackers:
		a.react = r.randf_range(PlaySetup.DEFENCE_TURN.x, PlaySetup.DEFENCE_TURN.y)
		if lost_by != null and a.player == lost_by:
			a.react += BREAKOUT_LOSER_TURN
		a.drive_t = 0.0
		a.called = 0.0
	_pair_breakout_centre()

## Who'll be the centre next possession (the team that won it: PlaySetup.build's "C") and the
## man of ours who'll guard him (our best wrestler): he picks him up and goes down the pool on his
## back, at his pace. With him already (PlaySetup.CENTER_WITH_R), he turns when the centre does.
func _pair_breakout_centre() -> void:
	var c_player: PoloPlayer = them.starters()[1]
	var g_player: PoloPlayer = PlaySetup.wrestlers(us.starters())[0]
	for d in defenders:
		if d.player == c_player and not d.out and d != holder:
			breakout_centre = d
	for a in attackers:
		if a.player == g_player and not a.out:
			breakout_guard = a
	if breakout_centre == null or breakout_guard == null:
		breakout_centre = null
		breakout_guard = null
		return
	if breakout_centre.pos.distance_to(breakout_guard.pos) <= PlaySetup.CENTER_WITH_R:
		breakout_guard.react = minf(breakout_guard.react, breakout_centre.react)

# ------------------------------------------------------------------ helpers
func _move(dt: float) -> void:
	var list := bodies()
	for s in list:
		s.surge = counter_surge(s)
		s.step(dt)
	for i in list.size():
		for j in range(i + 1, list.size()):
			var a := list[i]
			var b := list[j]
			if a.out or b.out or a.rejoin or b.rejoin:
				continue
			var d := b.pos - a.pos
			var l := d.length()
			if l < 0.6 and l > 0.001:
				var push := d / l * (0.6 - l) * 0.5
				if not a.keeper:
					a.pos -= push
				if not b.keeper:
					b.pos += push
	for s in list:
		if s.rejoin:
			# swimming in from the exclusion box (behind the goal line): no snapping him in, he's
			# back in the field when he's swum into it
			if Geo.clamp_in_pool(s.pos).distance_squared_to(s.pos) > 0.0001:
				continue
			s.rejoin = false
		if not s.out:
			s.pos = Geo.clamp_in_pool(s.pos)

func _pickers() -> Array[Swimmer]:
	var out: Array[Swimmer] = []
	for d in defenders:
		if not d.out:
			out.append(d)
	if keeper_in:
		out.append(keeper)
	return out

func _receiver_for(p: Vector2, radius: float = 3.5) -> Swimmer:
	var best: Swimmer = null
	var bd := radius
	for a in attackers:
		if a == holder:
			continue
		var dd := a.pos.distance_to(p)
		if dd < bd:
			bd = dd
			best = a
	return best

func _catcher_near(p: Vector2) -> Swimmer:
	if ball.receiver != null and ball.receiver.pos.distance_to(p) < CATCH_R:
		return ball.receiver
	var best: Swimmer = null
	var bd := CATCH_R * 0.8
	for a in attackers:
		var dd := a.pos.distance_to(p)
		if dd < bd:
			bd = dd
			best = a
	return best

func _marker(s: Swimmer) -> Swimmer:
	for d in defenders:
		if d.mark == s and not d.out:
			return d
	return _nearest_defender(s.pos)

func _nearest_defender(at: Vector2) -> Swimmer:
	var best: Swimmer = null
	var bd := INF
	for d in defenders:
		if d.out:
			continue
		var dd := d.pos.distance_to(at)
		if dd < bd:
			bd = dd
			best = d
	return best

## The defender (or keeper) who could pick off a pass to `to` if nobody moved, or null.
## Same reach rules as the real flight, with a little slack for them reacting.
func pass_risk(to: Vector2, receiver: Swimmer) -> Swimmer:
	if holder == null:
		return null
	var from := _hand(holder)
	var peak := peak_for(from, to, holder, receiver)
	var entry := center_entry(from, receiver) if receiver != null else ""
	for d in _pickers():
		if entry != "" and d.mark == receiver:
			if entry == "fronted" or (entry == "trailed" and _trailer(receiver, from) == d):
				return d   # his guard's on that side (or on his back as he swims in): it's his, or could be
			continue
		if entry == "open" and d.mark == holder:
			continue   # (from the open side it goes round the passer's own man: _entry_guard)
		var reach_z := 1.9 if d.keeper else 1.35
		var reach_r := ((SWING_KEEPER_R if is_swing(from, to, holder, receiver) else 0.9) if d.keeper else DefenseFormation.TIP_REACH) + 0.12
		var u := 0.2
		while u < 0.9:
			var bp := from.lerp(to, u)
			var z := pass_z(u, peak)
			var dd := d.pos.distance_to(bp)
			if z <= reach_z and dd <= reach_r and (receiver == null or receiver.pos.distance_to(bp) >= dd):
				return d
			u += 0.04
	return null

## Who a DRIVE call on `side` would send right now, or null (the ball's not ours to call with,
## or it's a power play: the 4-2 has nobody to drive).
func drive_candidate(side: String) -> Swimmer:
	if over or man_up > 0.0 or kind == Kind.PENALTY or holder == null or holder.side != Swimmer.Side.US:
		return null
	var slid := DefenseFormation.slide_man(self)   # (left open by a 5 DROP: the first to go)
	if slid != null and slid.tag in DRIVE_CALLS.get(side, []) and slid != holder and not slid.out:
		return slid
	for t in DRIVE_CALLS.get(side, []):
		for a in attackers:
			if a.tag == t and a != holder and not a.out:
				return a
	return null

## The call: he drives at the goal now, flat out, and the next automatic drive waits.
func call_drive(side: String) -> Swimmer:
	var a := drive_candidate(side)
	if a == null:
		return null
	a.drive_t = CALLED_DRIVE
	a.called = CALLED_BURST
	a.drive_goal = Vector2(27.4, lerpf(a.home.y, Geo.GOAL_Y, 0.55))
	if a == DefenseFormation.slide_man(self):
		a.drive_goal = DefenseFormation.slide_drive(a)   # (on in from where he's slid to)
	drive_timer = maxf(drive_timer, CALLED_DRIVE)
	events.append({"k": "drive", "side": side, "tag": a.tag})
	return a

## How fast `s` passes: his passing sets the pace, never his team's OVR (Tempo.pass_mult), and a
## PLAYMAKER's are quicker still.
func pass_speed(s: Swimmer) -> float:
	if s == null:
		return PASS_SPEED
	return PASS_SPEED * Tempo.pass_mult(s.player.live("passing")) \
		* (PLAYMAKER_PASS if Traits.has(s.player, "playmaker") else 1.0)

## How high a pass of `dist` metres loops (the flight, the aim guide and pass_risk share it).
## Never higher than PASS_PEAK_MAX: a long ball right across the pool sails over a man in the
## middle of the lane, but one standing in it near the passer or the catcher can still get a hand to it.
const PASS_PEAK_MAX := 0.5
static func pass_peak(dist: float) -> float:
	return clampf(dist * 0.09, 0.25, PASS_PEAK_MAX)

## THE WING-TO-WING LOB: a ball from one wing ("1", "5") to the other, both up by the goal (inside
## 6 m) and on opposite sides of it, crosses the goal mouth right in front of the keeper. It's thrown
## as a high lob over him (WING_LOB_PEAK: pass_z puts it above even the keeper's 1.9 m reach for the
## whole stretch of its flight that can be picked off near the goal), so the same height rules that
## settle every pass (_fly_pass, pass_risk) let it over him. Its pace, its line and where it lands
## (lead_point, pass_at) are the pass's own, as ever: only its height is different.
const WING_LOB_PEAK := 1.8
const WING_TAGS := ["1", "5"]
static func is_wing_lob(from: Vector2, to: Vector2, passer: Swimmer, receiver: Swimmer) -> bool:
	if passer == null or receiver == null or passer == receiver:
		return false
	if not (passer.tag in WING_TAGS and receiver.tag in WING_TAGS):
		return false
	if from.x < Geo.SIX_M or to.x < Geo.SIX_M:
		return false   # (out on a break, say: a wing-to-wing ball across the goal is only by the goal)
	var a := from.y - Geo.GOAL_Y
	var b := to.y - Geo.GOAL_Y
	return a * b < 0.0 and absf(a) > Geo.GOAL_HALF and absf(b) > Geo.GOAL_HALF

## How high a pass from `from` to `to` loops: the wing-to-wing lob's, else pass_peak's.
static func peak_for(from: Vector2, to: Vector2, passer: Swimmer, receiver: Swimmer) -> float:
	return WING_LOB_PEAK if is_wing_lob(from, to, passer, receiver) else pass_peak(from.distance_to(to))

## Metres from `s` to the closest defender; used by the aim guide and the bot.
func openness(s: Swimmer) -> float:
	var d := _nearest_defender(s.pos)
	return d.pos.distance_to(s.pos) if d else 99.0
