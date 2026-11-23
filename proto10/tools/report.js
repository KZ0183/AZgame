// sim.js の出力（JSON の行）をまとめて表にする。  node tools/report.js out1.json out2.json ...
'use strict';
const fs = require('fs');
const path = require('path');
const E = require(path.join(__dirname, '..', 'engine.js'));
const recs = process.argv.slice(2).flatMap((f) => fs.readFileSync(f, 'utf8').trim().split('\n').flatMap((l) => JSON.parse(l)));
const pct = (a, b) => b ? (a / b * 100).toFixed(0) + '%' : '-';
const avg = (a) => a.length ? (a.reduce((x, y) => x + y, 0) / a.length).toFixed(1) : '-';
const q = (a, p) => { const s = a.slice().sort((x, y) => x - y); return s.length ? s[Math.min(s.length - 1, Math.floor(s.length * p))] : '-'; };

console.log(`■ ステージのクリア率 ${pct(recs.filter((r) => r.won).length, recs.length)}（${recs.length}回）  クリア時の残りライフ 平均${avg(recs.filter((r) => r.won).map((r) => r.life))}`);

console.log('■ 戦闘ごと');
for (const st of [0, 1, 2]) {
  const fs_ = recs.flatMap((r) => r.fights.filter((f) => f.stage === st));
  const rs = fs_.map((f) => f.rounds);
  console.log(`  ${st === 2 ? 'ボス ' : `第${st + 1}戦`} 勝率${pct(fs_.filter((f) => f.win).length, fs_.length)} ラウンド 平均${avg(rs)} 中央${q(rs, 0.5)} 5%点${q(rs, 0.05)} 95%点${q(rs, 0.95)} 最大${q(rs, 1)}`);
}
console.log('■ 敵ごと（第1・2戦）');
for (const e of E.ENEMIES.filter((x) => !x.boss)) {
  const fs_ = recs.flatMap((r) => r.fights.filter((f) => f.foe === e.id));
  console.log(`  ${e.name} 勝率${pct(fs_.filter((f) => f.win).length, fs_.length)} 平均${avg(fs_.map((f) => f.rounds))}R`);
}

console.log('■ ヒーロー別クリア率');
for (const h of E.HEROES) { const rs = recs.filter((r) => r.heroes.includes(h.id)); console.log(`  ${h.name} ${pct(rs.filter((r) => r.won).length, rs.length)}`); }

console.log('■ 組み合わせ別クリア率（並びごと / 良いほう）');
const pk = {};
for (const r of recs) { const k = r.heroes.join('+'); pk[k] = pk[k] || [[0, 0], [0, 0]]; pk[k][r.front][1]++; if (r.won) pk[k][r.front][0]++; }
for (const [k, v] of Object.entries(pk)) {
  const [a, b] = k.split('+').map((id) => E.HERO[id].name);
  const r0 = v[0][0] / (v[0][1] || 1), r1 = v[1][0] / (v[1][1] || 1);
  console.log(`  ${a}＋${b}  ${a}前衛 ${pct(v[0][0], v[0][1])} / ${b}前衛 ${pct(v[1][0], v[1][1])}  → ${(Math.max(r0, r1) * 100).toFixed(0)}%`);
}

console.log('■ 報酬ごとのクリア率（その報酬を1回でも選んだ冒険）');
const rw = {};
for (const r of recs) for (const x of r.rewards) { const k = x.type === 'card' ? `カード:${E.CARD[x.card].name}` : `${x.type === 'up' ? 'スキル強化' : '最大HP+'}:${E.HERO[x.hero].name}`; rw[k] = rw[k] || [0, 0]; rw[k][1]++; if (r.won) rw[k][0]++; }
for (const [k, v] of Object.entries(rw).sort()) console.log(`  ${k} ${pct(v[0], v[1])}（${v[1]}）`);
const typ = {};
for (const r of recs) for (const x of r.rewards) { typ[x.type] = typ[x.type] || [0, 0]; typ[x.type][1]++; if (r.won) typ[x.type][0]++; }
console.log('  種類別', Object.entries(typ).map(([k, v]) => `${k} ${pct(v[0], v[1])}`).join(' / '));

console.log('■ カードの使用回数（そのヒーローがいた冒険1回あたり）');
for (const h of E.HEROES) {
  const rs = recs.filter((r) => r.heroes.includes(h.id));
  const line = E.CARDS.filter((c) => c.hero === h.id).map((c) => `${c.name}${(rs.reduce((s, r) => s + (r.stats.card[c.id] || 0), 0) / (rs.length || 1)).toFixed(1)}`).join(' ');
  const sk = (rs.reduce((s, r) => s + (r.stats.skill[h.id] || 0), 0) / (rs.length || 1)).toFixed(1);
  console.log(`  ${h.name}: ${line} ｜スキル${sk}`);
}
console.log(`■ 移動 1冒険あたり${avg(recs.map((r) => r.stats.move))}回`);
