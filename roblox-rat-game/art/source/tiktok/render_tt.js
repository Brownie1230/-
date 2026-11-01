const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const [lang, mode, outDir, startArg, endArg] = process.argv.slice(2);
  const fps = 30;
  const b = await chromium.launch({ args: ['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 } });
  p.on('pageerror', e => console.log('pageerror:', e.message));
  p.on('console', m => { if (m.type() === 'error') console.log('console:', m.text()); });
  await p.goto(`http://localhost:8766/tiktok.html?lang=${lang}`);
  await p.waitForFunction(() => window.READY === true, null, { timeout: 120000 });
  fs.mkdirSync(outDir, { recursive: true });
  const wrap = p.locator('#wrap');
  let times = [];
  if (mode === 'test') { const tl = JSON.parse(fs.readFileSync('tt/timeline_' + lang + '.json')); times = tl.scenes.map(s => +(s.start + Math.min(2.4, (s.end - s.start) * 0.75)).toFixed(2)); }
  else { const s = +startArg || 0, e = +endArg || JSON.parse(fs.readFileSync('tt/timeline_' + lang + '.json')).total; for (let f = Math.round(s*fps); f < Math.round(e*fps); f++) times.push(f / fps); }
  const t0 = Date.now();
  for (const t of times) {
    await p.evaluate(t => window.renderFrame(t), t);
    const name = mode === 'test' ? `t${t.toFixed(1)}.png` : `f${String(Math.round(t*fps)).padStart(4,'0')}.png`;
    await wrap.screenshot({ path: `${outDir}/${name}` });
  }
  console.log(`rendered ${times.length} frames in ${((Date.now()-t0)/1000).toFixed(1)}s`);
  await b.close();
})();
