// ステージ（3連戦）のシミュレーション。
//   node tools/sim.js [1組あたりの回数=4] [mode=strong|greedy|random] [分割 i/n]
// 全10組（並び順は両方）を回し、JSON を1行出す。集計は tools/report.js。
'use strict';
const path = require('path');
const E = require(path.join(__dirname, '..', 'engine.js'));
const B = require('./bot.js');
const N = +process.argv[2] || 4, mode = process.argv[3] || 'strong';
const [pi, pn] = (process.argv[4] || '0/1').split('/').map(Number);

const ids = E.HEROES.map((h) => h.id);
const pairs = [];
for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) for (const front of [0, 1]) pairs.push({ heroes: [ids[i], ids[j]], front });

function fight(g, stats) {
  if (mode === 'strong') return B.playFight(E, g, stats);
  let guard = 0;
  while (!g.over && guard++ < 40) {
    for (let t = 0; t < 12 && !g.over; t++) {
      let a;
      if (mode === 'greedy') a = E.botAction(g);
      else { const as = E.actions(g); a = as.length && Math.random() < 0.85 ? as[Math.floor(Math.random() * as.length)] : null; }
      if (!a) break;
      if (a.type === 'card') { const f = E.findCard(g, a.uid); stats.card[f.c.id] = (stats.card[f.c.id] || 0) + 1; }
      E.act(g, a);
    }
    if (!g.over) E.endTurn(g);
  }
  return g;
}

const out = [];
pairs.forEach((team, idx) => {
  if (idx % pn !== pi) return;
  for (let t = 0; t < N; t++) {
    const run = E.newRun(team);
    const rec = { heroes: team.heroes, front: team.front, fights: [], rewards: [], won: false, stats: { card: {}, skill: {}, move: 0 } };
    while (!run.over) {
      const st = run.stage;
      const g = E.runFight(run);
      fight(g, rec.stats);
      const more = E.endFight(run, g);
      rec.fights.push({ stage: st, foe: g.enemy.id, rounds: g.round, win: g.winner === 0, life: run.life });
      if (more) {
        const opts = E.rewardOptions(run);
        // 報酬はランダム。REWARD=card|up|hp で取り方を固定できる。あとで「選んだ報酬ごとのクリア率」を見る
        const want = process.env.REWARD || 'random';
        const kind = (x) => x.type === 'card' ? 'card' : x.what === 'skill' ? 'up' : 'hp';
        const o = (want !== 'random' && opts.find((x) => kind(x) === want)) || opts[Math.floor(Math.random() * opts.length)];
        // 新カードの入れ替え先（rewards.sh で良かったもの）
        // 1番目が無ければ2番目（同じヒーローの2枚目を取ったとき）
        const OUT = { sw_cleave: ['sw_lunge', 'sw_double'], sw_parry: ['sw_double', 'sw_lunge'], st_sanctum: ['st_bless', 'st_heal'], st_judge: ['st_heal', 'st_bless'], kn_charge: ['kn_taunt', 'kn_wall'], kn_stand: ['kn_taunt', 'kn_wall'], mg_frost: ['mg_thunder', 'mg_flame'], mg_meteor: ['mg_thunder', 'mg_flame'], rg_poison: ['rg_backstab', 'rg_trip'], rg_pick: ['rg_dagger', 'rg_trip'] };
        const rep = o.type === 'card' ? (OUT[o.card].find((c) => run.mods[o.k].cards.includes(c)) || run.mods[o.k].cards[0]) : null;
        E.applyReward(run, o, rep);
        rec.rewards.push({ type: kind(o), what: o.what || null, card: o.card || null, rep, hero: run.heroes[o.k] });
      }
    }
    rec.won = run.won; rec.life = run.life;
    out.push(rec);
  }
});
console.log(JSON.stringify(out));
