// 画面の通しテスト兼スクリーンショット。 node tools/shots.js <出力フォルダ> [幅x高さ ...]
// 計測用CPUの手を、実際の画面のタップで打って3連戦を進める。途中の各画面を撮り、エラー・はみ出しを調べる。
'use strict';
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const out = process.argv[2];
const sizes = process.argv.slice(3).length ? process.argv.slice(3) : ['375x650', '390x844'];
if (!out) { console.error('出力フォルダを指定'); process.exit(1); }
fs.mkdirSync(out, { recursive: true });
const root = path.join(__dirname, '..');

// テスト用のページ：index.html を HTML の骨組みで包み、中の状態を覗く口を足す
const page = '<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head><body>'
  + fs.readFileSync(path.join(root, 'index.html'), 'utf8').replace(/\n  title\(\);\n/, '\n  window.__dbg = { get game() { return game; }, get run() { return run; } };\n  title();\n')
  + '</body></html>';
if (!page.includes('__dbg')) { console.error('覗く口を足せなかった'); process.exit(1); }
fs.writeFileSync(path.join(out, 'test.html'), page);
fs.copyFileSync(path.join(root, 'engine.js'), path.join(out, 'engine.js'));
fs.copyFileSync(path.join(root, 'tools', 'bot.js'), path.join(out, 'bot.js'));

(async () => {
  const b = await chromium.launch();
  let bad = 0;
  for (const size of sizes) {
    const [w, h] = size.split('x').map(Number);
    const p = await b.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    const errs = [];
    p.on('pageerror', (e) => errs.push(e.message));
    p.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
    await p.goto('file://' + path.join(out, 'test.html'));
    await p.evaluate(() => localStorage.setItem('futari-pve-settings', JSON.stringify({ auto: false })));
    await p.reload();
    // 計測用CPUをページに入れる
    await p.addScriptTag({ content: 'window.module = { exports: {} };' });
    await p.addScriptTag({ path: path.join(out, 'bot.js') });
    await p.evaluate(() => { window.Bot = window.module.exports; });

    const issues = [];
    const shot = async (name) => {
      await p.screenshot({ path: path.join(out, `${size}-${name}.png`) });
      // はみ出し：ページの横スクロール、画面からはみ出た要素、文字が切れた要素
      const r = await p.evaluate(() => {
        const out = [];
        const de = document.documentElement;
        if (de.scrollWidth > de.clientWidth + 1) out.push(`横にはみ出し ${de.scrollWidth}>${de.clientWidth}`);
        if (de.scrollHeight > de.clientHeight + 1) out.push(`縦にはみ出し ${de.scrollHeight}>${de.clientHeight}`);
        for (const el of document.querySelectorAll('#app *, .overlay *')) {
          const cs = getComputedStyle(el);
          if (cs.display === 'none' || cs.visibility === 'hidden') continue;
          const r = el.getBoundingClientRect();
          if (!r.width || !r.height) continue;
          // スクロールできる枠の中身は対象外
          let sc = el.parentElement, inScroll = false;
          while (sc) { const o = getComputedStyle(sc).overflowY; if (o === 'auto' || o === 'scroll') { inScroll = true; break; } sc = sc.parentElement; }
          if (!inScroll && (r.right > innerWidth + 1 || r.left < -1 || r.bottom > innerHeight + 1)) out.push(`画面の外 ${el.className || el.tagName} ${Math.round(r.right)}x${Math.round(r.bottom)}`);
          if (cs.textOverflow === 'ellipsis' && el.scrollWidth > el.clientWidth + 1) out.push(`文字切れ ${el.className}「${el.textContent.trim().slice(0, 20)}」`);
          if ((el.tagName === 'BUTTON' || el.getAttribute('role') === 'button') && r.height < 40 && !el.disabled) out.push(`押す場所が低い ${el.className || el.id} ${Math.round(r.height)}px「${el.textContent.trim().slice(0, 12)}」`);
        }
        const box = (q) => { const el = document.querySelector(q); return el && getComputedStyle(el).display !== 'none' ? el.getBoundingClientRect() : null; };
        const life = box('.life'), hand = box('.hand'), detail = box('.detail'), act = box('.act');
        if (life && hand && life.bottom > hand.top + 1) out.push(`ライフの帯が手札に重なる ${Math.round(life.bottom - hand.top)}px`);
        if (life && detail && !hand && life.bottom > detail.top + 1) out.push('ライフの帯が説明欄に重なる');
        if (detail && act && detail.bottom > act.top + 1) out.push('説明欄がボタンに重なる');
        for (const el of document.querySelectorAll('.hero')) { if (el.scrollHeight > el.clientHeight + 1) out.push(`ヒーロー枠の中身がはみ出す ${el.scrollHeight}>${el.clientHeight}`); }
        for (const q of ['.estat', '.hr-name span', '.hero .nm', '.hero .nums', '.hero .flags', '.upnext', '.card b']) for (const el of document.querySelectorAll(q)) {
          if (el.scrollWidth > el.clientWidth + 1) out.push(`横に切れる ${q}「${el.textContent.trim().slice(0, 16)}」`);
        }
        for (const el of document.querySelectorAll('.hero > span:not(.pops):not(.hpbar)')) { const r = el.getBoundingClientRect(), pr = el.parentElement.getBoundingClientRect(); if (r.height && r.bottom > pr.bottom - 4) out.push(`ヒーロー枠の下に切れる「${el.textContent.trim().slice(0, 16)}」`); }
        const hitTest = (r1, r2) => Math.min(r1.right, r2.right) - Math.max(r1.left, r2.left) > 2 && Math.min(r1.bottom, r2.bottom) - Math.max(r1.top, r2.top) > 2;
        for (const hero of document.querySelectorAll('.hero, .enemy')) for (const pop of hero.querySelectorAll('.pops .pop')) for (const t of hero.querySelectorAll('.nums > span, .flags i, .fore, .nm b, .hpn')) {
          if (getComputedStyle(t).visibility !== 'hidden' && hitTest(pop.getBoundingClientRect(), t.getBoundingClientRect())) out.push(`数字「${pop.textContent}」が「${t.textContent.trim().slice(0, 10)}」に重なる`);
        }
        for (const tag of document.querySelectorAll('.card .tag')) { const r = tag.getBoundingClientRect(), c = tag.closest('.card').getBoundingClientRect(); if (r.right > c.right + 1 || r.left < c.left - 1) out.push(`札がカードの外「${tag.textContent}」`); }
        for (const row of document.querySelectorAll('.frow')) { const cs = [...row.querySelectorAll('.cell')].map((c) => Math.round(c.getBoundingClientRect().width)); if (Math.abs(cs[0] - cs[1]) > 1) out.push(`列の幅がずれる ${cs.join('/')}`); }
        for (const el of document.querySelectorAll('.card b, .hr-name b, .hr-name span')) { if (el.getBoundingClientRect().height > 20) out.push(`折り返している「${el.textContent.trim()}」`); }
        return [...new Set(out)];
      });
      for (const x of r) issues.push(`${name}: ${x}`);
    };
    const skipPlay = async (cap) => {
      for (let i = 0; i < 80; i++) {
        if (await p.$('.overlay')) break;
        if (!(await p.$('#next'))) break;
        if (cap && i === 0) await shot(cap);
        await p.click('#next');
      }
    };

    await shot('01-title');
    await p.click('#rules'); await shot('02-rules'); await p.click('#back');
    await p.click('#pick'); await shot('03-pick'); await p.click('#back');
    // 1人外したまま「戻る」でも、タイトルに戻れる（選ぶ前の組のまま）
    await p.click('#pick'); await p.click('[data-hero][aria-pressed="true"]'); await p.click('#back');
    if (!(await p.$('#go'))) errs.push('ヒーローを1人外して「戻る」でタイトルに戻れない');
    await p.click('#go'); await shot('04-route');
    const log = [];
    for (let fight = 0; fight < 3; fight++) {
      await p.click('#fight');
      await skipPlay(fight === 0 ? '05-round-start' : null);
      let turn = 0;
      const did = {};
      for (let guard = 0; guard < 60 && !(await p.$('.overlay')); guard++) {
        turn++;
        if (fight === 0 && turn === 1) await shot('06-my-turn');
        const seq = await p.evaluate(() => window.Bot.planTurn(window.Engine, window.__dbg.game));
        let auto = false;
        const round0 = await p.evaluate(() => window.__dbg.game.round);
        for (const a of seq) {
          if (await p.$('.overlay')) break;
          if (await p.$('#next')) { auto = true; break; }      // マナ0で自動的にターンが終わった
          if (a.type === 'move') {
            if (!did.focus) { did.focus = 1; await p.click(`[data-hero="${a.k}"]`); await shot('08-hero-focus'); await p.click('#cancel'); }
            await p.click(`[data-move="${a.k}"]`);
            if (!did.move) { did.move = 1; await shot('08b-move'); }
            await p.click('#use');
          } else if (a.type === 'skill') {
            await p.click(`[data-skill="${a.k}"]`);
            if (a.target === 0 || a.target === 1) await p.click(`[data-hero="${a.target}"]`);
            if (!did.skill) { did.skill = 1; await shot('09-skill'); }
            await p.click('#use');
          } else {
            await p.click(`[data-card="${a.uid}"]`);
            if (a.target === 0 || a.target === 1) { await p.click(`[data-hero="${a.target}"]`); if (!did.ally) { did.ally = 1; await shot('10-card-ally'); } }
            else if (!did.card) { did.card = 1; await shot('07-card-selected'); }
            await p.click('#use');
          }
          if (!did.after || (a.type === 'skill' && !did.afterSkill)) { await shot(a.type === 'skill' ? '11b-after-skill' : '11-after-action'); did.after = 1; if (a.type === 'skill') did.afterSkill = 1; }
          await skipPlay(null);
        }
        if (await p.$('.overlay')) break;
        if (!auto && await p.$('#endturn') && round0 === await p.evaluate(() => window.__dbg.game.round)) {   // 自動でターンが終わっていたら押さない
          if (!did.enemy) { did.enemy = 1; await p.click('[data-target="enemy"]'); await shot('12-enemy-focus'); await p.click('#cancel'); }
          await p.click('#endturn');
        }
        await skipPlay(!did.foe ? '13-enemy-action' : null); did.foe = 1;
      }
      const txt = (await p.$eval('.overlay', (o) => o.innerText)).replace(/\n+/g, ' ');
      log.push(txt);
      await shot(`20-result-${fight}`);
      if (!(await p.$('#next-r'))) break;
      await p.click('#next-r');
      await shot(`21-reward-${fight}`);
      await p.click(`[data-opt="${fight === 0 ? 0 : 1}"]`);
      await p.click('#take');
      if (await p.$('[data-rep]')) { await p.click('[data-rep="1"]'); await shot('22-swap'); await p.click('#take'); }
      await shot(`23-route-${fight + 1}`);
    }
    // 込み入った場面：状態をたくさん付けた盤面を作って撮る
    await p.evaluate(() => localStorage.setItem('futari-pve-settings', JSON.stringify({ auto: false })));
    await p.goto('file://' + path.join(out, 'test.html'));
    await p.click('#go'); await p.click('#fight'); await skipPlay(null);
    await p.evaluate(() => {
      const g = window.__dbg.game;
      Object.assign(g.heroes[0], { shield: 12, taunt: true, counter: 6, focus: 2, hp: 3 });
      Object.assign(g.heroes[1], { shield: 5, guard: 0, focus: 4, hp: 2, pos: g.heroes[0].pos });
      Object.assign(g.enemy, { shield: 6, charge: 9, weak: 3, poison: 6, loops: 3, acted: 16, hp: 9 });
      g.life = 3;
    });
    await p.click('[data-target="enemy"]'); await p.click('#cancel');
    await shot('30-stress-mine');
    await p.click('#endturn');
    for (let i = 0; i < 6 && await p.$('#next') && !(await p.$('.overlay')); i++) { await shot(`31-stress-play${i}`); await p.click('#next'); }
    if (!(await p.$('.overlay'))) await shot('32-stress-next-mine');
    // 自動再生で、長い説明で止まったあと「再開」で進むこと
    await p.evaluate(() => localStorage.setItem('futari-pve-settings', JSON.stringify({ auto: true })));
    await p.goto('file://' + path.join(out, 'test.html'));
    await p.click('#go'); await p.click('#fight');
    await p.waitForSelector('#endturn', { timeout: 20000 });
    await p.evaluate(() => { const g = window.__dbg.game; g.life = 20; Object.assign(g.heroes[0], { hp: 30, maxHp: 30, counter: 3, taunt: true, shield: 2 }); Object.assign(g.heroes[1], { hp: 1, guard: 0, pos: g.heroes[0].pos }); Object.assign(g.enemy, { id: 'spider', step: 4, charge: 5, weak: 2, loops: 1, poison: 2 }); });
    await p.click('#endturn');
    await p.waitForTimeout(1500);
    const before = await p.evaluate(() => document.querySelector('.detail .dh') && document.querySelector('.detail .dh').textContent);
    const stopped = await p.evaluate(() => { const b = document.querySelector('#pause'); return b && b.textContent; });
    await shot('33-auto-overflow');
    if (size === '375x650' && stopped !== '再開') issues.push('33-auto-overflow: 説明があふれる場面を作れていない（検査が空振り）');
    if (stopped === '再開') {
      await p.click('#pause');
      await p.waitForTimeout(1500);
      const after = await p.evaluate(() => document.querySelector('.detail .dh') ? document.querySelector('.detail .dh').textContent : 'mine');
      if (after === before) issues.push('33-auto-overflow: 「再開」を押しても進まない');
    }
    console.log(`■ ${size}`);
    for (const l of log) console.log('  ' + l);
    if (errs.length) { bad++; console.log('  エラー:', errs); }
    const uniq = [...new Set(issues)];
    if (uniq.length) { bad++; for (const i of uniq) console.log('  ! ' + i); } else console.log('  はみ出し・文字切れ・低いボタンなし');
    await p.close();
  }
  await b.close();
  process.exit(bad ? 1 : 0);
})();
