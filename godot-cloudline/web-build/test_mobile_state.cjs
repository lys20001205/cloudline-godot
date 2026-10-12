// Deterministic controller tests with a DOM/Fullscreen API double, not a browser.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname, '../web-shell/index.html'), 'utf8');
const controller = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
let checks = 0;
function setup({supported = true, standalone = false, reject = false, prefixed = false} = {}) {
  const events = {}, els = {}, queries = {};
  const element = id => els[id] ||= {hidden: id === 'help', width: 0, height: 0, textContent: '', handlers: {}, addEventListener(k, cb) {this.handlers[k] = cb;}, focus() {document.focused = id;}, getBoundingClientRect() {return {width: 844, height: 346};}};
  const document = {documentElement: {}, fullscreenElement: null, getElementById: element, addEventListener(k, cb) {events[k] = cb;}};
  let calls = 0;
  const request = () => {calls++; if (reject) return Promise.reject(new Error('denied')); document.fullscreenElement = document.documentElement; return Promise.resolve().then(() => events.fullscreenchange());};
  if (supported) document.documentElement[prefixed ? 'webkitRequestFullscreen' : 'requestFullscreen'] = request;
  document.exitFullscreen = () => {document.fullscreenElement = null; events.fullscreenchange(); return Promise.resolve();};
  const window = {devicePixelRatio: 2, matchMedia: key => queries[key] ||= {matches: false, addEventListener() {}}, addEventListener() {}};
  vm.runInNewContext(controller, {document, window, navigator: {standalone}, Promise, Math});
  return {window, document, els, events, get calls() {return calls;}, click: id => element(id).handlers.click()};
}
const tick = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  let s = setup();
  assert.equal(s.els.canvas.width, 1688); assert.equal(s.els.canvas.height, 692); checks += 2;
  assert.equal(s.els['display-button'].textContent, '进入全屏'); checks++;
  s.click('display-button'); s.click('display-button'); assert.equal(s.calls, 1); checks++;
  await tick(); assert.equal(s.els['display-button'].textContent, '退出全屏'); checks++;
  s.click('display-button'); await tick(); assert.equal(s.document.fullscreenElement, null); checks++;
  s.click('display-button'); await tick(); assert.equal(s.calls, 2); checks++;
  await s.document.exitFullscreen(); assert.equal(s.els['display-button'].textContent, '进入全屏'); checks++;
  s.click('help-button'); assert.equal(s.els.help.hidden, false); s.click('close-help'); assert.equal(s.els.help.hidden, true); checks += 2;
  s = setup({reject: true}); s.click('display-button'); await tick();
  assert.match(s.els.feedback.textContent, /未允许全屏/); assert.equal(s.els.help.hidden, false); checks += 2;
  s.click('fullscreen-button'); await tick(); assert.equal(s.calls, 2); checks++;
  s.click('close-help'); assert.equal(s.document.focused, 'canvas'); checks++;
  s = setup({supported: false}); s.click('display-button');
  assert.equal(s.els['display-button'].textContent, '添加到主屏幕'); assert.equal(s.els['fullscreen-button'].hidden, true); assert.equal(s.els.help.hidden, false); checks += 3;
  s = setup({standalone: true}); s.click('display-button');
  assert.match(s.els.mode.textContent, /主屏幕模式/); assert.equal(s.calls, 0); assert.equal(s.els['fullscreen-button'].hidden, true); checks += 3;
  s = setup(); s.window.cloudlineDisplay.toggle(); await tick();
  assert.equal(s.document.fullscreenElement, s.document.documentElement); checks++;
  s.window.cloudlineDisplay.toggle(); await tick(); assert.equal(s.document.fullscreenElement, null); checks++;
  s = setup({prefixed: true}); s.click('display-button'); await tick(); assert.equal(s.calls, 1); checks++;
  console.log(`PASS ${checks} mobile controller checks (DOM/API doubles)`);
})().catch(e => {console.error(e); process.exitCode = 1;});
