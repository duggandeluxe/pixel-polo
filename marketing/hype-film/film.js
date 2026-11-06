// Retro Polo: "COACH IT." A 46 s hype film for college water polo players.
// Cut to music.py: 150 BPM, beat 0.4 s, bar 1.6 s. Drops at 9.6 s (first goal) and 32.0 s (champions).
// Signature: the slingshot. Pull back, aim, release, the way you throw in the game. Three times: the
// first goal, their shot in the shootout, the logo.
'use strict';
const BEAT = 0.4, BAR = 1.6, at = (bar, beat = 0) => bar * BAR + beat * BEAT;
const DUR = 46.4;
const E = {};
const GOLD = '#ffd23f', INK = '#06103a', BLUE = '#2a68f5', LIME = '#7fe35f', RED = '#ff4a4a', WHITE = '#f4f7ff';
const PUNCH = { w: 30, z: 0.62 };          // slams: hard landing with one small rebound
const CARD = { w: 22, z: 0.7 };            // cards and toasts: snappy, a little overshoot
const POSE = { w: 9, z: 0.86 };            // the phone: heavy, inertial

// ---------------------------------------------------------------- timeline data
const SLAMS = [];   // big type, one per beat
const slam = (txt, tin, tout, x, y, size, cls = '', ax = 0, big = 1) => SLAMS.push({ txt, tin, tout, x, y, size, cls, ax, big });

// hook
['COLLEGE', 'WATER', 'POLO', 'PLAYERS.'].forEach((w, i) => slam(w, at(0, i), at(1) - 0.09, 140, 190 + i * 228, 270, i === 3 ? '' : 'white'));
['YOU\'VE', 'PLAYED', 'THE', 'GAME.'].forEach((w, i) => slam(w, at(1, i), at(2) - 0.09, 140, 190 + i * 228, 270, i === 3 ? '' : 'white'));
slam('NOW', at(2, 0), at(3) - 0.09, 140, 330, 300, 'white');
slam('COACH IT.', at(2, 2), at(3) - 0.09, 140, 650, 400, '', 0, 1.6);
// how it plays
slam('GOAL!', at(6, 0) + 0.06, at(7) - 0.09, 960, 470, 560, '', 0.5, 2);
slam('CALL THE', at(7, 0), at(8) - 0.09, 110, 300, 150, 'white');
slam('DRIVE.', at(7, 1), at(8) - 0.09, 110, 500, 250);
slam('PLAY', at(8, 0), at(9) - 0.09, 110, 290, 170, 'white');
slam('DEFENSE.', at(8, 1), at(9) - 0.09, 110, 470, 190, 'white');
slam('STEAL IT.', at(8, 2), at(9) - 0.09, 110, 690, 190, 'lime');
slam('THEY', at(9, 0), at(10) - 0.09, 110, 280, 170, 'white');
slam('SHOOT.', at(9, 1), at(10) - 0.09, 110, 450, 170, 'white');
slam('YOU\'RE THE', at(9, 2), at(10) - 0.09, 110, 640, 140, 'white');
slam('KEEPER.', at(9, 2.5), at(10) - 0.09, 110, 820, 230, '', 0, 1.3);
// the run to the final
slam('THE FINAL.', at(18, 0), at(19) - 0.09, 140, 270, 220, 'white');
slam('TIED.', at(18, 1), at(19) - 0.09, 140, 520, 300, 'red');
slam('SHOOTOUT.', at(18, 2), at(19) - 0.09, 140, 790, 300, '', 0, 1.3);
slam('NCSA', at(20, 0) + 0.04, at(21) - 0.09, 960, 210, 190, 'white', 0.5);
slam('CHAMPIONS', at(20, 0) + 0.08, at(21) - 0.09, 960, 470, 380, '', 0.5, 2);
// ending
slam('RETRO POLO', at(26, 0) + 0.06, null, 960, 575, 330, '', 0.5, 2);

// screens inside the phone: [image, start]
const SCREENS = [
  ['c01_new_career', at(3)], ['04_sprint_race', at(4)], ['06_aim_shot', at(5)],
  ['05b_drive_call', at(7)], ['10_defense', at(8)], ['10b_their_shot', at(9)], ['09_result_banner', at(9, 2)],
  ['c_recruiting', at(12)], ['c_player', at(13)], ['c_locker', at(14)], ['c_press', at(15)],
  ['c_their_shot', at(19)],
  ['c_records_awards', at(21)], ['c_records', at(22)], ['c_cap_shop', at(23)], ['c_roster', at(24)], ['c_hub', at(25)],
];

// the phone's pose: x, y, scale, opacity
const PX = new Track(960), PY = new Track(1800), PS = new Track(0.92), PO = new Track(1), PR = new Track(0);
function pose(t, x, y, s, sp = POSE, r = 0) { PX.to(t, x, sp); PY.to(t, y, sp); PS.to(t, s, sp); PR.to(t, r, sp); }
pose(at(3) - 0.12, 960, 622, 1.07);
PS.to(at(5), 1.0, { w: 3, z: 1 }); PX.to(at(5), 1010, { w: 3, z: 1 });        // leans back with the pull
pose(at(6), 960, 600, 0.86, PUNCH); PO.to(at(6), 0.28, { w: 30, z: 1 });       // knocked back by the goal
pose(at(7) - 0.12, 1260, 560, 0.86); PO.to(at(7) - 0.12, 1, { w: 20, z: 1 });
pose(at(10), 1260, 1900, 0.86, { w: 10, z: 1 }, 6);                               // out for the trait cards
pose(at(12) - 0.25, 600, 560, 0.8, POSE, 0);
pose(at(16), -800, 560, 0.8, { w: 10, z: 1 });                                  // out for the season
pose(at(19) - 0.25, 960, 610, 1.04, POSE);
pose(at(20), 960, 600, 1.6, { w: 14, z: 1 }); PO.to(at(20), 0, { w: 40, z: 1 }); // their shot hits the lens
pose(at(21) - 0.3, 500, 600, 0.68, POSE); PO.to(at(21) - 0.3, 1, { w: 20, z: 1 });
pose(at(26), 500, 1900, 0.68, { w: 12, z: 1 });

// caption lines (Silkscreen) above the phone
const CAPS = [
  ['EVERY COACH STARTS AT THE BOTTOM.', at(3), at(4) - 0.09, 960, 108, 50],
  ['TAP TAP TAP. WIN THE SPRINT.', at(4), at(5) - 0.09, 960, 108, 50],
  ['PULL BACK. AIM. LET IT RIP.', at(5), at(6) - 0.09, 960, 108, 50],
  ['EVERY STAR GETS A TRAIT.', at(10), at(12) - 0.09, 960, 100, 50],
  ['YOU\'RE IN GOAL. TAP HIGH OR LOW.', at(19), at(20) - 0.09, 960, 108, 46],
  ['SEASON AFTER SEASON.', at(21), at(26) - 0.09, 500, 270, 44],
  ['COACH IT. PLAY IT. WIN IT ALL.', at(26, 1), null, 960, 790, 52],
];

// traits (src/core/traits.gd), one card per beat
const TRAITS = [
  ['CANNON', 'Shoots harder than anyone.'], ['LEFTY SNIPER', 'Tighter shots from the right side.'],
  ['ICE', 'Sharper when the shot clock dies.'], ['WRESTLER', 'Owns the 2-meter fight.'],
  ['BALL HAWK', 'Reads passes. Picks them off.'], ['PLAYMAKER', 'Zips passes nobody catches.'],
  ['JET', 'Fastest man in the water.'], ['WALL', 'A keeper who fills the goal.'],
];

// the coach's week, right of the phone
const WEEK = [
  ['MONDAY', 'RECRUIT.', 'Calls. Visits. Scholarship offers. Land the 5-star.'],
  ['TUESDAY', 'TRAIN.', 'Every player grows toward his ceiling.'],
  ['GAME NIGHT', 'LEAD.', '"Nobody sees the guy who fronts the center for four quarters. I do."'],
  ['NEXT MORNING', 'PRESS.', '"Is this team for real?"'],
];

// bracket (an 8-team NCSA Championship)
const BRACKET = ['HARBOR POINT', 'MAPLE RIDGE', 'KINGSPORT', 'STONEBRIDGE', 'CRESCENT BAY', 'FAIRHAVEN ST', 'GULFHAVEN A&M', 'BRIGHTWATER'];
const QF = [0, 2, 4, 6], SF = [0, 4];

// achievements, every two beats on drop 2
const ACH = [
  'COACH OF THE YEAR', 'GOLDEN CAP', 'KEEPER OF THE YEAR', 'PLAYER OF THE YEAR', 'SCHOOL RECORD +5 CR',
  'NCSA RECORD +30 CR', 'ALL-CONFERENCE x3', 'CHAMPIONS CAP', 'JOB OFFER: BIG SCHOOL', 'DYNASTY STARTED',
];
const ACH_T = ACH.map((_, i) => at(21) + i * 2 * BEAT);
const PRESTIGE = new Track(26);
[8, 7, 7, 8, 7, 7, 8, 7, 7, 8].reduce((v, d, i) => (PRESTIGE.to(ACH_T[i] + 0.05, v + d, { w: 16, z: 0.9 }), v + d), 26);

// screen shakes, punches and flashes: [t, amount]
const SHAKES = [[at(2, 2), 18], [at(6) + 0.06, 46], [at(9, 2.5), 16], [at(18, 1), 12], [at(18, 2), 16], [at(20), 52], [at(26), 40]];
const PUNCHES = [[at(6) + 0.06, 0.07], [at(20), 0.08], [at(26), 0.06], [at(2, 2), 0.035]];
const FLASHES = [[at(6) + 0.04, 0.85], [at(20), 0.9], [at(26), 0.8], [at(9, 2), 0.25]];
// confetti bursts: [t, x, y, count, power, seed]
const BURSTS = [
  [at(6) + 0.06, 1500, 430, 90, 1.2, 1], [at(6) + 0.1, 960, 470, 70, 1.0, 2], [at(9, 2.5), 1190, 560, 40, 0.7, 3],
  [at(20), 960, 470, 140, 1.5, 4], [at(20, 2), 960, 470, 60, 1.0, 5],
  [at(26), 960, 560, 130, 1.4, 6], [at(26, 2), 400, 900, 40, 0.9, 7], [at(26, 2), 1520, 900, 40, 0.9, 8],
];

// global slingshot pull before the logo
const PULL_X = new Track(0), PULL_S = new Track(1);
PULL_X.to(at(25, 2), 140, { w: 3.2, z: 1 }).to(at(26) - 0.02, 0, { w: 40, z: 0.7 });
PULL_S.to(at(25, 2), 0.92, { w: 3.2, z: 1 }).to(at(26) - 0.02, 1, { w: 40, z: 0.7 });

// ---------------------------------------------------------------- the ball (one object, three slingshots)
const SHOT1 = { show: at(5), pull: at(5) + 0.15, rel: at(6), from: [860, 660], back: [600, 800], goal: [1560, 440] };
function ballAt(t) {
  // hook: big, bobbing on the right, popping on each beat
  if (t < at(3) + 0.6) {
    const pop = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11].reduce((a, k) => a + kick(t, at(0, k), 10), 0);
    const hop = t > at(2, 2) ? -160 * Math.sin(Math.PI * clamp((t - at(2, 2)) / 0.5)) : 0;
    const dive = t > at(3) - 0.1 ? 1400 * Math.pow(clamp((t - at(3) + 0.1) / 0.6), 2) : 0;
    const enter = stepR(t - 0.0, { w: 14, z: 0.75 });
    return { x: 1480, y: 560 + 18 * Math.sin(t * 4) + hop + dive + (1 - enter) * 700, s: 2.5 * (1 + 0.08 * pop), o: 1, rot: 4 * Math.sin(t * 2.2) };
  }
  // shot 1: comes up into the phone, gets pulled back, released on the drop
  if (t >= SHOT1.show - 0.2 && t < SHOT1.rel + 0.3) {
    const e = stepR(t - SHOT1.show, CARD), p = ease((t - SHOT1.pull) / (SHOT1.rel - 0.25 - SHOT1.pull));
    const trem = p * 5 * Math.sin(t * 95);
    let x = lerp(SHOT1.from[0], SHOT1.back[0], p) + trem, y = lerp(SHOT1.from[1], SHOT1.back[1], p) + (1 - e) * 500;
    let s = 0.9 + 0.12 * p, o = 1;
    if (t >= SHOT1.rel) {
      const f = outC((t - SHOT1.rel) / 0.13);
      x = lerp(SHOT1.back[0], SHOT1.goal[0], f); y = lerp(SHOT1.back[1], SHOT1.goal[1], f) - 140 * Math.sin(Math.PI * f);
      s = 0.9 - 0.4 * f; o = 1 - clamp((t - SHOT1.rel - 0.13) / 0.08);
    }
    return { x, y, s, o, rot: (t - SHOT1.show) * 720 * (t >= SHOT1.rel ? 1 : 0.05), aim: t < SHOT1.rel ? p : 0 };
  }
  // shot 2: their penalty, coming straight at the lens, explodes into CHAMPIONS
  if (t >= at(19, 1) && t < at(20) + 0.12) {
    const p = clamp((t - at(19, 1)) / (at(20) - at(19, 1)));
    const s = 0.35 + 2.4 * Math.pow(p, 3.2) + (t > at(20) ? (t - at(20)) * 30 : 0);
    return { x: 1000 - 40 * p, y: 470 + 40 * p + 4 * p * Math.sin(t * 90), s, o: t > at(20) ? 1 - (t - at(20)) / 0.12 : 1, rot: t * 400 };
  }
  // shot 3: pulled back with the whole frame, fires into the logo, then bobs on top of it
  if (t >= at(25, 2)) {
    const p = ease((t - at(25, 2)) / (at(26) - 0.1 - at(25, 2)));
    if (t < at(26)) return { x: lerp(1500, 1280, p) + p * 5 * Math.sin(t * 90), y: lerp(900, 980, p), s: 1.1, o: stepR(t - at(25, 2), CARD), rot: 0, aim2: p };
    const f = outC((t - at(26)) / 0.14), e = stepR(t - at(26) - 0.14, PUNCH);
    return { x: lerp(1280, 960, f), y: lerp(980, 300, f) + 10 * Math.sin(t * 3.2), s: lerp(1.1, 1.7, e), o: 1, rot: (1 - f) * 360 + 3 * Math.sin(t * 2) };
  }
  return null;
}

// ---------------------------------------------------------------- build
const FILM = {
  dur: DUR,
  fonts: ["40px Jersey", "40px Silk", "40px Tiny"],
  build() {
    const W = $('world'), H = $('hud');
    // phone
    E.phone = mk('div', 'a phone', null, W);
    E.scr = mk('div', 'scr', null, E.phone);
    E.imgs = SCREENS.map(([n]) => mk('img', '', null, E.scr));
    E.imgs.forEach((im, i) => { im.src = `img/${SCREENS[i][0]}.png`; });
    // trait cards
    E.cards = TRAITS.map(([n, d], i) => {
      const c = mk('div', 'a card', null, W);
      mk('div', 'nm', n, c, n.length > 9 ? 'font-size:66px' : ''); mk('div', 'ds', d, c); mk('div', 'no', `${i + 1}/8`, c);
      return c;
    });
    // the coach's week
    E.week = WEEK.map(([day, verb, line]) => ({
      day: mk('div', 'a cap', day, H, 'font-size:42px;color:#7fe35f'),
      verb: mk('div', 'a slam', verb, H, 'font-size:210px'),
      line: mk('div', 'a tiny', line, H, 'font-size:52px;line-height:1.05;white-space:normal;width:640px'),
    }));
    // season counters
    E.season = {
      wk: mk('div', 'a cap', 'WEEK', H, 'font-size:58px'), wins: mk('div', 'a cap', 'WINS', H, 'font-size:58px;color:#7fe35f'),
      wkN: mk('div', 'a slam white', '1', H, 'font-size:460px'), winsN: mk('div', 'a slam lime', '0', H, 'font-size:460px'),
      sub: mk('div', 'a tiny', 'CONFERENCE PLAY  >  CONFERENCE TOURNAMENT', H, 'font-size:54px'),
    };
    // bracket
    E.bTitle = mk('div', 'a slam', 'NCSA CHAMPIONSHIP', H, 'font-size:150px');
    E.bNames = BRACKET.map(n => mk('div', 'a team', n, H));
    E.bQF = QF.map(i => mk('div', 'a team', BRACKET[i], H));
    E.bSF = SF.map(i => mk('div', 'a team', BRACKET[i], H, 'font-size:46px;color:#ffd23f'));
    // scoreboard after the goal
    E.score = mk('div', 'a plate', null, H, 'width:900px;height:150px');
    mk('div', 'a team', 'HARBOR PT', E.score, 'left:40px;top:52px;font-size:44px');
    E.scoreN = mk('div', 'a slam', '0 - 0', E.score, 'left:450px;top:22px;font-size:130px;transform:translateX(-50%)');
    mk('div', 'a team', 'CRESCENT', E.score, 'right:40px;left:auto;top:52px;font-size:44px');
    // drive chips
    E.chips = ['LEFT', 'MIDDLE', 'RIGHT'].map(c => mk('div', 'a chip', c, H));
    // prestige meter and toasts
    E.prest = mk('div', 'a', null, H, 'width:820px;height:150px');
    mk('div', 'a cap', 'PRESTIGE', E.prest, 'font-size:40px;top:20px');
    E.prestN = mk('div', 'a slam', '26', E.prest, 'font-size:120px;left:auto;right:0;top:-6px');
    E.prestBar = mk('div', 'a', null, E.prest, 'top:96px;width:820px;height:44px;background:#06103a;box-shadow:0 0 0 5px #06103a');
    E.prestCells = Array.from({ length: 20 }, (_, i) => mk('div', 'a', null, E.prestBar, `left:${i * 41 + 3}px;top:4px;width:36px;height:36px;background:#ffd23f`));
    E.toasts = ACH.map((a, i) => {
      const d = mk('div', 'a toast', null, H);
      const ic = mk('div', 'ic', null, d);
      if (a === 'CHAMPIONS CAP') { ic.style.background = '#1d4ab8'; ic.style.boxShadow = 'none'; const im = mk('img', 'a pix', null, ic, 'width:88px;left:4px;top:-6px'); im.src = 'img/champ.png'; }
      else mk('div', 'a', trophy(), ic, 'left:16px;top:12px');
      mk('div', 'l1', 'ACHIEVEMENT UNLOCKED', d); mk('div', 'l2', a, d);
      return d;
    });
    E.champ = mk('img', 'a pix', null, H, 'width:308px'); E.champ.src = 'img/champ.png';
    // captions
    E.caps = CAPS.map(([txt, , , , , size]) => mk('div', 'a cap', txt, H, `font-size:${size}px`));
    E.store = mk('div', 'a tiny', 'iPHONE  +  ANDROID', H, 'font-size:60px;color:#7fe35f');
    // slams on top
    E.slams = SLAMS.map(s => mk('div', `a slam ${s.cls}`, s.txt, H, `font-size:${s.size}px`));
    // the ball
    E.ball = mk('img', 'a pix', null, H, 'width:168px;height:144px'); E.ball.src = 'img/ball.png';
    E.bg = $('bg').getContext('2d'); E.fx = $('fx').getContext('2d');
    E.week.forEach(w => { w.vfit = Math.min(210, 210 * 680 / measure(w.verb.textContent, 210, 400, 0, "font-family:'Jersey'")); w.verb.style.fontSize = w.vfit + 'px'; });
    buildCues();
  },
  seek(t) {
    drawBg(t);
    E.fx.clearRect(0, 0, 1920, 1080);
    drawShake(t);
    drawPhone(t);
    drawSlams(t);
    drawCaps(t);
    drawBall(t);
    drawScore(t);
    drawChips(t);
    drawCards(t);
    drawWeek(t);
    drawSeason(t);
    drawBracket(t);
    drawAch(t);
    drawEnd(t);
    drawTaps(t);
    drawConfetti(t);
  },
};

// a small pixel trophy, drawn with box-shadows (8 px cells)
function trophy() {
  const rows = ['XXXXXXXX', 'XXXXXXXX', ' XXXXXX ', ' XXXXXX ', '  XXXX  ', '   XX   ', '  XXXX  ', ' XXXXXX '];
  const sh = []; rows.forEach((r, y) => [...r].forEach((c, x) => { if (c === 'X') sh.push(`${x * 8}px ${y * 8}px 0 #06103a`); }));
  return `<div style="width:8px;height:8px;box-shadow:${sh.join(',')}"></div>`;
}

// ---------------------------------------------------------------- draw
function drawBg(t) {
  const g = E.bg, champ = clamp((t - at(20)) / 0.05) * (1 - clamp((t - at(21) + 0.2) / 0.3));
  g.fillStyle = mixC(BLUE, '#1b2f9a', champ); g.fillRect(0, 0, 480, 270);
  // scroll distance is the integral of speed: piecewise, so it stays continuous
  const segs = [[0, 18], [at(6), 46], [at(12), 14], [at(16), 30], [at(20), 60]];
  let dist = 0; for (let i = 0; i < segs.length; i++) { const a = segs[i][0], b = i + 1 < segs.length ? segs[i + 1][0] : 1e9; if (t > a) dist += (Math.min(t, b) - a) * segs[i][1]; }
  // light bands
  g.fillStyle = 'rgba(59,123,255,0.55)';
  for (let k = 0; k < 6; k++) g.fillRect(0, k * 54 + 22, 480, 10);
  // lane ropes: floats in pixel dots, red near the walls
  for (let k = 0; k < 5; k++) {
    const y = k * 54 + 50, off = (dist * (k % 2 ? 1 : -1)) % 12;
    for (let x = -12; x < 492; x += 12) {
      const xx = Math.round(x + off), edge = xx < 60 || xx > 420;
      g.fillStyle = edge ? '#ff4a4a' : (Math.floor((x + 12) / 12) % 2 ? '#f4f7ff' : '#ffd23f');
      g.fillRect(xx, y, 6, 3);
    }
  }
  // glints drifting on the water
  g.fillStyle = 'rgba(143,208,245,0.8)';
  for (let i = 0; i < 26; i++) {
    const x = ((hash(i) * 480 + dist * (0.5 + hash(i + 50))) % 500) - 10, y = Math.floor(hash(i + 9) * 270);
    if ((t * 2 + hash(i + 3) * 6) % 3 < 2.2) g.fillRect(Math.round(x), y, 6 + Math.floor(hash(i + 7) * 8), 2);
  }
  if (champ > 0) {   // gold rays behind CHAMPIONS
    g.save(); g.translate(240, 120); g.rotate(t * 0.4); g.fillStyle = `rgba(255,210,63,${0.35 * champ})`;
    for (let k = 0; k < 12; k++) { g.rotate(Math.PI / 6); g.beginPath(); g.moveTo(0, 0); g.lineTo(400, -30); g.lineTo(400, 30); g.fill(); }
    g.restore();
  }
  if (t >= at(26)) {  // end: deeper blue so the logo pops
    const e = clamp((t - at(26)) / 0.4); g.fillStyle = `rgba(27,47,154,${0.45 * e})`; g.fillRect(0, 0, 480, 270);
  }
}

function drawShake(t) {
  let sx = 0, sy = 0, sc = 1;
  for (const [t0, a] of SHAKES) { const k = kick(t, t0, 9) * a; sx += k * Math.sin(t * 97 + t0); sy += k * Math.cos(t * 83 + t0 * 3); }
  for (const [t0, a] of PUNCHES) sc += a * (stepR(t - t0, { w: 40, z: 0.5 }) - stepR(t - t0 - 0.12, { w: 14, z: 1 }));
  sc *= PULL_S.at(t);
  $('shake').style.transform = `translate(${(sx + PULL_X.at(t)).toFixed(2)}px,${sy.toFixed(2)}px) translate(960px,540px) scale(${sc.toFixed(4)}) translate(-960px,-540px)`;
  let fl = 0; for (const [t0, a] of FLASHES) fl = Math.max(fl, a * kick(t, t0, 11));
  $('flash').style.opacity = fl.toFixed(3);
}

function drawPhone(t) {
  const y = PY.at(t), o = PO.at(t);
  if (y > 1500 || PX.at(t) < -700 || o < 0.01) { hide(E.phone); return; }
  E.phone.style.visibility = 'inherit'; E.phone.style.opacity = o.toFixed(3);
  E.phone.style.transform = `translate(${(PX.at(t) - 630).toFixed(2)}px,${(y - 367.5).toFixed(2)}px) scale(${PS.at(t).toFixed(4)}) rotate(${PR.at(t).toFixed(2)}deg)`;
  // push wipe: the new screen slides in from the right, the old one leaves to the left
  let cur = -1; for (let i = 0; i < SCREENS.length; i++) if (t >= SCREENS[i][1]) cur = i;
  E.imgs.forEach((im, i) => {
    if (i !== cur && i !== cur - 1) { hide(im); return; }
    const p = cur >= 0 ? stepR(t - SCREENS[cur][1], { w: 34, z: 0.9 }) : 0;
    if (i === cur - 1 && p > 0.995) { hide(im); return; }
    const x = i === cur ? (cur === 0 ? 0 : (1 - p) * 1200) : -p * 1200;
    im.style.visibility = 'inherit'; im.style.opacity = '1';
    im.style.transform = `translateX(${x.toFixed(1)}px)`;
  });
}

function slamVis(t, s) {
  if (t < s.tin) return null;
  const p = stepR(t - s.tin, PUNCH), o0 = clamp((t - s.tin) / 0.03);
  const x = s.tout == null ? 0 : clamp((t - s.tout) / 0.1);
  if (x >= 1) return null;
  return { o: o0 * (1 - x), s: (1 + 0.9 * s.big * (1 - p)) * (1 + 0.35 * x), b: x * 14, r: (1 - p) * (s.ax ? 0 : -4) };
}
function drawSlams(t) {
  SLAMS.forEach((s, i) => {
    const e = E.slams[i], v = slamVis(t, s);
    if (!v) { hide(e); return; }
    const breathe = 1 + 0.012 * Math.sin(t * 5 + i);
    e.style.visibility = 'inherit'; e.style.opacity = v.o.toFixed(3); e.style.filter = v.b > 0.05 ? `blur(${v.b.toFixed(1)}px)` : 'none';
    e.style.transformOrigin = s.ax ? '50% 50%' : '0% 50%';
    e.style.transform = `translate(${s.x}px,${s.y}px) translate(${-s.ax * 100}%,-50%) scale(${(v.s * breathe).toFixed(4)}) rotate(${v.r.toFixed(2)}deg)`;
  });
}

function drawCaps(t) {
  CAPS.forEach(([, tin, tout, x, y], i) => {
    const v = vis(t, tin, tout), e = E.caps[i];
    if (v.o < 0.002) { hide(e); return; }
    place(e, x, y, 0.5, v);
  });
}

function drawBall(t) {
  const b = ballAt(t);
  if (!b || b.o < 0.01) { hide(E.ball); return; }
  // aim guide: yellow dots with a dark rim, from the ball to the goal, the way the game draws it
  if (b.aim > 0.02) aimDots(b.x, b.y, SHOT1.goal[0], SHOT1.goal[1], b.aim);
  if (b.aim2 > 0.02) aimDots(b.x, b.y, 960, 330, b.aim2);
  // motion trail on release
  if (t > SHOT1.rel && t < SHOT1.rel + 0.25) for (let k = 1; k <= 6; k++) { const q = ballAt(t - k * 0.012); if (q) pix(q.x, q.y, 70 * q.s * (1 - k / 8), `rgba(255,210,63,${0.35 * (1 - k / 7)})`); }
  if (t > at(26) && t < at(26) + 0.3) for (let k = 1; k <= 6; k++) { const q = ballAt(t - k * 0.014); if (q) pix(q.x, q.y, 70 * q.s * (1 - k / 8), `rgba(255,210,63,${0.35 * (1 - k / 7)})`); }
  E.ball.style.visibility = 'inherit'; E.ball.style.opacity = b.o.toFixed(3); E.ball.style.filter = 'none';
  E.ball.style.transform = `translate(${(b.x - 84).toFixed(2)}px,${(b.y - 72).toFixed(2)}px) scale(${b.s.toFixed(4)}) rotate(${(b.rot || 0).toFixed(1)}deg)`;
}
function aimDots(x0, y0, x1, y1, p) {
  const g = E.fx, n = 16, shown = Math.round(n * clamp(p * 1.4));
  for (let i = 1; i <= shown; i++) {
    const f = i / n, x = lerp(x0, x1, f), y = lerp(y0, y1, f) - 120 * Math.sin(Math.PI * f) * p;
    const r = 9 + 3 * p;
    g.fillStyle = INK; g.fillRect(Math.round(x - r - 4), Math.round(y - r - 4), 2 * r + 8, 2 * r + 8);
    g.fillStyle = i === shown ? '#ffffff' : GOLD; g.fillRect(Math.round(x - r), Math.round(y - r), 2 * r, 2 * r);
  }
  // target ring at the goal
  const k = 34 + 8 * Math.sin(p * 40);
  g.strokeStyle = GOLD; g.lineWidth = 8; g.strokeRect(x1 - k, y1 - k, 2 * k, 2 * k);
}
const pix = (x, y, s, c) => { E.fx.fillStyle = c; E.fx.fillRect(Math.round(x - s / 2), Math.round(y - s / 2), s, s); };

function drawScore(t) {
  const t0 = at(6, 2);
  if (t < t0 || t > at(7)) { hide(E.score); return; }
  const v = vis(t, t0, at(7) - 0.12), e = stepR(t - t0, CARD);
  place(E.score, 960, 880 + (1 - e) * 200, 0.5, v);
  E.scoreN.textContent = t < at(6, 3) ? '0 - 0' : '1 - 0';
  const pop = kick(t, at(6, 3), 12);
  E.scoreN.style.transform = `translateX(-50%) scale(${(1 + 0.5 * pop).toFixed(3)})`;
}

function drawChips(t) {
  E.chips.forEach((c, i) => {
    const tin = at(7, 2 + i * 0.5), v = vis(t, tin, at(8) - 0.1);
    if (v.o < 0.002) { hide(c); return; }
    const e = stepR(t - tin, PUNCH), lit = i === 2 && t > at(7, 3.3);
    c.style.background = lit ? GOLD : '#0b1224'; c.style.color = lit ? INK : WHITE;
    place(c, 110 + [0, 240, 560][i], 760, 0, v, `scale(${(1.6 - 0.6 * e).toFixed(3)})`);
  });
}

function drawCards(t) {
  E.cards.forEach((c, i) => {
    const tin = at(10, i), tout = at(12) - 0.3 + i * 0.03;
    if (t < tin - 0.01 || t > tout + 0.5) { hide(c); return; }
    const col = i % 4, row = Math.floor(i / 4), e = stepR(t - tin, CARD), x0 = stepR(t - tout, { w: 14, z: 1 });
    const x = 960 + (col - 1.5) * 448, y = 380 + row * 360 + (1 - e) * 760 - x0 * 1300;
    const r = (1 - e) * (i % 2 ? 14 : -14) + (hash(i) - 0.5) * 4;
    c.style.visibility = 'inherit'; c.style.opacity = '1';
    c.style.transform = `translate(${(x - 200).toFixed(1)}px,${(y - 135).toFixed(1)}px) rotate(${r.toFixed(2)}deg) scale(${(1 + 0.08 * kick(t, tin + 0.06, 10)).toFixed(3)})`;
  });
}

function drawWeek(t) {
  E.week.forEach((w, i) => {
    const tin = at(12 + i), tout = at(13 + i) - 0.12;
    const vd = vis(t, tin, tout), vv = vis(t, tin + 0.08, tout), vl = vis(t, tin + 0.4, tout);
    const x = 1170;
    if (vd.o < 0.002) hide(w.day); else place(w.day, x, 330, 0, vd);
    if (vv.o < 0.002) hide(w.verb); else place(w.verb, x, 470, 0, vv, `scale(${(1 + 0.4 * (1 - stepR(t - tin - 0.08, PUNCH))).toFixed(3)})`);
    if (vl.o < 0.002) hide(w.line); else place(w.line, x, 600, 0, vl, '', 0);
    w.verb.style.transformOrigin = '0% 50%';
  });
}

// season counters: one step per 16th note, two losses on the way
const SEASON_T0 = at(16), STEP = BEAT / 4, LOSSES = [4, 9];
function drawSeason(t) {
  const S = E.season, tin = at(16), tout = at(17) - 0.1;
  const v = vis(t, tin, tout);
  if (v.o < 0.002) { [S.wk, S.wins, S.wkN, S.winsN, S.sub].forEach(hide); return; }
  const k = clamp(Math.floor((t - SEASON_T0) / STEP), 0, 14), wk = k + 1;
  let wins = 0; for (let i = 1; i <= wk; i++) if (!LOSSES.includes(i)) wins++;
  const pop = kick(t, SEASON_T0 + k * STEP, 18);
  S.wkN.textContent = String(wk); S.winsN.textContent = String(wins);
  place(S.wk, 560, 230, 0.5, v); place(S.wins, 1360, 230, 0.5, v);
  place(S.wkN, 560, 560, 0.5, v, `scale(${(1 + 0.12 * pop).toFixed(3)})`);
  place(S.winsN, 1360, 560, 0.5, v, `scale(${(1 + 0.12 * pop * (LOSSES.includes(wk) ? 0 : 1)).toFixed(3)})`);
  place(S.sub, 960, 900, 0.5, vis(t, tin + 0.6, tout));
}

function drawBracket(t) {
  const t0 = at(17), tout = at(18) - 0.1, v = vis(t, t0, tout);
  if (v.o < 0.002) { hide(E.bTitle); E.bNames.forEach(hide); E.bQF.forEach(hide); E.bSF.forEach(hide); return; }
  place(E.bTitle, 960, 120, 0.5, v);
  const ys = BRACKET.map((_, i) => 270 + i * 92);
  const qfY = QF.map(i => (ys[i] + ys[i + 1]) / 2), sfY = [(qfY[0] + qfY[1]) / 2, (qfY[2] + qfY[3]) / 2];
  const pQF = stepR(t - at(17, 1), { w: 30, z: 1 }), pSF = stepR(t - at(17, 2), { w: 30, z: 1 });
  E.bNames.forEach((e, i) => {
    const vi = vis(t, t0 + i * 0.05, tout), lose = i % 2 === 1 ? pQF : 0;
    place(e, 160, ys[i], 0, { ...vi, o: vi.o * (1 - 0.7 * lose) });
  });
  const g = E.fx; g.lineWidth = 6;
  // quarterfinal brackets
  if (pQF > 0.001) QF.forEach((i, q) => {
    g.strokeStyle = `rgba(244,247,255,${v.o})`; g.beginPath();
    const xr = 700, xm = lerp(xr, 820, pQF);
    g.moveTo(xr - 20, ys[i]); g.lineTo(xm, ys[i]); g.moveTo(xr - 20, ys[i + 1]); g.lineTo(xm, ys[i + 1]);
    g.moveTo(xm, ys[i]); g.lineTo(xm, ys[i + 1]); g.moveTo(xm, qfY[q]); g.lineTo(lerp(xm, 880, pQF), qfY[q]); g.stroke();
  });
  E.bQF.forEach((e, q) => {
    const vi = vis(t, at(17, 1) + 0.1 + q * 0.04, tout), lose = q % 2 === 1 ? pSF : 0;
    place(e, 900, qfY[q], 0, { ...vi, o: vi.o * (1 - 0.7 * lose) });
  });
  if (pSF > 0.001) [0, 2].forEach((q, s) => {
    g.strokeStyle = `rgba(255,210,63,${v.o})`; g.beginPath();
    const xr = 1290, xm = lerp(xr, 1360, pSF);
    g.moveTo(xr, qfY[q]); g.lineTo(xm, qfY[q]); g.moveTo(xr, qfY[q + 1]); g.lineTo(xm, qfY[q + 1]);
    g.moveTo(xm, qfY[q]); g.lineTo(xm, qfY[q + 1]); g.moveTo(xm, sfY[s]); g.lineTo(lerp(xm, 1400, pSF), sfY[s]); g.stroke();
  });
  E.bSF.forEach((e, s) => {
    const vi = vis(t, at(17, 2) + 0.1 + s * 0.05, tout), pop = kick(t, at(17, 3), 8);
    place(e, 1420, sfY[s], 0, vi, `scale(${(1 + 0.25 * pop).toFixed(3)})`);
  });
}

function drawAch(t) {
  // prestige meter
  const vp = vis(t, at(21) - 0.1, at(26) - 0.1);
  if (vp.o < 0.002) hide(E.prest);
  else {
    place(E.prest, 1010, 150, 0, vp, '', 0);
    const val = Math.min(100, Math.round(PRESTIGE.at(t)));
    E.prestN.textContent = String(val);
    const lastHit = ACH_T.filter(x => x + 0.05 <= t).pop() || -9;
    E.prestN.style.transform = `scale(${(1 + 0.25 * kick(t, lastHit + 0.05, 10)).toFixed(3)})`;
    E.prestN.style.transformOrigin = '100% 50%';
    E.prestCells.forEach((c, i) => { c.style.opacity = (i < Math.floor(PRESTIGE.at(t) / 5) ? 1 : 0.12).toFixed(2); c.style.background = PRESTIGE.at(t) >= 99.5 ? LIME : GOLD; });
  }
  // toasts: newest on top, older ones get pushed down a slot
  E.toasts.forEach((d, i) => {
    const tin = ACH_T[i];
    if (t < tin - 0.01 || t > at(26) + 0.2) { hide(d); return; }
    let slot = 0; for (let j = i + 1; j < ACH.length; j++) slot += stepR(t - ACH_T[j], CARD);
    const e = stepR(t - tin, CARD), out = clamp(slot - 3);
    const x = 1010 + (1 - e) * 1000, y = 340 + slot * 168;
    const o = (1 - out) * (1 - clamp((t - at(26) + 0.12) / 0.1));
    if (o < 0.01) { hide(d); return; }
    d.style.visibility = 'inherit'; d.style.opacity = o.toFixed(3); d.style.filter = 'none';
    d.style.transform = `translate(${x.toFixed(1)}px,${y.toFixed(1)}px) scale(${(1 + 0.06 * kick(t, tin + 0.08, 10)).toFixed(3)})`;
  });
  // the Champions cap under CHAMPIONS
  const vc = vis(t, at(20, 2), at(21) - 0.1);
  if (vc.o < 0.002) hide(E.champ);
  else place(E.champ, 960, 840, 0.5, vc, `scale(${(1 + 0.6 * (1 - stepR(t - at(20, 2), PUNCH))).toFixed(3)}) rotate(${(3 * Math.sin(t * 4)).toFixed(2)}deg)`);
}

function drawEnd(t) {
  const v = vis(t, at(26, 2), null);
  if (v.o < 0.002) hide(E.store); else place(E.store, 960, 900, 0.5, v);
}

// finger taps on the sprint screen (16ths, like mashing) and the keeper dive
function drawTaps(t) {
  const taps = [];
  for (let k = 0; k < 14; k++) taps.push([at(4, 0.5) + k * BEAT / 4, 760 + (hash(k) - 0.5) * 700, 470 + (hash(k + 30) - 0.5) * 360]);
  taps.push([at(19, 2.5), 760, 380]);
  for (const [t0, x, y] of taps) {
    const a = t - t0; if (a < 0 || a > 0.35) continue;
    const r = 20 + 140 * outC(a / 0.35), o = 1 - a / 0.35;
    E.fx.strokeStyle = `rgba(255,255,255,${o.toFixed(3)})`; E.fx.lineWidth = 8; E.fx.strokeRect(x - r, y - r, 2 * r, 2 * r);
    if (a < 0.08) pix(x, y, 36, 'rgba(255,255,255,0.9)');
  }
}

const CONF = [GOLD, WHITE, RED, LIME, '#3b7bff', '#ffd23f'];
function drawConfetti(t) {
  const g = E.fx;
  for (const [t0, x0, y0, n, pw, seed] of BURSTS) {
    const a = t - t0; if (a < 0 || a > 2.6) continue;
    for (let i = 0; i < n; i++) {
      const h1 = hash(seed * 97 + i), h2 = hash(seed * 131 + i * 7), h3 = hash(seed * 17 + i * 3);
      const ang = h1 * Math.PI * 2, sp = (500 + 1500 * h2) * pw, k = 2.4;
      const dx = Math.cos(ang) * sp * (1 - Math.exp(-k * a)) / k, dy = Math.sin(ang) * sp * (1 - Math.exp(-k * a)) / k - 300 * a + 520 * a * a;
      const s = Math.round(10 + 16 * h3), flip = Math.abs(Math.cos(a * (6 + 10 * h1) + h2 * 6));
      const life = 1 - clamp((a - 1.6 - h3 * 0.6) / 0.4);
      if (life <= 0) continue;
      g.globalAlpha = life; g.fillStyle = CONF[i % CONF.length];
      g.fillRect(Math.round(x0 + dx - s / 2), Math.round(y0 + dy - s * flip / 2), s, Math.max(2, Math.round(s * flip)));
    }
    g.globalAlpha = 1;
  }
  // a gentle gold rain under the logo, looping on its own clock
  if (t > at(26, 1)) {
    const e = clamp((t - at(26, 1)) / 0.6);
    for (let i = 0; i < 50; i++) {
      const sp = 140 + 120 * hash(i + 400), y = ((t - at(26)) * sp + hash(i + 300) * 1200) % 1200 - 60;
      g.globalAlpha = 0.8 * e; g.fillStyle = CONF[i % CONF.length];
      const s = 10 + Math.round(10 * hash(i + 500));
      g.fillRect(Math.round(hash(i + 200) * 1920 + 30 * Math.sin(t * 2 + i)), Math.round(y), s, Math.max(2, Math.round(s * Math.abs(Math.cos(t * 4 + i)))));
    }
    g.globalAlpha = 1;
  }
}

// ---------------------------------------------------------------- sound cues (exported by engine/cues.mjs)
function buildCues() {
  SLAMS.forEach(s => cue(s.tin, s.big >= 2 ? 'mega' : s.big > 1 ? 'big' : 'slam'));
  cue(at(3) - 0.12, 'whoosh'); cue(at(3) - 0.1, 'splash');
  SCREENS.forEach(([, t0], i) => { if (i) cue(t0, 'swipe'); });
  for (let k = 0; k < 14; k++) cue(at(4, 0.5) + k * BEAT / 4, 'tap', k);
  cue(SHOT1.pull, 'stretch', SHOT1.rel - 0.25 - SHOT1.pull);
  cue(SHOT1.rel, 'release'); cue(at(6) + 0.06, 'goal'); cue(at(6, 3), 'coin');
  [0, 1, 2].forEach(i => cue(at(7, 2 + i * 0.5), 'stamp', i));
  cue(at(9, 2), 'save');
  TRAITS.forEach((_, i) => cue(at(10, i), 'card', i));
  cue(at(12) - 0.3, 'whoosh');
  WEEK.forEach((_, i) => cue(at(12 + i) + 0.08, 'verb', i));
  for (let k = 0; k < 15; k++) cue(SEASON_T0 + k * STEP, 'tick', LOSSES.includes(k + 1) ? 0 : 1);
  cue(at(17, 1), 'bracket'); cue(at(17, 2), 'bracket'); cue(at(17, 3), 'coin');
  cue(at(19, 1), 'incoming', at(20) - at(19, 1)); cue(at(19, 2.5), 'tap', 0);
  cue(at(20), 'champions');
  ACH_T.forEach((x, i) => cue(x, 'achieve', i));
  cue(at(25, 2), 'stretch', at(26) - 0.1 - at(25, 2)); cue(at(26), 'release'); cue(at(26) + 0.06, 'logo');
}

window.addEventListener('load', () => boot(FILM));
