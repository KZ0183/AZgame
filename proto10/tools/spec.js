// エンジンの定義から、仕様書のヒーロー・カード・敵の表を出す。 node tools/spec.js
'use strict';
const E = require(require('path').join(__dirname, '..', 'engine.js'));
const tag = (c) => `【${c.cost}${c.pos === 'front' ? '・前衛' : ''}】`;
const act = (a) => `${E.ACT_NAME[a.type]}${a.n}`;
console.log('## ヒーロー\n\n| ヒーロー | HP | 固有スキル【1マナ・1人1ターン1回】 | 強化後 |\n| --- | --- | --- | --- |');
for (const h of E.HEROES) console.log(`| ${h.name} | ${h.hp} | **${h.skill.name}**${h.skill.pos === 'front' ? '（前衛）' : ''}：${h.skill.text} | ${E.SKILL_UP[h.id]} |`);
console.log('\n## カード\n\n【】はコスト。「前衛」は、そのヒーローが前衛にいるときだけ使える。\n');
for (const h of E.HEROES) {
  console.log(`### ${h.name}\n\n| カード | 効果 | 入手 |\n| --- | --- | --- |`);
  for (const c of E.CARDS.filter((x) => x.hero === h.id)) console.log(`| ${c.name}${tag(c)} | ${c.text} | ${c.extra ? '報酬' : '初期'} |`);
  console.log('');
}
console.log('## 敵\n\n| 敵 | HP | 予告の巡回 |\n| --- | --- | --- |');
for (const e of E.ENEMIES) {
  console.log(`| ${e.name}${e.boss ? '（ボス）' : ''} | ${e.boss ? e.hp : `第1戦 ${E.RUN_HP[0]} / 第2戦 ${E.RUN_HP[1]}`} | ${e.pattern.map(act).join(' → ')} |`);
  if (e.phase2) console.log(`| 　本気（HP半分以下） | | ${e.phase2.pattern.map(act).join(' → ')} |`);
}
