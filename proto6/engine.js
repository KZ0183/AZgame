// ふたりの英雄（仮）ルールエンジン（ブラウザ・Node 共用、DOM 非依存）
// 2 人のヒーローを前衛・後衛に置いて戦う。カードはヒーローが位置に応じて生み出す
(function (root) {
  'use strict';

  const WIN_POINTS = 3;
  const MAX_ROUND = 12;
  const HAND_MAX = 5;
  const MANA_MAX = 6;

  // lvExp: Lv2・Lv3 になるのに必要な累計経験値
  const HEROES = [
    { id: 'sword', name: '剣士', color: 'red', hp: 12, atk: 3, lvExp: [4, 9], grow: '与えたダメージ1につき経験値1',
      cards: ['sw_slash', 'sw_focus', 'sw_lunge', 'sw_double', 'sw_ult'] },
    { id: 'saint', name: '聖女', color: 'gold', hp: 10, atk: 1, lvExp: [3, 7], grow: '回復した量・張った盾1につき経験値1',
      cards: ['st_heal', 'st_mace', 'st_bless', 'st_prayer', 'st_ult'] },
    { id: 'knight', name: '守護騎士', color: 'grey', hp: 15, atk: 2, lvExp: [4, 9], grow: '受けたダメージ（盾で防いだ分も）1につき経験値1',
      cards: ['kn_bash', 'kn_taunt', 'kn_guard', 'kn_wall', 'kn_ult'] },
    { id: 'mage', name: '魔術師', color: 'blue', hp: 8, atk: 1, lvExp: [3, 7], grow: '後衛でターンを始めるたび経験値2。魔法でダメージを与えるたび経験値1',
      cards: ['mg_bolt', 'mg_flame', 'mg_meditate', 'mg_thunder', 'mg_ult'] },
    { id: 'rogue', name: '盗賊', color: 'green', hp: 10, atk: 3, lvExp: [3, 7], grow: '後衛の敵にダメージを与える・手札を奪うたび経験値2',
      cards: ['rg_dagger', 'rg_trip', 'rg_steal', 'rg_backstab', 'rg_ult'] },
  ];
  const HERO = Object.fromEntries(HEROES.map((h) => [h.id, h]));

  // pos: front = 前衛で生まれ、前衛にいるときだけ使える / back = 後衛で生まれ、どこからでも使える
  // target: front = 敵の前衛（いなければ後衛に−1で届く）/ any = 敵の誰でも（遠距離）/ ally = 味方 / none
  const CARDS = [
    { id: 'sw_slash', hero: 'sword', name: '斬撃', cost: 1, pos: 'front', lv: 1, target: 'front', text: '3ダメージ。' },
    { id: 'sw_focus', hero: 'sword', name: '気合い', cost: 1, pos: 'back', lv: 1, target: 'none', text: 'このヒーローの次の攻撃のダメージ+2。' },
    { id: 'sw_lunge', hero: 'sword', name: '踏み込み', cost: 2, pos: 'front', lv: 1, target: 'front', text: '5ダメージ。自分も1ダメージを受ける。' },
    { id: 'sw_double', hero: 'sword', name: '連撃', cost: 2, pos: 'front', lv: 2, target: 'front', text: '3ダメージを2回。' },
    { id: 'sw_ult', hero: 'sword', name: '一閃', cost: 3, pos: 'front', lv: 3, target: 'front', text: '【覚醒】8ダメージ。' },

    { id: 'st_heal', hero: 'saint', name: '癒しの光', cost: 1, pos: 'back', lv: 1, target: 'ally', text: '味方1人のHPを3回復。' },
    { id: 'st_mace', hero: 'saint', name: '光の槌', cost: 1, pos: 'front', lv: 1, target: 'front', text: '2ダメージ。味方全員のHPを1回復。' },
    { id: 'st_bless', hero: 'saint', name: '加護', cost: 1, pos: 'back', lv: 1, target: 'ally', text: '味方1人に盾3（次の自分のターンまで）。' },
    { id: 'st_prayer', hero: 'saint', name: '祈り', cost: 0, pos: 'back', lv: 2, target: 'none', text: 'このターン、マナ+2。' },
    { id: 'st_ult', hero: 'saint', name: '奇跡', cost: 3, pos: 'back', lv: 3, target: 'none', text: '【覚醒】味方全員のHPを全回復。倒れている味方はすぐ復活する。' },

    { id: 'kn_bash', hero: 'knight', name: '盾打ち', cost: 1, pos: 'front', lv: 1, target: 'front', text: '2ダメージ。自分に盾2。' },
    { id: 'kn_taunt', hero: 'knight', name: '挑発', cost: 1, pos: 'front', lv: 1, target: 'none', text: '次の相手のターン、相手はこのヒーローしか狙えない。' },
    { id: 'kn_guard', hero: 'knight', name: '守りの構え', cost: 1, pos: 'back', lv: 1, target: 'ally', text: '味方1人に盾4（次の自分のターンまで）。' },
    { id: 'kn_wall', hero: 'knight', name: '鉄壁', cost: 2, pos: 'front', lv: 2, target: 'none', text: '味方全員に盾3。' },
    { id: 'kn_ult', hero: 'knight', name: '不屈', cost: 2, pos: 'front', lv: 3, target: 'none', text: '【覚醒】次の相手のターン、味方は倒れない（HP1で耐える）。' },

    { id: 'mg_bolt', hero: 'mage', name: '魔力の矢', cost: 1, pos: 'back', lv: 1, target: 'any', text: '遠距離。2ダメージ。' },
    { id: 'mg_flame', hero: 'mage', name: '火炎', cost: 2, pos: 'front', lv: 1, target: 'none', text: '敵の前衛全員に3ダメージ。' },
    { id: 'mg_meditate', hero: 'mage', name: '瞑想', cost: 0, pos: 'back', lv: 1, target: 'none', text: 'このターン、マナ+1。' },
    { id: 'mg_thunder', hero: 'mage', name: '雷', cost: 3, pos: 'back', lv: 2, target: 'any', text: '遠距離。5ダメージ。' },
    { id: 'mg_ult', hero: 'mage', name: '隕石', cost: 4, pos: 'back', lv: 3, target: 'none', text: '【覚醒】敵全員に5ダメージ。' },

    { id: 'rg_dagger', hero: 'rogue', name: '投げナイフ', cost: 1, pos: 'front', lv: 1, target: 'any', text: '遠距離。2ダメージ。' },
    { id: 'rg_trip', hero: 'rogue', name: '足払い', cost: 1, pos: 'front', lv: 1, target: 'front', text: '1ダメージ。相手を後衛に下げる。' },
    { id: 'rg_steal', hero: 'rogue', name: '盗み', cost: 1, pos: 'back', lv: 1, target: 'none', text: '相手の手札を1枚ランダムに捨てさせる。' },
    { id: 'rg_backstab', hero: 'rogue', name: '急所突き', cost: 2, pos: 'front', lv: 2, target: 'any', text: '遠距離。3ダメージ。相手のHPが半分以下なら6ダメージ。' },
    { id: 'rg_ult', hero: 'rogue', name: '影分身', cost: 3, pos: 'front', lv: 3, target: 'none', text: '【覚醒】ランダムな敵に3ダメージを3回。' },
  ];
  const CARD = Object.fromEntries(CARDS.map((c) => [c.id, c]));
  const POS_NAME = { front: '前衛', back: '後衛' };

  function shuffleOne(arr, rng) { return arr[Math.floor(rng() * arr.length)]; }

  // ── 状態 ──
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
    return { id, hp: h.hp, maxHp: h.hp, atk: h.atk, pos, lv: 1, exp: 0, shield: 0, ko: false, revealed: pos === 'front',
      attacked: false, moved: false, focus: 0, taunt: false, undying: false };
  }

  function newGame(teams, names, rng, first) {
    rng = rng || Math.random;
    let uid = 1;
    const state = {
      round: 1, first: first ?? (rng() < 0.5 ? 0 : 1), active: 0, mana: 0, over: false, winner: null, endReason: '',
      log: [], steps: [],
      players: teams.map((t, i) => ({
        name: names[i], points: 0, hand: [],
        heroes: t.heroes.map((id, k) => makeHero(id, (t.front ?? 0) === k ? 'front' : 'back')),
      })),
      nextUid() { return uid++; },
      rng,
    };
    state.active = state.first;
    begin(state);
    // 最初の手札：各ヒーローが1枚ずつ生む
    for (let p = 0; p < 2; p++) for (let k = 0; k < 2; k++) generate(state, p, k);
    startTurn(state);
    return state;
  }

  // ── 演出用の記録 ──
  function begin(state) { state.log = []; state.steps = []; state._hits = []; state._logAt = 0; }
  function mark(state, hit) { state._hits.push(hit); }

  function view(state) {
    return {
      round: state.round, active: state.active, mana: state.mana,
      players: state.players.map((pl) => ({
        points: pl.points, handCount: pl.hand.length,
        heroes: pl.heroes.map((h) => ({ ...h })),
      })),
    };
  }

  function step(state, title, force) {
    const lines = state.log.slice(state._logAt);
    if (!lines.length && !state._hits.length && !force) return;
    state._logAt = state.log.length;
    state.steps.push({ title, lines, hits: state._hits, view: view(state) });
    state._hits = [];
  }

  function heroName(state, p, k) { return `${state.players[p].name}の${HERO[state.players[p].heroes[k].id].name}`; }

  // ── 成長 ──
  function gainExp(state, p, k, n) {
    const h = state.players[p].heroes[k];
    if (h.ko || n <= 0 || h.lv >= 3) return;
    h.exp += n;
    const need = HERO[h.id].lvExp;
    while (h.lv < 3 && h.exp >= need[h.lv - 1]) {
      h.lv++;
      mark(state, { p, k, label: `Lv${h.lv}！` });
      const card = HERO[h.id].cards.find((id) => CARD[id].lv === h.lv);
      state.log.push(`${heroName(state, p, k)}がLv${h.lv}に上がった`);
      if (card) addCard(state, p, card, true);
    }
  }

  function addCard(state, p, id, announce) {
    const pl = state.players[p];
    if (pl.hand.length >= HAND_MAX) {
      state.log.push(`手札がいっぱいで、${CARD[id].name}は消えた`);
      return;
    }
    pl.hand.push({ uid: state.nextUid(), id });
    if (announce) state.log.push(`${pl.name}は${CARD[id].name}を得た`);
  }

  // ヒーローが今の位置に合ったカードを1枚生む
  function generate(state, p, k) {
    const h = state.players[p].heroes[k];
    if (h.ko) return;
    const pool = HERO[h.id].cards.filter((id) => CARD[id].pos === h.pos && CARD[id].lv <= h.lv);
    if (!pool.length) return;
    addCard(state, p, shuffleOne(pool, state.rng), false);
  }

  // ── ダメージ・回復 ──
  function damage(state, sp, sk, p, k, n, src, kind) {
    const h = state.players[p].heroes[k];
    if (h.ko || n <= 0) return 0;
    h.revealed = true;
    let rest = n;
    const absorbed = Math.min(h.shield, rest);
    h.shield -= absorbed;
    rest -= absorbed;
    h.hp -= rest;
    if (h.undying && h.hp < 1) h.hp = 1;
    mark(state, { p, k, n: -rest, label: absorbed ? `盾−${absorbed}` : null });
    state.log.push(`${src} → ${heroName(state, p, k)}に${n}ダメージ${absorbed ? `（盾で${absorbed}防いだ）` : ''}`);
    // 成長
    if (sp != null) {
      const sid = state.players[sp].heroes[sk].id;
      if (sid === 'sword') gainExp(state, sp, sk, n);
      if (sid === 'mage' && kind === 'spell') gainExp(state, sp, sk, 1);
      if (sid === 'rogue' && h.pos === 'back') gainExp(state, sp, sk, 2);
    }
    if (h.id === 'knight' && h.hp > 0) gainExp(state, p, k, n);
    if (h.hp <= 0) knockOut(state, p, k, sp);
    return n;
  }

  function knockOut(state, p, k, byP) {
    const pl = state.players[p];
    const h = pl.heroes[k];
    h.ko = true; h.hp = 0; h.shield = 0; h.taunt = false;
    const lost = pl.hand.filter((c) => CARD[c.id].hero === h.id).length;
    pl.hand = pl.hand.filter((c) => CARD[c.id].hero !== h.id);
    const o = byP != null ? byP : 1 - p;
    state.players[o].points++;
    mark(state, { p, k, label: '撃破' });
    state.log.push(`${heroName(state, p, k)}は倒れた（${state.players[o].name}に1点）${lost ? `。手札の${HERO[h.id].name}のカード${lost}枚が消えた` : ''}`);
    if (state.players[o].points >= WIN_POINTS) finish(state, `${WIN_POINTS}点先取`);
  }

  function heal(state, sp, sk, p, k, n, src) {
    const h = state.players[p].heroes[k];
    if (h.ko) return;
    const d = Math.min(n, h.maxHp - h.hp);
    h.hp += d;
    mark(state, { p, k, n: d, heal: true });
    state.log.push(`${src} → ${heroName(state, p, k)}のHPを${d}回復`);
    if (state.players[sp].heroes[sk].id === 'saint') gainExp(state, sp, sk, d);
  }

  function shield(state, sp, sk, p, k, n, src) {
    const h = state.players[p].heroes[k];
    if (h.ko) return;
    h.shield += n;
    mark(state, { p, k, label: `盾+${n}` });
    state.log.push(`${src} → ${heroName(state, p, k)}に盾${n}`);
    if (state.players[sp].heroes[sk].id === 'saint') gainExp(state, sp, sk, n);
  }

  // ── 狙える相手 ──
  // kind: front | any。挑発が最優先。front は前衛がいなければ後衛に届く（ダメージ−1）
  function targetsFor(state, p, kind) {
    const o = 1 - p;
    const hs = state.players[o].heroes;
    const alive = [0, 1].filter((k) => !hs[k].ko);
    const taunt = alive.filter((k) => hs[k].taunt);
    if (taunt.length) return taunt;
    if (kind === 'any') return alive;
    const front = alive.filter((k) => hs[k].pos === 'front');
    return front.length ? front : alive;
  }
  function reach(state, p, kind, k) {
    // 前衛を狙う攻撃が後衛に届くときは −1
    const h = state.players[1 - p].heroes[k];
    return kind === 'front' && h.pos === 'back' && !h.taunt ? -1 : 0;
  }

  // ── ターン ──
  function startTurn(state) {
    const p = state.active, pl = state.players[p];
    state.mana = p === state.first && state.round === 1 ? 1 : Math.min(state.round + 1, MANA_MAX);
    state.log.push(`${pl.name}のターン（ラウンド${state.round}・マナ${state.mana}）`);
    pl.heroes.forEach((h, k) => {
      if (h.ko) {
        Object.assign(h, makeHero(h.id, 'back'), { revealed: h.revealed });
        mark(state, { p, k, label: '復活' });
        state.log.push(`${heroName(state, p, k)}が後衛で復活した（Lv1）`);
      }
      h.shield = 0; h.taunt = false; h.undying = false; h.attacked = false; h.moved = false;
    });
    pl.heroes.forEach((h, k) => { if (h.id === 'mage' && h.pos === 'back') gainExp(state, p, k, 2); });
    const before = pl.hand.length;
    for (let k = 0; k < 2; k++) generate(state, p, k);
    state.log.push(`カードを${pl.hand.length - before}枚生んだ`);
    step(state, `${pl.name}のターン`, true);
  }

  function endTurn(state) {
    if (state.over) return;
    begin(state);
    state.active = 1 - state.active;
    if (state.active === state.first) state.round++;
    if (state.round > MAX_ROUND) { finish(state, `${MAX_ROUND}ラウンド終了`); step(state, '終了', true); return; }
    startTurn(state);
  }

  // ── 行動 ──
  // action = { type: 'card', uid, target } | { type: 'attack', k, target } | { type: 'move', k }
  function cardHeroIndex(state, p, id) { return state.players[p].heroes.findIndex((h) => h.id === CARD[id].hero); }

  function check(state, p, a) {
    if (state.over || state.active !== p) return '自分のターンではない';
    const pl = state.players[p];
    if (a.type === 'card') {
      const c = pl.hand.find((x) => x.uid === a.uid);
      if (!c) return '手札にない';
      const def = CARD[c.id];
      const k = cardHeroIndex(state, p, c.id);
      const h = pl.heroes[k];
      if (h.ko) return `${HERO[h.id].name}が倒れている`;
      if (def.pos === 'front' && h.pos !== 'front') return `${HERO[h.id].name}が前衛にいない`;
      if (def.cost > state.mana) return 'マナが足りない';
      if (def.target === 'front' || def.target === 'any') { if (!targetsFor(state, p, def.target).includes(a.target)) return '狙えない相手'; }
      else if (def.target === 'ally') { if (!(a.target === 0 || a.target === 1) || pl.heroes[a.target].ko) return '対象が不正'; }
      return null;
    }
    if (a.type === 'attack') {
      const h = pl.heroes[a.k];
      if (!h || h.ko) return '倒れている';
      if (h.pos !== 'front') return '前衛にいない';
      if (h.attacked) return 'このターンはもう攻撃した';
      if (state.mana < 1) return 'マナが足りない';
      if (!targetsFor(state, p, 'front').includes(a.target)) return '狙えない相手';
      return null;
    }
    if (a.type === 'move') {
      const h = pl.heroes[a.k];
      if (!h || h.ko) return '倒れている';
      if (h.moved) return 'このターンはもう動いた';
      if (state.mana < 1) return 'マナが足りない';
      return null;
    }
    return '不明な行動';
  }

  function act(state, p, a) {
    begin(state);
    const err = check(state, p, a);
    if (err) return err;
    const pl = state.players[p], o = 1 - p;
    if (a.type === 'move') {
      state.mana -= 1;
      const h = pl.heroes[a.k];
      h.moved = true;
      h.pos = h.pos === 'front' ? 'back' : 'front';
      if (h.pos === 'front') h.revealed = true;
      mark(state, { p, k: a.k, label: POS_NAME[h.pos] + 'へ' });
      state.log.push(`${heroName(state, p, a.k)}が${POS_NAME[h.pos]}へ移った`);
      step(state, '移動', true);
      return null;
    }
    if (a.type === 'attack') {
      state.mana -= 1;
      const h = pl.heroes[a.k];
      h.attacked = true;
      const n = h.atk + h.focus + reach(state, p, 'front', a.target);
      h.focus = 0;
      state.log.push(`${heroName(state, p, a.k)}の攻撃`);
      damage(state, p, a.k, o, a.target, Math.max(0, n), HERO[h.id].name, 'attack');
      step(state, `攻撃：${HERO[h.id].name}`, true);
      return null;
    }
    // カード
    const c = pl.hand.find((x) => x.uid === a.uid);
    const def = CARD[c.id];
    const k = cardHeroIndex(state, p, c.id);
    const h = pl.heroes[k];
    pl.hand = pl.hand.filter((x) => x.uid !== a.uid);
    state.mana -= def.cost;
    h.revealed = true;
    state.log.push(`${pl.name}：${HERO[h.id].name}の「${def.name}」`);
    const hit = (n, kind = 'attack') => {
      if (state.over || pl.heroes[k].ko) return;
      const t = a.target;
      if (state.players[o].heroes[t].ko) return;
      const bonus = kind === 'attack' ? h.focus : 0;
      if (kind === 'attack') h.focus = 0;
      damage(state, p, k, o, t, Math.max(0, n + bonus + reach(state, p, def.target, t)), def.name, kind);
    };
    const enemies = () => [0, 1].filter((x) => !state.players[o].heroes[x].ko);
    switch (def.id) {
      case 'sw_slash': hit(3); break;
      case 'sw_focus': h.focus += 2; mark(state, { p, k, label: '次の攻撃+2' }); state.log.push('次の攻撃のダメージ+2'); break;
      case 'sw_lunge': hit(5); if (!state.over) damage(state, null, null, p, k, 1, '反動'); break;
      case 'sw_double': hit(3); hit(3); break;
      case 'sw_ult': hit(8); break;
      case 'st_heal': heal(state, p, k, p, a.target, 3, def.name); break;
      case 'st_mace': hit(2); for (let x = 0; x < 2; x++) if (!pl.heroes[x].ko) heal(state, p, k, p, x, 1, def.name); break;
      case 'st_bless': shield(state, p, k, p, a.target, 3, def.name); break;
      case 'st_prayer': state.mana += 2; mark(state, { p, k, label: 'マナ+2' }); state.log.push('このターン、マナ+2'); break;
      case 'st_ult':
        for (let x = 0; x < 2; x++) {
          const hh = pl.heroes[x];
          if (hh.ko) { Object.assign(hh, makeHero(hh.id, 'back'), { revealed: true }); mark(state, { p, k: x, label: '復活' }); state.log.push(`${heroName(state, p, x)}が復活した`); }
          else heal(state, p, k, p, x, hh.maxHp, def.name);
        }
        break;
      case 'kn_bash': hit(2); shield(state, p, k, p, k, 2, def.name); break;
      case 'kn_taunt': h.taunt = true; mark(state, { p, k, label: '挑発' }); state.log.push('次の相手のターン、相手はこのヒーローしか狙えない'); break;
      case 'kn_guard': shield(state, p, k, p, a.target, 4, def.name); break;
      case 'kn_wall': for (let x = 0; x < 2; x++) shield(state, p, k, p, x, 3, def.name); break;
      case 'kn_ult': pl.heroes.forEach((hh, x) => { if (!hh.ko) { hh.undying = true; mark(state, { p, k: x, label: '不屈' }); } }); state.log.push('次の相手のターン、味方は倒れない'); break;
      case 'mg_bolt': hit(2, 'spell'); break;
      case 'mg_flame':
        for (const t of enemies()) if (state.players[o].heroes[t].pos === 'front' && !state.over) damage(state, p, k, o, t, 3, def.name, 'spell');
        break;
      case 'mg_meditate': state.mana += 1; mark(state, { p, k, label: 'マナ+1' }); state.log.push('このターン、マナ+1'); break;
      case 'mg_thunder': hit(5, 'spell'); break;
      case 'mg_ult': for (const t of enemies()) if (!state.over) damage(state, p, k, o, t, 5, def.name, 'spell'); break;
      case 'rg_dagger': hit(2); break;
      case 'rg_trip': {
        const t = state.players[o].heroes[a.target];
        hit(1);
        if (!t.ko && t.pos === 'front') { t.pos = 'back'; mark(state, { p: o, k: a.target, label: '後衛へ' }); state.log.push(`${heroName(state, o, a.target)}は後衛に下げられた`); }
        break;
      }
      case 'rg_steal': {
        const oh = state.players[o].hand;
        if (oh.length) {
          const i = Math.floor(state.rng() * oh.length);
          const lost = oh.splice(i, 1)[0];
          mark(state, { p: o, k: null, label: '手札−1' });
          state.log.push(`${state.players[o].name}は「${CARD[lost.id].name}」を失った`);
          gainExp(state, p, k, 2);
        } else state.log.push('相手の手札がなかった');
        break;
      }
      case 'rg_backstab': {
        const t = state.players[o].heroes[a.target];
        hit(t.hp * 2 <= t.maxHp ? 6 : 3);
        break;
      }
      case 'rg_ult':
        for (let i = 0; i < 3 && !state.over; i++) {
          const es = enemies();
          if (!es.length) break;
          const t = es[Math.floor(state.rng() * es.length)];
          damage(state, p, k, o, t, 3, def.name, 'attack');
        }
        break;
    }
    step(state, `${HERO[h.id].name}：${def.name}`, true);
    return null;
  }

  function finish(state, reason) {
    const P = state.players;
    state.over = true;
    const hp = (pl) => pl.heroes.reduce((s, h) => s + (h.ko ? 0 : h.hp), 0);
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

  // 今できる行動を全部挙げる
  function actions(state, p) {
    const pl = state.players[p];
    const out = [];
    for (const c of pl.hand) {
      const def = CARD[c.id];
      const ts = def.target === 'front' || def.target === 'any' ? [0, 1] : def.target === 'ally' ? [0, 1] : [null];
      for (const t of ts) { const a = { type: 'card', uid: c.uid, target: t }; if (!check(state, p, a)) out.push(a); }
    }
    for (let k = 0; k < 2; k++) {
      for (const t of [0, 1]) { const a = { type: 'attack', k, target: t }; if (!check(state, p, a)) out.push(a); }
      const m = { type: 'move', k }; if (!check(state, p, m)) out.push(m);
    }
    return out;
  }

  // ── CPU ──
  function clone(state) {
    const s = JSON.parse(JSON.stringify({ ...state, nextUid: undefined, rng: undefined, steps: undefined, log: undefined, _hits: undefined }));
    let uid = 100000;
    s.nextUid = () => uid++;
    s.rng = () => 0.5;
    s.steps = []; s.log = []; s._hits = [];
    return s;
  }

  function value(s, p) {
    const o = 1 - p;
    if (s.over) return s.winner === p ? 10000 : s.winner === o ? -10000 : 0;
    const side = (q) => {
      const pl = s.players[q], opp = s.players[1 - q];
      const threat = opp.heroes.reduce((t, h) => t + (h.ko || h.pos !== 'front' ? 0 : h.atk + 3), 0) + 2;
      // 手札は持っているだけでは得にならない。次のターンに溢れて消える分は損
      let v = pl.points * 40 + Math.min(pl.hand.length, HAND_MAX - 2) * 0.4 - Math.max(0, pl.hand.length - (HAND_MAX - 2)) * 1.5;
      pl.heroes.forEach((h) => {
        if (h.ko) { v -= 8; return; }
        v += h.hp + h.shield * 0.6 + h.lv * 6 + h.exp * 0.8 + (h.taunt ? 2 : 0) + (h.undying ? 4 : 0);
        // 次の相手のターンに倒されそうなら減点（前衛ほど危ない）
        const exposed = h.pos === 'front' || pl.heroes.every((x) => x.ko || x.pos === 'back');
        if (exposed && h.hp + h.shield <= threat && !h.undying) v -= 10 + h.lv * 4;
      });
      return v;
    };
    return side(p) - side(o);
  }

  // 良くなる限り行動を重ねる。実行した行動の段階を返す
  function cpuTurn(state, p) {
    const steps = [];
    for (let guard = 0; guard < 12 && !state.over; guard++) {
      const base = value(state, p);
      let best = null, bestV = base + 0.25;
      for (const a of actions(state, p)) {
        const s = clone(state);
        act(s, p, a);
        const v = value(s, p) + state.rng() * 0.2;
        if (v > bestV) { bestV = v; best = a; }
      }
      if (!best) break;
      act(state, p, best);
      steps.push(...state.steps);
    }
    return steps;
  }

  const CPU_TEAMS = [
    { label: '剣士と聖女', heroes: ['sword', 'saint'], front: 0 },
    { label: '守護騎士と魔術師', heroes: ['knight', 'mage'], front: 0 },
    { label: '盗賊と剣士', heroes: ['rogue', 'sword'], front: 0 },
    { label: '魔術師と聖女', heroes: ['mage', 'saint'], front: 1 },
    { label: '守護騎士と盗賊', heroes: ['knight', 'rogue'], front: 0 },
  ];

  const api = {
    WIN_POINTS, MAX_ROUND, HAND_MAX, MANA_MAX, HEROES, HERO, CARDS, CARD, POS_NAME, CPU_TEAMS,
    validateTeam, newGame, view, check, act, actions, endTurn, targetsFor, cardHeroIndex, cpuTurn, value,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.Engine = api;
})(typeof self !== 'undefined' ? self : this);
