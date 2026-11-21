// ふたりの英雄（仮）・対応版 ルールエンジン（ブラウザ・Node 共用、DOM 非依存）
// 攻守交代のターン制。手番の側は行動を1つずつ行い、攻撃には相手が「対応」できる（1段だけ）。
// 使わずに残したマナは、相手のターンの対応に使える（MTG と同じ考え方）
(function (root) {
  'use strict';

  const MAX_ROUND = 10;
  const HAND_MAX = 5;
  const MANA_MAX = 6;
  const TOWER = 2; // 攻撃の対象としてのタワーの番号
  const TOWER_HP = 20;
  const TOWER_COUNTER = 4;
  const FRONT_CARDS = 2; // 前衛のヒーローが毎ターン生むカードの枚数（後衛は1枚）
  const ATTACK_COST = 1; // 通常攻撃のマナ
  const REVIVE_WAIT = 1; // 倒されたヒーローが、復活するまでに休む自分のターンの数

  const HEROES = [
    { id: 'sword', name: '剣士', color: 'red', hp: 12, atk: 3, cards: ['sw_slash', 'sw_focus', 'sw_lunge'] },
    { id: 'saint', name: '聖女', color: 'gold', hp: 10, atk: 1, cards: ['st_heal', 'st_mace', 'st_bless'] },
    { id: 'knight', name: '守護騎士', color: 'grey', hp: 15, atk: 2, cards: ['kn_bash', 'kn_taunt', 'kn_guard'] },
    { id: 'mage', name: '魔術師', color: 'blue', hp: 8, atk: 1, cards: ['mg_bolt', 'mg_flame', 'mg_meditate'] },
    { id: 'rogue', name: '盗賊', color: 'green', hp: 10, atk: 3, cards: ['rg_dagger', 'rg_trip', 'rg_steal'] },
  ];
  const HERO = Object.fromEntries(HEROES.map((h) => [h.id, h]));

  // pos: front = 前衛で生まれ、そのヒーローが前衛にいるときだけ使える / back = 後衛で生まれ、どこからでも使える
  // target: front = 敵の前衛かタワー / any = 敵の誰でもかタワー（遠距離）/ ally = 味方 / none
  // attack: 攻撃（相手が対応できる）。resp: 対応カード（相手の攻撃に合わせて使える。自分のターンにも使える）
  const CARDS = [
    { id: 'sw_slash', hero: 'sword', name: '斬撃', cost: 1, pos: 'front', target: 'front', attack: true, text: '3ダメージ。' },
    { id: 'sw_focus', hero: 'sword', name: '気合い', cost: 1, pos: 'back', target: 'none', text: 'このターン、このヒーローの次の攻撃のダメージ+2。' },
    { id: 'sw_lunge', hero: 'sword', name: '踏み込み', cost: 2, pos: 'front', target: 'front', attack: true, text: '5ダメージ。自分も1ダメージを受ける。' },

    { id: 'st_heal', hero: 'saint', name: '癒しの光', cost: 1, pos: 'back', target: 'ally', resp: true, text: '味方1人のHPを3回復。' },
    { id: 'st_mace', hero: 'saint', name: '光の槌', cost: 1, pos: 'front', target: 'front', attack: true, text: '2ダメージ。当たれば味方全員のHPを1回復。' },
    { id: 'st_bless', hero: 'saint', name: '加護', cost: 1, pos: 'back', target: 'ally', resp: true, text: '味方1人に盾3（次の自分のターンまで）。' },

    { id: 'kn_bash', hero: 'knight', name: '盾打ち', cost: 1, pos: 'front', target: 'front', attack: true, text: '2ダメージ。当たれば自分に盾2。' },
    { id: 'kn_taunt', hero: 'knight', name: '挑発', cost: 1, pos: 'front', target: 'none', resp: true, text: '次の自分のターンまで、相手の攻撃はこのヒーローに向く。対応で使うと、その攻撃を引きつける。' },
    { id: 'kn_guard', hero: 'knight', name: '守りの構え', cost: 1, pos: 'back', target: 'ally', resp: true, text: '味方1人に盾4（次の自分のターンまで）。' },

    { id: 'mg_bolt', hero: 'mage', name: '魔力の矢', cost: 1, pos: 'back', target: 'any', attack: true, text: '遠距離。2ダメージ。' },
    { id: 'mg_flame', hero: 'mage', name: '火炎', cost: 2, pos: 'front', target: 'none', attack: true, text: '前衛にいる敵全員に3ダメージ。' },
    { id: 'mg_meditate', hero: 'mage', name: '瞑想', cost: 0, pos: 'back', target: 'none', text: 'このターン、マナ+1。' },

    { id: 'rg_dagger', hero: 'rogue', name: '投げナイフ', cost: 1, pos: 'front', target: 'any', attack: true, text: '遠距離。2ダメージ。' },
    { id: 'rg_trip', hero: 'rogue', name: '足払い', cost: 1, pos: 'front', target: 'front', resp: true, text: '1ダメージ。相手を後衛に下げる。対応で使うと、攻撃してきた前衛を下げて、その攻撃を空振りさせる。' },
    { id: 'rg_steal', hero: 'rogue', name: '盗み', cost: 1, pos: 'back', target: 'none', text: '相手の手札を1枚ランダムに捨てさせる。' },
  ];
  const CARD = Object.fromEntries(CARDS.map((c) => [c.id, c]));
  const POS_NAME = { front: '前衛', back: '後衛' };

  function validateTeam(team) {
    const errs = [];
    if (!team || !Array.isArray(team.heroes) || team.heroes.length !== 2) errs.push('ヒーローを2人選んでください');
    else if (team.heroes[0] === team.heroes[1]) errs.push('同じヒーローは選べません');
    else if (team.heroes.some((h) => !HERO[h])) errs.push('不明なヒーロー');
    return errs;
  }

  function makeHero(id, pos) {
    const h = HERO[id];
    return { id, hp: h.hp, maxHp: h.hp, atk: h.atk, pos, shield: 0, ko: false, revealed: pos === 'front',
      focus: 0, taunt: false, attacked: false, moved: false, note: null };
  }

  // ── 状態 ──
  function newGame(teams, names, rng, first) {
    rng = rng || Math.random;
    let uid = 1;
    const state = {
      round: 1, first: first ?? (rng() < 0.5 ? 0 : 1), active: 0, over: false, winner: null, endReason: '',
      pending: null, log: [], steps: [],
      players: teams.map((t, i) => ({
        name: names[i], tower: TOWER_HP, mana: 0, hand: [],
        heroes: t.heroes.map((id, k) => makeHero(id, (t.front ?? 0) === k ? 'front' : 'back')),
      })),
      nextUid() { return uid++; },
      rng,
    };
    state.active = state.first;
    begin(state);
    for (let p = 0; p < 2; p++) for (let k = 0; k < 2; k++) generate(state, p, k);
    startTurn(state);
    return state;
  }

  // ── 演出用の記録 ──
  // step = { title, lines, hits, actor, view }。lines の「※」で始まる行は理由（画面で「なぜ」と表示）
  function begin(state) { state.log = []; state.steps = []; state._hits = []; state._aim = []; state._logAt = 0; }
  function mark(state, hit) { state._hits.push(hit); }
  function towerDefended(state, p) { return state.players[p].heroes.some((h) => !h.ko && h.hp > 0 && h.pos === 'front'); }
  function view(state) {
    return {
      round: state.round, active: state.active,
      players: state.players.map((pl, p) => ({ tower: pl.tower, mana: pl.mana, defended: towerDefended(state, p), handCount: pl.hand.length, heroes: pl.heroes.map((h) => ({ ...h })) })),
    };
  }
  // aim：その段階で攻撃が向かった先（矢印の表示用）。{ p, k } の配列
  function step(state, title, force, actor) {
    const lines = state.log.slice(state._logAt);
    if (!lines.length && !state._hits.length && !force) return;
    state._logAt = state.log.length;
    state.steps.push({ title, lines, hits: state._hits, actor: actor || null, aim: state._aim || [], view: view(state) });
    state._hits = [];
    state._aim = [];
  }
  function aimAt(state, p, k) { (state._aim = state._aim || []).push({ p, k }); }
  function heroName(state, p, k) { return `${state.players[p].name}の${HERO[state.players[p].heroes[k].id].name}`; }

  function generate(state, p, k) {
    const pl = state.players[p], h = pl.heroes[k];
    if (h.ko || pl.hand.length >= HAND_MAX) return;
    const pool = HERO[h.id].cards.filter((id) => CARD[id].pos === h.pos);
    if (pool.length) pl.hand.push({ uid: state.nextUid(), id: pool[Math.floor(state.rng() * pool.length)] });
  }

  // ── ターン ──
  function manaFor(state, p) { return p === state.first && state.round === 1 ? 1 : Math.min(state.round + 1, MANA_MAX); }

  function startTurn(state) {
    const p = state.active, pl = state.players[p];
    pl.mana = manaFor(state, p);
    state.log.push(`${pl.name}のターン（ラウンド${state.round}・マナ${pl.mana}）`);
    pl.heroes.forEach((h, k) => {
      if (h.ko && h.wait > 0) {
        h.wait--;
        state.log.push(`${heroName(state, p, k)}は休んでいる（復活まで、あと${h.wait + 1}ターン）`);
      } else if (h.ko) {
        Object.assign(h, makeHero(h.id, 'back'), { revealed: h.revealed });
        mark(state, { p, k, label: '復活' });
        state.log.push(`${heroName(state, p, k)}が後衛で復活した`);
      }
      h.shield = 0; h.taunt = false; h.focus = 0; h.attacked = false; h.moved = false; h.note = null;
    });
    for (let k = 0; k < 2; k++) for (let n = pl.heroes[k].pos === 'front' ? FRONT_CARDS : 1; n > 0; n--) generate(state, p, k);
    step(state, `${pl.name}のターン`, true);
  }

  function endTurn(state) {
    begin(state);
    if (state.over) return state.steps;
    const p = state.active;
    state.players[p].heroes.forEach((h) => { h.focus = 0; });
    state.active = 1 - p;
    if (state.active === state.first) state.round++;
    if (state.round > MAX_ROUND) { finish(state, `${MAX_ROUND}ラウンド終了`); step(state, '終了', true); return state.steps; }
    startTurn(state);
    return state.steps;
  }

  // ── 行動の確認 ──
  // action = { type: 'card', uid, target } | { type: 'attack', k, target } | { type: 'move', k }
  function cardHero(state, p, id) { return state.players[p].heroes.findIndex((h) => h.id === CARD[id].hero); }

  // 自分のターンの行動として正しいか。正しければ null
  function check(state, p, a) {
    if (state.over || state.active !== p || state.pending) return '今は行動できない';
    const pl = state.players[p];
    if (a.type === 'move') {
      const h = pl.heroes[a.k];
      if (!h || h.ko) return '倒れている';
      if (h.moved) return '移動は1ターン1回';
      if (pl.mana < 1) return 'マナが足りない';
      return null;
    }
    if (a.type === 'attack') {
      const h = pl.heroes[a.k];
      if (!h || h.ko) return '倒れている';
      if (h.pos !== 'front') return '前衛にいない';
      if (h.attacked) return '通常攻撃は1ターン1回';
      if (pl.mana < ATTACK_COST) return 'マナが足りない';
      if (!validFoe(state, p, a.target)) return '狙えない相手';
      return null;
    }
    if (a.type === 'card') {
      const c = pl.hand.find((x) => x.uid === a.uid);
      if (!c) return '手札にない';
      return checkCard(state, p, CARD[c.id], a.target);
    }
    return '不明な行動';
  }

  function validFoe(state, p, t) {
    if (t === TOWER) return true;
    const h = state.players[1 - p].heroes[t];
    return !!h && !h.ko;
  }

  function checkCard(state, p, def, target) {
    const pl = state.players[p];
    const k = cardHero(state, p, def.id);
    const h = pl.heroes[k];
    if (h.ko) return `${HERO[h.id].name}が倒れている`;
    if (def.pos === 'front' && h.pos !== 'front') return `${HERO[h.id].name}が前衛にいない`;
    if (def.cost > pl.mana) return 'マナが足りない';
    if (def.target === 'none') return target == null ? null : '対象が不正';
    if (def.target === 'ally') return (target === 0 || target === 1) && !pl.heroes[target].ko ? null : '対象が不正';
    if (def.id === 'rg_trip') { const t = state.players[1 - p].heroes[target]; return t && !t.ko && t.pos === 'front' ? null : '前衛の相手を選んでください'; }
    return validFoe(state, p, target) ? null : '狙えない相手';
  }

  // 相手の攻撃に対応できるか。resp = { uid, target }
  function checkResponse(state, q, resp) {
    const pd = state.pending;
    if (!pd || pd.p === q) return '対応できる攻撃がない';
    const c = state.players[q].hand.find((x) => x.uid === resp.uid);
    if (!c) return '手札にない';
    const def = CARD[c.id];
    if (!def.resp) return '対応カードではない';
    const k = cardHero(state, q, def.id);
    const h = state.players[q].heroes[k];
    if (h.ko) return `${HERO[h.id].name}が倒れている`;
    if (def.pos === 'front' && h.pos !== 'front') return `${HERO[h.id].name}が前衛にいない`;
    if (def.cost > state.players[q].mana) return 'マナが足りない';
    if (def.id === 'rg_trip') {
      const a = state.players[pd.p].heroes[pd.k];
      return a.pos === 'front' ? null : '攻撃してきた相手が前衛にいない';
    }
    if (def.target === 'ally') return (resp.target === 0 || resp.target === 1) && !state.players[q].heroes[resp.target].ko ? null : '対象が不正';
    return null;
  }

  // ── 処理 ──
  function damage(state, p, k, n, src) {
    const h = state.players[p].heroes[k];
    if (h.ko || n <= 0) return;
    h.revealed = true;
    const absorbed = Math.min(h.shield, n);
    h.shield -= absorbed;
    h.hp -= n - absorbed;
    mark(state, { p, k, n: -(n - absorbed), label: absorbed ? `盾−${absorbed}` : null, hit: true });
    state.log.push(`${src} → ${heroName(state, p, k)}に${n}ダメージ${absorbed ? `（盾で${absorbed}防いだ）` : ''}`);
    if (h.hp <= 0) {
      const pl = state.players[p];
      h.ko = true; h.hp = 0; h.shield = 0; h.taunt = false; h.wait = REVIVE_WAIT;
      const lost = pl.hand.filter((c) => CARD[c.id].hero === h.id).length;
      pl.hand = pl.hand.filter((c) => CARD[c.id].hero !== h.id);
      mark(state, { p, k, label: '撃破' });
      state.log.push(`${heroName(state, p, k)}は倒れた（次の自分のターンに復活）${lost ? `。手札の${HERO[h.id].name}のカード${lost}枚が消えた` : ''}`);
    }
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

  // タワーを殴る。守られていれば、殴ったヒーロー（k）に反撃
  function hitTower(state, p, k, n, src) {
    const o = 1 - p, pl = state.players[o];
    const defended = towerDefended(state, o);
    pl.tower -= n;
    mark(state, { p: o, k: TOWER, n: -n, hit: true });
    const guards = pl.heroes.filter((h) => !h.ko && h.hp > 0 && h.pos === 'front').map((h) => HERO[h.id].name).join('と');
    state.log.push(defended ? `※${pl.name}の前衛に${guards}がいるので、タワーは守られている（殴ると反撃${TOWER_COUNTER}）` : `※${pl.name}の前衛が空なので、タワーは無防備（反撃なし）`);
    state.log.push(`${src} → ${pl.name}のタワーに${n}ダメージ`);
    if (defended && k != null) { state.log.push('タワーの反撃！'); damage(state, p, k, TOWER_COUNTER, 'タワーの反撃'); }
    if (pl.tower <= 0) finish(state, 'タワー破壊');
  }

  // 攻撃が当たる相手を決める。null なら空振り
  function resolveTarget(state, p, kind, t) {
    const o = 1 - p, hs = state.players[o].heroes;
    const taunt = [0, 1].find((x) => !hs[x].ko && hs[x].taunt);
    if (taunt != null) return { k: taunt, why: taunt !== t ? `※${HERO[hs[taunt].id].name}の挑発で、攻撃が引きつけられた` : null };
    if (t === TOWER) return { k: TOWER };
    const h = hs[t];
    if (h.ko) return null;
    if (kind === 'any' || h.pos === 'front') return { k: t };
    return null;
  }
  function whyMiss(state, p, t) {
    const h = state.players[1 - p].heroes[t];
    const nm = `${state.players[1 - p].name}の${HERO[h.id].name}`;
    if (h.ko) return `※狙った${nm}は、もう倒れていた`;
    return `※狙った${nm}は後衛にいた${h.note ? `（${h.note}）` : ''}。後衛はタワーに守られていて、前衛向けの攻撃は届かない`;
  }
  function strike(state, p, k, t, n, src) {
    aimAt(state, 1 - p, t.k);
    if (t.k === TOWER) { hitTower(state, p, k, n, src); return TOWER; }
    damage(state, 1 - p, t.k, n, src);
    return t.k;
  }

  // 攻撃以外のカード、または攻撃カードの本体を処理する
  function applyCard(state, p, def, target) {
    const pl = state.players[p], o = 1 - p;
    const k = cardHero(state, p, def.id);
    const h = pl.heroes[k];
    h.revealed = true;
    const hit = (n) => {
      if (h.ko) return null;
      const t = resolveTarget(state, p, def.target, target);
      if (!t) { mark(state, { p: o, k: target, label: '空振り' }); state.log.push('空振り！', whyMiss(state, p, target)); return null; }
      if (t.why) state.log.push(t.why);
      const bonus = h.focus; h.focus = 0;
      return strike(state, p, k, t, n + bonus, def.name);
    };
    switch (def.id) {
      case 'sw_slash': hit(3); break;
      case 'sw_focus': h.focus += 2; mark(state, { p, k, label: '次の攻撃+2' }); state.log.push('このターン、次の攻撃のダメージ+2'); break;
      case 'sw_lunge': if (hit(5) != null && !h.ko) damage(state, p, k, 1, '反動'); break;
      case 'st_heal': heal(state, p, target, 3, def.name); break;
      case 'st_mace': if (hit(2) != null) for (let x = 0; x < 2; x++) heal(state, p, x, 1, def.name); break;
      case 'st_bless': shield(state, p, target, 3, def.name); break;
      case 'kn_bash': if (hit(2) != null && !h.ko) shield(state, p, k, 2, def.name); break;
      case 'kn_taunt': h.taunt = true; mark(state, { p, k, label: '挑発' }); state.log.push('次の自分のターンまで、相手の攻撃はこのヒーローに向く'); break;
      case 'kn_guard': shield(state, p, target, 4, def.name); break;
      case 'mg_bolt': hit(2); break;
      case 'mg_flame': {
        const fr = [0, 1].filter((x) => !state.players[o].heroes[x].ko && state.players[o].heroes[x].pos === 'front');
        if (!fr.length) state.log.push('誰にも当たらなかった', '※火炎は前衛にいる敵にだけ当たる。前衛に敵がいなかった');
        for (const x of fr) { aimAt(state, o, x); damage(state, o, x, 3, def.name); }
        break;
      }
      case 'mg_meditate': pl.mana += 1; mark(state, { p, k, label: 'マナ+1' }); state.log.push('このターン、マナ+1'); break;
      case 'rg_dagger': hit(2); break;
      case 'rg_trip': {
        const t = state.players[o].heroes[target];
        aimAt(state, o, target);
        damage(state, o, target, 1, def.name);
        if (!t.ko && t.pos === 'front') { t.pos = 'back'; t.note = '足払いで下げられた'; mark(state, { p: o, k: target, label: '後衛へ' }); state.log.push(`${heroName(state, o, target)}は後衛に下げられた`); }
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
    }
  }

  // 自分のターンの行動。攻撃なら pending にして相手の対応を待ち、それ以外はすぐ処理する
  // 戻り値：{ error } か { waiting: true }（相手の対応待ち）か { done: true }
  function act(state, p, a) {
    begin(state);
    const err = check(state, p, a);
    if (err) return { error: err };
    const pl = state.players[p];
    if (a.type === 'move') {
      pl.mana -= 1;
      const h = pl.heroes[a.k];
      h.moved = true;
      h.pos = h.pos === 'front' ? 'back' : 'front';
      h.note = `このターンに${POS_NAME[h.pos]}へ移った`;
      if (h.pos === 'front') h.revealed = true;
      mark(state, { p, k: a.k, label: POS_NAME[h.pos] + 'へ' });
      state.log.push(`${heroName(state, p, a.k)}が${POS_NAME[h.pos]}へ移った`);
      step(state, '移動', true, { p, k: a.k });
      return { done: true };
    }
    if (a.type === 'attack') {
      pl.mana -= ATTACK_COST;
      const h = pl.heroes[a.k];
      h.attacked = true;
      state.pending = { p, k: a.k, type: 'attack', target: a.target };
      aimAt(state, 1 - p, a.target);
      state.log.push(`${heroName(state, p, a.k)}が${targetName(state, p, a.target)}に通常攻撃（${h.atk + h.focus}ダメージ）`);
      step(state, `攻撃の宣言：${HERO[h.id].name}`, true, { p, k: a.k });
      return { waiting: true };
    }
    // カード
    const c = pl.hand.find((x) => x.uid === a.uid);
    const def = CARD[c.id];
    const k = cardHero(state, p, def.id);
    pl.hand = pl.hand.filter((x) => x.uid !== a.uid);
    pl.mana -= def.cost;
    pl.heroes[k].revealed = true;
    if (def.attack) {
      state.pending = { p, k, type: 'card', id: def.id, target: a.target };
      if (a.target != null) aimAt(state, 1 - p, a.target);
      else if (def.id === 'mg_flame') [0, 1].forEach((x) => { const e = state.players[1 - p].heroes[x]; if (!e.ko && e.pos === 'front') aimAt(state, 1 - p, x); });
      state.log.push(`${heroName(state, p, k)}の「${def.name}」${def.target === 'none' ? '' : `→${targetName(state, p, a.target)}`}：${def.text}`);
      step(state, `攻撃の宣言：${HERO[def.hero].name}の${def.name}`, true, { p, k });
      return { waiting: true };
    }
    state.log.push(`${heroName(state, p, k)}の「${def.name}」`);
    applyCard(state, p, def, a.target);
    step(state, `${HERO[def.hero].name}：${def.name}`, true, { p, k });
    return { done: true };
  }

  function targetName(state, p, t) {
    if (t == null) return '';
    if (t === TOWER) return `${state.players[1 - p].name}のタワー`;
    return heroName(state, 1 - p, t);
  }

  // 相手の対応（resp = null なら対応しない）を処理してから、保留中の攻撃を処理する
  function respond(state, q, resp) {
    begin(state);
    const pd = state.pending;
    if (!pd) return { error: '対応できる攻撃がない' };
    const P = state.players, p = pd.p;
    if (resp) {
      const err = checkResponse(state, q, resp);
      if (err) return { error: err };
      const c = P[q].hand.find((x) => x.uid === resp.uid);
      const def = CARD[c.id];
      const k = cardHero(state, q, def.id);
      P[q].hand = P[q].hand.filter((x) => x.uid !== resp.uid);
      P[q].mana -= def.cost;
      P[q].heroes[k].revealed = true;
      state.log.push(`${heroName(state, q, k)}が対応：「${def.name}」`);
      if (def.id === 'rg_trip') applyCard(state, q, def, pd.k);
      else if (def.id === 'kn_taunt') { applyCard(state, q, def, null); state.log.push('※挑発は、今の攻撃にも効く'); }
      else applyCard(state, q, def, resp.target);
      step(state, `対応：${HERO[def.hero].name}の${def.name}`, true, { p: q, k });
    } else {
      state.log.push(`${P[q].name}は対応しなかった`);
      step(state, '対応なし', true);
    }
    // 攻撃の本体
    state.pending = null;
    const h = P[p].heroes[pd.k];
    const nm = HERO[h.id].name;
    const def = pd.type === 'card' ? CARD[pd.id] : null;
    const title = def ? `${nm}：${def.name}` : `攻撃：${nm}`;
    if (h.ko) { state.log.push(`${heroName(state, p, pd.k)}は倒れていて、攻撃できなかった`); step(state, title, true); return { done: true }; }
    const needFront = !def || def.pos === 'front';
    if (needFront && h.pos !== 'front') {
      mark(state, { p, k: pd.k, label: '不発' });
      state.log.push(`${heroName(state, p, pd.k)}の攻撃は不発`, `※${nm}は後衛に下げられていた（${h.note || ''}）。前衛からの攻撃は、後衛からはできない`);
      step(state, title, true);
      return { done: true };
    }
    if (def) applyCard(state, p, def, pd.target);
    else {
      const t = resolveTarget(state, p, 'front', pd.target);
      if (!t) { mark(state, { p: 1 - p, k: pd.target, label: '空振り' }); state.log.push('空振り！', whyMiss(state, p, pd.target)); }
      else {
        if (t.why) state.log.push(t.why);
        const n = h.atk + h.focus; h.focus = 0;
        strike(state, p, pd.k, t, n, nm);
      }
    }
    step(state, title, true, { p, k: pd.k });
    return { done: true };
  }

  function finish(state, reason) {
    if (state.over) return;
    const P = state.players;
    state.over = true;
    const hp = (pl) => pl.heroes.reduce((s, h) => s + (h.ko ? 0 : h.hp), 0);
    const tw = (pl) => Math.max(0, pl.tower);
    if (P[0].tower !== P[1].tower) { state.winner = P[0].tower > P[1].tower ? 0 : 1; state.endReason = `${reason}：タワーの残りHP ${tw(P[0])} 対 ${tw(P[1])}`; }
    else if (hp(P[0]) !== hp(P[1])) { state.winner = hp(P[0]) > hp(P[1]) ? 0 : 1; state.endReason = `${reason}：タワーは同じ。ヒーローの残りHP ${hp(P[0])} 対 ${hp(P[1])}`; }
    else { state.winner = 'draw'; state.endReason = `${reason}：タワーもヒーローの残りHPも同じ`; }
  }

  // 自分のターンにできる行動を全部挙げる
  function actions(state, p) {
    const pl = state.players[p], out = [];
    const tryA = (a) => { if (!check(state, p, a)) out.push(a); };
    for (let k = 0; k < 2; k++) { tryA({ type: 'move', k }); for (const t of [0, 1, TOWER]) tryA({ type: 'attack', k, target: t }); }
    for (const c of pl.hand) {
      const def = CARD[c.id];
      const ts = def.target === 'none' ? [null] : def.target === 'ally' ? [0, 1] : def.id === 'rg_trip' ? [0, 1] : [0, 1, TOWER];
      for (const t of ts) tryA({ type: 'card', uid: c.uid, target: t });
    }
    return out;
  }

  // 今の攻撃に対してできる対応を全部挙げる
  function responses(state, q) {
    const out = [];
    for (const c of state.players[q].hand) {
      const def = CARD[c.id];
      if (!def.resp) continue;
      for (const t of def.target === 'ally' ? [0, 1] : [null]) { const r = { uid: c.uid, target: t }; if (!checkResponse(state, q, r)) out.push(r); }
    }
    return out;
  }

  // ── CPU ──
  function clone(state) {
    const s = JSON.parse(JSON.stringify({ ...state, nextUid: undefined, rng: undefined, steps: undefined, log: undefined, _hits: undefined }));
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
      let v = pl.tower * 3 + Math.min(pl.hand.length, HAND_MAX - 2) * 0.4;
      if (!pl.heroes.some((h) => !h.ko && h.pos === 'front')) v -= threat * 1.5;
      pl.heroes.forEach((h) => {
        if (h.ko) { v -= 10; return; }
        v += h.hp + h.shield * 0.7;
        if (h.pos === 'front' && h.hp + h.shield <= threat) v -= 6;
      });
      return v;
    };
    return side(p) - side(o);
  }

  // 攻撃を処理しきった結果（相手は対応しない、と仮定）
  function simulate(state, p, a) {
    const s = clone(state);
    const r = act(s, p, a);
    if (r.waiting) respond(s, 1 - p, null);
    return s;
  }

  // 対応カードを持っているなら、そのコストぶんのマナを相手のターンに残す価値
  function reserve(s, p) {
    const pl = s.players[p];
    const need = pl.hand.filter((c) => CARD[c.id].resp).map((c) => CARD[c.id].cost).sort((a, b) => a - b)[0];
    return need != null && pl.mana >= need ? 2.5 : 0;
  }

  // 次の行動を1つ選ぶ。良くなる行動がなければ null（ターン終了）
  function cpuAction(state, p, rng) {
    rng = rng || Math.random;
    const base = value(state, p) + reserve(state, p);
    let best = null, bestV = base + 0.3;
    for (const a of actions(state, p)) {
      const s = simulate(state, p, a);
      const v = value(s, p) + reserve(s, p) + rng() * 0.3;
      if (v > bestV) { bestV = v; best = a; }
    }
    return best;
  }

  // 相手の攻撃への対応を選ぶ。対応しないなら null
  function cpuResponse(state, q, rng) {
    rng = rng || Math.random;
    const run = (resp) => { const s = clone(state); respond(s, q, resp); return value(s, q); };
    let best = null, bestV = run(null) + 0.5; // 少しでも得なら使う
    for (const r of responses(state, q)) {
      const v = run(r) + rng() * 0.3;
      if (v > bestV) { bestV = v; best = r; }
    }
    return best;
  }

  const CPU_TEAMS = [
    { label: '剣士と聖女', heroes: ['sword', 'saint'], front: 0 },
    { label: '守護騎士と魔術師', heroes: ['knight', 'mage'], front: 0 },
    { label: '盗賊と剣士', heroes: ['rogue', 'sword'], front: 0 },
    { label: '魔術師と聖女', heroes: ['mage', 'saint'], front: 1 },
    { label: '守護騎士と盗賊', heroes: ['knight', 'rogue'], front: 0 },
  ];

  const api = {
    MAX_ROUND, HAND_MAX, MANA_MAX, TOWER, TOWER_HP, TOWER_COUNTER, HEROES, HERO, CARDS, CARD, POS_NAME, CPU_TEAMS,
    FRONT_CARDS, REVIVE_WAIT, validateTeam, newGame, view, towerDefended, check, checkCard, checkResponse, act, respond, endTurn, actions, responses,
    cpuAction, cpuResponse, cardHero,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.Engine = api;
})(typeof self !== 'undefined' ? self : this);
