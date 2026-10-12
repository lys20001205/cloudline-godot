/* Shell-only browser regression; requires Playwright + Chromium.
 * No game-rendering or real-phone claim: engine downloads are intentionally mocked.
 * Run: node godot-cloudline/web-build/test_mobile_shell.cjs
 */
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const root = path.resolve(__dirname, '../../cloudline-godot');
(async () => {
  const server = http.createServer((req, res) => {
    const name = req.url === '/cloudline-godot/' ? 'index.html' : req.url.replace('/cloudline-godot/', '');
    if (!/^[\w.-]+$/.test(name) || !fs.existsSync(path.join(root, name))) {res.writeHead(404).end(); return;}
    res.setHeader('Content-Type', name.endsWith('.webmanifest') ? 'application/manifest+json' : name.endsWith('.html') ? 'text/html' : 'application/octet-stream');
    res.end(fs.readFileSync(path.join(root, name)));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}/cloudline-godot/`;
  let browser;
  let checks = 0;
  async function setup(options = {}, init = null) {
    const context = await browser.newContext({viewport: {width: 844, height: 390}, ...options});
    if (init) await context.addInitScript(init);
    const page = await context.newPage();
    await page.route('**/index.js', route => route.fulfill({contentType: 'application/javascript', body: 'window.Engine=class {static getMissingFeatures(){return []} startGame(){return Promise.resolve()}}'}));
    await page.goto(base);
    await page.waitForSelector('#loading', {state: 'hidden'});
    return {context, page};
  }
  try {
    browser = await chromium.launch({executablePath: process.env.CHROMIUM || '/usr/bin/chromium', headless: true, args: ['--no-sandbox']});
    let {context, page} = await setup();
    assert.equal(await page.locator('#display-button').innerText(), '进入全屏'); checks++;
    await page.locator('#display-button').click();
    await page.waitForFunction(() => document.fullscreenElement === document.documentElement); checks++;
    assert.equal(await page.locator('#display-button').innerText(), '退出全屏'); checks++;
    await page.locator('#display-button').click();
    await page.waitForFunction(() => !document.fullscreenElement); checks++;
    await page.locator('#display-button').click();
    await page.waitForFunction(() => !!document.fullscreenElement); checks++;
    await page.evaluate(() => document.exitFullscreen());
    await page.waitForFunction(() => document.querySelector('#display-button').textContent === '进入全屏'); checks++;
    await page.locator('#help-button').click();
    await page.locator('#close-help').click();
    assert.equal(await page.locator('#help').isVisible(), false); checks++;
    const dimensions = await page.evaluate(() => ({width: canvas.width, height: canvas.height, area: document.querySelector('#screen').getBoundingClientRect().toJSON()}));
    assert.equal(dimensions.width, dimensions.area.width); assert.equal(dimensions.height, dimensions.area.height); checks += 2;
    await page.setViewportSize({width: 390, height: 844});
    await page.waitForFunction(() => canvas.width === 390); checks++;
    await context.close();
    ({context, page} = await setup({}, () => {
      Element.prototype.requestFullscreen = () => Promise.reject(new Error('denied'));
    }));
    await page.locator('#display-button').click();
    await page.waitForSelector('#help:not([hidden])');
    assert.match(await page.locator('#feedback').innerText(), /未允许全屏/); checks++;
    await page.locator('#fullscreen-button').click();
    assert.equal(await page.locator('#help').isVisible(), true); checks++;
    await page.locator('#close-help').click();
    assert.equal(await page.locator('#help').isVisible(), false); checks++;
    await context.close();
    ({context, page} = await setup({isMobile: true, hasTouch: true, viewport: {width: 390, height: 844}}, () => {
      Element.prototype.requestFullscreen = undefined;
      Element.prototype.webkitRequestFullscreen = undefined;
    }));
    assert.equal(await page.locator('#display-button').innerText(), '添加到主屏幕'); checks++;
    await page.locator('#display-button').tap();
    assert.equal(await page.locator('#fullscreen-button').isVisible(), false); checks++;
    assert.match(await page.locator('#help').innerText(), /Safari.*分享.*添加到主屏幕/); checks++;
    await page.screenshot({path: '/tmp/cloudline-mobile-iphone-help.png'});
    await page.locator('#close-help').tap();
    await context.close();
    ({context, page} = await setup({}, () => Object.defineProperty(navigator, 'standalone', {value: true})));
    assert.match(await page.locator('#mode').innerText(), /主屏幕模式/); checks++;
    await page.locator('#display-button').click();
    assert.equal(await page.locator('#fullscreen-button').isVisible(), false); checks++;
    assert.match(await page.locator('#feedback').innerText(), /已从主屏幕打开/); checks++;
    const manifestURL = await page.locator('link[rel=manifest]').evaluate(el => el.href);
    const manifest = await (await page.request.get(manifestURL)).json();
    for (const field of ['id', 'scope', 'start_url']) { assert.equal(new URL(manifest[field], manifestURL).pathname, '/cloudline-godot/'); checks++; }
    for (const icon of manifest.icons) { assert.equal((await page.request.get(new URL(icon.src, manifestURL).href)).status(), 200); checks++; }
    assert.equal(manifest.display, 'standalone'); checks++;
    assert.equal(await page.locator('meta[name=apple-mobile-web-app-capable]').getAttribute('content'), 'yes'); checks++;
    await context.close();
    console.log(`PASS mobile shell: ${checks} checks (mocked engine; no real phone/3D validation)`);
  } finally { if (browser) await browser.close(); server.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
