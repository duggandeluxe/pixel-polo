# Retro Polo: what's missing compared to Retro Swim

The goal is the same engine as Retro Swim with a different game at the core. Retro Swim is the template; this file lists what Retro Polo still lacks and the order to build it in.

## Status (2026-10-14)

| | State |
|---|---|
| Career v1 (season, playoffs, training, recruiting, facilities and staff, AD, job offers, saves) | **Built**, tested with 10-season autopilot runs |
| One pool, one per school | **Built**: `game/src/core/pools.gd` |
| Store (PRO, packs, starter, playoff bundle, vault, StoreKit 2) | **Built**; needs the products in App Store Connect |
| Multiplayer over Wi-Fi | **Built**; two-copy test passes |
| Multiplayer online (room code, quick match) | **Built**; needs the relay deployed (`relay/README.md`) |
| Bluetooth, Android | **Built** (plugin compiles); untested on phones |
| Bluetooth, iPhone | **Built** (new CoreBluetooth plugin; the app builds for device); untested on phones |
| You're the keeper on their shots (single player and multiplayer) | **Built** |
| Difficulty: Dynamic (default), Easy, Normal, Hard | **Built** |
| Tutorial opening every new career (pop-ups, SKIP) | **Built** |
| Locker room, momentum, morale, event cards, press | **Built** (25 cards, 8 press questions, 6 talk contexts) |
| Cap Shop (8 designs bought with credits) | **Built** |
| Awards (POY, Golden Cap, Keeper, Coach of the Year, All-Conference) and records (school + NCSA) | **Built** |
| Playtest round 2026-10-13: live defence, DRIVE▾ call, dribbling, tighter aim, sprint from the goal lines, 20 s exclusions, Deck Blue menus with a simpler hub, star/role players with traits, roster cards | **Built** |
| Rest of phase 2 (women's program, transfer portal, career team in multiplayer) | Not started |

## 1. Side by side

| | Retro Swim (shipped) | Retro Polo before this work | Plan |
|---|---|---|---|
| The core game | Swim races with per-stroke touch controls | Quick Match: sprint, slingshot passing and shooting, exclusions, penalties, their attacks as cards, shootout | Keep it. This is the "different game" part. |
| Career | 19-week college season; 32 schools in 4 conferences; AD goals, prestige, realignment; off-season | **None.** The title screen says "SEASON - COMING NEXT" | **Build** a college water polo career |
| Saves | `user://career.json`, saved every week | Settings only | **Build** |
| Players | Ratings, potential, traits, class year, morale, fatigue, injuries, Legends | 13-man rosters, 6 ratings, no growth | Add class year, potential, growth, morale, injuries, season stats |
| Training | Weekly focus × intensity per group | None | Weekly team focus × intensity |
| Recruiting | 56 prospects; calls, visits, offers; AI boards; signing day; transfer portal | None | Recruit board, visits, offers, signing day (portal later) |
| Facilities and staff | 6 facilities × 5 levels, 4 staff × 3 levels | None | 5 facilities, 4 staff |
| Economy | Coaching Credits (CR), earned and spent | None | Same |
| Store | PRO $0.99, 6 credit packs, starter pack, taper bundle, credit vault, StoreKit 2 + Play Billing | **None** | **Port** |
| Locker room, momentum, press, 95 event cards, sponsors | Yes | None | Phase 2 |
| Records, Hall of Fame, history | Yes | None | Season history and awards first, records later |
| Multiplayer | Bluetooth (**Android only**) and Wi-Fi/hotspot (on iPhone you type the host's address). **No internet play.** | None | Wi-Fi + **Online** first, then Bluetooth |
| Pools | Every meet uses the same pool | One pool | One fixed pool per college (section 3) |
| Coach on deck, walk-on "The Dream", School Cup | Yes (Cup hidden in 1.0) | None | Later |
| Drag-to-scroll lists | Yes (`TouchScroll`) | Plain lists: on a phone you can't drag a list when your finger starts on a row | **Ported** |

Two things worth knowing about Retro Swim:
- **Bluetooth never worked on iPhone.** Only the Android plugin was built.
- **There is no online play.** Multiplayer is Bluetooth or the same Wi-Fi network only.

## 2. Career mode

You are the head coach of a small college program.

- **World:** 32 fictional schools in 4 conferences, from the bottom one up to the top one.
- **Season:** Retro Bowl pace, one game a week.
  - 3 non-conference games (early-season invitational).
  - 7 conference games (round robin).
  - Conference tournament (top 4).
  - National championship: 8 teams, made up of the 4 conference champions plus the 4 best at-large teams.
- **Games:** you play your own games with today's match. Every other game in the league is simmed from ratings.
- **Hub** between games:
  - Next opponent, venue and PLAY.
  - ROSTER, TRAINING, FACILITIES, RECRUITING, SCHEDULE / STANDINGS, STORE.
  - AD goals, fan hype and the CR wallet.
- **Players:**
  - Class year FR to SR, hidden potential, weekly growth from training, morale and injuries.
  - Season stats: goals, assists, saves, steals and exclusions drawn.
- **Coaching Credits:**
  - Earned from wins, titles and national-championship runs.
  - Spent on facilities: Aquatic Center, Weight Room, Sports Medicine, Video Room, Recruiting Department.
  - Spent on staff: Offense, Defense, Goalkeeping and Recruiting coaches.
  - Also spent on +1 rating boosts and on rehab.
- **Athletic Director:** sets three goals each season and has a confidence bar. If it hits 0, you're fired.
- **Off-season:** the review and **job offers** from bigger schools, then Transfer Portal 1, spring recruiting, Transfer Portal 2 and the roster lock: seniors graduate, everyone grows, recruits and transfers join, walk-ons fill every roster to 18.
- **Progression:** winning builds prestige. Prestige brings job offers from schools in higher conferences. Taking one means a new roster, new colours and a **new home pool**.

## 3. Pools

How I read your note: **players can't customize pools.** You make a few, and each college has exactly one fixed home pool. A match is played in the home team's pool, so moving up to a bigger school takes you to a better pool. For now there's just one pool. It's called "Harbor Natatorium" and has today's look. Every school uses it until you make more.

- The list lives in `game/src/core/pools.gd`. A pool has a name, indoor or outdoor, colours (deck, water, stands, roof) and the number of grandstand rows.
- **To add a pool:** copy the `harbor` entry, change it, and set `pool` on the schools that should play there. If you'd rather paint a pool as a picture, send it over and I'll add an image layer.
- The crowd fills up with your fan hype. The pool itself never changes.

## 4. Store

This is a straight port of Retro Swim's store, with water polo names.

- **Products:**
  - PIXEL POLO + (product id pro_unlock), $7.99 one-time: 500 Yellow Coins once, player name and
    cap number customization, both division packs.
  - Yellow Coin packs (ids blue_100/350/650/1400): 500 for $1.99, 1,750 for $5.99, 3,250 for
    $9.99, 7,000 for $19.99.
  - Division II (division2_pack) and Division III (division3_pack): one-time products, planned
    $2.99 and $3.99. For sale only once the store confirms the product and its price (below).
  - Starter pack.
  - A playoff bundle that replaces the taper bundle: the whole team healthy and fired up before the conference tournament.
- **PRO perks:**
  - +25% CR.
  - Rename and recolour your program.
  - Edit player names and numbers.
  - +2 recruiting visits.
- **Credit vault:** bought credits survive a new career.
- **"N CR SHORT" prompt:** offers the smallest pack that covers the gap, then finishes the upgrade.
- **Real money needs:**
  - The products created in App Store Connect under the bundle `com.akikawasaki.retropolo`.
  - The Paid Apps agreement.
  - The StoreKit 2 plugin Retro Swim already built for Godot 4.7.2.

## 5. Multiplayer

**How a water polo match works across two phones**
- The rules are the same as single player. The difference is that the other team's attacks aren't cards: your friend plays them.
- **Possessions alternate.** The attacking phone runs its attack live, so your throws have zero lag. The AI defends for the other side. The other phone watches live, about 12 updates a second. The host keeps the official score and clock.
- The **sprint** that starts each quarter begins at the same moment on both phones. Whoever reaches the ball first gets it.
- Penalties, exclusions, counterattacks and the shootout all work the same way.
- **Equal teams** is on by default: both clubs get the same ratings, so it's pure skill. Later you'll be able to bring your career team.

| Link | Works on | Status |
|---|---|---|
| Wi-Fi / hotspot | Every phone. On iPhone you type the host's address, because iOS blocks room discovery without an Apple entitlement. | Port from Retro Swim |
| **Online**, with a room code like `K7QX` | Every phone, anywhere | New. Needs a tiny relay server (free Cloudflare Worker). |
| Bluetooth | Android to Android, by porting Retro Swim's plugin | iPhone needs a new CoreBluetooth plugin, and it has to be tested on two real phones |

Your phone is an iPhone, so **Online is the one you'll be able to play first.**

## 6. Build order

1. ~~**Career v1:** saves, hub and screens, the one pool, CONTINUE / NEW CAREER on the title screen.~~ Done.
2. ~~**Store:** the CR chip on every screen, "CR short" prompts, the store screen.~~ Done.
3. **Multiplayer:**
   1. ~~The possession protocol over Wi-Fi.~~ Done.
   2. ~~Online room codes.~~ Done; deploy the relay to switch it on.
   3. ~~Android Bluetooth.~~ Built; test on two phones.
   4. ~~The iPhone Bluetooth plugin.~~ Built; test on an iPhone with a second phone.
4. **Phase 2:** locker room and momentum, event cards and press, records, a women's program, the transfer portal, bringing your career team into multiplayer.

## 7. What only you can do

- **Pools:** design them (colours or pictures) and decide which schools get which.
- **Online:** a free Cloudflare account to deploy the relay (`relay/README.md`). Then put its URL in `game/src/net/net_config.gd`.
- **Bluetooth:** test it with a second phone. iPhone to iPhone, iPhone to Android and Android to Android all use the same protocol.
- **Store:** create the products in App Store Connect.
- **Name:** "Retro ___" is New Star Games' naming family, so pick a final name before release.

## Division packs

Built. 24 schools join the 30 (Colleges.EXPANSION_SCHOOLS): 7 Division II (WWPA), 17 Division III (SCIAC 9,
MPSF East 7, NWPC 1). Ids D2_01..D2_07 and D3_01..D3_17; conference ids WWPA, SCIAC, MPSFE, NEWPC (never
Division I's old MPSF / NWPC ids).

- **Buying.** division2_pack and division3_pack must be created as non-consumables in App Store Connect and
  Play Console. Until the store answers with a price the shop shows COMING SOON with nothing to press
  (Store.division_for_sale). Pixel Polo + owners have both (Store.division_access).
- **New dynasty.** YOUR COACH has ACTIVE DIVISIONS. Only active divisions have teams in that save
  (Career.divisions). The picker filters ALL / I / II / III; unowned packs show locked.
- **Existing dynasties.** NEW DIVISION AVAILABLE! is asked once per pack (Career.div_answers). ADD NEXT SEASON
  waits for Offseason.finish; NOT NOW can be changed in Settings > Game Options.
- **Postseason.** Conference tournaments as before. The WWPA champion is Division II champion and takes one
  of the NCSA's 12 places, seeded by the poll. The NCSA Division III Championship is four teams (SCIAC and MPSF
  East champions, two at-large), played in the NCSA's first two weeks: its games carry `k` (Schedule.game_kind).
  The NWPC has no tournament.
- **Developer Mode.** DIVISION EXPANSION TESTING (division_lab, DivisionChecks); `--test divisions`.
