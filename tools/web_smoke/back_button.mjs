// Browser Back check for a Web export built with web_back.gd injected (web_smoke.sh back).
// usage: node back_button.mjs <export_dir>
// Drives real history navigation (page.goBack / goForward / deep links) in headless Chrome and
// asserts the arcade follows: Back from a game -> gallery, never off the site.
import { chromium } from 'playwright-core';
import http from 'node:http'; import fs from 'node:fs'; import path from 'node:path';
const [dir] = process.argv.slice(2);
const types = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x'); const p = path.join(dir, u.pathname === '/' ? 'index.html' : u.pathname);
  if (!fs.existsSync(p)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'content-type': types[path.extname(p)] || 'application/octet-stream', 'cache-control': 'no-store' });
  res.end(fs.readFileSync(p));
}).listen(0);
const base = `http://127.0.0.1:${srv.address().port}/index.html`;
const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const errs = []; let state = null; let fails = 0;
page.on('console', m => { const t = m.text();
  const i = t.indexOf('WEBBACK '); if (i !== -1) { state = JSON.parse(t.slice(i + 8)); console.log('  state', t.slice(i + 8)); }
  if (m.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(t)) errs.push(t); });
page.on('pageerror', e => errs.push('pageerror: ' + e.message));
const ARCADE = 'res://arcade/main.tscn', TETRA = 'res://games/tetraminex/direct/game.tscn';
async function until(desc, pred, ms = 60000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) { if (state && pred(state)) { console.log('ok:', desc); return true; } await new Promise(r => setTimeout(r, 100)); }
  console.log('FAIL:', desc, JSON.stringify(state)); fails++; return false;
}
function check(desc, cond) { console.log(cond ? 'ok:' : 'FAIL:', desc); if (!cond) fails++; }
const settle = () => new Promise(r => setTimeout(r, 600));
const histLen = () => page.evaluate(() => history.length);

await page.goto(`${base}?back=1`);
await until('boot -> gallery', s => s.scene === ARCADE);
await settle();
const l0 = await histLen();

await page.evaluate(() => window.webBackLaunch('tetraminex', 'direct'));
await until('launch Tetraminex Direct', s => s.scene === TETRA && s.hash === '#play/tetraminex/direct'
  && (s.path || '').includes('/tetraminex/'));
check('launch pushed one history entry', await histLen() === l0 + 1);
check('pretty path on launch', page.url().includes('/tetraminex/'));

await page.goBack({ waitUntil: 'commit' });
await until('browser Back -> gallery', s => s.scene === ARCADE && s.hash === ''
  && !(s.path || '').includes('/tetraminex/'));
check('still on the arcade page after Back', page.url().startsWith(`${base}?back=1`));
check('gallery root path after Back', !page.url().includes('/tetraminex/'));

await page.goForward({ waitUntil: 'commit' });
await until('browser Forward -> Tetraminex again', s => s.scene === TETRA && s.hash === '#play/tetraminex/direct' && (s.path || '').includes('/tetraminex/'));

await settle();
await page.keyboard.press('Escape');
await until('Esc pauses with panel', s => s.scene === TETRA && s.paused && s.panel);
await page.goBack({ waitUntil: 'commit' });
await until('Back while paused -> gallery, unpaused, panel hidden', s => s.scene === ARCADE && !s.paused && !s.panel && s.hash === '');

await page.evaluate(() => window.webBackLaunch('tetraminex', 'direct'));
await until('relaunch', s => s.scene === TETRA && s.hash === '#play/tetraminex/direct' && (s.path || '').includes('/tetraminex/'));
const l1 = await histLen();
await settle();
await page.keyboard.press('Escape');
await until('Esc #1 pauses', s => s.paused && s.panel);
await page.keyboard.press('Escape');
await until('Esc #2 -> gallery, play hash replaced away', s => s.scene === ARCADE && !s.paused && !s.panel && s.hash === '' && !(s.path || '').includes('/tetraminex/'));
check('Esc return did not add or pop history', await histLen() === l1);

state = null;
await page.goto(`${base}?back=1&cold=1#play/tetraminex/direct`);
await until('cold deep link launches Tetraminex', s => s.scene === TETRA && s.hash === '#play/tetraminex/direct');
await page.goBack({ waitUntil: 'commit' });
await until('Back from deep link -> gallery', s => s.scene === ARCADE && s.hash === '');
check('deep-link Back stays on the page', page.url() === `${base}?back=1&cold=1`);

state = null;
await page.goto(`${base}?back=1&cold=2#play/no_such_game/direct`);
await until('invalid deep link -> gallery, hash cleared', s => s.scene === ARCADE && s.hash === '');

await settle();
console.log(JSON.stringify({ fails, errors: errs.length }));
if (errs.length) console.log('ERRORS:\n' + errs.join('\n'));
await browser.close(); srv.close();
process.exit(fails || errs.length ? 1 : 0);
