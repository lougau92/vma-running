import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { test } from 'node:test';
import { chromium } from 'playwright';

const worker = readFileSync(new URL('../web/service_worker.js', import.meta.url), 'utf8');
const update = readFileSync(new URL('../web/app_update.js', import.meta.url), 'utf8');
const index = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');

// Reproduce the previous worker's unscoped cache lookup and HTTP-cached
// precache requests so migration is covered as well as future upgrades.
const legacyWorker = `
const CACHE_NAME = 'vma-running-cache-test-1';
self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll([
    './', './index.html', './flutter_bootstrap.js', './main.dart.js'
  ])));
  self.skipWaiting();
});
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));
self.addEventListener('fetch', (event) => {
  event.respondWith(event.request.mode === 'navigate'
    ? fetch(event.request)
    : caches.match(event.request).then((cached) => cached || fetch(event.request)));
});
`;

for (const { base, legacy } of [
  { base: '/', legacy: false },
  { base: '/vma-running/', legacy: false },
  { base: '/vma-running/', legacy: true },
]) {
  test(`installed app updates and stays usable offline at ${base} (legacy: ${legacy})`, { timeout: 45000 }, async () => {
    let release = 1;
    let broken = false;
    const server = createServer((request, response) => {
      const path = new URL(request.url, 'http://localhost').pathname;
      if (!path.startsWith(base)) {
        response.writeHead(404).end();
        return;
      }
      const asset = path.slice(base.length);
      // Deliberately keep HTTP assets fresh across deployments, like an
      // existing browser session. Installation must bypass this cache.
      response.setHeader('Cache-Control', 'public, max-age=3600');
      if (asset === 'service_worker.js') {
        response.setHeader('Content-Type', 'text/javascript');
        response.end(legacy && release === 1 ? legacyWorker
          : worker.replace("'vma-running-cache-v1'", `'vma-running-cache-test-${release}'`));
      } else if (asset === '' || asset === 'index.html') {
        response.setHeader('Content-Type', 'text/html');
        response.setHeader('Cache-Control', 'no-cache');
        response.end(index.replace('$FLUTTER_BASE_HREF', base));
      } else if (asset === 'app_update.js') {
        response.setHeader('Content-Type', 'text/javascript');
        response.end(update);
      } else if (asset === 'flutter_bootstrap.js') {
        response.setHeader('Content-Type', 'text/javascript');
        response.end("const entry = document.createElement('script'); entry.src = 'main.dart.js'; document.head.append(entry);");
      } else if (asset === 'main.dart.js') {
        response.setHeader('Content-Type', 'text/javascript');
        if (broken) response.writeHead(503).end('Deployment incomplete');
        else response.end(`document.body.dataset.release = '${release}';`);
      } else {
        if (asset === 'uncacheable.json') response.setHeader('Vary', '*');
        response.setHeader('Content-Type', 'application/json');
        response.end(JSON.stringify({ release }));
      }
    });
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const url = `http://127.0.0.1:${server.address().port}${base}`;
    let browser;
    try {
      browser = await chromium.launch({
        headless: true,
        ...(process.env.CHROME_EXECUTABLE ? { executablePath: process.env.CHROME_EXECUTABLE } : {}),
      });
      const context = await browser.newContext();
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', (error) => errors.push(error.message));
      await page.goto(url);
      await page.waitForFunction(() => document.body.dataset.release === '1');
      await page.waitForFunction(() => Boolean(navigator.serviceWorker.controller));
      await page.waitForLoadState('load');
      await page.waitForFunction(() => document.body.dataset.release === '1');
      await page.evaluate(async () => {
        localStorage.setItem('saved-vma', '20.05');
        document.cookie = 'saved-preference=keep; SameSite=Lax';
        // A legacy Flutter cache must never override a release's assets.
        const legacy = await caches.open('flutter-app-cache');
        await legacy.put(new URL('late.json', document.baseURI), new Response('{"release":0}'));
      });
      const late = await page.evaluate(async () => (await fetch('late.json')).json());
      assert.equal(late.release, legacy ? 0 : 1,
        'legacy cache bug is reproduced before verifying migration');

      release = 2;
      if (!legacy) {
        const stillInstalled = await page.evaluate(async () =>
          (await fetch(`version.json?cachebuster=${Date.now()}`)).json());
        assert.equal(stillInstalled.release, 1, 'reported version follows installed code until activation');
      }
      // Exercise the real reconnect listener, without clearing cookies/cache
      // or manually reloading the page.
      await page.evaluate(() => window.dispatchEvent(new Event('online')));
      await page.waitForFunction(() => document.body.dataset.release === '2');
      const state = await page.evaluate(async () => ({
        vma: localStorage.getItem('saved-vma'),
        cookie: document.cookie,
        version: await (await fetch(`version.json?cachebuster=${Date.now()}`)).json(),
        keys: await caches.keys(),
        registrations: (await navigator.serviceWorker.getRegistrations()).map((r) => r.active?.scriptURL),
      }));
      assert.equal(state.vma, '20.05');
      assert.match(state.cookie, /saved-preference=keep/);
      assert.equal(state.version.release, 2, 'version and running code belong to the same release');
      const freshLate = await page.evaluate(async () => (await fetch('late.json')).json());
      assert.equal(freshLate.release, 2, 'new worker ignores the legacy Flutter cache');
      const uncacheable = await page.evaluate(async () =>
        (await fetch('uncacheable.json')).json());
      assert.equal(uncacheable.release, 2, 'cache-write failure does not discard a network response');
      assert.ok(!state.keys.includes('vma-running-cache-test-1'));
      assert.deepEqual(state.registrations, [new URL('service_worker.js', url).href]);

      // A partially published release must not displace the working one.
      release = 3;
      broken = true;
      const rejected = await page.evaluate(async () => {
        const registration = await navigator.serviceWorker.getRegistration();
        await registration.update();
        const installing = registration.installing;
        if (!installing) return false;
        return new Promise((resolve) => {
          const check = () => {
            if (installing.state === 'redundant') resolve(true);
            if (installing.state === 'activated') resolve(false);
          };
          installing.addEventListener('statechange', check);
          check();
        });
      });
      assert.equal(rejected, true, 'failed precache retains the previous worker');
      await context.setOffline(true);
      await page.reload({ waitUntil: 'load' });
      await page.waitForFunction(() => document.body.dataset.release === '2');
      const offlinePlan = await page.evaluate(async () =>
        (await fetch('assets/assets/training_plans/training_example.json')).json());
      assert.equal(offlinePlan.release, 2);
      const offlineVersion = await page.evaluate(async () =>
        (await fetch(`version.json?cachebuster=${Date.now()}`)).json());
      assert.equal(offlineVersion.release, 2);
      assert.deepEqual(errors, []);
    } finally {
      if (browser) await browser.close();
      await new Promise((resolve) => server.close(resolve));
    }
  });
}
