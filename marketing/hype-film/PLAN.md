# Retro Polo — "COACH IT." (46 s hype film)

Built with the `product-launch-motion` skill. Source: `index.html` + `film.js` (pure seek(t) on `engine/core.js`),
`music.py` (original track), `mix.py` (SFX on the film's own cues). Output: `deliver/`.

## Direction kept: ARCADE CALL-UP
- **Thesis:** an arcade attract-mode trailer that hands a college water polo player the whistle.
- **Dials:** relentless energy · dense · Deck Blue pool ground with lane ropes · flat 2D + phone layer · locked camera with
  shakes/punches · pixel display type (Jersey 10 / Silkscreen / Tiny5, the game's own fonts) · CRT scanlines ·
  full game palette (blue, gold, red, lime) · literal product (real screenshots) · original chiptune-trap, 150 BPM.
- **Structure:** hook to the player → how it plays → the coach's week → the season run → achievements → logo.
  Turn (drop 1) at 21 %, second drop at 69 %. Ends loud on the logo.
- **Signature:** the slingshot — pull back, aim dots, release, the way you throw in the game. Three times: the first goal
  (9.6 s), their penalty flying at the lens into CHAMPIONS (32.0 s), the whole frame pulled back into the logo (41.6 s).
- **Spring:** punchy slams (w 30, z 0.62), snappy cards (w 22, z 0.7), heavy phone (w 9, z 0.86).

## Directions that lost
- **BOTTOM OF THE LEAGUE** — slow documentary, 6 a.m. empty pool, quiet serif captions, chaos only at 75 %. Lost: you asked
  for dopamine and gaming, and it hides the gameplay for half the film.
- **SCOREBOARD** — the whole film lives on one giant pixel scoreboard; every story beat is a number rolling. Lost: shows
  almost none of how the game plays.

## Scene list (bar = 1.6 s)
| Bars | Time | Scene |
|---|---|---|
| 0–2 | 0–4.8 | COLLEGE / WATER / POLO / PLAYERS. → YOU'VE PLAYED THE GAME. → NOW **COACH IT.** (ball bobbing) |
| 3 | 4.8 | Phone rises: Pick your school. "EVERY COACH STARTS AT THE BOTTOM." |
| 4 | 6.4 | Sprint: taps on 16ths. "TAP TAP TAP. WIN THE SPRINT." |
| 5 | 8.0 | Slingshot #1: pull back, aim dots, riser, half-beat of silence |
| 6 | 9.6 | **DROP — GOAL!** flash, shake, confetti, scoreboard 0-0 → 1-0 |
| 7–9 | 11.2 | CALL THE DRIVE (LEFT/MIDDLE/RIGHT) · PLAY DEFENSE / STEAL IT · THEY SHOOT / YOU'RE THE KEEPER (SAVED) |
| 10–11 | 16.0 | 8 trait cards, one per beat |
| 12–15 | 19.2 | Breakdown — the coach's week: RECRUIT · TRAIN · LEAD (locker room) · PRESS |
| 16–17 | 25.6 | WEEK 1→15 / WINS 0→13 · 8-team NCSA bracket collapsing to the final |
| 18–19 | 28.8 | THE FINAL. TIED. SHOOTOUT. · their penalty flies at the lens |
| 20 | 32.0 | **DROP 2 — NCSA CHAMPIONS** + Champions cap |
| 21–25 | 33.6 | 10 achievement toasts every 2 beats, prestige meter 26 → 100 |
| 26–28 | 41.6 | Slingshot #3 → RETRO POLO · COACH IT. PLAY IT. WIN IT ALL. · iPHONE + ANDROID |

## Real vs invented
- **Real (from the game):** every screenshot (captured from the build with `--test shots_png` / `career_png`), the 8 traits,
  the NCSA 8-team championship, school names, award names (Coach/Keeper/Player of the Year, Golden Cap, All-Conference),
  record payouts (+5 CR school, +30 CR NCSA), the Champions cap, job offers, prestige, the locker-room and press quotes.
- **Invented for the story:** the 13-2 season (WINS 0→13), the bracket results, prestige rising 26 → 100, "DYNASTY STARTED".

## DECISIONs (overturn any in one reply)
- DECISION: overrode the skill's "no particle bursts / glows" taste rule: you asked for exaggerated and dopamine-spiking.
  Confetti is square pixels, no soft glows.
- DECISION: original synthesized soundtrack (no licensing risk) instead of a licensed song.
- DECISION: 16:9 1080p60, because the game is landscape-only. A 9:16 cut for Reels/TikTok is the obvious next deliverable.
- DECISION: title "RETRO POLO" set in Jersey 10, not the in-game logo art. Working title; note "Retro ___" is New Star
  Games' naming family.
- DECISION: end card says "iPHONE + ANDROID", no store badges, since the game isn't on the stores yet.
- DECISION: "DEFENSE" (US spelling) for a US college audience.
