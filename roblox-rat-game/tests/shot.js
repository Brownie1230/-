const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1.5 });
  await p.goto('http://localhost:8767/render.html');
  for (const f of ['shop_hats_ru', 'shop_pets_en', 'shop_robux_ru']) {
    await p.evaluate(f => window.draw(f + '.json'), f);
    await p.waitForTimeout(300);
    await p.screenshot({ path: f + '.png' });
  }
  await b.close();
})();
