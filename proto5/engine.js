// 五枚決闘 ルールエンジン（ブラウザ・Node 共用、DOM 非依存）
// 交互ターン制。自分のターンに「カード1枚まで・起動能力・攻撃」を行い、相手に渡す
(function (root) {
  'use strict';

  const MAX_ROUND = 10;
  const START_LIFE = 15;
  const DECK_SIZE = 5;

  const COLOR_NAME = { red: '赤', blue: '青', none: '無色' };

  // type: creature | spell
  // target: lane = 相手側のレーンを 1 つ選ぶ / none = 対象なし
  // keywords: flying 飛行（飛行のないクリーチャーにはブロックされない）/ trample 貫通 / haste 速攻（出したターンから攻撃できる）
  // ab: 起動能力。1 体につき 1 ターン 1 回。tap = 使うと「休む」（攻撃できず、次の相手のターンにブロックもできない）
  //   target: enemyLane = 相手側のレーン / adjacent = 自陣の隣のレーン / none
  const CARDS = [
    // ── 赤：攻め・火力 ──
    { id: 'imp', name: '火の小鬼', color: 'red', cost: 1, type: 'creature', power: 2, toughness: 1, keywords: ['haste'], text: '速攻' },
    { id: 'warcry', name: '鬨の声', color: 'red', cost: 1, type: 'spell', target: 'none', text: 'このターン、自分のクリーチャー全体のパワー+2。' },
    { id: 'fireball', name: '火球', color: 'red', cost: 2, type: 'spell', target: 'lane', text: '選んだレーンの相手クリーチャーに3ダメージ。いなければ相手に2ダメージ。' },
    { id: 'berserker', name: '溶岩の狂戦士', color: 'red', cost: 3, type: 'creature', power: 4, toughness: 2, keywords: ['trample'], text: '貫通' },
    { id: 'firerain', name: '炎の雨', color: 'red', cost: 4, type: 'spell', target: 'none', text: '相手のクリーチャー全体に2ダメージ。' },
    { id: 'salamander', name: '火吹きトカゲ', color: 'red', cost: 2, type: 'creature', power: 2, toughness: 2, ab: { kind: 'breath', tap: true, cost: 2, target: 'none', text: '向かいの相手クリーチャーに2ダメージ。' } },
    { id: 'bladedancer', name: '炎の剣士', color: 'red', cost: 3, type: 'creature', power: 3, toughness: 2, ab: { kind: 'pump', cost: 1, target: 'none', text: 'このターン、パワー+2。' } },
    { id: 'dragon', name: '紅蓮の竜', color: 'red', cost: 5, type: 'creature', power: 5, toughness: 4, keywords: ['flying'], text: '飛行' },
    // ── 青：妨害・飛行 ──
    { id: 'sprite', name: '霧の精', color: 'blue', cost: 1, type: 'creature', power: 1, toughness: 2, keywords: ['flying'], text: '飛行' },
    { id: 'seal', name: '封じの言葉', color: 'blue', cost: 2, type: 'spell', target: 'none', text: '罠を張る。次の相手のターン、相手が最初に出すカードを打ち消す。' },
    { id: 'tidecaller', name: '潮の術師', color: 'blue', cost: 2, type: 'creature', power: 2, toughness: 2, etb: 'bounceFront', text: '登場時、向かいの相手クリーチャーを手札に戻す。' },
    { id: 'whirlpool', name: '渦潮', color: 'blue', cost: 3, type: 'spell', target: 'lane', text: '選んだレーンの相手クリーチャーを手札に戻す。' },
    { id: 'scout', name: '風読みの斥候', color: 'blue', cost: 2, type: 'creature', power: 1, toughness: 3, keywords: ['flying'], text: '飛行', ab: { kind: 'move', cost: 1, target: 'adjacent', text: '隣の空いている自陣レーンへ移る。' } },
    { id: 'tidesage', name: '潮見の賢者', color: 'blue', cost: 4, type: 'creature', power: 1, toughness: 4, ab: { kind: 'bounce', tap: true, cost: 4, target: 'enemyLane', text: '選んだレーンの相手クリーチャーを手札に戻す。' } },
    { id: 'skywhale', name: '空鯨', color: 'blue', cost: 4, type: 'creature', power: 3, toughness: 5, keywords: ['flying'], text: '飛行' },
    { id: 'archmage', name: '嵐の大魔導', color: 'blue', cost: 5, type: 'creature', power: 3, toughness: 3, keywords: ['flying'], etb: 'discard', text: '飛行。登場時、相手の手札を1枚ランダムに捨てさせる。' },
    // ── 無色 ──
    { id: 'mercenary', name: '傭兵', color: 'none', cost: 2, type: 'creature', power: 2, toughness: 3, text: '' },
    { id: 'slinger', name: '投石兵', color: 'none', cost: 2, type: 'creature', power: 1, toughness: 2, ab: { kind: 'shoot', tap: true, cost: 2, target: 'enemyLane', text: '選んだレーンの相手クリーチャーに1ダメージ。' } },
    { id: 'golem', name: '石のゴーレム', color: 'none', cost: 3, type: 'creature', power: 3, toughness: 3, text: '' },
    { id: 'colossus', name: '鉄の巨兵', color: 'none', cost: 4, type: 'creature', power: 4, toughness: 4, text: '' },
    { id: 'catapult', name: '攻城弩', color: 'none', cost: 4, type: 'creature', power: 0, toughness: 4, ab: { kind: 'siege', tap: true, cost: 3, target: 'none', text: '相手に2ダメージ。' } },
  ];
  for (const c of CARDS) {
    if (c.ab) c.text = [c.text, `【${c.ab.cost}${c.ab.tap ? '・休む' : ''}】${c.ab.text}`].filter(Boolean).join('。');
  }
  const CARD = Object.fromEntries(CARDS.map((c) => [c.id, c]));

  // 地形は自陣側の各レーンに 1 つずつ置く。効果は基本的に自陣側にだけ働く
  const TERRAINS = [
    { id: 'plain', name: '平原', icon: '🌾', text: '効果なし。' },
    { id: 'volcano', name: '火山', icon: '🌋', text: 'ここの自分の赤クリーチャーはパワー+1。' },
    { id: 'lake', name: '霧の湖', icon: '🌫️', text: 'ここの自分の青クリーチャーが受ける戦闘ダメージ−1。' },
    { id: 'wall', name: '城壁', icon: '🧱', text: 'このレーンから自分が受けるダメージ−1。' },
    { id: 'altar', name: '祭壇', icon: '🕯️', text: 'ここで自分のクリーチャーが死ぬと、自分のライフ+2。' },
    { id: 'swamp', name: '沼地', icon: '🪷', text: '向かいに出た相手のクリーチャーは−1/−1。' },
    { id: 'tower', name: '見張り塔', icon: '🗼', text: 'ここに自分のクリーチャーを出すと、相手の手札を1枚ランダムに見る。' },
  ];
  const TERRAIN = Object.fromEntries(TERRAINS.map((t) => [t.id, t]));

  const LANE_NAME = ['左', '中', '右'];

  // ── デッキ ──
  // deck = { main: 'red'|'blue', sub: null|'red'|'blue', cards: [id x5], terrains: [id x3] }
  function validateDeck(deck) {
    const errs = [];
    if (!deck.main || !COLOR_NAME[deck.main] || deck.main === 'none') errs.push('主属性を選んでください');
    if (deck.sub && deck.sub === deck.main) errs.push('副属性は主属性と別にしてください');
    if (!deck.cards || deck.cards.length !== DECK_SIZE) errs.push(`カードを${DECK_SIZE}枚選んでください`);
    if (new Set(deck.cards || []).size !== (deck.cards || []).length) errs.push('同じカードは1枚まで');
    for (const id of deck.cards || []) {
      const c = CARD[id];
      if (!c) errs.push(`不明なカード: ${id}`);
      else if (c.color !== 'none' && c.color !== deck.main && c.color !== deck.sub) errs.push(`${c.name} は属性が合いません`);
    }
    if (!deck.terrains || deck.terrains.length !== 3 || deck.terrains.some((t) => !TERRAIN[t])) errs.push('地形を3つ選んでください');
    else if (new Set(deck.terrains).size !== 3) errs.push('同じ地形は1つまで');
    return errs;
  }

  function costFor(deck, id) {
    const c = CARD[id];
    return c.cost + (deck.sub && c.color === deck.sub ? 1 : 0);
  }

  function shuffle(a, rng) {
    rng = rng || Math.random;
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  // ── 状態 ──
  // first: 先攻のプレイヤー（0 | 1）。省略するとランダム
  function newGame(decks, names, rng, first) {
    rng = rng || Math.random;
    let uid = 1;
    const state = {
      round: 1,
      first: first ?? (rng() < 0.5 ? 0 : 1),
      active: 0,
      mana: 0,
      cardPlayed: false,
      over: false,
      winner: null, // 0 | 1 | 'draw'
      endReason: '',
      log: [],
      steps: [],
      buff: [0, 0],
      players: decks.map((deck, i) => ({
        name: names[i],
        deck,
        life: START_LIFE,
        hand: shuffle(deck.cards.slice(), rng),
        grave: [],
        terrains: deck.terrains.slice(),
        board: [null, null, null],
        seen: [], // 見張り塔で見た相手の手札
        trap: null, // 'seal' = 封じの言葉の罠
      })),
      nextUid() { return uid++; },
      rng,
    };
    state.active = state.first;
    begin(state);
    startTurn(state);
    return state;
  }

  function has(cr, kw) { return (CARD[cr.id].keywords || []).includes(kw); }

  function powerOf(state, p, lane) {
    const cr = state.players[p].board[lane];
    if (!cr) return 0;
    let pw = cr.power + state.buff[p] + (cr.tmp || 0);
    if (state.players[p].terrains[lane] === 'volcano' && CARD[cr.id].color === 'red') pw += 1;
    return Math.max(0, pw);
  }

  function makeCreature(state, id) {
    const c = CARD[id];
    return { uid: state.nextUid(), id, power: c.power, toughness: c.toughness, hp: c.toughness, sick: !(c.keywords || []).includes('haste'), tapped: false, used: false, tmp: 0 };
  }

  // ── 演出用の記録 ──
  // 行動ごとに begin() で記録を始め、処理の区切りで step() を呼ぶ
  function begin(state) {
    state.log = [];
    state.steps = [];
    state._hits = [];
    state._lanes = new Set();
    state._logAt = 0;
  }

  function mark(state, hit) {
    state._hits.push(hit);
    if (hit.l != null) state._lanes.add(hit.l);
  }

  function view(state) {
    return {
      round: state.round,
      active: state.active,
      mana: state.mana,
      players: state.players.map((pl, p) => ({
        life: pl.life,
        handCount: pl.hand.length,
        trap: pl.trap,
        board: pl.board.map((cr, l) => cr && { id: cr.id, pw: powerOf(state, p, l), hp: cr.hp, toughness: cr.toughness, sick: cr.sick, tapped: cr.tapped, used: cr.used }),
      })),
    };
  }

  function step(state, title, force) {
    const lines = state.log.slice(state._logAt);
    if (!lines.length && !state._hits.length && !force) { state._lanes = new Set(); return; }
    state._logAt = state.log.length;
    state.steps.push({ title, lines, hits: state._hits, lanes: [...state._lanes], view: view(state) });
    state._hits = [];
    state._lanes = new Set();
  }

  function damagePlayer(state, p, n, lane, src) {
    let d = n;
    if (lane != null && state.players[p].terrains[lane] === 'wall') d = Math.max(0, d - 1);
    state.players[p].life -= d;
    mark(state, { p, l: null, n: -d });
    if (lane != null) state._lanes.add(lane);
    state.log.push(`${src} → ${state.players[p].name}に${d}ダメージ${d < n ? '（城壁で軽減）' : ''}`);
  }

  function damageCreature(state, p, lane, n, src) {
    const cr = state.players[p].board[lane];
    if (!cr) return;
    cr.hp -= n;
    mark(state, { p, l: lane, n: -n });
    state.log.push(`${src} → ${state.players[p].name}の${CARD[cr.id].name}に${n}ダメージ`);
  }

  function bounce(state, p, lane, src) {
    const cr = state.players[p].board[lane];
    if (!cr) return false;
    state.players[p].board[lane] = null;
    state.players[p].hand.push(cr.id);
    mark(state, { p, l: lane, label: '手札へ' });
    state.log.push(`${src} → ${state.players[p].name}の${CARD[cr.id].name}を手札に戻した`);
    return true;
  }

  function reapDeaths(state) {
    for (let p = 0; p < 2; p++) {
      const pl = state.players[p];
      for (let l = 0; l < 3; l++) {
        const cr = pl.board[l];
        if (cr && cr.hp <= 0) {
          pl.board[l] = null;
          pl.grave.push(cr.id);
          mark(state, { p, l, label: '撃破' });
          state.log.push(`${pl.name}の${CARD[cr.id].name}は倒れた`);
          if (pl.terrains[l] === 'altar') {
            pl.life += 2;
            mark(state, { p, l: null, n: 2 });
            state.log.push(`祭壇 → ${pl.name}のライフ+2`);
          }
        }
      }
    }
  }

  function checkOver(state) {
    if (state.over) return true;
    const dead = state.players.map((pl) => pl.life <= 0);
    if (dead[0] || dead[1]) finish(state, dead[0] && dead[1] ? 'どちらもライフが尽きた' : 'ライフが尽きた');
    return state.over;
  }

  // ── ターン ──
  function startTurn(state) {
    const p = state.active;
    const pl = state.players[p];
    state.mana = state.round;
    state.cardPlayed = false;
    state.buff = [0, 0];
    for (const cr of pl.board) if (cr) { cr.sick = false; cr.tapped = false; cr.used = false; cr.tmp = 0; }
    state.log.push(`${pl.name}のターン（ラウンド${state.round}・マナ${state.mana}）`);
    if (pl.trap) {
      state.log.push(`${pl.name}の封じの言葉は、何も打ち消さずに消えた`);
      pl.trap = null;
    }
    step(state, `${pl.name}のターン`, true);
  }

  // 攻撃のあとに呼ぶ。相手のターンを始める
  function endTurn(state) {
    if (state.over) return;
    begin(state);
    for (const pl of state.players) for (const cr of pl.board) if (cr) cr.tmp = 0;
    state.buff = [0, 0];
    state.active = 1 - state.active;
    if (state.active === state.first) state.round++;
    if (state.round > MAX_ROUND) {
      finish(state, `${MAX_ROUND}ラウンド終了`);
      return;
    }
    startTurn(state);
  }

  // ── カードを出す ──
  function needsLane(id) { const c = CARD[id]; return c.type === 'creature' || c.target === 'lane'; }

  function canPlay(state, p, id, lane) {
    const pl = state.players[p];
    if (state.over || state.active !== p) return '自分のターンではない';
    if (state.cardPlayed) return 'カードはこのターンもう出した';
    if (!pl.hand.includes(id)) return '手札にないカード';
    if (costFor(pl.deck, id) > state.mana) return 'マナが足りない';
    if (needsLane(id) ? !(lane >= 0 && lane < 3) : lane != null) return 'レーンの指定が不正';
    return null;
  }

  function playCard(state, p, id, lane) {
    begin(state);
    const err = canPlay(state, p, id, needsLane(id) ? lane : null);
    if (err) return err;
    const P = state.players, o = 1 - p, pl = P[p], c = CARD[id];
    pl.hand.splice(pl.hand.indexOf(id), 1);
    state.mana -= costFor(pl.deck, id);
    state.cardPlayed = true;
    if (c.target === 'lane' || c.type === 'creature') state._lanes.add(lane);
    state.log.push(`${pl.name}：${c.name}${needsLane(id) ? `（${LANE_NAME[lane]}）` : ''}`);
    step(state, `${pl.name}：${c.name}`, true);

    if (P[o].trap === 'seal') {
      P[o].trap = null;
      pl.grave.push(id);
      mark(state, { p, l: null, label: '打ち消し', card: true });
      state.log.push(`封じの言葉の罠 → ${c.name}は打ち消された`);
      step(state, '罠：封じの言葉', true);
      return null;
    }

    if (c.type === 'spell') {
      switch (id) {
        case 'warcry': state.buff[p] += 2; state.log.push(`${c.name} → ${pl.name}のクリーチャーはこのターン、パワー+2`); for (let l = 0; l < 3; l++) if (pl.board[l]) mark(state, { p, l, label: 'パワー+2' }); break;
        case 'fireball':
          if (P[o].board[lane]) damageCreature(state, o, lane, 3, c.name);
          else damagePlayer(state, o, 2, null, c.name);
          state._lanes.add(lane);
          break;
        case 'firerain':
          for (let l = 0; l < 3; l++) if (P[o].board[l]) damageCreature(state, o, l, 2, c.name);
          break;
        case 'whirlpool':
          if (!bounce(state, o, lane, c.name)) state.log.push(`${c.name} → 対象がいなかった`);
          state._lanes.add(lane);
          break;
        case 'seal':
          pl.trap = 'seal';
          mark(state, { p, l: null, label: '罠を張った', card: true });
          state.log.push(`${pl.name}は罠を張った。次の相手のターン、相手が最初に出すカードを打ち消す`);
          break;
      }
      pl.grave.push(id);
      step(state, `呪文：${c.name}`, true);
      reapDeaths(state);
      step(state, '撃破');
      checkOver(state);
      return null;
    }

    // クリーチャー
    const old = pl.board[lane];
    if (old) {
      pl.grave.push(old.id);
      state.log.push(`${pl.name}の${CARD[old.id].name}は入れ替わりで退場`);
    }
    const cr = makeCreature(state, id);
    pl.board[lane] = cr;
    mark(state, { p, l: lane, label: '登場' });
    state.log.push(`${c.name}が${LANE_NAME[lane]}レーンに登場${cr.sick ? '' : '（速攻：すぐ攻撃できる）'}`);
    step(state, '登場', true);
    if (c.etb === 'bounceFront') {
      if (!bounce(state, o, lane, c.name)) state.log.push(`${c.name} → 向かいに相手がいなかった`);
      state._lanes.add(lane);
      step(state, `登場時効果：${c.name}`, true);
    } else if (c.etb === 'discard') {
      if (P[o].hand.length) {
        const i = Math.floor(state.rng() * P[o].hand.length);
        const d = P[o].hand.splice(i, 1)[0];
        P[o].grave.push(d);
        mark(state, { p: o, l: null, label: '手札−1' });
        state.log.push(`${c.name} → ${P[o].name}は${CARD[d].name}を捨てた`);
      } else state.log.push(`${c.name} → 相手の手札がなかった`);
      step(state, `登場時効果：${c.name}`, true);
    }
    if (pl.board[lane] === cr && P[o].terrains[lane] === 'swamp') {
      cr.power -= 1; cr.toughness -= 1; cr.hp -= 1;
      mark(state, { p, l: lane, label: '−1/−1' });
      state.log.push(`沼地 → ${c.name}は−1/−1`);
      step(state, '地形：沼地');
    }
    if (pl.board[lane] === cr && pl.terrains[lane] === 'tower' && P[o].hand.length) {
      const s = P[o].hand[Math.floor(state.rng() * P[o].hand.length)];
      pl.seen.push(s);
      mark(state, { p, l: lane, label: '偵察' });
      state.log.push(`見張り塔 → ${pl.name}は相手の手札を1枚見た`);
      step(state, '地形：見張り塔');
    }
    reapDeaths(state);
    step(state, '撃破');
    checkOver(state);
    return null;
  }

  // ── 起動能力 ──
  function abTargets(ab, from) {
    if (ab.target === 'enemyLane') return [0, 1, 2];
    if (ab.target === 'adjacent') return [from - 1, from + 1].filter((l) => l >= 0 && l < 3);
    return [null];
  }

  function canActivate(state, p, from, target) {
    if (state.over || state.active !== p) return '自分のターンではない';
    const cr = state.players[p].board[from];
    if (!cr || !CARD[cr.id].ab) return '起動能力がない';
    const ab = CARD[cr.id].ab;
    if (cr.used) return 'このターンはもう使った';
    if (ab.tap && cr.sick) return '出したばかりで使えない';
    if (ab.tap && cr.tapped) return '休んでいる';
    if (ab.cost > state.mana) return 'マナが足りない';
    if (!abTargets(ab, from).includes(target ?? null)) return '対象が不正';
    if (ab.kind === 'move' && state.players[p].board[target]) return '移動先が埋まっている';
    return null;
  }

  function activate(state, p, from, target) {
    begin(state);
    const err = canActivate(state, p, from, target);
    if (err) return err;
    const P = state.players, o = 1 - p;
    const cr = P[p].board[from];
    const ab = CARD[cr.id].ab, name = CARD[cr.id].name;
    state.mana -= ab.cost;
    cr.used = true;
    if (ab.tap) cr.tapped = true;
    state._lanes.add(from);
    switch (ab.kind) {
      case 'shoot':
        if (P[o].board[target]) damageCreature(state, o, target, 1, name);
        else state.log.push(`${name} → ${LANE_NAME[target]}レーンに相手がいなかった`);
        state._lanes.add(target);
        break;
      case 'breath':
        if (P[o].board[from]) damageCreature(state, o, from, 2, name);
        else state.log.push(`${name} → 向かいに相手がいなかった`);
        break;
      case 'pump':
        cr.tmp += 2;
        mark(state, { p, l: from, label: 'パワー+2' });
        state.log.push(`${name} → このターン、パワー+2`);
        break;
      case 'bounce':
        if (!bounce(state, o, target, name)) state.log.push(`${name} → ${LANE_NAME[target]}レーンに相手がいなかった`);
        state._lanes.add(target);
        break;
      case 'siege':
        damagePlayer(state, o, 2, null, name);
        break;
      case 'move':
        P[p].board[from] = null;
        P[p].board[target] = cr;
        mark(state, { p, l: target, label: '移動' });
        state._lanes.add(target);
        state.log.push(`${name} → ${LANE_NAME[target]}レーンへ移った`);
        break;
    }
    if (ab.tap) mark(state, { p, l: ab.kind === 'move' ? target : from, label: '休む' });
    step(state, `起動：${name}`, true);
    reapDeaths(state);
    step(state, '撃破');
    checkOver(state);
    return null;
  }

  // ── 攻撃 ──
  function canAttackWith(state, p, l) {
    const cr = state.players[p].board[l];
    return !!cr && !cr.sick && !cr.tapped && powerOf(state, p, l) > 0;
  }

  function canBlock(attacker, blocker) {
    if (!blocker || blocker.tapped) return false;
    return !has(attacker, 'flying') || has(blocker, 'flying');
  }

  // attackers: 攻撃させるレーンの配列。攻撃したクリーチャーは「休む」
  function attack(state, p, attackers) {
    begin(state);
    if (state.over || state.active !== p) return '自分のターンではない';
    const P = state.players, o = 1 - p;
    const list = [0, 1, 2].filter((l) => attackers.includes(l) && canAttackWith(state, p, l));
    if (!list.length) {
      state.log.push(`${P[p].name}は攻撃しなかった`);
      step(state, '攻撃なし', true);
      return null;
    }
    state.log.push(`${P[p].name}の攻撃：${list.map((l) => `${CARD[P[p].board[l].id].name}（${LANE_NAME[l]}）`).join('、')}`);
    for (const l of list) { P[p].board[l].tapped = true; mark(state, { p, l, label: '攻撃' }); }
    step(state, '攻撃宣言', true);
    for (const l of list) {
      const a = P[p].board[l];
      if (!a) continue;
      const pw = powerOf(state, p, l);
      const b = P[o].board[l];
      if (canBlock(a, b)) {
        const bpw = powerOf(state, o, l);
        let toB = pw, toA = bpw;
        if (P[o].terrains[l] === 'lake' && CARD[b.id].color === 'blue') toB = Math.max(0, toB - 1);
        if (P[p].terrains[l] === 'lake' && CARD[a.id].color === 'blue') toA = Math.max(0, toA - 1);
        state.log.push(`${CARD[b.id].name}がブロック`);
        const excess = has(a, 'trample') ? Math.max(0, pw - b.hp) : 0;
        if (toB > 0) damageCreature(state, o, l, toB, CARD[a.id].name);
        if (toA > 0) damageCreature(state, p, l, toA, CARD[b.id].name);
        if (excess > 0) damagePlayer(state, o, excess, l, `${CARD[a.id].name}（貫通）`);
      } else {
        const why = b ? (b.tapped ? '（相手は休んでいてブロックできない）' : '（飛行はブロックされない）') : '';
        if (why) state.log.push(`${CARD[a.id].name}${why}`);
        damagePlayer(state, o, pw, l, CARD[a.id].name);
      }
      state._lanes.add(l);
      step(state, `戦闘：${LANE_NAME[l]}レーン`, true);
      reapDeaths(state);
      state._lanes.add(l);
      step(state, `戦闘：${LANE_NAME[l]}レーン`);
      if (checkOver(state)) break;
    }
    return null;
  }

  // ── 勝敗 ──
  function boardPower(state, p) {
    let s = 0;
    for (let l = 0; l < 3; l++) { const cr = state.players[p].board[l]; if (cr) s += cr.power + (state.players[p].terrains[l] === 'volcano' && CARD[cr.id].color === 'red' ? 1 : 0); }
    return s;
  }

  function finish(state, reason) {
    const P = state.players;
    state.over = true;
    if (P[0].life !== P[1].life) {
      state.winner = P[0].life > P[1].life ? 0 : 1;
      state.endReason = `${reason}：ライフ ${P[0].life} 対 ${P[1].life}`;
    } else {
      const a = boardPower(state, 0), b = boardPower(state, 1);
      if (a !== b) {
        state.winner = a > b ? 0 : 1;
        state.endReason = `${reason}：ライフ同点、盤面のパワー ${a} 対 ${b}`;
      } else {
        state.winner = 'draw';
        state.endReason = `${reason}：ライフも盤面のパワーも同じ`;
      }
    }
  }

  // ── CPU ──
  function clone(state) {
    const s = JSON.parse(JSON.stringify({ ...state, nextUid: undefined, rng: undefined, steps: undefined, log: undefined, _lanes: undefined, _hits: undefined }));
    let uid = 100000;
    s.nextUid = () => uid++;
    s.rng = () => 0.5;
    s.steps = []; s.log = [];
    return s;
  }

  function staticValue(s, p) {
    const o = 1 - p;
    if (s.over) return s.winner === p ? 1000 : s.winner === o ? -1000 : 0;
    const P = s.players;
    let v = (P[p].life - P[o].life) * 3;
    for (let l = 0; l < 3; l++) {
      const a = P[p].board[l], b = P[o].board[l];
      if (a) v += a.power * 1.5 + a.hp;
      if (b) v -= b.power * 1.5 + b.hp;
    }
    if (P[p].trap) v += 2;
    return v;
  }

  // 自分のターンを終えたあと、相手が全員で殴り返してきた場合の盤面で評価する
  function evaluate(s, p) {
    if (s.over) return staticValue(s, p);
    const t = clone(s);
    endTurn(t);
    if (!t.over) attack(t, 1 - p, [0, 1, 2]);
    return staticValue(t, p);
  }

  function bestAttack(s, p) {
    const lanes = [0, 1, 2].filter((l) => canAttackWith(s, p, l));
    let best = { set: [], v: -Infinity };
    for (let mask = 0; mask < 1 << lanes.length; mask++) {
      const set = lanes.filter((_, i) => mask & (1 << i));
      const t = clone(s);
      attack(t, p, set);
      const v = evaluate(t, p);
      if (v > best.v) best = { set, v };
    }
    return best;
  }

  // CPU の 1 ターン分の計画：{ card: { id, lane } | null, acts: [{ from, target }], attackers: [レーン] }
  function cpuPlan(state, p, rng) {
    rng = rng || Math.random;
    const pl = state.players[p];
    const cards = [null];
    for (const id of new Set(pl.hand)) {
      for (const lane of needsLane(id) ? [0, 1, 2] : [null]) if (!canPlay(state, p, id, lane)) cards.push({ id, lane });
    }
    let best = null;
    for (const card of cards) {
      let s = clone(state);
      if (card) playCard(s, p, card.id, card.lane);
      const acts = [];
      let cur = bestAttack(s, p);
      // 起動能力を良くなる限り足す
      for (let l = 0; l < 3; l++) {
        const cr = s.players[p].board[l];
        if (!cr || !CARD[cr.id].ab) continue;
        let pick = null;
        for (const t of abTargets(CARD[cr.id].ab, l)) {
          if (canActivate(s, p, l, t)) continue;
          const s2 = clone(s);
          activate(s2, p, l, t);
          const r = bestAttack(s2, p);
          if (r.v > cur.v + 0.3 && (!pick || r.v > pick.r.v)) pick = { s2, r, t };
        }
        if (pick) { s = pick.s2; cur = pick.r; acts.push({ from: l, target: pick.t }); }
      }
      let v = cur.v;
      if (card && card.id === 'seal') v += state.players[1 - p].hand.length ? 2 : -5;
      v += rng() * 1.2;
      if (!best || v > best.v) best = { v, card, acts, attackers: cur.set };
    }
    return { card: best.card, acts: best.acts, attackers: best.attackers };
  }

  // CPU の 1 ターンを実行し、そのターンの全段階を返す（ターン終了は含まない）
  function cpuTurn(state, p, rng) {
    const plan = cpuPlan(state, p, rng);
    const steps = [];
    if (plan.card) { playCard(state, p, plan.card.id, plan.card.lane); steps.push(...state.steps); }
    for (const a of plan.acts) {
      if (state.over) break;
      // 移動などで位置が変わることがあるので、実行できるものだけ
      if (!canActivate(state, p, a.from, a.target)) { activate(state, p, a.from, a.target); steps.push(...state.steps); }
    }
    if (!state.over) { attack(state, p, plan.attackers); steps.push(...state.steps); }
    return steps;
  }

  const CPU_DECKS = [
    { label: '赤単・速攻', main: 'red', sub: null, cards: ['imp', 'fireball', 'berserker', 'colossus', 'dragon'], terrains: ['volcano', 'swamp', 'plain'] },
    { label: '青単・制圧', main: 'blue', sub: null, cards: ['sprite', 'tidecaller', 'seal', 'skywhale', 'archmage'], terrains: ['lake', 'tower', 'wall'] },
    { label: '赤青・火力', main: 'red', sub: 'blue', cards: ['imp', 'fireball', 'golem', 'seal', 'dragon'], terrains: ['volcano', 'altar', 'wall'] },
    { label: '青赤・空軍', main: 'blue', sub: 'red', cards: ['sprite', 'mercenary', 'whirlpool', 'skywhale', 'firerain'], terrains: ['swamp', 'lake', 'altar'] },
    { label: '赤単・砲台', main: 'red', sub: null, cards: ['salamander', 'slinger', 'bladedancer', 'catapult', 'dragon'], terrains: ['volcano', 'wall', 'altar'] },
    { label: '青単・遊撃', main: 'blue', sub: null, cards: ['scout', 'tidecaller', 'seal', 'tidesage', 'skywhale'], terrains: ['lake', 'tower', 'wall'] },
  ];

  const api = {
    MAX_ROUND, START_LIFE, DECK_SIZE, COLOR_NAME, CARDS, CARD, TERRAINS, TERRAIN, LANE_NAME, CPU_DECKS,
    validateDeck, costFor, newGame, needsLane, canPlay, playCard, abTargets, canActivate, activate,
    canAttackWith, canBlock, attack, endTurn, powerOf, boardPower, view, cpuPlan, cpuTurn,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.Engine = api;
})(typeof self !== 'undefined' ? self : this);
