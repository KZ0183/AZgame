// 報酬1つずつの価値を測る。最初からその報酬を持った状態で冒険し（ほかの報酬はなし）、何もなしの場合と比べる。
//   node tools/rewards.js [回数=40] [ヒーロー id（省略で全員）] [分割 i/n]
// 出力は JSON の行：{ hero, kind, label, n, won }
'use strict';
const path = require('path');
const E = require(path.join(__dirname, '..', 'engine.js'));
const B = require('./bot.js');
const N = +process.argv[2] || 40;
const only = process.argv[3] && process.argv[3] !== '-' ? process.argv[3] : null;
const [pi, pn] = (process.argv[4] || '0/1').split('/').map(Number);

function runWith(hero, partner, front, mod) {
  const run = E.newRun({ heroes: [hero, partner], front });
  if (mod) mod(run.mods[0], run);
  while (!run.over) {
    const g = E.runFight(run);
    B.playFight(E, g, null);
    E.endFight(run, g);
  }
  return run.won;
}

const jobs = [];
for (const h of E.HEROES) {
  if (only && h.id !== only) continue;
  jobs.push({ hero: h.id, kind: 'base', label: '報酬なし', mod: null });
  jobs.push({ hero: h.id, kind: 'up', label: 'スキル強化', mod: (m) => { m.up = true; } });
  jobs.push({ hero: h.id, kind: 'hp', label: '最大HP+', mod: (m) => { m.hp += E.HP_UP; } });
  for (const c of E.CARDS.filter((x) => x.hero === h.id && x.extra)) for (const old of h.cards) {
    jobs.push({ hero: h.id, kind: 'card', label: `${c.name} ← ${E.CARD[old].name}`, card: c.id, old, mod: (m) => { m.cards[m.cards.indexOf(old)] = c.id; } });
  }
}
jobs.forEach((j, idx) => {
  if (idx % pn !== pi) return;
  let n = 0, won = 0;
  for (const p of E.HEROES) {
    if (p.id === j.hero) continue;
    for (const front of [0, 1]) for (let t = 0; t < N / 8; t++) { n++; if (runWith(j.hero, p.id, front, j.mod)) won++; }
  }
  console.log(JSON.stringify({ hero: j.hero, kind: j.kind, label: j.label, card: j.card, old: j.old, n, won }));
});
