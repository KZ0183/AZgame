// 調整用の強いCPU。1ターン分の行動の並びをビーム探索し、敵の行動と次の自分のターン（貪欲）まで進めた盤面で評価する。
// 敵の行動は決定的なので、先読みは正確。山札の順番も見えている（次に来るカードは画面にも出ている）。
'use strict';

function key(s) {
  return JSON.stringify([s.mana, s.life, s.enemy, s.heroes, s.decks.map((d) => [d.hand.map((c) => c.id), d.queue])]);
}

// 貪欲に1ターン打つ（エンジンの botAction）
function greedyTurn(E, s) {
  for (let i = 0; i < 12 && !s.over; i++) { const a = E.botAction(s, () => 0); if (!a) break; E.act(s, a); }
}

// 自分のターンを終えた盤面 s の評価：敵が動く → 次のターンを貪欲に打つ → 敵が動く
function evalDeep(E, s) {
  const t = E.clone(s);
  if (!t.over) E.endTurn(t);
  if (!t.over) { greedyTurn(E, t); if (!t.over) E.endTurn(t); }
  return E.value(t);
}
function evalShallow(E, s) {
  const t = E.clone(s);
  if (!t.over) E.endTurn(t);
  return E.value(t);
}

// このターンの行動の並びを返す
function planTurn(E, state, opt) {
  const B = (opt && opt.beam) || 6, K = (opt && opt.final) || 6;
  let frontier = [{ s: E.clone(state), seq: [] }];
  const seen = new Set([key(frontier[0].s)]);
  const all = [{ s: frontier[0].s, seq: [], v: evalShallow(E, frontier[0].s) }];
  for (let depth = 0; depth < 10 && frontier.length; depth++) {
    const next = [];
    for (const node of frontier) {
      if (node.s.over) continue;
      for (const a of E.actions(node.s)) {
        const s = E.clone(node.s);
        E.act(s, a);
        const k = key(s);
        if (seen.has(k)) continue;
        seen.add(k);
        next.push({ s, seq: node.seq.concat([a]), v: s.over ? E.value(s) : evalShallow(E, s) });
      }
    }
    next.sort((x, y) => y.v - x.v);
    frontier = next.slice(0, B);
    all.push(...frontier);
  }
  all.sort((x, y) => y.v - x.v);
  let best = null, bestV = -Infinity;
  for (const n of all.slice(0, K)) {
    const v = n.s.over ? E.value(n.s) : evalDeep(E, n.s) - n.seq.length * 0.01;
    if (v > bestV) { bestV = v; best = n; }
  }
  return best.seq;
}

// 1戦を最後まで打つ。stats に使ったカードなどを記録する
function playFight(E, g, stats, opt) {
  let guard = 0;
  while (!g.over && guard++ < 40) {
    const seq = planTurn(E, g, opt);
    for (const a of seq) {
      if (g.over) break;
      if (stats && a.type === 'card') { const f = E.findCard(g, a.uid); if (f) stats.card[f.c.id] = (stats.card[f.c.id] || 0) + 1; }
      if (stats && a.type === 'skill') stats.skill[g.heroes[a.k].id] = (stats.skill[g.heroes[a.k].id] || 0) + 1;
      if (stats && a.type === 'move') stats.move++;
      const r = E.act(g, a);
      if (r.error) throw new Error('計画した行動が実行できない: ' + r.error + ' ' + JSON.stringify(a));
    }
    if (!g.over) E.endTurn(g);
  }
  return g;
}

module.exports = { planTurn, playFight, greedyTurn };
