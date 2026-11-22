// ふたりの英雄（仮）PvE 連戦版 ルールエンジン（ブラウザ・Node 共用、DOM 非依存）
// ヒーロー2人で、次の行動を予告する敵と戦う。予告が見えているので、自分のターンのうちに備える
(function (root) {
  'use strict';

  const LIFE = 20;          // あなたのライフ。0 で負け
  const HAND_SIZE = 2;      // ヒーローごとの手札。カードは決まった順番で巡回する
  const MANA_MAX = 6;
  const SKILL_COST = 1;     // 固有スキル（1人1ターン1回）
  const KO_LIFE = 4;        // ヒーローが倒れたときに失うライフ
  const REVIVE_WAIT = 1;    // 倒れたヒーローが休むターン数
  const ENRAGE = 3;         // 敵が予告を一巡するたびに、攻撃のダメージがこれだけ上がる（怒り）
  const POS_NAME = { front: '前衛', back: '後衛' };

  // ── ヒーロー ──
  // skill.target: enemy = 敵 / ally = 味方 / none。pos: front = 前衛にいるときだけ
  const HEROES = [
    { id: 'sword', name: '剣士', color: 'red', hp: 12, cards: ['sw_slash', 'sw_focus', 'sw_lunge', 'sw_double'],
      skill: { name: '斬りかかる', pos: 'front', target: 'enemy', text: '敵に2ダメージ。気合いの強化も乗る。' } },
    { id: 'saint', name: '聖女', color: 'gold', hp: 10, cards: ['st_heal', 'st_mace', 'st_bless', 'st_prayer'],
      skill: { name: '祈りの手', pos: 'back', target: 'ally', text: '味方1人のHPを2回復。' } },
    { id: 'knight', name: '守護騎士', color: 'grey', hp: 15, cards: ['kn_bash', 'kn_taunt', 'kn_guard', 'kn_wall'],
      skill: { name: 'かばう', pos: 'front', target: 'ally', text: '次のターンまで、味方1人への1体攻撃を代わりに受ける。' } },
    { id: 'mage', name: '魔術師', color: 'blue', hp: 8, cards: ['mg_bolt', 'mg_flame', 'mg_meditate', 'mg_thunder'],
      skill: { name: '魔弾', pos: 'back', target: 'enemy', text: '敵に1ダメージ。後衛からでも撃てる。' } },
    { id: 'rogue', name: '盗賊', color: 'green', hp: 10, cards: ['rg_dagger', 'rg_trip', 'rg_jam', 'rg_backstab'],
      skill: { name: 'すり抜け', pos: 'front', target: 'enemy', text: '敵に2ダメージ。このターン、もう1回移動できる。' } },
  ];
  const HERO = Object.fromEntries(HEROES.map((h) => [h.id, h]));
  // 報酬で強化した固有スキル
  const SKILL_UP = {
    sword: '敵に4ダメージ。気合いの強化も乗る。',
    saint: '味方1人のHPを4回復。',
    knight: '次のターンまで、味方1人への1体攻撃を代わりに受ける。自分に盾3。',
    mage: '敵に2ダメージ。後衛からでも撃てる。',
    rogue: '敵に3ダメージ。このターン、もう1回移動できる。',
  };
  // h = { id, up }
  function skillOf(h) { const sk = HERO[h.id].skill; return h.up ? { ...sk, text: SKILL_UP[h.id], up: true } : sk; }

  // ── カード ──
  // pos: front = そのヒーローが前衛にいるときだけ使える / back = どこからでも
  const CARDS = [
    { id: 'sw_slash', hero: 'sword', name: '斬撃', cost: 1, pos: 'front', target: 'enemy', text: '敵に3ダメージ。' },
    { id: 'sw_focus', hero: 'sword', name: '気合い', cost: 1, pos: 'back', target: 'none', text: 'このターン、このヒーローの次の攻撃+2。' },
    { id: 'sw_lunge', hero: 'sword', name: '踏み込み', cost: 2, pos: 'front', target: 'enemy', text: '敵に5ダメージ。自分も1ダメージを受ける。' },
    { id: 'sw_double', hero: 'sword', name: '連撃', cost: 2, pos: 'front', target: 'enemy', text: '敵に2ダメージを2回。' },

    { id: 'st_heal', hero: 'saint', name: '癒しの光', cost: 1, pos: 'back', target: 'ally', text: '味方1人のHPを3回復。' },
    { id: 'st_mace', hero: 'saint', name: '光の槌', cost: 1, pos: 'front', target: 'enemy', text: '敵に2ダメージ。味方全員のHPを1回復。' },
    { id: 'st_bless', hero: 'saint', name: '加護', cost: 1, pos: 'back', target: 'ally', text: '味方1人に盾3（次のターンまで）。' },
    { id: 'st_prayer', hero: 'saint', name: '祈り', cost: 0, pos: 'back', target: 'none', text: 'このターン、マナ+2。' },

    { id: 'kn_bash', hero: 'knight', name: '盾打ち', cost: 1, pos: 'front', target: 'enemy', text: '敵に2ダメージ。自分に盾2。' },
    { id: 'kn_taunt', hero: 'knight', name: '挑発', cost: 1, pos: 'front', target: 'none', text: '次のターンまで、敵の1体攻撃（強打）はこのヒーローに向く。' },
    { id: 'kn_guard', hero: 'knight', name: '守りの構え', cost: 1, pos: 'back', target: 'ally', text: '味方1人に盾4（次のターンまで）。' },
    { id: 'kn_wall', hero: 'knight', name: '鉄壁', cost: 2, pos: 'front', target: 'none', text: '味方全員に盾3（次のターンまで）。' },

    { id: 'mg_bolt', hero: 'mage', name: '魔力の矢', cost: 1, pos: 'back', target: 'enemy', text: '遠距離。敵に2ダメージ。' },
    { id: 'mg_flame', hero: 'mage', name: '火炎', cost: 2, pos: 'front', target: 'enemy', text: '敵に4ダメージ。敵の溜めを消す。' },
    { id: 'mg_meditate', hero: 'mage', name: '瞑想', cost: 0, pos: 'back', target: 'none', text: 'このターン、マナ+1。' },
    { id: 'mg_thunder', hero: 'mage', name: '雷', cost: 3, pos: 'back', target: 'enemy', text: '遠距離。敵に5ダメージ。' },

    { id: 'rg_dagger', hero: 'rogue', name: '投げナイフ', cost: 1, pos: 'back', target: 'enemy', text: '遠距離。敵に2ダメージ。' },
    { id: 'rg_trip', hero: 'rogue', name: '足払い', cost: 1, pos: 'front', target: 'enemy', text: '敵に1ダメージ。敵の次の攻撃のダメージ−3。' },
    { id: 'rg_jam', hero: 'rogue', name: '撹乱', cost: 2, pos: 'front', target: 'none', text: '敵の予告を1つ飛ばす（次の予告に変わる）。' },
    { id: 'rg_backstab', hero: 'rogue', name: '急所突き', cost: 2, pos: 'front', target: 'enemy', text: '敵に3ダメージ。敵のHPが半分以下なら6ダメージ。' },
    // ── 報酬で手に入るカード ──
    { id: 'sw_cleave', hero: 'sword', name: '盾割り', cost: 2, pos: 'front', target: 'enemy', text: '敵の盾を壊してから、4ダメージ。', extra: true },
    { id: 'sw_parry', hero: 'sword', name: '受け流し', cost: 1, pos: 'front', target: 'none', text: '自分に盾4。このターン、次の攻撃+2。', extra: true },
    { id: 'st_sanctum', hero: 'saint', name: '聖域', cost: 2, pos: 'back', target: 'none', text: '味方全員のHPを3回復。', extra: true },
    { id: 'st_judge', hero: 'saint', name: '裁きの光', cost: 2, pos: 'back', target: 'enemy', text: '遠距離。敵に3ダメージ。', extra: true },
    { id: 'kn_charge', hero: 'knight', name: '突撃', cost: 2, pos: 'front', target: 'enemy', text: '敵に3ダメージ＋自分の盾の数だけ追加ダメージ。', extra: true },
    { id: 'kn_stand', hero: 'knight', name: '不動', cost: 1, pos: 'front', target: 'none', text: '自分に盾4。次のターンまで挑発。', extra: true },
    { id: 'mg_frost', hero: 'mage', name: '氷結', cost: 2, pos: 'back', target: 'enemy', text: '遠距離。敵に2ダメージ。敵の次の攻撃のダメージ−3。', extra: true },
    { id: 'mg_meteor', hero: 'mage', name: '隕石', cost: 4, pos: 'back', target: 'enemy', text: '遠距離。敵に9ダメージ。', extra: true },
    { id: 'rg_poison', hero: 'rogue', name: '毒刃', cost: 1, pos: 'front', target: 'enemy', text: '敵に1ダメージ。毒3（敵が行動するたびに2ダメージ、3回）。', extra: true },
    { id: 'rg_pick', hero: 'rogue', name: 'かすめ取る', cost: 0, pos: 'back', target: 'none', text: 'マナ+1。敵の盾を消す。', extra: true },
  ];
  const CARD = Object.fromEntries(CARDS.map((c) => [c.id, c]));

  // ── 敵 ──
  // 行動は順番に巡回する。type:
  //   front = 前衛全員（前衛が空ならライフ）/ back = 後衛全員（遠距離。後衛が空ならライフ）
  //   strong = 前衛でHPが一番高い1人（挑発・かばうで向きが変わる。前衛が空ならライフ）
  //   all = 全員 / charge = 次の攻撃+n / guard = 敵に盾n
  const ENEMIES = [
    { id: 'golem', name: '石の番人', hp: 26, text: '硬く、前衛を殴り続ける。溜めのあとの強打に注意。',
      pattern: [{ type: 'front', n: 5 }, { type: 'guard', n: 6 }, { type: 'strong', n: 9 }, { type: 'charge', n: 5 }, { type: 'strong', n: 9 }] },
    { id: 'spider', name: '毒蜘蛛の女王', hp: 26, text: '後衛を狙ってくる。前衛に逃がすか、守るか。',
      pattern: [{ type: 'back', n: 7 }, { type: 'front', n: 6 }, { type: 'back', n: 9 }, { type: 'all', n: 5 }] },
    { id: 'dragon', name: '紅蓮の竜', hp: 26, text: '溜めてから全体を焼く。溜めを消すか、盾で耐えるか。',
      pattern: [{ type: 'strong', n: 7 }, { type: 'charge', n: 4 }, { type: 'all', n: 5 }, { type: 'guard', n: 5 }, { type: 'strong', n: 7 }] },
  ];
  // ボス：HPが半分になると、予告の巡回が変わる
  const BOSS = { id: 'lord', name: '黄昏の魔王', hp: 32, boss: true, text: 'HPが半分を切ると本気を出し、予告が変わる。',
    pattern: [{ type: 'front', n: 5 }, { type: 'back', n: 5 }, { type: 'charge', n: 3 }, { type: 'strong', n: 7 }, { type: 'guard', n: 5 }],
    phase2: { text: '本気を出した。', pattern: [{ type: 'all', n: 4 }, { type: 'charge', n: 4 }, { type: 'strong', n: 8 }, { type: 'back', n: 6 }] } };
  ENEMIES.push(BOSS);
  const ENEMY = Object.fromEntries(ENEMIES.map((e) => [e.id, e]));
  // 敵の今の予告の巡回（ボスは本気になると変わる）
  function patternOf(e) { const d = ENEMY[e.id]; return e.phase && d.phase2 ? d.phase2.pattern : d.pattern; }
  const ACT_NAME = { front: '前衛へ攻撃', back: '後衛へ攻撃', strong: '強打', all: '全体攻撃', charge: '溜め', guard: '身を固める' };

  function validateTeam(team) {
    const errs = [];
    if (!team || !Array.isArray(team.heroes) || team.heroes.length !== 2) errs.push('ヒーローを2人選んでください');
    else if (team.heroes[0] === team.heroes[1]) errs.push('同じヒーローは選べません');
    else if (team.heroes.some((h) => !HERO[h])) errs.push('不明なヒーロー');
    return errs;
  }

  function makeHero(id, pos, mod) {
    const h = HERO[id];
    mod = mod || {};
    const hp = h.hp + (mod.hp || 0);
    return { id, up: !!mod.up, hp, maxHp: hp, pos, shield: 0, ko: false, wait: 0, focus: 0, taunt: false, guard: null, skilled: false, moved: false };
  }

  // ── 状態 ──
  // opt = { life, hp }。team.mods = [{ hp, up, cards }]（連戦の強化）
  function newGame(team, enemyId, rng, opt) {
    opt = opt || {};
    const mods = team.mods || [];
    rng = rng || Math.random;
    let uid = 1;
    const e = ENEMY[enemyId];
    const state = {
      round: 1, mana: 0, life: opt.life ?? LIFE, over: false, winner: null, endReason: '',
      heroes: team.heroes.map((id, k) => makeHero(id, (team.front ?? 0) === k ? 'front' : 'back', mods[k])),
      decks: [],
      enemy: { id: e.id, hp: opt.hp || e.hp, maxHp: opt.hp || e.hp, shield: 0, charge: 0, weak: 0, poison: 0, step: 0, loops: 0, phase: 0 },
      log: [], steps: [],
      nextUid() { return uid++; },
      rng,
    };
    state.decks = state.heroes.map((h, k) => {
      const order = ((mods[k] && mods[k].cards) || HERO[h.id].cards).slice();
      for (let i = order.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [order[i], order[j]] = [order[j], order[i]]; }
      return { hand: order.slice(0, HAND_SIZE).map((id) => ({ uid: state.nextUid(), id })), queue: order.slice(HAND_SIZE) };
    });
    begin(state);
    startTurn(state);
    return state;
  }

  // ── 演出用の記録 ──
  // step = { title, lines, hits, actor, aim, view }。actor/aim の p は 0 = 味方、1 = 敵。k = ヒーローの番号、'life' = ライフ
  function begin(state) { state.log = []; state.steps = []; state._hits = []; state._aim = []; state._logAt = 0; }
  function mark(state, hit) { state._hits.push(hit); }
  function view(state) {
    return { round: state.round, mana: state.mana, life: state.life, enemy: { ...state.enemy, rage: rage(state) }, heroes: state.heroes.map((h) => ({ ...h })), intent: intent(state) };
  }
  function step(state, title, force, actor) {
    const lines = state.log.slice(state._logAt);
    if (!lines.length && !state._hits.length && !force) return;
    state._logAt = state.log.length;
    state.steps.push({ title, lines, hits: state._hits, actor: actor || null, aim: state._aim, view: view(state) });
    state._hits = [];
    state._aim = [];
  }
  const hname = (state, k) => HERO[state.heroes[k].id].name;
  const ename = (state) => ENEMY[state.enemy.id].name;

  // ── 予告 ──
  // 今の予告と、それが誰に何ダメージ当たるかの見込み（盾は考えない素のダメージ）
  function intent(state) {
    const e = state.enemy;
    const p = patternOf(e);
    const a = p[e.step % p.length];
    const out = { ...a, name: ACT_NAME[a.type] };
    if (['front', 'back', 'strong', 'all'].includes(a.type)) {
      out.dmg = Math.max(0, a.n + e.charge + rage(state) - e.weak);
      out.targets = targetsOf(state, a.type);
    }
    return out;
  }
  // 怒り：予告を一巡するたびに攻撃が強くなる
  function rage(state) { return state.enemy.loops * ENRAGE; }
  // 予告を1つ進める。一巡したら怒る
  function nextStep(state) {
    const e = state.enemy;
    e.step++;
    if (e.step % patternOf(e).length === 0) {
      e.loops++;
      state.log.push(`${ename(state)}の怒りが増した（攻撃+${ENRAGE}）`);
      mark(state, { p: 1, k: 'enemy', label: `怒り+${ENRAGE}` });
      return true;
    }
    return false;
  }

  // 攻撃の当たり先。[{ k }] か [{ life: true }]
  function targetsOf(state, type) {
    const alive = [0, 1].filter((k) => !state.heroes[k].ko);
    const front = alive.filter((k) => state.heroes[k].pos === 'front');
    const back = alive.filter((k) => state.heroes[k].pos === 'back');
    if (type === 'all') return alive.length ? alive.map((k) => ({ k })) : [{ life: true }];
    if (type === 'back') return back.length ? back.map((k) => ({ k })) : [{ life: true }];
    if (type === 'front') return front.length ? front.map((k) => ({ k })) : [{ life: true }];
    if (type === 'strong') {
      const taunt = alive.find((k) => state.heroes[k].taunt);
      if (taunt != null) return [{ k: taunt, why: '挑発' }];
      if (!front.length) return [{ life: true }];
      let k = front.reduce((a, b) => (state.heroes[b].hp > state.heroes[a].hp ? b : a));
      const g = state.heroes[k].guard;
      if (g != null && !state.heroes[g].ko) return [{ k: g, why: 'かばう' }];
      return [{ k }];
    }
    return [];
  }

  // ── ターン ──
  function startTurn(state) {
    state.mana = state.round === 1 ? 2 : Math.min(state.round + 1, MANA_MAX);
    state.log.push(`ラウンド${state.round}（マナ${state.mana}）`);
    state.heroes.forEach((h, k) => {
      if (h.ko && h.wait > 0) { h.wait--; state.log.push(`${hname(state, k)}は休んでいる（復活まで、あと${h.wait + 1}ターン）`); }
      else if (h.ko) { Object.assign(h, makeHero(h.id, 'back', { hp: h.maxHp - HERO[h.id].hp, up: h.up })); mark(state, { p: 0, k, label: '復活' }); state.log.push(`${hname(state, k)}が後衛で復活した`); }
      h.shield = 0; h.taunt = false; h.guard = null; h.focus = 0; h.skilled = false; h.moved = false;
    });
    const it = intent(state);
    state.log.push(`敵の予告：${it.name}${it.dmg != null ? `（${it.dmg}ダメージ）` : `（${it.n}）`}`);
    step(state, `ラウンド${state.round}`, true);
  }

  // 敵が予告どおりに動き、次のラウンドを始める
  function endTurn(state) {
    begin(state);
    if (state.over) return state.steps;
    const e = state.enemy;
    const it = intent(state);
    e.shield = 0;
    state.log.push(`${ename(state)}の「${it.name}」`);
    if (it.type === 'charge') {
      e.charge += it.n;
      mark(state, { p: 1, k: 'enemy', label: `溜め+${it.n}` });
      state.log.push(`次の攻撃のダメージ+${it.n}`);
    } else if (it.type === 'guard') {
      e.shield = it.n;
      mark(state, { p: 1, k: 'enemy', label: `盾+${it.n}` });
      state.log.push(`敵に盾${it.n}（次の敵の行動まで）`);
    } else {
      if (e.weak) state.log.push(`※足払いで、ダメージが${e.weak}減っている`);
      for (const t of it.targets) {
        if (t.life) {
          state.log.push(`※${it.type === 'back' ? '後衛に誰もいないので' : it.type === 'all' ? '立っているヒーローがいないので' : '前衛に誰もいないので'}、あなたのライフに当たる`);
          hitLife(state, it.dmg, ename(state));
          state._aim.push({ p: 0, k: 'life' });
        } else {
          if (t.why) state.log.push(`※${t.why}で、${hname(state, t.k)}が攻撃を受ける`);
          damageHero(state, t.k, it.dmg, ename(state));
          state._aim.push({ p: 0, k: t.k });
        }
      }
      e.charge = 0; e.weak = 0;
    }
    step(state, `敵の行動：${it.name}`, true, { p: 1, k: 'enemy' });
    if (e.poison > 0) {
      e.poison--;
      state.log.push(`※毒が回っている（あと${e.poison}回）`);
      damageEnemy(state, 2, '毒');
      step(state, '毒', true);
      if (state.over) return state.steps;
    }
    if (nextStep(state)) step(state, '怒り', true);
    if (state.over) return state.steps;
    state.round++;
    startTurn(state);
    return state.steps;
  }

  // ── ダメージ ──
  function damageHero(state, k, n, src) {
    const h = state.heroes[k];
    if (h.ko || n <= 0) return;
    const absorbed = Math.min(h.shield, n);
    h.shield -= absorbed;
    h.hp -= n - absorbed;
    mark(state, { p: 0, k, n: -(n - absorbed), label: absorbed ? `盾−${absorbed}` : null, hit: true });
    state.log.push(`${src} → ${hname(state, k)}に${n}ダメージ${absorbed ? `（盾で${absorbed}防いだ）` : ''}`);
    if (h.hp <= 0) {
      h.ko = true; h.hp = 0; h.shield = 0; h.taunt = false; h.wait = REVIVE_WAIT;
      mark(state, { p: 0, k, label: '撃破' });
      state.log.push(`${hname(state, k)}は倒れた（ライフ−${KO_LIFE}。ターンを1回休んでから復活）`);
      hitLife(state, KO_LIFE, '仲間が倒れた');
    }
  }
  function hitLife(state, n, src) {
    state.life -= n;
    mark(state, { p: 0, k: 'life', n: -n, hit: true });
    state.log.push(`${src} → あなたのライフに${n}ダメージ`);
    if (state.life <= 0) { state.life = 0; finish(state, 1, 'ライフが尽きた'); }
  }
  function damageEnemy(state, n, src) {
    const e = state.enemy;
    if (n <= 0 || state.over) return;
    const absorbed = Math.min(e.shield, n);
    e.shield -= absorbed;
    e.hp -= n - absorbed;
    mark(state, { p: 1, k: 'enemy', n: -(n - absorbed), label: absorbed ? `盾−${absorbed}` : null, hit: true });
    state.log.push(`${src} → ${ename(state)}に${n}ダメージ${absorbed ? `（盾で${absorbed}防いだ）` : ''}`);
    if (e.hp <= 0) { e.hp = 0; finish(state, 0, `${ename(state)}を倒した`); return; }
    const d = ENEMY[e.id];
    if (d.phase2 && !e.phase && e.hp * 2 <= e.maxHp) {
      e.phase = 1; e.step = 0; e.charge = 0;
      mark(state, { p: 1, k: 'enemy', label: '本気' });
      state.log.push(`※HPが半分を切り、${ename(state)}は${d.phase2.text}予告が「${intent(state).name}」に変わった`);
    }
  }
  function heal(state, k, n, src) {
    const h = state.heroes[k];
    if (h.ko) return;
    const d = Math.min(n, h.maxHp - h.hp);
    h.hp += d;
    mark(state, { p: 0, k, n: d, heal: true });
    state.log.push(`${src} → ${hname(state, k)}のHPを${d}回復`);
  }
  function shield(state, k, n, src) {
    const h = state.heroes[k];
    if (h.ko) return;
    h.shield += n;
    mark(state, { p: 0, k, label: `盾+${n}` });
    state.log.push(`${src} → ${hname(state, k)}に盾${n}`);
  }
  function finish(state, winner, reason) {
    if (state.over) return;
    state.over = true; state.winner = winner;
    state.endReason = `${reason}（ラウンド${state.round}・残りライフ${state.life}）`;
  }

  // ── 手札 ──
  function findCard(state, uid) {
    for (let k = 0; k < state.decks.length; k++) { const c = state.decks[k].hand.find((x) => x.uid === uid); if (c) return { k, c }; }
    return null;
  }
  // 使ったカードを列の最後へ回し、同じ場所に列の先頭を入れる
  function cycle(state, k, uid) {
    const d = state.decks[k];
    const i = d.hand.findIndex((x) => x.uid === uid);
    if (i < 0) return;
    d.queue.push(d.hand[i].id);
    d.hand[i] = { uid: state.nextUid(), id: d.queue.shift(), fresh: true };
  }

  // ── 行動の確認 ──
  // action = { type: 'card', uid, target } | { type: 'skill', k, target } | { type: 'move', k }
  // target: 敵なら 'enemy'、味方ならヒーローの番号、なしなら null
  function check(state, a) {
    if (state.over) return '試合は終わった';
    if (a.type === 'move') {
      const h = state.heroes[a.k];
      if (!h || h.ko) return '倒れている';
      if (h.moved) return '移動は1ターン1回';
      return null;
    }
    if (a.type === 'skill') {
      const h = state.heroes[a.k];
      if (!h || h.ko) return '倒れている';
      const sk = skillOf(h);
      if (sk.pos === 'front' && h.pos !== 'front') return '前衛にいない';
      if (h.skilled) return '固有スキルは1ターン1回';
      if (state.mana < SKILL_COST) return 'マナが足りない';
      return checkTarget(state, sk.target, a.target, h.id === 'knight' ? a.k : null);
    }
    if (a.type === 'card') {
      const f = findCard(state, a.uid);
      if (!f) return '手札にない';
      const def = CARD[f.c.id], h = state.heroes[f.k];
      if (h.ko) return `${HERO[h.id].name}が倒れている`;
      if (def.pos === 'front' && h.pos !== 'front') return `${HERO[h.id].name}が前衛にいない`;
      if (def.cost > state.mana) return 'マナが足りない';
      return checkTarget(state, def.target, a.target, null);
    }
    return '不明な行動';
  }
  function checkTarget(state, kind, t, notSelf) {
    if (kind === 'none') return t == null ? null : '対象が不正';
    if (kind === 'enemy') return t === 'enemy' ? null : '対象が不正';
    if (!(t === 0 || t === 1) || state.heroes[t].ko) return '対象が不正';
    if (t === notSelf) return '自分はかばえない';
    return null;
  }

  // ── 行動 ──
  function act(state, a) {
    begin(state);
    const err = check(state, a);
    if (err) return { error: err };
    if (a.type === 'move') {
      const h = state.heroes[a.k];
      h.moved = true;
      h.pos = h.pos === 'front' ? 'back' : 'front';
      mark(state, { p: 0, k: a.k, label: POS_NAME[h.pos] + 'へ' });
      state.log.push(`${hname(state, a.k)}が${POS_NAME[h.pos]}へ移った`);
      step(state, '移動', true, { p: 0, k: a.k });
      return { done: true };
    }
    if (a.type === 'skill') {
      const h = state.heroes[a.k], sk = skillOf(h);
      state.mana -= SKILL_COST;
      h.skilled = true;
      state.log.push(`${hname(state, a.k)}の「${sk.name}」`);
      switch (h.id) {
        case 'sword': attack(state, a.k, h.up ? 4 : 2); break;
        case 'mage': attack(state, a.k, h.up ? 2 : 1); break;
        case 'rogue': attack(state, a.k, h.up ? 3 : 2); if (!state.over) { h.moved = false; mark(state, { p: 0, k: a.k, label: 'もう1回移動できる' }); } break;
        case 'saint': heal(state, a.target, h.up ? 4 : 2, sk.name); break;
        case 'knight': state.heroes[a.target].guard = a.k; mark(state, { p: 0, k: a.target, label: 'かばわれ中' }); state.log.push(`次のターンまで、${hname(state, a.k)}が${hname(state, a.target)}への1体攻撃を代わりに受ける`); if (h.up) shield(state, a.k, 3, sk.name); break;
      }
      step(state, `${HERO[h.id].name}：${sk.name}`, true, { p: 0, k: a.k });
      return { done: true };
    }
    const { k, c } = findCard(state, a.uid);
    const def = CARD[c.id], h = state.heroes[k], e = state.enemy;
    cycle(state, k, a.uid);
    state.mana -= def.cost;
    state.log.push(`${hname(state, k)}の「${def.name}」`);
    switch (def.id) {
      case 'sw_slash': attack(state, k, 3); break;
      case 'sw_focus': h.focus += 2; mark(state, { p: 0, k, label: '次の攻撃+2' }); break;
      case 'sw_lunge': attack(state, k, 5); if (!state.over) damageHero(state, k, 1, '反動'); break;
      case 'sw_double': attack(state, k, 2); attack(state, k, 2); break;
      case 'st_heal': heal(state, a.target, 3, def.name); break;
      case 'st_mace': attack(state, k, 2); for (let x = 0; x < 2; x++) heal(state, x, 1, def.name); break;
      case 'st_bless': shield(state, a.target, 3, def.name); break;
      case 'st_prayer': state.mana += 2; mark(state, { p: 0, k, label: 'マナ+2' }); break;
      case 'kn_bash': attack(state, k, 2); shield(state, k, 2, def.name); break;
      case 'kn_taunt': h.taunt = true; mark(state, { p: 0, k, label: '挑発' }); state.log.push('次のターンまで、敵の強打はこのヒーローに向く'); break;
      case 'kn_guard': shield(state, a.target, 4, def.name); break;
      case 'kn_wall': for (let x = 0; x < 2; x++) shield(state, x, 3, def.name); break;
      case 'mg_bolt': attack(state, k, 2); break;
      case 'mg_flame': attack(state, k, 4); if (e.charge) { e.charge = 0; mark(state, { p: 1, k: 'enemy', label: '溜めが消えた' }); state.log.push('敵の溜めが消えた'); } break;
      case 'mg_meditate': state.mana += 1; mark(state, { p: 0, k, label: 'マナ+1' }); break;
      case 'mg_thunder': attack(state, k, 5); break;
      case 'rg_dagger': attack(state, k, 2); break;
      case 'rg_trip': attack(state, k, 1); e.weak += 3; mark(state, { p: 1, k: 'enemy', label: '次の攻撃−3' }); state.log.push('敵の次の攻撃のダメージ−3'); break;
      case 'rg_jam': nextStep(state); mark(state, { p: 1, k: 'enemy', label: '予告が変わった' }); state.log.push(`敵の予告が「${intent(state).name}」に変わった`); break;
      case 'sw_cleave': if (e.shield) { e.shield = 0; mark(state, { p: 1, k: 'enemy', label: '盾が壊れた' }); state.log.push('敵の盾が壊れた'); } attack(state, k, 4); break;
      case 'sw_parry': shield(state, k, 4, def.name); h.focus += 2; mark(state, { p: 0, k, label: '次の攻撃+2' }); break;
      case 'st_sanctum': for (let x = 0; x < 2; x++) heal(state, x, 3, def.name); break;
      case 'st_judge': attack(state, k, 3); break;
      case 'kn_charge': attack(state, k, 3 + h.shield); break;
      case 'kn_stand': shield(state, k, 4, def.name); h.taunt = true; mark(state, { p: 0, k, label: '挑発' }); break;
      case 'mg_frost': attack(state, k, 2); e.weak += 3; mark(state, { p: 1, k: 'enemy', label: '次の攻撃−3' }); state.log.push('敵の次の攻撃のダメージ−3'); break;
      case 'mg_meteor': attack(state, k, 9); break;
      case 'rg_poison': attack(state, k, 1); e.poison += 3; mark(state, { p: 1, k: 'enemy', label: '毒3' }); state.log.push('敵に毒（行動するたびに2ダメージ、3回）'); break;
      case 'rg_pick': state.mana += 1; mark(state, { p: 0, k, label: 'マナ+1' }); if (e.shield) { e.shield = 0; mark(state, { p: 1, k: 'enemy', label: '盾が消えた' }); state.log.push('敵の盾が消えた'); } break;
      case 'rg_backstab': attack(state, k, e.hp * 2 <= e.maxHp ? 6 : 3); break;
    }
    step(state, `${HERO[def.hero].name}：${def.name}`, true, { p: 0, k });
    return { done: true };
  }
  // ヒーロー k が敵を攻撃する（気合いの強化が乗る）
  function attack(state, k, n) {
    const h = state.heroes[k];
    const bonus = h.focus; h.focus = 0;
    state._aim.push({ p: 1, k: 'enemy' });
    damageEnemy(state, n + bonus, HERO[h.id].name);
  }

  // 今できる行動を全部挙げる
  function actions(state) {
    const out = [];
    const tryA = (a) => { if (!check(state, a)) out.push(a); };
    for (let k = 0; k < 2; k++) {
      tryA({ type: 'move', k });
      for (const t of ['enemy', 0, 1, null]) tryA({ type: 'skill', k, target: t });
    }
    for (const c of state.decks.flatMap((d) => d.hand)) for (const t of ['enemy', 0, 1, null]) tryA({ type: 'card', uid: c.uid, target: t });
    return out;
  }

  // ── 自動プレイ（調整用） ──
  // 自分の行動のあと、敵の予告まで処理した盤面で評価し、良くなる限り行動を重ねる
  function clone(state) {
    const s = JSON.parse(JSON.stringify({ ...state, nextUid: undefined, rng: undefined, steps: undefined, log: undefined, _hits: undefined, _aim: undefined }));
    let uid = 100000;
    s.nextUid = () => uid++;
    s.rng = () => 0.5;
    begin(s);
    return s;
  }
  function value(s) {
    if (s.over) return s.winner === 0 ? 10000 - s.round : -10000;
    let v = s.life * 4 - s.enemy.hp * 3;
    s.heroes.forEach((h) => { v += h.ko ? -6 : h.hp; });
    return v;
  }
  function botAction(state, rng) {
    rng = rng || Math.random;
    const look = (s) => { const t = clone(s); endTurn(t); return value(t); };
    let best = null, bestV = look(state) + 0.2;
    for (const a of actions(state)) {
      const s = clone(state);
      act(s, a);
      const v = (s.over ? value(s) : look(s)) + rng() * 0.1;
      if (v > bestV) { bestV = v; best = a; }
    }
    return best;
  }

  // ── 連戦 ──
  // 3戦：普通の敵2体 → ボス。ライフは持ち越し、ヒーローのHPは戦闘ごとに全快
  const RUN_LIFE_HEAL = 6;
  const RUN_HP = [22, 26, null];
  function newRun(team, rng) {
    rng = rng || Math.random;
    const pool = ENEMIES.filter((e) => !e.boss).map((e) => e.id);
    for (let i = pool.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [pool[i], pool[j]] = [pool[j], pool[i]]; }
    return {
      heroes: team.heroes.slice(), front: team.front ?? 0,
      mods: team.heroes.map((id) => ({ hp: 0, up: false, cards: HERO[id].cards.slice() })),
      life: LIFE, stage: 0, foes: [pool[0], pool[1], BOSS.id], over: false, won: false,
    };
  }
  function runFight(run, rng) {
    return newGame({ heroes: run.heroes, front: run.front, mods: run.mods }, run.foes[run.stage], rng, { life: run.life, hp: RUN_HP[run.stage] });
  }
  // 戦闘の結果を連戦に反映する。true なら報酬へ
  function endFight(run, game) {
    run.life = game.life;
    run.front = game.heroes.findIndex((h) => h.pos === 'front' && !h.ko);
    if (run.front < 0) run.front = 0;
    if (game.winner !== 0) { run.over = true; return false; }
    run.stage++;
    if (run.stage >= run.foes.length) { run.over = true; run.won = true; return false; }
    return true;
  }
  // 報酬の候補を3つ。{ type:'card', k, card } / { type:'up', k, what:'skill'|'hp' } / { type:'heal' }
  function rewardOptions(run, rng) {
    rng = rng || Math.random;
    const pickOf = (arr) => arr[Math.floor(rng() * arr.length)];
    const out = [];
    const ks = rng() < 0.5 ? [0, 1] : [1, 0];
    const newCards = (k) => CARDS.filter((c) => c.hero === run.heroes[k] && c.extra && !run.mods[k].cards.includes(c.id)).map((c) => c.id);
    const k1 = newCards(ks[0]).length ? ks[0] : ks[1];
    if (newCards(k1).length) out.push({ type: 'card', k: k1, card: pickOf(newCards(k1)) });
    const k2 = out.length ? 1 - out[0].k : ks[0];
    out.push({ type: 'up', k: k2, what: run.mods[k2].up ? 'hp' : 'skill' });
    out.push({ type: 'heal', n: Math.min(RUN_LIFE_HEAL, LIFE - run.life) });
    return out;
  }
  // replace = カードの報酬で、入れ替える元のカード id
  function applyReward(run, opt, replace) {
    const m = opt.k != null ? run.mods[opt.k] : null;
    if (opt.type === 'card') { const i = m.cards.indexOf(replace); if (i >= 0) m.cards[i] = opt.card; }
    else if (opt.type === 'up') { if (opt.what === 'skill') m.up = true; else m.hp += 3; }
    else if (opt.type === 'heal') run.life = Math.min(LIFE, run.life + RUN_LIFE_HEAL);
  }

  const api = {
    LIFE, HAND_SIZE, MANA_MAX, SKILL_COST, KO_LIFE, REVIVE_WAIT, ENRAGE, POS_NAME, HEROES, HERO, CARDS, CARD, ENEMIES, ENEMY, ACT_NAME,
    SKILL_UP, BOSS, RUN_LIFE_HEAL, skillOf, patternOf, newRun, runFight, endFight, rewardOptions, applyReward,
    validateTeam, newGame, view, intent, check, act, endTurn, actions, findCard, botAction,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.Engine = api;
})(typeof self !== 'undefined' ? self : this);
