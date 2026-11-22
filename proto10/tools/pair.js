// ある組の内訳を見る。 node tools/pair.js saint knight out*.json
'use strict';
const fs = require('fs');
const [a, b, ...files] = process.argv.slice(2);
const recs = files.flatMap((f) => fs.readFileSync(f, 'utf8').trim().split('\n').flatMap((l) => JSON.parse(l))).filter((r) => r.heroes.includes(a) && (b === '-' || r.heroes.includes(b)));
const by = {};
for (const r of recs) for (const f of r.fights) { const k = `${f.stage}:${f.foe}`; by[k] = by[k] || { n: 0, w: 0, r: 0 }; by[k].n++; if (f.win) by[k].w++; by[k].r += f.rounds; }
for (const [k, v] of Object.entries(by).sort()) console.log(k, `勝率${(v.w / v.n * 100).toFixed(0)}% 平均${(v.r / v.n).toFixed(1)}R (${v.n})`);
