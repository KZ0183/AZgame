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
          await skipPlay(!did.play ? '11-playback' : null); did.play = 1;
        }
        if (await p.$('.overlay')) break;
        if (!auto && await p.$('#endturn')) {
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
      if (await p.$('[data-rep]')) { await shot('22-swap'); await p.click('[data-rep="1"]'); }
      await shot(`23-route-${fight + 1}`);
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
