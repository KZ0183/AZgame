// ふたりの英雄（仮）ルールエンジン（ブラウザ・Node 共用、DOM 非依存）
// 同時計画制：お互いが同じ時間で行動を計画し、確定したら同時に処理する。
// オンライン対戦では「計画」だけを送り、処理は resolveRound が決定的に行う想定
(function (root) {
  'use strict';

  const WIN_POINTS = 2;
  const MAX_ROUND = 10;
  const HAND_MAX = 5;
  const MANA_MAX = 6;
  const PLAN_SECONDS = 30;

  // lvCost: Lv2・Lv3 に上げるのに払うマナ。spd: 素早さ（攻撃の順番。大きいほど先）
  const HEROES = [
    { id: 'sword', name: '剣士', color: 'red', hp: 12, atk: 3, spd: 4, lvCost: [2, 5], grow: '早熟。すぐ強くなるが、覚醒は重い',
      cards: ['sw_slash', 'sw_focus', 'sw_lunge', 'sw_double', 'sw_ult'] },
    { id: 'saint', name: '聖女', color: 'gold', hp: 10, atk: 1, spd: 2, lvCost: [3, 3], grow: '安定。どの段階も同じ重さ',
      cards: ['st_heal', 'st_mace', 'st_bless', 'st_prayer', 'st_ult'] },
    { id: 'knight', name: '守護騎士', color: 'grey', hp: 15, atk: 2, spd: 1, lvCost: [3, 4], grow: '堅実',
      cards: ['kn_bash', 'kn_taunt', 'kn_guard', 'kn_wall', 'kn_ult'] },
    { id: 'mage', name: '魔術師', color: 'blue', hp: 8, atk: 1, spd: 3, lvCost: [4, 6], grow: '大器晩成。育てるのは重いが、覚醒が一番強い',
      cards: ['mg_bolt', 'mg_flame', 'mg_meditate', 'mg_thunder', 'mg_ult'] },
    { id: 'rogue', name: '盗賊', color: 'green', hp: 10, atk: 3, spd: 5, lvCost: [2, 4], grow: '身軽。早めに覚醒まで届く',
      cards: ['rg_dagger', 'rg_trip', 'rg_steal', 'rg_backstab', 'rg_ult'] },
  ];
  const HERO = Object.fromEntries(HEROES.map((h) => [h.id, h]));

  // pos: front = 前衛で生まれ、（移動後に）前衛にいるときだけ使える / back = 後衛で生まれ、どこからでも使える
  // target: front = 敵の前衛（下がられたら空振り）/ any = 敵の誰でも（遠距離）/ ally = 味方 / none
  // kind: support = 守り・支援の段階 / attack = 攻撃の段階（素早さ順）/ mana = 計画中にマナが増える
  const CARDS = [
    { id: 'sw_slash', hero: 'sword', name: '斬撃', cost: 1, pos: 'front', lv: 1, target: 'front', kind: 'attack', text: '3ダメージ。' },
    { id: 'sw_focus', hero: 'sword', name: '気合い', cost: 1, pos: 'back', lv: 1, target: 'none', kind: 'support', text: 'このラウンド、このヒーローの次の攻撃のダメージ+2。' },
    { id: 'sw_lunge', hero: 'sword', name: '踏み込み', cost: 2, pos: 'front', lv: 1, target: 'front', kind: 'attack', text: '5ダメージ。自分も1ダメージを受ける。' },
    { id: 'sw_double', hero: 'sword', name: '連撃', cost: 2, pos: 'front', lv: 2, target: 'front', kind: 'attack', text: '3ダメージを2回。' },
    { id: 'sw_ult', hero: 'sword', name: '一閃', cost: 3, pos: 'front', lv: 3, target: 'front', kind: 'attack', text: '【覚醒】8ダメージ。' },

    { id: 'st_heal', hero: 'saint', name: '癒しの光', cost: 1, pos: 'back', lv: 1, target: 'ally', kind: 'support', text: '味方1人のHPを3回復。' },
    { id: 'st_mace', hero: 'saint', name: '光の槌', cost: 1, pos: 'front', lv: 1, target: 'front', kind: 'attack', text: '2ダメージ。味方全員のHPを1回復。' },
    { id: 'st_bless', hero: 'saint', name: '加護', cost: 1, pos: 'back', lv: 1, target: 'ally', kind: 'support', text: '味方1人に盾3（このラウンドの間）。' },
    { id: 'st_prayer', hero: 'saint', name: '祈り', cost: 0, pos: 'back', lv: 2, target: 'none', kind: 'mana', text: 'このラウンド、マナ+2（計画中すぐに使える）。' },
    { id: 'st_ult', hero: 'saint', name: '奇跡', cost: 3, pos: 'back', lv: 3, target: 'none', kind: 'support', text: '【覚醒】味方全員のHPを全回復。' },

    { id: 'kn_bash', hero: 'knight', name: '盾打ち', cost: 1, pos: 'front', lv: 1, target: 'front', kind: 'attack', text: '2ダメージ。自分に盾2。' },
    { id: 'kn_taunt', hero: 'knight', name: '挑発', cost: 1, pos: 'front', lv: 1, target: 'none', kind: 'support', text: 'このラウンド、相手の攻撃はすべてこのヒーローに向く。' },
    { id: 'kn_guard', hero: 'knight', name: '守りの構え', cost: 1, pos: 'back', lv: 1, target: 'ally', kind: 'support', text: '味方1人に盾4（このラウンドの間）。' },
    { id: 'kn_wall', hero: 'knight', name: '鉄壁', cost: 2, pos: 'front', lv: 2, target: 'none', kind: 'support', text: '味方全員に盾3（このラウンドの間）。' },
    { id: 'kn_ult', hero: 'knight', name: '不屈', cost: 2, pos: 'front', lv: 3, target: 'none', kind: 'support', text: '【覚醒】このラウンド、味方は倒れない（HP1で耐える）。' },

    { id: 'mg_bolt', hero: 'mage', name: '魔力の矢', cost: 1, pos: 'back', lv: 1, target: 'any', kind: 'attack', text: '遠距離。2ダメージ。' },
    { id: 'mg_flame', hero: 'mage', name: '火炎', cost: 2, pos: 'front', lv: 1, target: 'none', kind: 'attack', text: 'その時点で前衛にいる敵全員に3ダメージ。' },
    { id: 'mg_meditate', hero: 'mage', name: '瞑想', cost: 0, pos: 'back', lv: 1, target: 'none', kind: 'mana', text: 'このラウンド、マナ+1（計画中すぐに使える）。' },
    { id: 'mg_thunder', hero: 'mage', name: '雷', cost: 3, pos: 'back', lv: 2, target: 'any', kind: 'attack', text: '遠距離。5ダメージ。' },
    { id: 'mg_ult', hero: 'mage', name: '隕石', cost: 4, pos: 'back', lv: 3, target: 'none', kind: 'attack', text: '【覚醒】敵全員に5ダメージ。' },

    { id: 'rg_dagger', hero: 'rogue', name: '投げナイフ', cost: 1, pos: 'front', lv: 1, target: 'any', kind: 'attack', text: '遠距離。2ダメージ。' },
    { id: 'rg_trip', hero: 'rogue', name: '足払い', cost: 1, pos: 'front', lv: 1, target: 'front', kind: 'attack', text: '1ダメージ。相手を後衛に下げる（そのあとの前衛向けの攻撃は空振りする）。' },
    { id: 'rg_steal', hero: 'rogue', name: '盗み', cost: 1, pos: 'back', lv: 1, target: 'none', kind: 'support', text: '相手の手札を1枚ランダムに捨てさせる。' },
    { id: 'rg_backstab', hero: 'rogue', name: '急所突き', cost: 2, pos: 'front', lv: 2, target: 'any', kind: 'attack', text: '遠距離。3ダメージ。相手のHPが半分以下なら6ダメージ。' },
    { id: 'rg_ult', hero: 'rogue', name: '影分身', cost: 3, pos: 'front', lv: 3, target: 'none', kind: 'attack', text: '【覚醒】ランダムな敵に3ダメージを3回。' },
  ];
  const CARD = Object.fromEntries(CARDS.map((c) => [c.id, c]));
  const POS_NAME = { front: '前衛', back: '後衛' };
  const MANA_GAIN = { st_prayer: 2, mg_meditate: 1 };

  // ── 編成 ──
  // team = { heroes: [id, id], front: 0|1 }（最初に前衛に立つヒーロー）
  function validateTeam(team) {
    const errs = [];
    if (!team || !Array.isArray(team.heroes) || team.heroes.length !== 2) errs.push('ヒーローを2人選んでください');
    else if (team.heroes[0] === team.heroes[1]) errs.push('同じヒーローは選べません');
    else if (team.heroes.some((h) => !HERO[h])) errs.push('不明なヒーロー');
    return errs;
  }

  function makeHero(id, pos) {
    const h = HERO[id];
    return { id, hp: h.hp, maxHp: h.hp, atk: h.atk, spd: h.spd, pos, lv: 1, shield: 0, ko: false, revealed: pos === 'front',
      focus: 0, taunt: false, undying: false };
  }

  function levelCost(h) { return h.lv >= 3 ? null : HERO[h.id].lvCost[h.lv - 1]; }

  // ── 状態 ──
  function newGame(teams, names, rng) {
    rng = rng || Math.random;
    let uid = 1;
    const state = {
      round: 0, mana: 0, over: false, winner: null, endReason: '', log: [], steps: [],
      players: teams.map((t, i) => ({
        name: names[i], points: 0, hand: [],
        heroes: t.heroes.map((id, k) => makeHero(id, (t.front ?? 0) === k ? 'front' : 'back')),
      })),
      nextUid() { return uid++; },
      rng,
    };
    begin(state);
    startRound(state);
    return state;
  }

  // ── 演出用の記録 ──
  // step = { title, lines, hits, ups, actor, view }。actor は「動いたヒーロー」（アニメーション用）
  function begin(state) { state.log = []; state.steps = []; state._hits = []; state._ups = []; state._logAt = 0; }
  function mark(state, hit) { state._hits.push(hit); }

  function view(state) {
    return {
      round: state.round, mana: state.mana,
      players: state.players.map((pl) => ({ points: pl.points, handCount: pl.hand.length, heroes: pl.heroes.map((h) => ({ ...h })) })),
    };
  }

  function step(state, title, force, actor) {
    const lines = state.log.slice(state._logAt);
    if (!lines.length && !state._hits.length && !force) return;
    state._logAt = state.log.length;
    state.steps.push({ title, lines, hits: state._hits, ups: state._ups, actor: actor || null, view: view(state) });
    state._hits = [];
    state._ups = [];
  }

  function heroName(state, p, k) { return `${state.players[p].name}の${HERO[state.players[p].heroes[k].id].name}`; }

  function addCard(state, p, id, announce, force) {
    const pl = state.players[p];
    if (pl.hand.length >= HAND_MAX && !force) return null;
    const uid = state.nextUid();
    pl.hand.push({ uid, id });
    if (announce) state.log.push(`${pl.name}は${CARD[id].name}を得た（次のラウンドから使える）`);
    return uid;
  }

  function generate(state, p, k) {
    const h = state.players[p].heroes[k];
    if (h.ko) return;
    const pool = HERO[h.id].cards.filter((id) => CARD[id].pos === h.pos && CARD[id].lv <= h.lv);
    if (pool.length) addCard(state, p, pool[Math.floor(state.rng() * pool.length)], false);
  }

  // ── ラウンド開始 ──
  function startRound(state) {
    state.round++;
    state.mana = Math.min(state.round + 2, MANA_MAX);
    state.log.push(`ラウンド${state.round}（マナ${state.mana}）`);
    state.players.forEach((pl, p) => {
      pl.heroes.forEach((h, k) => {
        if (h.ko) {
          Object.assign(h, makeHero(h.id, 'back'), { revealed: h.revealed });
          mark(state, { p, k, label: '復活' });
          state.log.push(`${heroName(state, p, k)}が後衛で復活した（Lv1）`);
        }
        h.shield = 0; h.taunt = false; h.undying = false; h.focus = 0;
      });
      for (let k = 0; k < 2; k++) generate(state, p, k);
    });
    step(state, `ラウンド${state.round}`, true);
  }

  // ── 計画 ──
  // plan = [action...]
  // action = { type: 'move', k } | { type: 'level', k } | { type: 'card', uid, target } | { type: 'attack', k, target }
  // 計画を自分側だけで先読みし、問題があれば最初の理由を返す。preview は UI 用の見込み
  function previewPlan(state, p, plan) {
    const pl = state.players[p];
    const heroes = pl.heroes.map((h) => ({ pos: h.pos, lv: h.lv, ko: h.ko, moved: false, attacked: false }));
    let mana = state.mana;
    const used = new Set();
    for (let i = 0; i < plan.length; i++) {
      const a = plan[i];
      const fail = (why) => ({ error: why, index: i, mana, heroes });
      if (a.type === 'move') {
        const h = heroes[a.k];
        if (!h || h.ko) return fail('倒れている');
        if (h.moved) return fail('移動は1ラウンド1回');
        if (mana < 1) return fail('マナが足りない');
        mana -= 1; h.moved = true; h.pos = h.pos === 'front' ? 'back' : 'front';
      } else if (a.type === 'level') {
        const h = heroes[a.k];
        if (!h || h.ko) return fail('倒れている');
        if (h.lv >= 3) return fail('もう覚醒している');
        const c = HERO[pl.heroes[a.k].id].lvCost[h.lv - 1];
        if (mana < c) return fail('マナが足りない');
        mana -= c; h.lv++;
      } else if (a.type === 'attack') {
        const h = heroes[a.k];
        if (!h || h.ko) return fail('倒れている');
        if (h.pos !== 'front') return fail('前衛にいない');
        if (h.attacked) return fail('通常攻撃は1ラウンド1回');
        if (mana < 1) return fail('マナが足りない');
        if (!(a.target === 0 || a.target === 1)) return fail('対象が不正');
        mana -= 1; h.attacked = true;
      } else if (a.type === 'card') {
        const c = pl.hand.find((x) => x.uid === a.uid);
        if (!c || used.has(a.uid)) return fail('手札にない');
        const def = CARD[c.id];
        const k = pl.heroes.findIndex((x) => x.id === def.hero);
        const h = heroes[k];
        if (h.ko) return fail('倒れている');
        if (def.pos === 'front' && h.pos !== 'front') return fail(`${HERO[def.hero].name}が前衛にいない`);
        if (def.cost > mana) return fail('マナが足りない');
        if (def.target === 'none' ? a.target != null : !(a.target === 0 || a.target === 1)) return fail('対象が不正');
        used.add(a.uid);
        mana -= def.cost;
        mana += MANA_GAIN[def.id] || 0;
      } else return fail('不明な行動');
    }
    return { error: null, mana, heroes };
  }

  function checkPlan(state, p, plan) { return previewPlan(state, p, plan).error; }

  // 計画の末尾に足せる行動を全部挙げる
  function candidates(state, p, plan) {
    const pl = state.players[p];
    const out = [];
    const inPlan = new Set(plan.filter((a) => a.type === 'card').map((a) => a.uid));
    const tryAdd = (a) => { if (!checkPlan(state, p, plan.concat([a]))) out.push(a); };
    for (let k = 0; k < 2; k++) {
      tryAdd({ type: 'move', k });
      tryAdd({ type: 'level', k });
      for (const t of [0, 1]) tryAdd({ type: 'attack', k, target: t });
    }
    for (const c of pl.hand) {
      if (inPlan.has(c.uid)) continue;
      const def = CARD[c.id];
      for (const t of def.target === 'none' ? [null] : [0, 1]) tryAdd({ type: 'card', uid: c.uid, target: t });
    }
    return out;
  }

  // ── 処理 ──
  function damage(state, sp, p, k, n, src) {
    const h = state.players[p].heroes[k];
    if (h.ko || n <= 0) return 0;
    h.revealed = true;
    let rest = n;
    const absorbed = Math.min(h.shield, rest);
    h.shield -= absorbed;
    rest -= absorbed;
    h.hp -= rest;
    if (h.undying && h.hp < 1) h.hp = 1;
    mark(state, { p, k, n: -rest, label: absorbed ? `盾−${absorbed}` : null, hit: true });
    state.log.push(`${src} → ${heroName(state, p, k)}に${n}ダメージ${absorbed ? `（盾で${absorbed}防いだ）` : ''}`);
    return n;
  }

  function heal(state, p, k, n, src) {
    const h = state.players[p].heroes[k];
    if (h.ko) return;
    const d = Math.min(n, h.maxHp - h.hp);
    h.hp += d;
    mark(state, { p, k, n: d, heal: true });
    state.log.push(`${src} → ${heroName(state, p, k)}のHPを${d}回復`);
  }

  function shield(state, p, k, n, src) {
    const h = state.players[p].heroes[k];
    if (h.ko) return;
    h.shield += n;
    mark(state, { p, k, label: `盾+${n}` });
    state.log.push(`${src} → ${heroName(state, p, k)}に盾${n}`);
  }

  // HP が 0 以下のヒーローを倒れたことにする（同じ素早さのまとまりが終わるごとに呼ぶ）
  function reap(state) {
    state.players.forEach((pl, p) => pl.heroes.forEach((h, k) => {
      if (h.ko || h.hp > 0) return;
      h.ko = true; h.hp = 0; h.shield = 0; h.taunt = false;
      const lost = pl.hand.filter((c) => CARD[c.id].hero === h.id).length;
      pl.hand = pl.hand.filter((c) => CARD[c.id].hero !== h.id);
      const o = 1 - p;
      state.players[o].points++;
      mark(state, { p, k, label: '撃破' });
      state.log.push(`${heroName(state, p, k)}は倒れた（${state.players[o].name}に1点）${lost ? `。手札の${HERO[h.id].name}のカード${lost}枚が消えた` : ''}`);
    }));
    if (state.players.some((pl) => pl.points >= WIN_POINTS)) finish(state, `${WIN_POINTS}点先取`);
  }

  // 攻撃が実際に当たる相手を決める。null なら空振り
  // kind: front | any。挑発が最優先。front は相手が後衛にいたら空振り（敵の前衛が全員いなければ −1 で当たる）
  function resolveTarget(state, p, kind, k) {
    const o = 1 - p;
    const hs = state.players[o].heroes;
    const taunt = [0, 1].find((x) => !hs[x].ko && hs[x].taunt);
    if (taunt != null) return { k: taunt, mod: 0, why: '挑発に引きつけられた' };
    const h = hs[k];
    if (h.ko || h.hp <= 0) return null;
    if (kind === 'any' || h.pos === 'front') return { k, mod: 0 };
    const anyFront = [0, 1].some((x) => !hs[x].ko && hs[x].hp > 0 && hs[x].pos === 'front');
    return anyFront ? null : { k, mod: -1 };
  }

  function canAct(state, p, k) { const h = state.players[p].heroes[k]; return !h.ko && h.hp > 0; }

  // 1 つの行動を処理する（守り・支援／攻撃の段階）
  function perform(state, p, a) {
    const pl = state.players[p], o = 1 - p;
    if (a.type === 'attack') {
      const h = pl.heroes[a.k];
      const nm = HERO[h.id].name;
      state.log.push(`${heroName(state, p, a.k)}の通常攻撃`);
      if (h.pos !== 'front') { state.log.push(`${nm}は前衛にいないので攻撃できなかった`); return; }
      const t = resolveTarget(state, p, 'front', a.target);
      if (!t) { mark(state, { p: o, k: a.target, label: '空振り' }); state.log.push('空振り！（狙った相手がいない）'); return; }
      if (t.why) state.log.push(t.why);
      const n = h.atk + h.focus + t.mod;
      h.focus = 0;
      damage(state, p, o, t.k, Math.max(0, n), nm);
      return;
    }
    // カード
    const def = CARD[a.id];
    const k = pl.heroes.findIndex((x) => x.id === def.hero);
    const h = pl.heroes[k];
    h.revealed = true;
    state.log.push(`${heroName(state, p, k)}の「${def.name}」`);
    if (def.pos === 'front' && h.pos !== 'front') { state.log.push('前衛にいないので使えなかった'); return; }
    const hit = (n, kind = 'attack') => {
      if (!canAct(state, p, k)) return;
      const t = resolveTarget(state, p, def.target, a.target);
      if (!t) { mark(state, { p: o, k: a.target, label: '空振り' }); state.log.push('空振り！'); return null; }
      if (t.why) state.log.push(t.why);
      const bonus = kind === 'attack' ? h.focus : 0;
      if (kind === 'attack') h.focus = 0;
      damage(state, p, o, t.k, Math.max(0, n + bonus + t.mod), def.name);
      return t.k;
    };
    const enemies = () => [0, 1].filter((x) => !state.players[o].heroes[x].ko && state.players[o].heroes[x].hp > 0);
    switch (def.id) {
      case 'sw_slash': hit(3); break;
      case 'sw_focus': h.focus += 2; mark(state, { p, k, label: '次の攻撃+2' }); state.log.push('次の攻撃のダメージ+2'); break;
      case 'sw_lunge': if (hit(5) != null) damage(state, null, p, k, 1, '反動'); break;
      case 'sw_double': hit(3); hit(3); break;
      case 'sw_ult': hit(8); break;
      case 'st_heal': heal(state, p, a.target, 3, def.name); break;
      case 'st_mace': if (hit(2) != null) for (let x = 0; x < 2; x++) heal(state, p, x, 1, def.name); break;
      case 'st_bless': shield(state, p, a.target, 3, def.name); break;
      case 'st_ult': for (let x = 0; x < 2; x++) heal(state, p, x, pl.heroes[x].maxHp, def.name); break;
      case 'kn_bash': if (hit(2) != null) shield(state, p, k, 2, def.name); break;
      case 'kn_taunt': h.taunt = true; mark(state, { p, k, label: '挑発' }); state.log.push('このラウンド、相手の攻撃はすべてこのヒーローに向く'); break;
      case 'kn_guard': shield(state, p, a.target, 4, def.name); break;
      case 'kn_wall': for (let x = 0; x < 2; x++) shield(state, p, x, 3, def.name); break;
      case 'kn_ult': pl.heroes.forEach((hh, x) => { if (!hh.ko) { hh.undying = true; mark(state, { p, k: x, label: '不屈' }); } }); state.log.push('このラウンド、味方は倒れない'); break;
      case 'mg_bolt': hit(2, 'spell'); break;
      case 'mg_flame': {
        const fr = enemies().filter((x) => state.players[o].heroes[x].pos === 'front');
        if (!fr.length) state.log.push('前衛に敵がいなかった');
        for (const x of fr) damage(state, p, o, x, 3, def.name);
        break;
      }
      case 'mg_thunder': hit(5, 'spell'); break;
      case 'mg_ult': for (const x of enemies()) damage(state, p, o, x, 5, def.name); break;
      case 'rg_dagger': hit(2); break;
      case 'rg_trip': {
        const tk = hit(1);
        const t = tk != null && state.players[o].heroes[tk];
        if (t && !t.ko && t.pos === 'front') { t.pos = 'back'; mark(state, { p: o, k: tk, label: '後衛へ' }); state.log.push(`${heroName(state, o, tk)}は後衛に下げられた`); }
        break;
      }
      case 'rg_steal': {
        const oh = state.players[o].hand;
        if (oh.length) {
          const lost = oh.splice(Math.floor(state.rng() * oh.length), 1)[0];
          mark(state, { p: o, k: null, label: '手札−1' });
          state.log.push(`${state.players[o].name}は「${CARD[lost.id].name}」を失った`);
        } else state.log.push('相手の手札がなかった');
        break;
      }
      case 'rg_backstab': {
        const t = resolveTarget(state, p, 'any', a.target);
        const big = t && state.players[o].heroes[t.k].hp * 2 <= state.players[o].heroes[t.k].maxHp;
        hit(big ? 6 : 3);
        break;
      }
      case 'rg_ult':
        for (let i = 0; i < 3; i++) {
          const es = enemies();
          if (!es.length) break;
          damage(state, p, o, es[Math.floor(state.rng() * es.length)], 3, def.name);
        }
        break;
    }
  }

  // 両者の計画を同時に処理する。最後に次のラウンドの開始まで進める
  function resolveRound(state, plans) {
    begin(state);
    if (state.over) return state.steps;
    const P = state.players;
    // 不正な計画は、問題のある行動の手前までだけ実行する
    const ok = plans.map((plan, p) => {
      const pv = previewPlan(state, p, plan || []);
      return pv.error ? (plan || []).slice(0, pv.index) : plan || [];
    });
    // 同じ段階・同じ素早さで先に処理する側は、ラウンドごとに交代する（奇数ラウンドはプレイヤー0が先）
    const order = state.round % 2 === 1 ? [0, 1] : [1, 0];
    const both = (arr) => order.flatMap((p) => arr[p]);
    // 使うカードを手札から取り除き、行動の形をそろえる
    const acts = ok.map((plan, p) => plan.map((a) => {
      if (a.type !== 'card') return { ...a, p };
      const c = P[p].hand.find((x) => x.uid === a.uid);
      P[p].hand = P[p].hand.filter((x) => x.uid !== a.uid);
      return { ...a, p, id: c.id, k: P[p].heroes.findIndex((h) => h.id === CARD[c.id].hero) };
    }));
    const describe = (a) => a.type === 'move' ? `${HERO[P[a.p].heroes[a.k].id].name}の移動` : a.type === 'level' ? `${HERO[P[a.p].heroes[a.k].id].name}のレベルアップ`
      : a.type === 'attack' ? `${HERO[P[a.p].heroes[a.k].id].name}の通常攻撃` : `${HERO[CARD[a.id].hero].name}の「${CARD[a.id].name}」`;
    state.log.push(...[0, 1].map((p) => `${P[p].name}の計画：${acts[p].length ? acts[p].map(describe).join('、') : 'なし'}`));
    step(state, '計画を公開', true);

    // 1. 移動
    for (const a of both(acts).filter((x) => x.type === 'move')) {
      const h = P[a.p].heroes[a.k];
      h.pos = h.pos === 'front' ? 'back' : 'front';
      if (h.pos === 'front') h.revealed = true;
      mark(state, { p: a.p, k: a.k, label: POS_NAME[h.pos] + 'へ' });
      state.log.push(`${heroName(state, a.p, a.k)}が${POS_NAME[h.pos]}へ移った`);
    }
    step(state, '移動');

    // 2. レベルアップ
    for (const a of both(acts).filter((x) => x.type === 'level')) {
      const h = P[a.p].heroes[a.k];
      h.lv++;
      h.revealed = true;
      mark(state, { p: a.p, k: a.k, label: `Lv${h.lv}！` });
      state.log.push(`${heroName(state, a.p, a.k)}がLv${h.lv}に上がった`);
      const card = HERO[h.id].cards.find((id) => CARD[id].lv === h.lv);
      const uid = card ? addCard(state, a.p, card, true, true) : null;
      state._ups.push({ p: a.p, k: a.k, hero: h.id, lv: h.lv, card, uid });
      step(state, `レベルアップ：${HERO[h.id].name}`, true, { p: a.p, k: a.k });
    }

    // 3. マナ・守り・支援（計画の順。先に処理する側から）
    for (const a of both(acts).filter((x) => x.type === 'card' && CARD[x.id].kind !== 'attack')) {
      if (CARD[a.id].kind === 'mana') { P[a.p].heroes[a.k].revealed = true; state.log.push(`${heroName(state, a.p, a.k)}の「${CARD[a.id].name}」（マナは計画中に使った）`); step(state, `${HERO[CARD[a.id].hero].name}：${CARD[a.id].name}`, true, { p: a.p, k: a.k }); continue; }
      perform(state, a.p, a);
      step(state, `${HERO[CARD[a.id].hero].name}：${CARD[a.id].name}`, true, { p: a.p, k: a.k });
    }

    // 4. 攻撃（素早い順。同じ素早さのヒーローはまとめて処理し、倒れる判定はまとまりの最後に行う）
    const attacks = both(acts).filter((x) => x.type === 'attack' || (x.type === 'card' && CARD[x.id].kind === 'attack'));
    const speeds = [...new Set(attacks.map((a) => P[a.p].heroes[a.k].spd))].sort((x, y) => y - x);
    for (const spd of speeds) {
      if (state.over) break;
      for (const a of attacks.filter((x) => P[x.p].heroes[x.k].spd === spd)) {
        if (state.over) break;
        const nm = HERO[P[a.p].heroes[a.k].id].name;
        const title = a.type === 'attack' ? `攻撃：${nm}` : `${nm}：${CARD[a.id].name}`;
        if (!canAct(state, a.p, a.k)) {
          state.log.push(`${heroName(state, a.p, a.k)}は先に倒されていて、${a.type === 'attack' ? '攻撃' : `「${CARD[a.id].name}」`}できなかった`);
          step(state, title, true);
          continue;
        }
        perform(state, a.p, a);
        step(state, title, true, { p: a.p, k: a.k });
      }
      reap(state);
      step(state, '撃破');
    }

    if (!state.over && state.round >= MAX_ROUND) { finish(state, `${MAX_ROUND}ラウンド終了`); step(state, '終了', true); }
    if (!state.over) startRound(state);
    return state.steps;
  }

  function finish(state, reason) {
    if (state.over) return;
    const P = state.players;
    state.over = true;
    const hp = (pl) => pl.heroes.reduce((s, h) => s + (h.ko ? 0 : Math.max(0, h.hp)), 0);
    if (P[0].points !== P[1].points) {
      state.winner = P[0].points > P[1].points ? 0 : 1;
      state.endReason = `${reason}：${P[0].points}点 対 ${P[1].points}点`;
    } else if (hp(P[0]) !== hp(P[1])) {
      state.winner = hp(P[0]) > hp(P[1]) ? 0 : 1;
      state.endReason = `${reason}：同点。残りHP ${hp(P[0])} 対 ${hp(P[1])}`;
    } else {
      state.winner = 'draw';
      state.endReason = `${reason}：点数も残りHPも同じ`;
    }
  }

  // ── CPU ──
  function clone(state) {
    const s = JSON.parse(JSON.stringify({ ...state, nextUid: undefined, rng: undefined, steps: undefined, log: undefined, _hits: undefined, _ups: undefined }));
    let uid = 100000;
    s.nextUid = () => uid++;
    s.rng = () => 0.5;
    begin(s);
    return s;
  }

  function value(s, p) {
    const o = 1 - p;
    if (s.over) return s.winner === p ? 10000 : s.winner === o ? -10000 : 0;
    const side = (q) => {
      const pl = s.players[q], opp = s.players[1 - q];
      const threat = opp.heroes.reduce((t, h) => t + (h.ko || h.pos !== 'front' ? 0 : h.atk + 3), 0) + 2;
      let v = pl.points * 40 + Math.min(pl.hand.length, HAND_MAX - 2) * 0.4 - Math.max(0, pl.hand.length - (HAND_MAX - 2)) * 1.5;
      pl.heroes.forEach((h) => {
        if (h.ko) { v -= 8; return; }
        v += h.hp + h.lv * 6;
        const exposed = h.pos === 'front' || pl.heroes.every((x) => x.ko || x.pos === 'back');
        if (exposed && h.hp <= threat) v -= 6 + h.lv * 3;
      });
      return v;
    };
    return side(p) - side(o);
  }

  // 相手の計画の見積もり：公開されている情報だけで、前衛が通常攻撃してくると考える
  function guessPlan(state, q) {
    const plan = [];
    state.players[q].heroes.forEach((h, k) => {
      if (h.ko || h.pos !== 'front') return;
      const ts = [0, 1].filter((t) => !state.players[1 - q].heroes[t].ko);
      const front = ts.filter((t) => state.players[1 - q].heroes[t].pos === 'front');
      plan.push({ type: 'attack', k, target: (front.length ? front : ts)[0] ?? 0 });
    });
    return plan;
  }

  // 良くなる限り行動を計画に足す
  function cpuPlan(state, p, rng) {
    rng = rng || Math.random;
    const o = 1 - p;
    const opp = guessPlan(state, o);
    const evalPlan = (plan) => {
      const s = clone(state);
      resolveRound(s, p === 0 ? [plan, opp] : [opp, plan]);
      return value(s, p);
    };
    let plan = [];
    let cur = evalPlan(plan);
    for (let guard = 0; guard < 10; guard++) {
      let best = null, bestV = cur + 0.25;
      for (const a of candidates(state, p, plan)) {
        const v = evalPlan(plan.concat([a])) + rng() * 0.3;
        if (v > bestV) { bestV = v; best = a; }
      }
      if (!best) break;
      plan = plan.concat([best]);
      cur = bestV;
    }
    return plan;
  }

  const CPU_TEAMS = [
    { label: '剣士と聖女', heroes: ['sword', 'saint'], front: 0 },
    { label: '守護騎士と魔術師', heroes: ['knight', 'mage'], front: 0 },
    { label: '盗賊と剣士', heroes: ['rogue', 'sword'], front: 0 },
    { label: '魔術師と聖女', heroes: ['mage', 'saint'], front: 1 },
    { label: '守護騎士と盗賊', heroes: ['knight', 'rogue'], front: 0 },
  ];

  const api = {
    WIN_POINTS, MAX_ROUND, HAND_MAX, MANA_MAX, PLAN_SECONDS, HEROES, HERO, CARDS, CARD, POS_NAME, CPU_TEAMS, MANA_GAIN,
    validateTeam, newGame, view, levelCost, previewPlan, checkPlan, candidates, resolveRound, cpuPlan, value,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.Engine = api;
})(typeof self !== 'undefined' ? self : this);
