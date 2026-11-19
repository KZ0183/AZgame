// 五枚決闘 ルールエンジン（ブラウザ・Node 共用、DOM 非依存）
(function (root) {
  'use strict';

  const MAX_TURN = 10;
  const START_LIFE = 10;
  const DECK_SIZE = 5;

  const COLOR_NAME = { red: '赤', blue: '青', none: '無色' };

  // type: creature | spell
  // target: lane = 相手側のレーンを 1 つ選ぶ / none = 対象なし
  // ab: 起動能力。1 体につき 1 ターン 1 回、マナを払って使う
  //   target: enemyLane = 相手側のレーン / adjacent = 自陣の隣のレーン / none
  const CARDS = [
    // ── 赤：攻め・火力 ──
    { id: 'imp', name: '火の小鬼', color: 'red', cost: 1, type: 'creature', power: 2, toughness: 1, text: '' },
    { id: 'warcry', name: '鬨の声', color: 'red', cost: 1, type: 'spell', target: 'none', text: 'このターン、自分のクリーチャー全体のパワー+2。' },
    { id: 'fireball', name: '火球', color: 'red', cost: 2, type: 'spell', target: 'lane', text: '選んだレーンの相手クリーチャーに3ダメージ。いなければ相手に2ダメージ。' },
    { id: 'berserker', name: '溶岩の狂戦士', color: 'red', cost: 3, type: 'creature', power: 4, toughness: 2, keywords: ['trample'], text: '貫通' },
    { id: 'firerain', name: '炎の雨', color: 'red', cost: 4, type: 'spell', target: 'none', text: '相手のクリーチャー全体に2ダメージ。' },
    { id: 'salamander', name: '火吹きトカゲ', color: 'red', cost: 2, type: 'creature', power: 2, toughness: 2, ab: { kind: 'breath', cost: 2, target: 'none', text: '向かいの相手クリーチャーに2ダメージ。' } },
    { id: 'bladedancer', name: '炎の剣士', color: 'red', cost: 3, type: 'creature', power: 3, toughness: 2, ab: { kind: 'pump', cost: 1, target: 'none', text: 'このターン、パワー+2。' } },
    { id: 'dragon', name: '紅蓮の竜', color: 'red', cost: 5, type: 'creature', power: 5, toughness: 4, keywords: ['flying'], text: '飛行' },
    // ── 青：妨害・飛行 ──
    { id: 'sprite', name: '霧の精', color: 'blue', cost: 1, type: 'creature', power: 1, toughness: 2, keywords: ['flying'], text: '飛行' },
    { id: 'seal', name: '封じの言葉', color: 'blue', cost: 2, type: 'spell', target: 'none', text: 'このターン相手が出したカードを打ち消す。' },
    { id: 'tidecaller', name: '潮の術師', color: 'blue', cost: 2, type: 'creature', power: 2, toughness: 2, etb: 'bounceFront', text: '登場時、向かいの相手クリーチャーを手札に戻す。' },
    { id: 'whirlpool', name: '渦潮', color: 'blue', cost: 3, type: 'spell', target: 'lane', text: '選んだレーンの相手クリーチャーを手札に戻す。' },
    { id: 'scout', name: '風読みの斥候', color: 'blue', cost: 2, type: 'creature', power: 1, toughness: 3, keywords: ['flying'], text: '飛行', ab: { kind: 'move', cost: 1, target: 'adjacent', text: '隣の空いている自陣レーンへ移る。' } },
    { id: 'tidesage', name: '潮見の賢者', color: 'blue', cost: 4, type: 'creature', power: 1, toughness: 4, ab: { kind: 'bounce', cost: 4, target: 'enemyLane', text: '選んだレーンの相手クリーチャーを手札に戻す。' } },
    { id: 'skywhale', name: '空鯨', color: 'blue', cost: 4, type: 'creature', power: 3, toughness: 5, keywords: ['flying'], text: '飛行' },
    { id: 'archmage', name: '嵐の大魔導', color: 'blue', cost: 5, type: 'creature', power: 3, toughness: 3, keywords: ['flying'], etb: 'discard', text: '飛行。登場時、相手の手札を1枚ランダムに捨てさせる。' },
    // ── 無色 ──
    { id: 'mercenary', name: '傭兵', color: 'none', cost: 2, type: 'creature', power: 2, toughness: 3, text: '' },
    { id: 'slinger', name: '投石兵', color: 'none', cost: 2, type: 'creature', power: 1, toughness: 2, ab: { kind: 'shoot', cost: 2, target: 'enemyLane', text: '選んだレーンの相手クリーチャーに1ダメージ。' } },
    { id: 'golem', name: '石のゴーレム', color: 'none', cost: 3, type: 'creature', power: 3, toughness: 3, text: '' },
    { id: 'colossus', name: '鉄の巨兵', color: 'none', cost: 4, type: 'creature', power: 4, toughness: 4, text: '' },
    { id: 'catapult', name: '攻城弩', color: 'none', cost: 4, type: 'creature', power: 0, toughness: 4, ab: { kind: 'siege', cost: 3, target: 'none', text: '相手に2ダメージ。' } },
  ];
  for (const c of CARDS) {
    if (c.ab) c.text = [c.text, `【${c.ab.cost}】${c.ab.text}`].filter(Boolean).join('。');
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

  // ── 状態 ──
  function newGame(decks, names, rng) {
    let uid = 1;
    const state = {
      turn: 1,
      over: false,
      winner: null, // 0 | 1 | 'draw'
      endReason: '',
      log: [],
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
      })),
      nextUid() { return uid++; },
      rng: rng || Math.random,
    };
    return state;
  }

  function shuffle(a, rng) {
    rng = rng || Math.random;
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  function mana(state) { return state.turn; }

  // move = { card: id | null, lane: 0..2 | null, acts: [{ from: 自陣レーン, target: レーン | null }] }
  // { pass: true } はカードも起動もしない手
  function normalize(m) {
    if (!m || m.pass) return { card: null, lane: null, acts: (m && m.acts) || [] };
    return { card: m.card || null, lane: m.lane ?? null, acts: m.acts || [] };
  }

  function abTargets(ab, from) {
    if (ab.target === 'enemyLane') return [0, 1, 2];
    if (ab.target === 'adjacent') return [from - 1, from + 1].filter((l) => l >= 0 && l < 3);
    return [null];
  }

  function moveCost(state, p, m) {
    const pl = state.players[p];
    let c = m.card ? costFor(pl.deck, m.card) : 0;
    for (const a of m.acts) { const cr = pl.board[a.from]; if (cr && CARD[cr.id].ab) c += CARD[cr.id].ab.cost; }
    return c;
  }

  // 手の正しさを調べる。問題なければ null、あれば理由
  function checkMove(state, p, move) {
    const m = normalize(move);
    const pl = state.players[p];
    if (m.card) {
      const c = CARD[m.card];
      if (!c || !pl.hand.includes(m.card)) return '手札にないカード';
      const needLane = c.type === 'creature' || c.target === 'lane';
      if (needLane ? !(m.lane >= 0 && m.lane < 3) : m.lane != null) return 'レーンの指定が不正';
    }
    const seen = new Set();
    for (const a of m.acts) {
      const cr = pl.board[a.from];
      if (!cr || !CARD[cr.id].ab) return '起動能力のないクリーチャー';
      if (seen.has(a.from)) return '同じクリーチャーは1ターンに1回まで';
      seen.add(a.from);
      if (!abTargets(CARD[cr.id].ab, a.from).includes(a.target ?? null)) return '起動能力の対象が不正';
    }
    if (moveCost(state, p, m) > mana(state)) return 'マナが足りない';
    return null;
  }

  // カードの出し方だけを列挙する（起動能力は含まない）
  function legalMoves(state, p) {
    const pl = state.players[p];
    const moves = [{ pass: true }];
    for (const id of new Set(pl.hand)) {
      const c = CARD[id];
      if (costFor(pl.deck, id) > mana(state)) continue;
      if (c.type === 'creature' || c.target === 'lane') {
        for (let l = 0; l < 3; l++) moves.push({ card: id, lane: l });
      } else {
        moves.push({ card: id, lane: null });
      }
    }
    return moves;
  }

  function isLegal(state, p, move) { return checkMove(state, p, move) === null; }

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
    return { uid: state.nextUid(), id, power: c.power, toughness: c.toughness, hp: c.toughness };
  }

  // ── 演出用の記録 ──
  // 処理の区切りごとに step() を呼ぶと、その時点の盤面・ログ・強調箇所が steps に積まれる
  function mark(state, hit) {
    state._hits.push(hit);
    if (hit.l != null) state._lanes.add(hit.l);
  }

  function view(state) {
    return {
      buff: state.buff.slice(),
      players: state.players.map((pl, p) => ({
        life: pl.life,
        handCount: pl.hand.length,
        board: pl.board.map((cr, l) => cr && { id: cr.id, pw: powerOf(state, p, l), hp: cr.hp, toughness: cr.toughness }),
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
    mark(state, { p, l: null, n: -d, from: lane });
    if (lane != null) state._lanes.add(lane);
    state.log.push(`${src} → ${state.players[p].name}に${d}ダメージ${d < n ? '（城壁で軽減）' : ''}`);
  }

  function damageCreature(state, p, lane, n, src) {
    const cr = state.players[p].board[lane];
    if (!cr) return;
    cr.hp -= n;
    mark(state, { p, l: lane, n: -n });
    state.log.push(`${src} → ${CARD[cr.id].name}に${n}ダメージ`);
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

  // 1 ターン解決。moves[0], moves[1] は同時に公開される
  function resolveTurn(state, moves) {
    if (state.over) return;
    const P = state.players;
    state.log = [];
    state.steps = [];
    state._hits = [];
    state._lanes = new Set();
    state._logAt = 0;
    state.buff = [0, 0];
    const played = [null, null];

    // 1. 公開・コスト支払い（手札から取り除く）
    const acts = [[], []];
    for (let p = 0; p < 2; p++) {
      let m = normalize(moves[p]);
      if (checkMove(state, p, m)) m = normalize(null);
      if (m.card) {
        P[p].hand.splice(P[p].hand.indexOf(m.card), 1);
        played[p] = m;
        if (m.lane != null) state._lanes.add(m.lane);
        const where = m.lane != null ? `（${LANE_NAME[m.lane]}）` : '';
        state.log.push(`${P[p].name}：${CARD[m.card].name}${where}`);
      } else {
        state.log.push(`${P[p].name}：カードなし`);
      }
      // 起動するクリーチャーは公開の時点で決まる。あとで入れ替わったり戻されたりしたら不発
      for (const a of m.acts) {
        const cr = P[p].board[a.from];
        acts[p].push({ uid: cr.uid, id: cr.id, from: a.from, target: a.target ?? null });
        state.log.push(`${P[p].name}：起動 ${CARD[cr.id].name}${a.target != null ? `→${LANE_NAME[a.target]}` : ''}`);
      }
    }
    state.revealed = [0, 1].map((p) => ({
      card: played[p] && played[p].card, lane: played[p] && played[p].lane,
      acts: acts[p].map((a) => ({ id: a.id, from: a.from, target: a.target })),
    }));
    step(state, '公開', true);

    // 2. 打ち消し（同時に処理。お互いに打ち消し合うこともある）
    const countered = [false, false];
    for (let p = 0; p < 2; p++) {
      if (played[p] && played[p].card === 'seal' && played[1 - p]) countered[1 - p] = true;
    }
    for (let p = 0; p < 2; p++) {
      if (countered[p]) {
        state.log.push(`封じの言葉 → ${P[p].name}の${CARD[played[p].card].name}を打ち消した`);
        mark(state, { p, l: null, label: '打ち消し', card: true });
        P[p].grave.push(played[p].card);
        played[p] = null;
      }
    }
    step(state, '打ち消し');

    // 3. 呪文
    for (let p = 0; p < 2; p++) {
      const m = played[p];
      if (!m || CARD[m.card].type !== 'spell') continue;
      const o = 1 - p;
      const name = CARD[m.card].name;
      switch (m.card) {
        case 'warcry': state.buff[p] += 2; state.log.push(`${name} → ${P[p].name}のクリーチャーはパワー+2`); mark(state, { p, l: null, label: 'パワー+2', card: true }); break;
        case 'fireball':
          if (P[o].board[m.lane]) damageCreature(state, o, m.lane, 3, name);
          else damagePlayer(state, o, 2, null, name);
          state._lanes.add(m.lane);
          break;
        case 'firerain':
          for (let l = 0; l < 3; l++) if (P[o].board[l]) damageCreature(state, o, l, 2, name);
          break;
        case 'whirlpool':
          if (!bounce(state, o, m.lane, name)) state.log.push(`${name} → 対象がいなかった`);
          state._lanes.add(m.lane);
          break;
        case 'seal': if (!countered[o]) state.log.push(`${name} → 打ち消す相手がいなかった`); break;
      }
      P[p].grave.push(m.card);
      step(state, `呪文：${name}`, !(m.card === 'seal' && countered[o]));
      reapDeaths(state);
      step(state, '撃破');
    }

    // 4. クリーチャー登場
    const entered = [];
    for (let p = 0; p < 2; p++) {
      const m = played[p];
      if (!m || CARD[m.card].type !== 'creature') continue;
      const old = P[p].board[m.lane];
      if (old) {
        P[p].grave.push(old.id);
        state.log.push(`${P[p].name}の${CARD[old.id].name}は入れ替わりで退場`);
      }
      const cr = makeCreature(state, m.card);
      P[p].board[m.lane] = cr;
      mark(state, { p, l: m.lane, label: '登場' });
      state.log.push(`${P[p].name}の${CARD[m.card].name}が${LANE_NAME[m.lane]}レーンに登場`);
      entered.push({ p, lane: m.lane, cr });
    }
    step(state, '登場');
    // 登場時効果・地形効果（同時に出たものは、片方が先に戻されても両方の効果が出る）
    for (const { p, lane, cr } of entered) {
      const o = 1 - p;
      const c = CARD[cr.id];
      if (c.etb === 'bounceFront') {
        if (!bounce(state, o, lane, c.name)) state.log.push(`${c.name} → 向かいに相手がいなかった`);
        state._lanes.add(lane);
      } else if (c.etb === 'discard') {
        if (P[o].hand.length) {
          const i = Math.floor(state.rng() * P[o].hand.length);
          const id = P[o].hand.splice(i, 1)[0];
          P[o].grave.push(id);
          mark(state, { p: o, l: null, label: '手札−1' });
          state.log.push(`${c.name} → ${P[o].name}は${CARD[id].name}を捨てた`);
        }
      }
      step(state, `登場時効果：${c.name}`);
      if (P[o].terrains[lane] === 'swamp' && P[p].board[lane] === cr) {
        cr.power -= 1; cr.toughness -= 1; cr.hp -= 1;
        mark(state, { p, l: lane, label: '−1/−1' });
        state.log.push(`沼地 → ${c.name}は−1/−1`);
        step(state, '地形：沼地');
      }
      if (P[p].terrains[lane] === 'tower' && P[o].hand.length) {
        const id = P[o].hand[Math.floor(state.rng() * P[o].hand.length)];
        P[p].seen.push(id);
        mark(state, { p, l: lane, label: '偵察' });
        state.log.push(`見張り塔 → ${P[p].name}は相手の手札を1枚見た`);
        step(state, '地形：見張り塔');
      }
    }
    reapDeaths(state);
    step(state, '撃破');

    // 5. 起動能力（同時に処理する。ダメージ・手札戻し・強化を先に全部、そのあと移動）
    const live = [];
    for (let p = 0; p < 2; p++) {
      for (const a of acts[p]) {
        const lane = P[p].board.findIndex((cr) => cr && cr.uid === a.uid);
        if (lane < 0) {
          state.log.push(`${P[p].name}の${CARD[a.id].name}の起動は不発（場にいない）`);
          step(state, `起動：${CARD[a.id].name}`);
        } else live.push({ ...a, p, lane, cr: P[p].board[lane] });
      }
    }
    for (const a of live.filter((x) => CARD[x.id].ab.kind !== 'move')) {
      const o = 1 - a.p;
      const ab = CARD[a.id].ab;
      const name = CARD[a.id].name;
      state._lanes.add(a.lane);
      switch (ab.kind) {
        case 'shoot':
          if (P[o].board[a.target]) damageCreature(state, o, a.target, 1, name);
          else state.log.push(`${name} → ${LANE_NAME[a.target]}レーンに相手がいなかった`);
          state._lanes.add(a.target);
          break;
        case 'breath':
          if (P[o].board[a.lane]) damageCreature(state, o, a.lane, 2, name);
          else state.log.push(`${name} → 向かいに相手がいなかった`);
          break;
        case 'pump':
          a.cr.tmp = (a.cr.tmp || 0) + 2;
          mark(state, { p: a.p, l: a.lane, label: 'パワー+2' });
          state.log.push(`${name} → このターン、パワー+2`);
          break;
        case 'bounce':
          if (!bounce(state, o, a.target, name)) state.log.push(`${name} → ${LANE_NAME[a.target]}レーンに相手がいなかった`);
          state._lanes.add(a.target);
          break;
        case 'siege':
          damagePlayer(state, o, 2, null, name);
          break;
      }
      step(state, `起動：${name}`, true);
    }
    for (const a of live.filter((x) => CARD[x.id].ab.kind === 'move')) {
      const name = CARD[a.id].name;
      const lane = P[a.p].board.indexOf(a.cr);
      if (lane < 0) state.log.push(`${name} → 場にいないので移れなかった`);
      else if (P[a.p].board[a.target]) state.log.push(`${name} → ${LANE_NAME[a.target]}レーンが埋まっていて移れなかった`);
      else {
        P[a.p].board[lane] = null;
        P[a.p].board[a.target] = a.cr;
        mark(state, { p: a.p, l: a.target, label: '移動' });
        state.log.push(`${name} → ${LANE_NAME[a.target]}レーンへ移った`);
      }
      state._lanes.add(a.lane); state._lanes.add(a.target);
      step(state, `起動：${name}`, true);
    }
    reapDeaths(state);
    step(state, '撃破');

    // 6. 戦闘（各レーンは互いに影響しないので、レーンごとに処理して見せる）
    for (let l = 0; l < 3; l++) {
      const creatureDmg = [0, 0];
      const playerDmg = [];
      for (let p = 0; p < 2; p++) {
        const o = 1 - p;
        const a = P[p].board[l];
        if (!a) continue;
        const pw = powerOf(state, p, l);
        if (pw <= 0) continue;
        const b = P[o].board[l];
        if (b && has(a, 'flying') === has(b, 'flying')) {
          let d = pw;
          if (P[o].terrains[l] === 'lake' && CARD[b.id].color === 'blue') d = Math.max(0, d - 1);
          creatureDmg[o] += d;
          if (has(a, 'trample') && pw > b.hp) playerDmg.push({ p: o, n: pw - b.hp, src: `${CARD[a.id].name}（貫通）` });
        } else {
          playerDmg.push({ p: o, n: pw, src: b ? `${CARD[a.id].name}（素通り）` : CARD[a.id].name });
        }
      }
      for (let p = 0; p < 2; p++) {
        if (creatureDmg[p] > 0) {
          const cr = P[p].board[l];
          cr.hp -= creatureDmg[p];
          mark(state, { p, l, n: -creatureDmg[p] });
          state.log.push(`${P[p].name}の${CARD[cr.id].name}に${creatureDmg[p]}ダメージ`);
        }
      }
      for (const d of playerDmg) damagePlayer(state, d.p, d.n, l, d.src);
      if (state._hits.length) {
        state._lanes.add(l);
        step(state, `戦闘：${LANE_NAME[l]}レーン`);
        reapDeaths(state);
        state._lanes.add(l);
        step(state, `戦闘：${LANE_NAME[l]}レーン`);
      }
    }
    state.buff = [0, 0];
    for (const pl of P) for (const cr of pl.board) if (cr) cr.tmp = 0;

    // 7. 勝敗判定
    const dead = P.map((pl) => pl.life <= 0);
    if (dead[0] || dead[1]) {
      finish(state, dead[0] && dead[1] ? 'どちらもライフが尽きた' : 'ライフが尽きた');
    } else if (state.turn >= MAX_TURN) {
      finish(state, `${MAX_TURN}ターン終了`);
    } else {
      state.turn++;
    }
  }

  function boardPower(state, p) {
    let s = 0;
    for (let l = 0; l < 3; l++) s += powerOf(state, p, l);
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
    const s = JSON.parse(JSON.stringify({ ...state, nextUid: undefined, rng: undefined, steps: undefined, _lanes: undefined, _hits: undefined }));
    let uid = 100000;
    s.nextUid = () => uid++;
    s.rng = () => 0.5;
    return s;
  }

  function evaluate(s, p) {
    const o = 1 - p;
    if (s.over) {
      if (s.winner === p) return 1000;
      if (s.winner === o) return -1000;
      return 0;
    }
    const P = s.players;
    let v = (P[p].life - P[o].life) * 3;
    for (let l = 0; l < 3; l++) {
      const a = P[p].board[l], b = P[o].board[l];
      if (a) v += powerOf(s, p, l) * 1.5 + a.hp;
      if (b) v -= powerOf(s, o, l) * 1.5 + b.hp;
    }
    return v;
  }

  // 相手の手札は見ない。相手の一手は「何もしない」と「適当な 3/3 をどこかに出す」で見積もる
  function simulate(state, p, m) {
    const o = 1 - p;
    let total = 0, n = 0;
    for (const probe of [null, 0, 1, 2]) {
      const s = clone(state);
      let om = { pass: true };
      if (probe != null) {
        s.players[o].hand.push('golem');
        om = { card: 'golem', lane: probe };
        if (costFor(s.players[o].deck, 'golem') > s.turn) { s.turn = 3; }
      }
      resolveTurn(s, p === 0 ? [m, om] : [om, m]);
      const w = probe == null ? 2 : 1;
      total += evaluate(s, p) * w;
      n += w;
    }
    return total / n;
  }

  function cpuMove(state, p, rng) {
    rng = rng || Math.random;
    const pl = state.players[p];
    const m0 = mana(state);
    const canPlay = pl.hand.some((id) => costFor(pl.deck, id) <= m0);
    // カードの候補ごとに、残りのマナで起動能力を良くなる限り足し、全体で一番いい手を選ぶ
    let best = null, bestV = -Infinity;
    for (const c of legalMoves(state, p)) {
      let m = normalize(c);
      let v = simulate(state, p, m);
      for (let l = 0; l < 3; l++) {
        const cr = pl.board[l];
        if (!cr || !CARD[cr.id].ab) continue;
        if (m.card && CARD[m.card].type === 'creature' && m.lane === l) continue; // 入れ替わるので不発
        let pick = null, pickV = v + 0.3;
        for (const t of abTargets(CARD[cr.id].ab, l)) {
          const mm = { ...m, acts: [...m.acts, { from: l, target: t }] };
          if (checkMove(state, p, mm)) continue;
          const vv = simulate(state, p, mm);
          if (vv > pickV) { pickV = vv; pick = mm; }
        }
        if (pick) { m = pick; v = pickV; }
      }
      if (!m.card && canPlay) v -= 1.5; // 出せるのに出さないのは少し損
      if (m.card === 'seal') v += state.turn >= 3 ? 3 + Math.min(state.turn, 6) : -5; // 読み
      v += rng() * 1.5;
      if (v > bestV) { bestV = v; best = m; }
    }
    return best;
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
    MAX_TURN, START_LIFE, DECK_SIZE, COLOR_NAME, CARDS, CARD, TERRAINS, TERRAIN, LANE_NAME, CPU_DECKS,
    validateDeck, costFor, newGame, legalMoves, isLegal, checkMove, abTargets, moveCost, normalize, resolveTurn, powerOf, cpuMove, boardPower, view,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.Engine = api;
})(typeof self !== 'undefined' ? self : this);
