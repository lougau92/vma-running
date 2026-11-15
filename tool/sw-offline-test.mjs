/* eslint-env node */
import { chromium } from 'playwright';
import { join } from 'path';
import { spawn } from 'child_process';
import { createServer, Socket } from 'net';
import { existsSync, symlinkSync, rmSync } from 'fs';
import treeKill from 'tree-kill';

const root = join(process.cwd(), 'build', 'web');
const host = '127.0.0.1';

// 1. Safer Base Path Logic (Force trailing slash)
const rawBasePath = process.env.BASE_PATH || process.env.BASE_HREF || '/vma-running/';
const normalizedBasePath = rawBasePath.replace(/\/+$/, '').replace(/^\/+/, '');
// URL must end in / so './' resolves to current dir, not parent
const basePath = normalizedBasePath ? `/${normalizedBasePath}/` : '/';
const mountDir = normalizedBasePath ? join(root, normalizedBasePath) : null;

const getFreePort = async () => {
  return new Promise((resolve, reject) => {
    const srv = createServer();
    srv.listen(0, () => {
      const port = srv.address().port;
      srv.close(() => resolve(port));
    });
    srv.on('error', reject);
  });
};

if (mountDir && !existsSync(mountDir)) {
  console.log(`Creating symlink: ${mountDir} -> ${root}`);
  // Use 'junction' on Windows to avoid admin privilege requirements
  symlinkSync(root, mountDir, process.platform === 'win32' ? 'junction' : 'dir');
}

const port = process.env.SW_TEST_PORT || await getFreePort();
const server = spawn(process.execPath, [
  join(process.cwd(), 'node_modules', 'http-server', 'bin', 'http-server'),
  root, '-p', `${port}`,
], { stdio: 'inherit' });

function cleanup() {
  if (server && server.pid) treeKill(server.pid, 'SIGKILL');
  if (mountDir && existsSync(mountDir)) {
    console.log('Cleaning up symlink...');
    try { rmSync(mountDir, { recursive: true, force: true }); } catch (e) { }
  }

}

process.on('SIGINT', () => { cleanup(); process.exit(); });
process.on('SIGTERM', () => { cleanup(); process.exit(); });

const waitForServer = async (port) => {
  for (let i = 0; i < 50; i++) {
    try {
      await new Promise((resolve, reject) => {
        const socket = new Socket();
        socket.connect(port, host, () => { socket.end(); resolve(); });
        socket.on('error', (err) => reject(err));
      });
      return;
    } catch (e) { await new Promise((r) => setTimeout(r, 100)); }
  }
  throw new Error(`Server failed to start on port ${port}`);
};

(async () => {
  let browser;
  try {
    console.log(`Waiting for server on ${host}:${port}...`);
    await waitForServer(port);

    browser = await chromium.launch({
      headless: true,
      ...(process.env.CHROME_EXECUTABLE ? { executablePath: process.env.CHROME_EXECUTABLE } : {}),
    });
    // URL: http://127.0.0.1:8080/vma-running/
    const targetURL = `http://${host}:${port}${basePath}`;
    console.log(`Target URL: ${targetURL}`);

    const context = await browser.newContext({ baseURL: targetURL });
    const page = await context.newPage();

    // 2. ENABLE DEBUG LOGGING (Crucial for CI)
    page.on('console', msg => {
      if (msg.type() === 'error') console.error(`[BROWSER ERROR] ${msg.text()}`);
      else console.log(`[BROWSER LOG] ${msg.text()}`);
    });
    let offline = false;
    const offlineAssetErrors = [];
    page.on('requestfailed', (request) => {
      if (offline && (request.url().includes('/assets/') || request.url().includes('/canvaskit/'))) {
        const error = request.failure()?.errorText;
        if (error !== 'net::ERR_ABORTED') offlineAssetErrors.push(`${error}: ${request.url()}`);
      }
    });
    const pageErrors = [];
    page.on('pageerror', err => {
      pageErrors.push(err.message);
      console.error(`[BROWSER UNCAUGHT] ${err.message}`);
    });

    // Navigate
    await page.goto('./', { waitUntil: 'domcontentloaded' });

    // Wait for Service Worker - Relaxed Check
    console.log('Waiting for Service Worker ready...');
    // We evaluate a simple boolean to avoid serialization issues with ServiceWorkerRegistration objects
    await page.waitForFunction(async () => {
      if (!navigator.serviceWorker) return false;
      await navigator.serviceWorker.ready;
      return Boolean(navigator.serviceWorker.controller);
    }, null, { timeout: 10000 }); // 10s timeout for SW specifically

    // First worker takeover reloads the app. Wait for the real Flutter view so
    // renderer/fonts have also passed through the controlling worker.
    await page.waitForSelector('flutter-view', { state: 'attached', timeout: 30000 });
    console.log('Service Worker is Ready. Going offline...');
    offline = true;
    await context.setOffline(true);

    const cachedOk = await page.evaluate(async () => {
      try {
        // Use the relative path logic from your SW
        const res = await fetch('./assets/assets/training_plans/training_example.json');
        if (!res.ok) return false;
        await res.arrayBuffer();
        return true;
      } catch (e) {
        return false;
      }
    });

    if (!cachedOk) throw new Error('Cached training plan not available offline');

    await page.reload({ waitUntil: 'load' });
    await page.waitForSelector('flutter-view', { state: 'attached', timeout: 30000 });
    if (pageErrors.length) throw new Error(`App errors: ${pageErrors.join('; ')}`);
    if (offlineAssetErrors.length) throw new Error(`Missing offline assets: ${offlineAssetErrors.join('; ')}`);
    console.log('Offline Flutter restart passed!');
    console.log('Test Passed!');
    await context.setOffline(false);
  } catch (err) {
    console.error('Test Failed:', err);
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close();
    cleanup();
  }
})();