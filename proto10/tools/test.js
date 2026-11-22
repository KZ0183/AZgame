// エンジンのテスト。 node tools/test.js
// 1) 決まった盤面でルールを1つずつ確かめる  2) でたらめに打ち続けて不変条件が崩れないか確かめる
'use strict';
const path = require('path');
const E = require(path.join(__dirname, '..', 'engine.js'));
let pass = 0, fail = 0;
const ok = (name, cond, info) => { if (cond) pass++; else { fail++; console.log('✗', name, info === undefined ? '' : JSON.stringify(info)); } };
const eq = (name, a, b) => ok(name, JSON.stringify(a) === JSON.stringify(b), { got: a, want: b });

// 決まった乱数
function rng(seed) { let s = seed >>> 0; return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; }; }

// 手札を好きなカードにした盤面を作る
function setup(heroes, front, enemyId, hands, opt) {
  const g = E.newGame({ heroes, front, mods: (opt && opt.mods) || undefined }, enemyId, rng(1), opt);
  if (hands) hands.forEach((ids, k) => {
    if (!ids) return;
    const all = g.decks[k].hand.map((c) => c.id).concat(g.decks[k].queue);
    const rest = all.filter((id) => !ids.includes(id));
    g.decks[k].hand = ids.map((id) => ({ uid: g.nextUid(), id }));
    g.decks[k].queue = rest.concat(ids.filter((id) => !all.includes(id)).length ? [] : []);
    while (g.decks[k].queue.length < 2) g.decks[k].queue.push(rest[0] || ids[0]);
  });
  g.mana = (opt && opt.mana) || 6;
  return g;
}
const play = (g, id, target) => { const c = g.decks.flatMap((d) => d.hand).find((x) => x.id === id); return E.act(g, { type: 'card', uid: c.uid, target: target === undefined ? null : target }); };
const setIntent = (g, i) => { g.enemy.step = i; };

// ── 予告の当たり先 ──
{
  const g = setup(['knight', 'mage'], 0, 'golem');           // 騎士が前衛、魔術師が後衛。予告は「前衛へ6」
  eq('前衛へ攻撃は前衛だけ', E.intent(g).targets, [{ k: 0 }]);
  E.endTurn(g);
  eq('前衛へ攻撃のダメージ', [g.heroes[0].hp, g.heroes[1].hp], [15 - 6, 9]);
}
{
  const g = setup(['knight', 'mage'], 0, 'golem');
  E.act(g, { type: 'move', k: 0 });                          // 前衛が空になる
  eq('前衛が空ならライフ', E.intent(g).targets, [{ life: true }]);
  E.endTurn(g);
  eq('ライフに当たる', g.life, 20 - 6);
}
{
  const g = setup(['knight', 'mage'], 0, 'spider');          // 後衛へ7
  eq('後衛へ攻撃は後衛だけ', E.intent(g).targets, [{ k: 1 }]);
  E.act(g, { type: 'move', k: 1 });
  eq('後衛が空ならライフ', E.intent(g).targets, [{ life: true }]);
}
{
  const g = setup(['knight', 'sword'], 0, 'dragon');         // 強打8
  E.act(g, { type: 'move', k: 1 });                          // 2人とも前衛。HPが高いのは騎士
  eq('強打はHPが高い前衛', E.intent(g).targets, [{ k: 0 }]);
  g.heroes[0].hp = 5;
  eq('強打はHPが高いほうへ移る', E.intent(g).targets, [{ k: 1 }]);
}

// ── 挑発・反撃・かばう ──
{
  const g = setup(['knight', 'sword'], 0, 'dragon', [['kn_taunt', 'kn_bash'], null]);
  E.act(g, { type: 'move', k: 1 });
  g.heroes[0].hp = 5;                                        // 強打は本来、剣士へ
  play(g, 'kn_taunt');
  eq('挑発で強打が騎士へ', E.intent(g).targets, [{ k: 0, why: '挑発' }]);
  const hp = g.enemy.hp;
  E.endTurn(g);
  ok('挑発の反撃は倒れたら出ない', g.heroes[0].ko && g.enemy.hp === hp, { ko: g.heroes[0].ko, hp: g.enemy.hp });
}
{
  const g = setup(['knight', 'sword'], 0, 'golem', [['kn_taunt', 'kn_bash'], null]);
  play(g, 'kn_taunt');
  const hp = g.enemy.hp;
  E.endTurn(g);
  eq('反撃4', g.enemy.hp, hp - 4);
  eq('反撃は次のターンに消える', g.heroes[0].counter, 0);
}
{
  const g = setup(['knight', 'mage'], 0, 'spider');          // 後衛へ7 → 魔術師
  E.act(g, { type: 'skill', k: 0, target: 1 });              // かばう
  eq('かばうで後衛への攻撃も騎士へ', E.intent(g).targets, [{ k: 0, why: 'かばう', from: 1 }]);
  E.endTurn(g);
  eq('かばった結果', [g.heroes[0].hp, g.heroes[1].hp], [15 - 7, 9]);
  eq('かばうは次のターンに消える', g.heroes[1].guard, null);
}
{
  const g = setup(['knight', 'mage'], 0, 'spider');
  setIntent(g, 4);                                           // 全体6
  E.act(g, { type: 'skill', k: 0, target: 1 });
  eq('全体攻撃をかばうと2回受ける', E.intent(g).targets.map((t) => t.k), [0, 0]);
  E.endTurn(g);
  eq('2回ぶん受ける', [g.heroes[0].hp, g.heroes[1].hp], [15 - 12, 9]);
}
ok('自分はかばえない', !!E.check(setup(['knight', 'mage'], 0, 'golem'), { type: 'skill', k: 0, target: 0 }));

{
  const g = setup(['knight', 'mage'], 0, 'spider', [['kn_taunt', 'kn_bash'], null]);
  setIntent(g, 4);                                           // 全体6。騎士 → 魔術師の順に当たる
  g.enemy.hp = 3; g.heroes[1].hp = 1; g.life = 4;
  play(g, 'kn_taunt');
  E.endTurn(g);
  ok('反撃で敵が倒れたら残りの攻撃は当たらない', g.over && g.winner === 0 && !g.heroes[1].ko && g.life === 4, { winner: g.winner, life: g.life });
}

// ── 盾・溜め・弱体・身を固める ──
{
  const g = setup(['knight', 'saint'], 0, 'golem', [['kn_guard', 'kn_bash'], null]);
  play(g, 'kn_guard', 0);                                    // 盾5、予告は前衛へ6
  E.endTurn(g);
  eq('盾が先に減る', [g.heroes[0].hp, g.heroes[0].shield], [14, 0]);
}
{
  const g = setup(['rogue', 'saint'], 0, 'golem', [['rg_trip', 'rg_dagger'], null]);
  play(g, 'rg_trip', 'enemy');
  eq('足払いで予告のダメージ−3', E.intent(g).dmg, 3);
  E.endTurn(g);
  eq('弱体は1回で消える', g.enemy.weak, 0);
}
{
  const g = setup(['mage', 'saint'], 0, 'dragon', [['mg_flame', 'mg_bolt'], null]);
  setIntent(g, 1); E.endTurn(g);                             // 溜め4 → 次は全体6
  eq('溜めが次の攻撃に乗る', E.intent(g).dmg, 10);
  play(g, 'mg_flame', 'enemy');
  eq('火炎で溜めが消える', E.intent(g).dmg, 6);
}
{
  const g = setup(['sword', 'saint'], 0, 'golem', [['sw_slash', 'sw_cleave'], null]);
  setIntent(g, 1); E.endTurn(g);                             // 身を固める6
  eq('敵の盾', g.enemy.shield, 6);
  const hp = g.enemy.hp;
  play(g, 'sw_slash', 'enemy');
  eq('盾が攻撃を防ぐ', [g.enemy.hp, g.enemy.shield], [hp, 3]);
  play(g, 'sw_cleave', 'enemy');
  eq('盾割りは盾を壊してから4', [g.enemy.hp, g.enemy.shield], [hp - 4, 0]);
}

// ── 怒り・撹乱・毒 ──
{
  const g = setup(['knight', 'saint'], 0, 'golem');
  g.life = 999; g.heroes.forEach((h) => { h.hp = h.maxHp = 999; });
  for (let i = 0; i < E.RAGE_EVERY - 1; i++) E.endTurn(g);
  eq('怒りの前', E.view(g).enemy.rage, 0);
  E.endTurn(g);
  eq('5回行動で怒り+3', E.view(g).enemy.rage, E.ENRAGE);
}
{
  const g = setup(['rogue', 'saint'], 0, 'golem', [['rg_jam', 'rg_dagger'], null]);
  const before = E.intent(g).type;
  play(g, 'rg_jam');
  ok('撹乱で予告が次へ', E.intent(g).type !== before && g.enemy.step === 1);
  eq('撹乱は怒りを早めない', g.enemy.acted, 0);
}
{
  const g = setup(['rogue', 'saint'], 0, 'golem', [['rg_poison', 'rg_dagger'], null]);
  play(g, 'rg_poison', 'enemy');
  const hp = g.enemy.hp;
  E.endTurn(g); E.endTurn(g); E.endTurn(g);
  eq('毒は敵の行動ごとに2、3回', [hp - g.enemy.hp, g.enemy.poison], [6, 0]);
  E.endTurn(g);
  eq('毒は3回で終わる', hp - g.enemy.hp, 6);
}

// ── 撃破と復活 ──
{
  const g = setup(['mage', 'knight'], 0, 'golem');
  g.heroes[0].hp = 1;
  E.endTurn(g);
  ok('倒れるとライフ−4', g.heroes[0].ko && g.life === 20 - E.KO_LIFE, { life: g.life });
  ok('倒れたヒーローのカードは使えない', g.decks[0].hand.every((c) => E.check(g, { type: 'card', uid: c.uid, target: 'enemy' }) && E.check(g, { type: 'card', uid: c.uid, target: null })));
  ok('次のターンは休む', g.heroes[0].ko && g.heroes[0].wait === 0);
  E.endTurn(g);
  ok('後衛で全快して復活', !g.heroes[0].ko && g.heroes[0].pos === 'back' && g.heroes[0].hp === g.heroes[0].maxHp, g.heroes[0]);
}

// ── マナ・巡回・スキル ──
{
  const g = E.newGame({ heroes: ['sword', 'mage'], front: 0 }, 'golem', rng(3));
  eq('1ラウンド目のマナ', g.mana, 2);
  E.endTurn(g); eq('2ラウンド目のマナ', g.mana, 3);
  for (let i = 0; i < 6; i++) { g.life = 99; g.heroes.forEach((h) => { h.hp = h.maxHp; }); E.endTurn(g); }
  eq('マナの上限', g.mana, E.MANA_MAX);
}
{
  const g = setup(['sword', 'mage'], 0, 'golem', [['sw_slash', 'sw_focus'], null]);
  const next = g.decks[0].queue[0];
  play(g, 'sw_slash', 'enemy');
  ok('使ったカードは列の最後、同じ場所に次のカード', g.decks[0].hand[0].id === next && g.decks[0].queue[g.decks[0].queue.length - 1] === 'sw_slash', g.decks[0]);
  const hp = g.enemy.hp;
  play(g, 'sw_focus');
  E.act(g, { type: 'skill', k: 0, target: 'enemy' });
  eq('気合いはスキルにも乗る', hp - g.enemy.hp, 4);
  ok('スキルは1ターン1回', !!E.check(g, { type: 'skill', k: 0, target: 'enemy' }));
  ok('前衛用は後衛で使えない', (() => { E.act(g, { type: 'move', k: 0 }); return g.decks[0].hand.some((c) => E.CARD[c.id].pos === 'front' && !!E.check(g, { type: 'card', uid: c.uid, target: 'enemy' })); })());
  ok('移動は1ターン1回', !!E.check(g, { type: 'move', k: 0 }));
}
{
  const g = setup(['rogue', 'mage'], 0, 'golem');
  E.act(g, { type: 'move', k: 0 }); E.act(g, { type: 'move', k: 1 });
  ok('すり抜けは前衛だけ', !!E.check(g, { type: 'skill', k: 0, target: 'enemy' }));
  g.heroes[0].pos = 'front'; g.heroes[0].moved = true;
  E.act(g, { type: 'skill', k: 0, target: 'enemy' });
  ok('すり抜けでもう1回移動', !E.check(g, { type: 'move', k: 0 }));
}
{
  const g = setup(['saint', 'mage'], 0, 'golem');
  g.heroes[1].hp = 5;
  const hp = g.enemy.hp;
  E.act(g, { type: 'skill', k: 0, target: 1 });
  eq('祈りの手：1ダメージと2回復', [hp - g.enemy.hp, g.heroes[1].hp], [1, 7]);
}

// ── ボスの本気 ──
{
  const g = setup(['sword', 'mage'], 0, 'lord');
  g.enemy.hp = 21; g.enemy.step = 3; g.enemy.charge = 3;
  E.act(g, { type: 'skill', k: 1, target: 'enemy' });        // 魔弾2 → 19（半分=20以下）
  ok('HP半分で本気、予告は最初から、溜めは消える', g.enemy.phase === 1 && g.enemy.step === 0 && g.enemy.charge === 0, g.enemy);
  eq('本気の予告', E.intent(g).type, E.BOSS.phase2.pattern[0].type);
}

// ── 連戦 ──
{
  const run = E.newRun({ heroes: ['sword', 'mage'], front: 0 }, rng(5));
  ok('敵は普通2体とボス', run.foes.length === 3 && run.foes[2] === E.BOSS.id && run.foes[0] !== run.foes[1] && !E.ENEMY[run.foes[0]].boss && !E.ENEMY[run.foes[1]].boss);
  const g = E.runFight(run, rng(6));
  g.enemy.hp = 1; g.life = 13;
  E.act(g, { type: 'skill', k: 1, target: 'enemy' });
  ok('勝つと報酬へ、ライフ持ち越し', E.endFight(run, g) === true && run.life === 13 && run.stage === 1);
  const opts = E.rewardOptions(run, rng(7));
  eq('報酬は3種類', opts.map((o) => o.type), ['card', 'up', 'heal']);
  ok('カードと強化は別のヒーロー', opts[0].k !== opts[1].k);
  const old = run.mods[opts[0].k].cards[0];
  E.applyReward(run, opts[0], old);
  ok('入れ替えても4枚', run.mods[opts[0].k].cards.length === 4 && run.mods[opts[0].k].cards.includes(opts[0].card) && !run.mods[opts[0].k].cards.includes(old));
  E.applyReward(run, opts[1]);
  ok('スキル強化', run.mods[opts[1].k].up === true);
  E.applyReward(run, { type: 'heal' });
  eq('回復', run.life, 19);
  const g2 = E.runFight(run, rng(8));
  ok('強化と新カードが戦闘に反映', g2.heroes[opts[1].k].up && g2.decks[opts[0].k].hand.concat(g2.decks[opts[0].k].queue.map((id) => ({ id }))).some((c) => c.id === opts[0].card));
  eq('ヒーローのHPは全快', g2.heroes.map((h) => h.hp), g2.heroes.map((h) => h.maxHp));
  g2.life = 0; g2.over = true; g2.winner = 1;
  ok('負けたら冒険終了', E.endFight(run, g2) === false && run.over && !run.won);
}

// ── でたらめに打ち続けて、不変条件を確かめる ──
{
  const r = rng(42);
  let games = 0, steps = 0;
  const ids = E.HEROES.map((h) => h.id);
  const bad = (g, why) => { fail++; console.log('✗ 不変条件', why, JSON.stringify({ heroes: g.heroes, enemy: g.enemy, life: g.life, mana: g.mana })); };
  for (let t = 0; t < 400; t++) {
    const a = ids[Math.floor(r() * 5)]; let b = ids[Math.floor(r() * 5)]; if (a === b) b = ids[(ids.indexOf(a) + 1) % 5];
    const run = E.newRun({ heroes: [a, b], front: Math.floor(r() * 2) }, r);
    // 報酬を先に適当に入れておく
    for (let i = 0; i < 2; i++) { const o = E.rewardOptions(run, r)[Math.floor(r() * 2)]; E.applyReward(run, o, o.type === 'card' ? run.mods[o.k].cards[Math.floor(r() * 4)] : null); }
    while (!run.over) {
      const g = E.runFight(run, r);
      const deck0 = g.decks.map((d) => d.hand.map((c) => c.id).concat(d.queue).sort().join());
      let guard = 0;
      while (!g.over && guard++ < 80) {
        for (let n = 0; n < 8 && !g.over; n++) {
          const as = E.actions(g);
          if (!as.length || r() < 0.2) break;
          const act = as[Math.floor(r() * as.length)];
          const res = E.act(g, act);
          steps++;
          if (res.error) bad(g, '挙げた行動が失敗 ' + JSON.stringify(act));
          if (!g.steps.length) bad(g, '行動に演出の記録がない');
        }
        if (!g.over) E.endTurn(g);
        if (g.mana < 0) bad(g, 'マナが負');
        if (g.life > E.LIFE || (g.life <= 0 && !g.over)) bad(g, 'ライフ');
        if (g.enemy.hp < 0 || g.enemy.shield < 0 || g.enemy.weak < 0 || (g.enemy.hp === 0 && !g.over)) bad(g, '敵の値');
        g.heroes.forEach((h) => { if (h.hp < 0 || h.hp > h.maxHp || h.shield < 0 || (h.hp === 0) !== h.ko) bad(g, 'ヒーローの値'); });
        g.decks.forEach((d, k) => { if (d.hand.length !== E.HAND_SIZE || d.hand.map((c) => c.id).concat(d.queue).sort().join() !== deck0[k]) bad(g, '手札・山札'); });
        const it = E.intent(g);
        if (it.dmg != null && (!it.targets.length || it.dmg < 0)) bad(g, '予告の当たり先がない');
      }
      if (!g.over) bad(g, '80ラウンドで終わらない');
      games++;
      E.endFight(run, g);
    }
  }
  ok(`でたらめ ${games}戦・${steps}手`, true);
}

console.log(`${pass} 件 合格 / ${fail} 件 不合格`);
process.exit(fail ? 1 : 0);
