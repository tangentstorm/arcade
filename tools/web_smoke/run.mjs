// Serve a Web export (gzip, like GitHub Pages) and load it in headless Chrome.
// usage: node run.mjs <export_dir> <smoke|boot> [screenshot.png]
//   boot : pass when the engine prints its "Godot Engine v" banner with no console errors
//   smoke: pass when web_smoke.gd prints "WEBSMOKE DONE failures=0" with no console errors
import { chromium } from 'playwright-core';
import http from 'node:http'; import fs from 'node:fs'; import path from 'node:path'; import zlib from 'node:zlib';
const [dir, mode = 'boot', shot] = process.argv.slice(2);
const types = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const cache = {};
const srv = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://x'); const p = path.join(dir, u.pathname === '/' ? 'index.html' : u.pathname);
  if (!fs.existsSync(p)) { res.writeHead(404); return res.end(); }
  const ext = path.extname(p);
  const h = { 'content-type': types[ext] || 'application/octet-stream', 'cache-control': 'no-store' };
  let body = fs.readFileSync(p);
  if (ext !== '.png' && /gzip/.test(req.headers['accept-encoding'] || '')) { body = cache[p] ??= zlib.gzipSync(body, { level: 9 }); h['content-encoding'] = 'gzip'; }
  res.writeHead(200, h); res.end(body);
}).listen(0);
const port = srv.address().port;
const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome',
  args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const t0 = Date.now(); let tBoot = null, done = null; const errs = [], lines = [];
page.on('console', m => { const t = m.text(); lines.push(`[${m.type()}] ${t}`);
  if (tBoot === null && /Godot Engine v/.test(t)) tBoot = Date.now() - t0;
  if (/WEBSMOKE DONE/.test(t)) done = t;
  if (m.type() === 'error' || /SCRIPT ERROR|ERROR:|WEBSMOKE FAIL/.test(t)) errs.push(t); });
page.on('pageerror', e => errs.push('pageerror: ' + e.message));
await page.goto(`http://127.0.0.1:${port}/index.html${mode === 'smoke' ? '?smoke=all' : ''}`);
const limit = mode === 'smoke' ? 600000 : 120000;
while (Date.now() - t0 < limit) { if (mode === 'smoke' ? done : tBoot !== null) break; await new Promise(r => setTimeout(r, 250)); }
if (mode === 'boot') await new Promise(r => setTimeout(r, 3000));
if (shot) await page.screenshot({ path: shot });
console.log(lines.filter(l => mode === 'smoke' ? /WEBSMOKE|ERROR|error/.test(l) : true).join('\n'));
console.log(JSON.stringify({ mode, boot_ms: tBoot, done, errors: errs.length }));
if (errs.length) console.log('ERRORS:\n' + errs.join('\n'));
await browser.close(); srv.close();
const ok = !errs.length && tBoot !== null && (mode !== 'smoke' || /failures=0/.test(done || ''));
process.exit(ok ? 0 : 1);
