# TestFlight checklist (real iPhones)

Test on at least: one **small** iPhone (SE 3rd gen / 13 mini), one **Dynamic Island** iPhone
(15/16/17 Pro), and the largest you have. Rotate between both landscape directions during each pass.

## Launch and screen
- [ ] Opens straight into the title. Navy launch screen, no Godot logo. Home-screen name "Pixel Polo".
- [ ] Landscape only, in both directions. Portrait never appears.
- [ ] Pixel art is sharp (no blur) and not stretched. Widescreen shows more pool, not fatter pixels.
- [ ] Nothing important is under the Dynamic Island / notch / home indicator: back buttons, header
      chips, the match PAUSE control, CALL DROP, the shooting stick.
- [ ] Every screen: title, Settings (PRIVACY, no DEV button), careers, PICK YOUR SCHOOL, hub, roster,
      player, recruiting, coaching, training, facilities, schedule, standings/conference, Top 20,
      news, records, trophy room, Polo Points Shop, visual shop. Nothing is cut off, and popups fit.
- [ ] Text is readable on the small iPhone.

## Controls (touch)
- [ ] Tap-to-pass, pull-back shot and its meter, DRIVE, defensive formation bar, CALL DROP, keeper dives.
- [ ] Hold the shooting stick and tap a teammate with another finger: neither control misfires.
- [ ] A swipe from the screen edge (Control Center / home) during a pull-back throws nothing.
- [ ] Pause / resume, SIM, and skipping goal celebrations.
- [ ] Scrolling lists, dragging roster cards, recruiting taps. No hover is needed anywhere.

## Interruptions and saves
- [ ] Mid-match: press home, wait, return. The match is paused and resumes cleanly with sound.
- [ ] Get a phone call / FaceTime mid-match, and open Control Center. Same result.
- [ ] In the hub after changing something: swipe the app away, relaunch. The change is there.
- [ ] Play a full game, advance a week, sign a recruit, finish a season, start the next. Force-quit
      at each step, relaunch, and nothing is lost.
- [ ] Low Power Mode and a full-ish disk: saving still works, or says it can't.

## Purchases (sandbox account)
- [ ] Each product: price shows in local currency. Buying it gives the right amount once.
- [ ] Cancel: nothing happens, no message. Ask to Buy: pending, then arrives once after approval.
- [ ] Force-quit right after paying, then relaunch: delivered once.
- [ ] Delete and reinstall, then RESTORE PURCHASES: PIXEL POLO + and ALL 30 TEAMS come back, coins don't.
- [ ] Polo Points balance survives restarts, a new dynasty and deleting a dynasty.

## Ads (test units appear in debug builds; TestFlight uses your real unit, so tap carefully)
- [ ] First launch in an EEA region (VPN, or a UMP debug geography) shows the consent form.
- [ ] Watch to the end: one spin, the wheel animates, correct Polo Points.
- [ ] Close early: "No spin was used." Airplane mode: "no ad available", and the wheel still opens.
- [ ] Game music stops during the ad and comes back afterwards.

## Performance
- [ ] A full match on the oldest iPhone: smooth, no stutters at goals or celebrations.
- [ ] 30 minutes of play: the phone stays reasonably cool, and battery drain is normal for a game.
- [ ] Opening each screen the first time: no long freeze (ScreenWarmup should cover this).
