const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'] });
  for (const [mode,w,h,out] of [['icon',512,512,'icon.png'],['thumb',1920,1080,'thumbnail.png']]) {
    const p = await b.newPage({ viewport: { width: w, height: h } });
    p.on('console', m => console.log('console:', m.text()));
    p.on('pageerror', e => console.log('pageerror:', e.message));
    await p.goto(`http://localhost:8765/scene.html?mode=${mode}&w=${w}&h=${h}`);
    await p.waitForFunction(() => window.DONE === true, null, { timeout: 60000 });
    await p.waitForTimeout(500);
    await p.locator('#wrap').screenshot({ path: '/home/user/-/roblox-rat-game/art/' + out });
  }
  await b.close();
})();
