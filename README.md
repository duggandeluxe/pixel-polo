# Retro Polo (working title)

A Retro Bowl-style water polo game for **iPhone and Android**, built on the same Godot 4.7
setup as Retro Swim (480x270 pixel canvas, GL Compatibility, same UI kit, fonts and sounds).

## The idea

Retro Bowl works because you only play the fun half: you throw, and everything else is
simulated. Here that means:

- **You play every one of your attacks.** Tap a teammate to pass to him, any man to any man,
  right across the pool (the camera frames the whole attack so every man is there to tap):
  the pass leads him, and defenders can still pick it off. A tap in open water passes to that
  spot. A long ball loops over a man in the middle of the lane, but one in it near either end can
  still get a hand to it (`Play.PASS_PEAK_MAX`). With the ball down, your man swims it to his
  spot.
- **The shooting stick is the only way to shoot.** It sits on the left over the pool, in from
  the edge (`ShotStick`), while you have the ball or your pass is on its way to one of yours
  (catch and shoot). Put a finger on it, drag its knob back (left) for power, up to aim low,
  down to aim high, and let go to shoot; once it's yours the finger can go anywhere. Pulling it
  back lifts the ball over his head; ease off and he puts it back in the water. It feeds the
  slingshot's own pull (`AimGuide.stick_at`), so the guide, the red X, the release and the shot
  are the slingshot's: the ball flies exactly along the line you aimed (no random spread,
  nothing pulls it towards the goal: aim just wide and it goes just wide). A touch that comes
  down anywhere else is never a shot, wherever it's dragged (onto the stick too): a pull on the
  water, a player or the deck does nothing. Other fingers never take over or let go of it. The
  stick never passes, except a tap on a teammate swimming under it.
- **DRIVE▾**, the big button right on top of the shooting stick, is your play call (like the
  audible in Retro Bowl): LEFT, MIDDLE or RIGHT, and that man drives at the goal now. Hit him in
  stride. Its touch area never meets the stick's.
- **On defense you're the keeper, and every save is yours.** The AI plays your field defenders
  (marking, help, blocks, fouls, exclusions). Your keeper shades a little towards the ball as
  they move it round (never more than half a metre off the middle: `MatchFlow.TRACK_MAX`), and
  stops when they shoot. Then tap the top, middle or bottom of your goal (LEFT, CENTRE, RIGHT):
  he explodes into a lunge that way, or springs up into a two-handed block (`KeeperDive`). Every
  dive runs the same cycle: a beat to react (0.05 s), the rise to full stretch (0.17 s; LUNGE
  SPEED), up for his window (0.34 s at Leg Strength 5; 0.22 s at 2, 0.50 s at 9), then he falls
  back into the water (0.16 s) and bobs back up (0.22 s) before he can go again. So timing counts
  as much as the side: dive too early and he's back in the water when it arrives, too late and
  it's past him while he's still rising (a GOAL from either says TOO EARLY / TOO LATE). You can
  guess during their wind-up too. Taps while a dive is running do nothing; it saves only what
  the body and arm you see can reach, so the wrong way is a goal. No dive, only a shot straight
  at him is stopped. Their keeper's dives on screen run the same cycle, timed to the ball.
  A save he holds goes straight into his hands (`Ball.secure`, `Play.held_at`,
  `KeeperDive.held`): from where it met him it eases into the hand his art draws, stays in it
  through the rest of his dive, onto the water in front of him as he falls back, and up into
  his hand as he bobs back up. A parry stays a loose ball.
- **Low shots and the top corner are the hard ones.** The pool is 2D, so a shot's height is
  rolled at the release (0 at the water .. 1 under the bar, `ShotModel.shot_height`, drawn in its
  flight). Their keeper's reach is 0.85x at the water, best (1.12x) around his shoulders, and
  under the bar it's his Leg Strength: 0.7x at 0 .. 1.1x at 10 (`ShotModel.height_reach`). Your
  keeper's is still the narrow 0.92x .. 1.08x. The pace never depends on it.
- **Their keeper reads, then reacts** (`KeeperAI`, `ShotModel.resolve`). Before the release he
  reads the shooter (the room either side, the angle, the range, earlier shots: never the aim) and
  leans that way a little on a long hold. The longer it's held, and the closer in the shooter is
  (he knows he won't see a point-blank one in time), the likelier he sets off early (5% for a snap
  shot from range .. 45% after 1.6 s, up to 75% from 3.5 m; on a penalty, always). After the
  release he sees the ball's line once he's recognised it (0.36 s at Lunge Speed 0 .. 0.20 s at 10,
  give or take 22% shot to shot) and goes for it: always the way it's going, only as far as it
  needs, timed for when it'll get to him. In live play his rise to full stretch takes 0.30 s
  (`KeeperAI.RISE`): a ball near him he gets to quickly, a far corner takes the lot. Seeing it isn't saving it:
  the dive (the same `KeeperDive`) still has to get a hand there before it crosses, and Blocking
  only holds what he reaches. Gone early the right way: a head start. Gone early the wrong way:
  barely moving, a quick correction; properly committed, a **panic** (`KeeperDive.turn`): he has
  to stop, gather himself and claw back off balance, reaching back with one arm. Never a second
  dive, and once fully committed he can't cover past `PANIC_WALL` (0.22 m beyond where he set):
  no far-side save, whatever his attributes. Contact is checked along the ball's path through his
  depth, so no pace tunnels through him. `--test keeper_measure` prints his save rates.
- **The first pass into the centre goes through his man, not past him.** The first pass of a
  possession into a set centre, thrown straight through a guard who's ball side of him and can
  reach it (`Play._first_entry_plan`: across, up, and with time to see it), is always stolen or
  knocked loose. Round him, over his hands, with him behind the centre or chasing him in, or any
  later pass: the normal entry rules. The keeper plays no part in it.
- **Steals are rare.** A defender only gets a go at a pass whose actual path crosses his reach
  (the stretch of the flight each frame, so the frame rate doesn't matter; a long ball loops over
  a man in the middle of it), once per pass: 2% + 1.5% x his Defense - 1% x (the passer's
  Passing - 5), less at the edge of his reach (`DefenseFormation.tip_chance`). One that comes off
  is a minor deflection (75%: knocked a little off line, loose nearby), a major one (20%: a race
  for it) or a clean interception (5%); a loose ball is whoever gets there first (TIPPED! if the
  defence does). The man on the ball is stripped only from in front, and rarely unless he holds
  it too long under pressure. Your AI defence gets a small edge (`Play.YOUR_DEFENCE_STEALS`) so
  stops still come along.
- **The Road to Glory** (`src/core/progression.gd`, PICK YOUR SCHOOL). The 30 schools are scrolling
  cards, strongest first. A new player can start only at the five lowest-rated programs; the others
  open in tiers for career achievements: 5 wins in one season (7 schools), reaching a conference
  final (7), winning one (7), winning the NCSA title (the top 4). Achievements are read from the
  career's own results, never bought, and kept in `user://progression.json` for every career.
- **Coaching** (`src/ui/screens/coaching.gd`, the hub's COACHING button). PICK YOUR DEFENSE: one
  of the four drops (M-DROP, 4-5, 5, 3-4) is your gameplan (`Career.gameplan`, saved at once;
  older saves start on M-DROP), with SCOUT OPPONENT (`scout.gd`: your next unplayed game's
  opponent, his record, team OVR and each man's current stars and four attributes; never
  potential, ceilings or XP). RECRUITING: OPEN RECRUITING, this season's signings (X / 4) and the
  projected roster, then up to three incoming recruits, each opening his profile. Facilities and
  staff are under MORE and Training.
- **Halftime: MID-GAME ADJUSTMENT** (`src/match/halftime_panel.gd`). Between Q2 and Q3 only, a
  button under the halftime card opens the four drops and their first half (`MatchFlow.half_stats`,
  frozen at the end of Q2: centre and perimeter goals by the scorer's tag, shots, shooting %,
  exclusions and 5 m penalties drawn, the score). One confirmed decision a match sets your drop for
  Q3 and Q4; Coaching's gameplan is never changed by it, and a match isn't saved part-way, so
  every match gets its own.
- **Defensive formations** (`src/match/defense_formation.gd`). Whenever they attack, two big
  buttons along the bottom (`FormationBar`: 15% of the pool's height on screen, as wide as the
  room right of your keeper's tag allows) offer PRESS | your gameplan's drop (`MatchFlow.
  user_formations`); the other three drops aren't yours this match. Every possession
  starts on PRESS, not picked (gold outline); tap one and it's yours for the whole possession
  (gold, the rest dimmed), through fouls, loose balls, rebounds and shot-clock resets, until the
  ball changes hands. While their shot is coming a tap is a dive, never a call. Their defence
  picks one at the start of each of its possessions (from your centre against its guard, your
  shooters man by man, its own defenders, the score and the clock, and where your goals have
  come from today, with some variety) and is locked the same way; it's shown under the shot
  clock. D1-D5 guard A1-A5 (the perimeter, right wing to left wing), D6 the centre. A
  formation's numbers are the defence's own, counted from its own end as the screen shows it
  (`DefenseFormation.slot`): your 4-5 DROP is the two men at the top of the pool (D4, D5), the
  computer's the two at the bottom (D2, D1); its 5 DROP drops D1, its 3-4 DROP D3 and D2.
  PRESS is man to man. M-DROP drops D3 in front of the centre (D6 behind him: a sandwich), D2
  and D4 split A2-A3 and A3-A4 (only the one who can get there closes out on A3, the other
  covers his lane; a splitter contests from a hand's distance, tightening the longer the man
  holds it). 5 DROP drops D5 and leaves A5, who attacks the goal on the diagonal when he has
  it; one perimeter man helps on him, leaving his own man until he swims back. 4-5 DROP and
  3-4 DROP are pistons: the man whose attacker has the ball goes out, the other drops in, and
  a quick pass between those two leaves the centre open while they swap. The centre's guard
  goes behind him only once a dropper's there to front him. The formation is only where they
  swim: a defender swims at 0.85 + 0.03 x his Defense of his speed, and the formations run
  in the settled 6 on 6 (counters, the breakout and man-down keep their own systems).
  Physical pressing: his own man in contact with the man with the ball (within 0.95 m, not
  behind him) shoves him straight away from the goal at 0.06 m/s a point of Defense over the
  attacker's Strength (to at most 1.5 m); a much stronger attacker (4+ points) gains water
  instead. Ordinary fouls only come from that contact, held for 1.1 s, so a catch is never
  fouled at once and a man who has to swim to him fouls later. A dropper in front of the
  centre gets his hands to entries through him about half the time; the centre who catches
  before he arrives has a moment to shoot or pass it out, and holding on until the dropper's on
  him is the dropper's steal. Their attack reads the formation from where everybody is: the
  centre against PRESS, the man a help leaves, the quick ball across the pistons, an open look
  the drop gives away. All the tuning is at the top of `DefenseFormation`.
- **The AI runs everybody else.** Teammates drive at the goal (a green ring = open), the
  defence marks goal-side with a reaction lag, the keeper leans to the ball side.
  The man guarding the ball can only block his shot after 2 s pressing him, so a catch and
  shoot beats him; a help defender in the shooting lane can still block it (the centre's
  defender doesn't: `Play.CENTER_DEFENDER_BLOCKS`).
  Their attack plays to score (`OffenseAI`): it swings the ball to the side the defence has
  left, feeds the centre, hits cutters and drives into open water, and its shot bar comes
  down as the possession goes on, so a settled attack usually shoots in 8-15 s and never runs
  the shot clock out on purpose. It remembers its passes, so it doesn't ping-pong the ball.
  The AI never shoots from outside 6 m (on or inside the 6 m line, `Geo.in_shot_range`), not on
  the break and not with the shot clock going: out there it moves the ball on with a purpose or
  swims it in (straight, or slanting off its man's shoulder into a shooting lane), and with the
  clock nearly gone it gives it to a man inside 6 m; nobody there, and it's a shot clock
  violation. The bot that plays your side in the demo and the tests (`PlayBot`) keeps to it too.
- **Shooting rewards the right shot.** Where you aim against where the keeper actually is
  decides most shots. A catch and shoot (within about 1 s of the catch) and a cross-cage shot
  with the keeper cheating to the near post are both clearly better (the catcher glows gold
  while his catch-and-shoot bonus lasts, and a catch and shoot leaves a white streak); now and then the centre's
  shot from 2 m is a rocket that beats the keeper on pace (`ShotModel`, tuning at the top).
- **Counterattacks grow out of the steal.** Where the ball was won decides it. On their bottom
  line (the wings, the centre at 2 m) there's no break: the team that won it swims straight into
  its set attack. Out on the top line (the perimeter) it's a break: usually 3 on 2, often 2 on 1,
  now and then 1 on 0 (`PlaySetup.BREAK_ODDS`, leaned on by where everybody was), led by the men
  nearest the ball, the men of theirs furthest back getting back. Anything else (a save, a shot
  wide) is just where everybody was, and only a man up is a break; level numbers are
  just the ball. The defence swims back, and once it has the numbers the attack sets up. Whoever's ahead leads it; the carrier swims it in to 3 m, and if
  nothing's on the attack sets up (`PlaySetup._counter`, `Play.break_numbers`). He only stops
  while you pull back at their goal to shoot (`Play.shooting_pull`); ease off and he swims on. Whenever the
  ball changes hands, both teams turn at once while the banner's up: the team with it breaks
  for the other goal, the team without it gets back (`PlayAI._breakout`); then it's the counter,
  or the normal set-up. A lead pass on the break (a tap into the water in front of a swimming
  man) is his: he swims straight through where it lands, taking it in his stride, and carries
  on at the goal; nobody on the break turns round for a ball thrown on ahead of him (only one
  thrown behind him). Thrown too far, it can still go begging, or to the keeper
  (`Play.receiver_at`, `PlayAI.run_onto`); thrown long and slow enough that he'd be there first,
  he times his run so he's just past it as it lands, never pulling up or swimming back.
  The break runs in lanes (`PlayAI.assign_lanes`): three men take TOP, MIDDLE and BOTTOM in the
  order they're across the pool, two take TOP and BOTTOM (the carrier on the inside of his,
  going in at the goal from 23 m), and they keep them; nobody crosses anybody, they slant into
  their lanes rather than swimming across, and a man ahead of the ball keeps swimming on. The
  lanes are invisible: they only guide the swim. The defence getting back picks up the most
  dangerous men first and keeps who it has (`PlayAI.counter_marks`: looked at again when the
  ball changes hands, or every 1.2 s, never swapping for nothing); each man goes goal side of
  where his man is swimming, and once back he never swims up the pool at him: he gives ground,
  3 m off in open water, tight by 6 m. A man short, the defender on the ball shades towards the
  free man and the others sag into the middle (`PlayAI.counter_spot`). Nobody swims faster than
  he can, so a man who's beaten his defender stays beaten, and one clean away is a 1 on 0.
- **The set attack and the centre.** The umbrella is spread out, 4-5 m between men, with the
  point just outside 6 m (`PlaySetup.HOME_6V6`). The centre's guard picks a side of him and
  holds it; when the ball goes round to the other side he waits a beat (better defenders less)
  and then swims round behind the centre (`PlayAI._center_guard_spot`). The two of them wrestle
  all possession, and every 5-10 s (sooner for a stronger centre or a WRESTLER) the centre wins
  inside water: he spins his man round behind him and seals him there, open from anywhere for
  3-5 s, then his man fights back round to the ball side (`PlayAI._center_battle`). If he's standing in the
  passing lane, between the ball and the centre, the entry is his, every time (a quarter of
  them knocked loose under his nose rather than caught); behind the
  centre or off the lane, the centre has it (`Play.center_entry`, decided where everybody is at
  the release). So swing it: a green ring on the centre means the entry from the man with the
  ball is open. When the fed centre catches it, his beaten man hangs on and is whistled 80% of
  the time, as he turns with it, before he can shoot (`Play._center_hold_foul`): a man up. Once a
  shot's gone up it's just a shot: a goal, the keeper's ball or a miss, never an exclusion. A
  poor ball, straight in beside his man, is caught, and his man fouls him (ordinary, no shot from
  it) about half the time. Both teams play by the same rules.
- **The centre swimming in.** On a counter and on the swim-in after the ball changes hands, the
  centre's man goes down the pool on his back, in contact, at his pace (`PlayAI._center_trail`),
  and turns with him while the banner's up. A ball in to him then is contested: his man gets a
  hand to it about half the time (`Play.TRAIL_PICK`); get him a step clear and it's his. Inside
  water still comes from the 2 m battle once he's set.
- **The keeper comes out.** Throw an entry well past the centre, where he can't get to it and the
  keeper can, and the keeper (theirs or yours) reads it, swims out and takes it: their ball. The
  further past him, the likelier (`Play._keeper_reads`); a ball to the centre never brings him out.
- **Water polo rules that matter:** a 30 s shot clock; the game clock and the shot clock both run
  at 1.25x real time (`MatchState.CLOCK_SPEED`: a 2:00 quarter is 96 s of play), and every change
  of possession in live play is a transition that takes 10 s off both, once (the game clock, and the
  next shot clock starts at 20: `MatchState.TURNOVER_TIME`); the centre drawing exclusions
  (6 on 5 for 20 s, and one attacker is always free), ordinary fouls and free throws (a pass
  first inside 6 m), 5 m penalties (called on the shot: a man with inside water in the goalie
  box, fouled going up, `Play._shot_penalty`; the shooter on the 5 m line, one defender either side of
  him, everybody else staggered just past half pool, mostly out of the picture; their keeper
  guesses a side at the release, 50/50, and commits), rebounds off the post, and counterattacks.
- A tap-as-fast-as-you-can **sprint** starts every quarter, both teams lined up on their own
  goal line, and a level game after four quarters goes to a **penalty shootout**.
- **Players:** stars, starters and role players, each position with its own strengths, and
  the good ones have a trait (CANNON, LEFTY SNIPER, ICE, WRESTLER, BALL HAWK, PLAYMAKER, JET,
  WALL) that changes how they play (`src/core/traits.gd`). A career program carries exactly
  seven players, one goalkeeper and six field players, in four class years (freshman to
  senior), 4 of them on scholarship. All seven play every game: there's no bench and no subs
  (a hurt player plays through it; he just can't train). The roster lines the seven up in the
  pool in a 3-3 offence facing the opponent's goal: LEFT WING, CENTER FORWARD, RIGHT WING on
  the 2 m line, LEFT FLAT, POINT, RIGHT FLAT behind them, and the keeper on his own below
  (`roster.gd` `formation`: placed by his own position, a center at center forward, a center-D
  at point, drivers on the wings, utilities on the flats, a lefty on the right; positions never
  change). Each card: position, class year and cap number over his head and shoulders (each
  player has his own hair, face and build, the same all career: `PlayerArt.looks`), then his
  surname and his stars (a bigger 7x7 star here) with HOT / VERY HOT; OVR and POT numbers are
  on the player page. An empty place is an OPEN SPOT (tap: recruiting); beside the pool is NEXT
  SEASON, and a BENCH for anyone past the seven; the bar under them reads ROSTER | TEAM |
  FORM (tap it for BASE | LIVE). Ratings, form, stats and trait are on the player page.
- **Player attributes** (`src/core/attributes.gd`, from "Retro Polo 2.0: Complete Player
  Attribute, Goalkeeper, and Star Rating System"). Every field player has PASSING, SHOOTING,
  STRENGTH and DEFENSE; every keeper COMMUNICATION, LUNGE SPEED, BLOCKING and LEG STRENGTH. Each
  is 0-10 (fractions kept to 4 decimals) with its own ceiling. OVERALL is the plain average of
  the four, POTENTIAL the average of the four ceilings, and stars are each of them halved: that
  is the only rating calculation (`Attributes.sync` keeps `stars`, `pot_stars` and the old 0-100
  ratings the pool still reads in step with it). What each one does in the pool, all neutral at
  5 and all tuning constants at the top of `Attributes`:
  PASSING gives the catcher of an immediate catch and shoot -10% .. +10% (the passer's, not the
  shooter's: the keeper's reach and the shot's spread); SHOOTING is the release, 20% slower .. 20%
  faster (the ball up, their wind-up at your goal, how late the keeper and blockers react; never
  the ball's speed, which stays `Tempo`'s); STRENGTH wins (and holds) the 2 m battle and keeps the
  man on the ball from being fouled off it; DEFENSE picks off passes through a defender's own reach
  (never further), forces ordinary fouls ((D - S) x 4%) and sets up on the centre;
  COMMUNICATION gives his defenders (C - 5) x 0.1 effective Defense while he's in goal; LUNGE
  SPEED is how fast he reacts and dives (20% either way), never how far; BLOCKING is how often a
  ball inside his reach stays out ((B - 5) x 3%, never certain); LEG STRENGTH is his reach (15%
  either way) and how long a dive stays up at full stretch (0.34 s + (G - 5) x 0.04 s: 0.14 ..
  0.54 s, `Attributes.dive_window`). Older saves are converted once, at each player's saved stars
  exactly (his old ratings give the shape), and kept. Swimming speed isn't one of the four: it
  stays each player's own rating (sprints, counters), grown by practice as before. The quick-match
  clubs (`League`) are rated above the college scale, so they keep their own 0-100 ratings and
  traits (`PoloPlayer.pro`); they still get attributes (on the clubs' own scale: a typical pro is
  a 5) and every attribute effect, read as what sets each man apart from his own level.
  Traits now go to the best players (OVERALL 9.25+) for the attribute they've maxed out (JET: speed).
  Developer Mode has an ATTRIBUTE TEST LAB (`AttrBench` measures every effect with the game's own code).
- **Stars and HOT form** (`src/core/player_form.gd`, from "Player Stars & 7-Player
  Rosters"). Every player has two permanent star ratings, CURRENT and POTENTIAL (0-5, half his
  OVERALL and POTENTIAL, so they move whenever an attribute does: training, upgrades; potential
  never below current; the star scale's values 1.0 = 44 ... 5.0 = 92 in between). The unified star
  bar draws them to the nearest half star (the exact number beside it): five places, gold to
  CURRENT, then his HOT form's red stars straight after the gold (one HOT, two VERY HOT, never
  past the fifth place), empty to POTENTIAL. On top of CURRENT sits form: after every
  game, played or simmed, all seven on both teams are graded from their own stat line. RAW
  points (field: goal +3, exclusion drawn +2, field block +2, missed shot -1, every goal
  against -0.5; keeper: save +2, goal against -1.5) minus EXPECTED points (worked out before
  the game from the engine's own odds for it, which come from the two teams' ratings, their
  form and home/away/neutral, and the player's shooting, defence and strength share by position;
  see `PlayerForm.ENV`, calibrated so a man playing to his level averages 0) is his +/-: +3 or
  more GOOD, -3 or less BAD, else NORMAL. His last five grades, GOOD less BAD (the run), move
  his HEAT a level a game at most: a run of +3 makes a NORMAL player HOT (one red star, +0.5
  star), +4 makes a HOT one VERY HOT (two red stars, +1 star); HOT holds while the run stays +2,
  VERY HOT only while it stays +4, and both cool a level at a time. There is no cold form: a
  player who isn't hot plays and shows his own stars. Over a season a player is HOT about one
  game in 15, VERY HOT about one in 100. EFFECTIVE stars = CURRENT + form (0-6.0; 5.5 = 96,
  6.0 = 99), drawn fiery red when hot, gold when normal. Older saves load with HOT only for a
  real run (three GOOD games) and every cold form as NORMAL.
  A team's OVR is worked out from its seven designated starters only, every time it's shown
  (`PoloTeam.team_overall`): 34.5 + 13 x their EFFECTIVE stars / 7, where EFFECTIVE is a man's
  CURRENT stars plus his active HEAT UP red stars (one HOT, two VERY HOT), never capped (a
  VERY HOT five-star counts 7; seven of them make 125). Nothing is rounded until the end, when
  it's rounded once for the screen, an exact half down (seven five-stars, 99.5, show 99). The
  bench never counts until it's in the lineup. BASE OVR is the same without HEAT UP. It is
  information only: nothing in the pool reads a team's OVR (shots, passes, the AI's decisions
  and the keeper duel all run off each man's own ratings and attributes, `Tempo`). The
  scoring engine plays on the starters' BASE ratings plus its own form term added once to OFF
  and DEF (`GameSim.live_ratings`); in a game you play, form moves each man's own ratings instead,
  8 a star (`PoloPlayer.live`: shooting, passing, defence and blocks, steals, keeping). After a
  game, only if someone's form went up (NORMAL to HOT, HOT to VERY HOT), the summary shows each
  of them on his roster card, his new red star heating up: HEATING UP! or ON FIRE! (`HotReveal`;
  a tap skips it). Nobody heated up: straight on. The grades (RAW, EXP, +/-) are still made and
  kept (his page's LAST GAME). Preview: Settings > Developer Mode > HOT STAR REVEAL.
  Form carries from game to game and is saved; each new season starts everyone NORMAL.

On top of that:

- **College career.** Coach any of 30 fictional college programs in 5 conferences: MPSF (4),
  Big West (6), WCC (8), MAWPC (7) and NWPC (5) (`src/data/colleges.gd`). Every school has an
  original OVR (62-91, with an OFF/DEF split): its INITIAL TEAM STRENGTH TARGET, used once, when
  a brand-new career generates its first roster (`CollegeGen.make_initial_roster`): the target's
  average starter stars, (OVR - 34.5) / 13; seven CURRENT star ratings around it (never all
  alike), moved half a star at a time (bounded) until the seven show the target exactly; each
  starter's four whole-number attributes made for his position and fitted to his stars (stars
  are read back from them, never set); his ceilings from a development profile, less room the
  older he is; then your program's three subs (a backup keeper and two more, mostly
  underclassmen) and a lineup that keeps the seven starting. Every school starts on its
  original OVR exactly. After that the target is never read again (saved as `init_target`, for
  the record): OVR, OFF and DEF are always the current seven's (OFF and DEF either side of OVR
  by how much better their passing and shooting are than their strength and defense), so they
  move with training, development, recruiting, graduation and lineup changes, never back
  towards the original. Each season keeps a snapshot of where everyone started.
  Games you sim, and everyone else's, use the scoring engine (`GameSim`): expected goals from the
  brief's neutral-pool formulas, the home pool's 5% (host x1.05, visitors x0.95, never again in
  overtime; the NCSA semifinals and final are at a neutral site), a total (SD 3.1, at least 15)
  and a margin (SD 4.5) sampled around them, four quarters, overtime for a tie, and a saved seed
  per game. The winner is whoever scores more. Games you play are decided in the pool.
  A 10-week regular season of 16 games (up to 3 a week, Fri to Sun), shown to you as GAME 1-16:
  a conference round robin (double in the MPSF), the rest non-conference and coast to coast,
  with road trips. Then every team plays its conference tournament (seeded by conference record,
  byes for the top seeds) and a 12-team NCSA Championship: the 5 tournament champions and 7
  at-large teams taken straight down the SELECTION poll, seeded by it; seeds 1-4 skip the first
  round.
- **National Top 20** (`src/core/poll.gd`, the TOP 20 button on the hub). A weekly poll of all 30
  teams by results, never by OVR: 45 x win % + 25 x strength of schedule + 20 x quality wins +
  10 x recent form (each 0-1); ties go to head to head, quality wins, then strength of schedule.
  The preseason poll is last season's final poll (Season 1: the team ratings) and fades out over
  three weeks. Out after every week, each conference tournament round (the last is the SELECTION
  poll) and the NCSA final. Rank, record, conference record, previous rank and movement, two
  teams receiving votes, your team highlighted; < and > step back through the season's polls.
  Training focus, recruiting (below), facilities and staff, the AD's goals,
  job offers from bigger schools. Saved after every week, in one of five career slots (NEW CAREER on the title
  opens SELECT CAREER; CONTINUE picks up the career played last). An old single save moves
  into a slot on first launch and the original is kept as `career_premigration.json`.
  A career saved before the current conferences plays its season out as it was, then moves
  onto the five conferences in the off-season, keeping its roster, staff, facilities and
  records; the last old-format save is kept as `career_slotN_backup.json`. A career from the
  first 32-school world can't be opened any more (its slot shows SAVE PROBLEM, the file stays).
- **Coaching Credits** (`src/core/credit_rewards.gd`). The only way a career earns credits:
  a regular-season win +3; for a win, the best one ranking bonus (beat No. 1 +8, else a Top 5
  team +5, else a team ranked above you +3, from the poll before the game); win by 5+ +2; a
  shutout +3; a loss 0. Once a season each: 5 straight wins +5, 10 straight +8, an unbeaten
  regular season +15, reach the conference final +8, win the conference +15, an NCSA bid +8,
  the NCSA semifinals +8, the final +8, the national title +23. Every season starts with +15.
  Each payment is claimed under an id (`Career.cr_claims`), so nothing pays twice. No cap, no
  expiry. Awards, records, home gates, events and PRO pay nothing. Bought credits (the store's
  packs) sit in the vault as before. Every amount shows as the number then the official golden
  coin (`src/ui/credit_coin.gd`, art in `game/assets/ui/`, made by `tools/make_credit_coin.py`
  from the original image; `{coin}` in text draws it).
- **Recruiting market** (`src/core/recruiting.gd`; screens `recruiting`, `roster_cuts`). Eight
  prospects for sale, each with his own price (8-99): 2 + 3(S-1.5) + 6(S-1.5)^2 for his stars,
  + 0.4 x his four attributes, + 0.65 x his room to his ceilings, + position (GK 3, C 2, DEF 2,
  UT 1). Up to four signings a season; REFRESH RECRUITS replaces the eight (first free, then
  3, 5, 8, 10 each). The prospects show as the Roster screen's player cards; a card opens his
  profile (the player page) with everything shown, potential and ceilings too (no scouting),
  and SIGN RECRUIT. Signed recruits wait in
  Incoming Recruits and join as freshmen after the season; the projected roster (now - seniors
  + signed) is shown live, with a warning before any signing that takes it over the cap
  (Career.roster_cap, 10). After the NCSA final the season is "done" (NEXT SEASON on the hub):
  seniors graduate, signings join, AI programs get freshmen made for their prestige
  (`Recruiting.ai_class`), and if your roster is over its cap the ROSTER CUTS screen must be
  finished (cut by hand, confirmed, nothing refunded) before the next season. No recruiting
  points, interest, offers, visits, transfer portal or CPU recruiting. Older saves keep their
  credits; prospects who had committed to you become incoming recruits.
- **Pools.** Every school has one fixed home pool and games are played in the home team's
  pool. There's one pool so far (`game/src/core/pools.gd`); add more there.
- **Store.** Pixel Polo +, Yellow Coin packs, and the Division II and III packs.
  Bought credits sit in a vault that survives a new career. Real purchases use the StoreKit 2
  plugin on iPhone; the desktop has a labelled test store.
- **You're the keeper.** When they shoot, tap the top, middle or bottom of your goal, timed so
  he's up as the ball arrives. In the
  shootout the camera cuts to your goal; dive too early there and a good shooter goes the
  other way. A shootout kick is just the shooter and the keeper. In multiplayer you make the
  saves against your friend's shots.
- **Difficulty:** DYNAMIC (the default) starts easy and follows how you play; a new career
  starts at the beginning. Or EASY, NORMAL, HARD. One number tunes the keeper duel, their
  shot rate, their keeper and how often passes get picked off (`src/core/difficulty.gd`).
- **Tutorial.** Every new career opens with it, before the first official game: one continuous
  tutorial in four parts (passing, the counterattack, shooting, goalie blocking). Each part opens
  on a short pop-up (a title, one sentence, GOT IT) with the play held behind it. SKIP TUTORIAL
  stays in the strip throughout (it asks first: CANCEL / SKIP), and TRAINING COMPLETE's START
  CAREER goes on to the hub; either way `Career.tutorial` saves how it ended and nothing else in
  the career changes. A loaded career never launches it. The GAME GUIDE's PLAY THE TUTORIAL is the
  practice run, which keeps the parts done (`tutorials_done`) and picks up at the first one not
  done. Everything in it is the match's own (`src/tutorial/`: a `Drill` per part, `DrillFlow`
  extends MatchFlow, the drill screen extends MatchScreen). The shooting part's keeper is a
  tutorial keeper: a beat slower to react, and for the near-side goal he cheats across and dives
  for the far corner.
- **Between games:** the locker room after every career game (team talk, Player of the Game,
  a word with whoever struggled, pizza night), player morale, team momentum, event cards
  and press conferences. Every choice is a trade-off.
- **Visual Upgrades.** The Dynasty Hub's VISUAL UPGRADES card (where the Game Guide was; the guide
  is on the title screen's help button) opens a gallery of six cards (each opens its
  own page: a live preview of any level, buying, wearing). The Yellow Coin Shop sells Yellow Coins and
  Pixel Polo +, and the Division II and III packs (COMING SOON until the store confirms them).
- **Awards and records.** Every season: NCSA Player of the Year, the Golden Cap, Keeper of
  the Year, Coach of the Year and the All-Conference team. School and NCSA record books for a
  game, a season and a career; breaking one pays credits (`src/core/awards.gd`,
  `src/core/records.gd`, the RECORDS screen).
- **Multiplayer, 1v1.** You play your attacks, your friend plays theirs; possessions
  alternate and each phone runs its own attack, so your throws never lag. Online with a room
  code or QUICK MATCH (needs the relay in `relay/` deployed), Wi-Fi/hotspot, or Bluetooth
  (Android plugin, and a new iPhone plugin that still needs testing on two real phones).

See `docs/SPEC.md` for what's left.

## Running it

```bash
godot --path game                                  # play on the Mac (mouse = touch)
godot --headless --path game -- --test all         # headless checks (exit 1 on failure)
godot --headless --path game -- --test career 8     # autopilot 8 seasons (balance + save checks)
godot --headless --path game -- --test credit_economy   # credits earned, the recruiting market, signing, cuts, saves
godot --path game -- --test credit_economy_png /tmp/ce  # its screenshots (needs a window)
godot --headless --path game -- --test balance 8    # league ratings over 8 seasons
godot --headless --path game -- --test teams        # schools, OVRs, conferences, 16-game season, brackets, old saves
godot --headless --path game -- --test attrs        # player attributes: ratings, every attribute in the pool, the star bar, saves, upgrades
godot --headless --path game -- --test form         # stars, HOT form, the postgame grade, BASE/LIVE, saves, a season to the lock
godot --headless --path game -- --test form_calibrate 40  # the expected-performance model against engine and bot-played games, and a season of form
godot --path game -- --test form_png /tmp/shots    # the roster's stars, a HOT player's page, the summary, the matchup's LIVE
godot --headless --path game -- --test star_fx      # HOT star animations (StarFx), the form lab, the roster's DEV panel, cards and formation
godot --path game -- --test star_fx_png /tmp/shots  # the animations paused phase by phase, and on a real roster card
godot --headless --path game -- --test hot_reveal   # the postgame HOT star reveal: who shows, timings, the summary's flow, the preview
godot --path game -- --test hot_reveal_png /tmp/shots  # the reveal frozen phase by phase (preview and a real summary)
godot --headless --path game -- --test tempo        # team skill: shot pace (shooter first, team second), one speed per shot whatever its ending, passing tempo
godot --path game -- --test tempo_png /tmp/shots    # Developer Mode's SHOT & TEMPO TEST: the shot race, passing table, wide vs on target
godot --path game -- --test roster_png /tmp/shots   # the roster: the formation in every form, cards coming in, a tap, an open spot, DEV, a bench, players' pages
godot --headless --path game -- --test engine       # OFF/DEF table, ratings from the players, scoring engine + calibration, Top 20, NCSA selection, saves
godot --headless --path game -- --test team_ovr     # 2.0 team overall: first rosters from the original OVR, seven starters, HEAT UP, no OVR in the pool
godot --headless --path game -- --test duel         # keeper duel goal rates by keeper skill and difficulty
godot --headless --path game -- --test defense      # steal rules, and their attacks against the AI defence
godot --headless --path game -- --test breakout     # both teams turning for the other goal after a steal
godot --headless --path game -- --test centre       # spacing, the point outside 6 m, the centre's guard and entries, steal lines
godot --headless --path game -- --test rules        # centre entries, the fed centre's exclusion (before the shot), penalties on the shot, the counter's carrier, the centre's man on his back, the keeper coming out
godot --headless --path game -- --test update       # the 2 m battle's windows, the transition and 1.25x clocks, every pass combination
godot --headless --path game -- --test stats 200    # bot matches: steals, passes, possessions, shots, goals, counters
godot --headless --path game -- --test offense 40   # their attack (OffenseAI) over 40 matches [and a level, -1..1]
godot --headless --path game -- --test aim|sprint|traits
godot --headless --path game -- --test tutorial     # the tutorial's four parts played through in one go with touches, RESTART, BACK, resuming
godot --headless --path game -- --test career_tutorial   # a new career's tutorial: pop-ups, SKIP at every stage, TRAINING COMPLETE, loaded careers, no Coaching Tips
godot --headless --path game -- --test leadpass     # lead passes on the break: 2-3 m ahead taken in stride, nobody turns back, overthrown can fail
godot --headless --path game -- --test counter      # the AI's 6 m rule, break lanes, timed lead runs, the defence getting goal side, breaks settling
godot --path game -- --test tutorial_png /tmp/shots # the title, each part's pop-up, each part, the callouts, SKIP, TRAINING COMPLETE
godot --path game -- --test shots_png /tmp/shots   # screenshot tour of a bot-played match
godot --path game -- --test career_png /tmp/shots  # screenshot tour of the career screens
godot --path game -- --test slots_png /tmp/shots   # the title and SELECT CAREER (scratch saves)
godot --path game -- --test goal_png /tmp/shots    # a goal going in at each end, and the quarter card
godot --path game -- --test penalty_png /tmp/shots # the 5 m formation, a shootout kick, their keeper's guess each way
godot --headless --path game -- --test keeper_overhaul # their keeper's anticipation, reaction, panic; the first pass into the centre
godot --headless --path game -- --test keeper_measure   # their keeper's save rates by range, placement, pace, hold, reaction
godot --path game -- --test ai_keeper_png /tmp/shots   # their keeper on your shots: his lean, a reaction dive, a panic
godot --headless --path game -- --test penalties    # penalty formation, their keeper's guess, your keeper's tracking and dives
godot --path game -- --test keeper_png /tmp/shots  # your keeper: tracking, both lunges, the block, a corner save, falling, recovering
godot --headless --path game -- --test keeper_timing # stars in the in-game tag, the timed dive, low / high shots
godot --headless --path game -- --test formations   # the five defensive formations, pressing, fouls, tips, the dropper, the bar, their attack against each
godot --headless --path game -- --test coaching    # Coaching: gameplan, scouting, top recruiting targets, PRESS + your drop, the halftime adjustment
godot --path game -- --test coaching_png /tmp/shots # Coaching, scouting, the two-button bar, the halftime card, the adjustment
godot --headless --path game -- --test glory       # The Road to Glory: school cards, tiers, achievements, the progression profile
godot --path game -- --test glory_png /tmp/shots    # PICK YOUR SCHOOL (new player, locked, returning, iPhone, 4:3) and the notification
godot --headless --path game -- --test goalie_tweaks # the keeper's catch into his hands, the computer's formations from its own end, stick-only shooting, DRIVE and the bar's layout
godot --path game -- --test goalie_tweaks_png /tmp/shots  # a save frame by frame (up, down, the block), the stick with DRIVE on it, the tall bar
godot --headless --path game -- --test formation_balance 400  # their attack against each of your formations (and against outside shooters)
godot --path game -- --test formation_png /tmp/shots # the bar unpicked and picked, each formation, their call on your attack
tools/test_mp.sh                                   # two copies play a match over Wi-Fi
tools/test_mp.sh online                            # ...through a local online relay
godot --headless --path game --script ../tools/make_icon.gd   # regenerate the icons
```

## Code map

```
game/src/core/    PoloPlayer, Attributes (the four attributes), PoloTeam, League (clubs + rosters), Traits,
                  ShotModel, OppSim (sims),
                  MatchState, Geo, Career, Schedule, Training, Recruiting, Transfers, RosterPlan,
                  Offseason, CollegeGen,
                  GameSim (the scoring engine), Poll (the National Top 20), Pools
game/src/match/   Play (one possession: ball, passes, fouls), PlayAI (movement), PlaySetup
                  (formations), PlayBot, OffenseAI (their attack's decisions), PlayDefense + DefenseView (their attack: you keep goal), DefenseFormation (the five defensive formations, pressing, tips) + FormationBar, CallStrip
                  (DRIVE▾), MatchFlow (sprint → your attack ↔ their attack → breaks → shootout),
                  MatchScreen (touch + drawing), PoolView (camera), PoolArt, AimGuide,
                  Hud, Sprint, MpMatchScreen (a multiplayer match), TempoBench + AttrBench (the
                  Developer Mode labs' measurements)
game/src/tutorial/ Drill (one part) + FrontcourtDrill, CounterDrill, ShootingDrill, KeeperDrill,
                  DrillFlow (MatchFlow for a drill), drill_screen.gd (MatchScreen playing the four parts)
game/src/net/     Proto, transports (Wi-Fi, Bluetooth, online relay), MpMatch (the 1v1 referee),
                  RelayServer (the relay in Godot), NetConfig (the relay's URL)
game/src/store/   store backends (StoreKit 2, Google Play, desktop test store)
game/src/data/    Colleges, NamesData, Regions (hometowns, distance, pipelines)
game/src/ui/      BaseScreen, Deck + DeckPanel + Juice (Retro Swim's "Deck Blue" kit), PlayerArt,
                  StorePrompt and the screens (title, careers (the five slots), career hub, more, roster, player, training, top20,
                  facilities, recruiting, plan (next season's roster), schedule, game_summary, recap, store, visual_shop, multiplayer,
                  quick_match, howto, settings)
game/src/autoload UI kit and Sfx (shared with Retro Swim), Game (navigation, settings, career slots),
                  Store, Net
game/tests/       test_runner.gd (headless), shot_harness.gd + career_shots.gd (screenshots)
plugins/          Bluetooth: android-ble (Java), ios-ble (Objective-C++, CoreBluetooth)
relay/            the online relay as a Cloudflare Worker (see relay/README.md)
```

## Phone builds

- **iOS:** `tools/build_ios.sh` writes an Xcode project to `build/ios/` and opens it. The first
  time, pick your team under Signing & Capabilities, plug in the iPhone and press Run. Every Run
  first repacks the current game (`tools/ios_pack_for_xcode.sh`, a build phase in the project),
  so Xcode always runs the latest code. Run `tools/build_ios.sh` again only when export settings,
  icons or the iOS plugins change, since it rewrites the Xcode project. Bundle ID `com.akikawasaki.retropolo`,
  team `7844HC9AYV` (same as Retro Swim). The iOS Simulator can't run it: Godot 4.7.2's iOS
  template only has an x86_64 simulator library.
  The iOS export includes two plugins in `game/ios/plugins/`: StoreKit 2 (copied from Retro
  Swim) and Bluetooth (`tools/build_ble_ios.sh` rebuilds it).
- **Android:** the preset exports `build/RetroPolo.apk`, but it needs Godot's Android export
  templates. `tools/build_ble_android.sh` builds the Bluetooth plugin; set `ANDROID_HOME` to
  `/Volumes/AkiKawasakis SSD/Android/sdk` and use JDK 17. Bluetooth needs a Gradle build
  (`gradle_build/use_gradle_build=true`).

## Before a store release

- Pick the final name. "Retro ___" is New Star Games' naming family (Retro Bowl, Retro
  Goal), so a distinct name is safer for App Store review. It's one string in
  `project.godot`, `export_presets.cfg` and the title screen.
- All clubs and players are fictional.
