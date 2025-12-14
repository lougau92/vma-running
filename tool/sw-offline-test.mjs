/* eslint-env node */
import { chromium } from 'playwright';
import { join } from 'path';
import { spawn } from 'child_process';
import { createServer, Socket } from 'net';
import { existsSync, symlinkSync, rmSync } from 'fs'; // ADD: rmSync
import treeKill from 'tree-kill';

const root = join(process.cwd(), 'build', 'web');
const host = '127.0.0.1';

const rawBasePath = process.env.BASE_PATH || process.env.BASE_HREF || '/vma-running/';
const normalizedBasePath = rawBasePath.replace(/\/+$/, '').replace(/^\/+/, '');
const basePath = normalizedBasePath ? `/${normalizedBasePath}` : '';

// Define mountDir outside to access it in cleanup
const mountDir = normalizedBasePath ? join(root, normalizedBasePath) : null;

// 1. Cross-platform spawn command
const npmCmd = process.platform === 'win32' ? 'npx.cmd' : 'npx';

// Function to get a random free port
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

// Create Symlink
if (mountDir && !existsSync(mountDir)) {
  console.log(`Creating symlink: ${mountDir}`);
  symlinkSync(root, mountDir, process.platform === 'win32' ? 'junction' : 'dir');
}
const port = process.env.SW_TEST_PORT || await getFreePort();
const server = spawn(npmCmd, ['http-server', root, '-p', `${port}`], { stdio: 'inherit' });

function cleanup() {
  if (server && server.pid) treeKill(server.pid, 'SIGKILL');

  // ADD: Remove the symlink so it doesn't get deployed
  if (mountDir && existsSync(mountDir)) {
    console.log('Cleaning up symlink...');
    try {
      rmSync(mountDir, { recursive: true, force: true });
    } catch (e) {
      console.error('Failed to cleanup symlink:', e);
    }
  }
}

// Ensure server stops if the process is manually terminated
process.on('SIGINT', () => { stopServer(); process.exit(); });
process.on('SIGTERM', () => { stopServer(); process.exit(); });

// 2. Helper to wait for server port instead of hardcoded 800ms
const waitForServer = async (port) => {
  const retryInterval = 100;
  const maxRetries = 50; // Wait up to 5 seconds
  for (let i = 0; i < maxRetries; i++) {
    try {
      await new Promise((resolve, reject) => {
        const socket = new Socket();
        socket.connect(port, host, () => {
          socket.end();
          resolve();
        });
        socket.on('error', (err) => reject(err));
      });
      return; // Connection successful
    } catch (e) {
      await new Promise((r) => setTimeout(r, retryInterval));
    }
  }
  throw new Error(`Server failed to start on port ${port}`);
};

(async () => {
  try {
    console.log('Waiting for server...');

    console.log(`Starting server on port: ${port}`);

    await waitForServer(port);

    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({ baseURL: `http://${host}:${port}${basePath}` });;
    const page = await context.newPage();

    const consoleErrors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    // 3. Robust Navigation
    await page.goto('./', { waitUntil: 'domcontentloaded' }); // 'networkidle' can be flaky with SWs

    // Wait for Service Worker activation
    await page.waitForFunction(() => navigator.serviceWorker?.ready);

    console.log('Going offline...');
    await context.setOffline(true);

    const cachedOk = await page.evaluate(async () => {
      try {
        const res = await fetch('assets/assets/training_plans/training_example.json');
        return res.ok;
      } catch (e) {
        return false;
      }
    });

    if (!cachedOk) {
      throw new Error('Cached training plan not available offline');
    }

    // Filter errors (same as your logic)
    const fontErrors = consoleErrors.filter((msg) =>
      msg.toLowerCase().includes('font') && msg.toLowerCase().includes('failed'),
    );
    if (fontErrors.length > 0) {
      throw new Error('Font errors observed offline: ' + fontErrors.join(' | '));
    }

    console.log('Test Passed!');
    await context.setOffline(false);
    await browser.close();
  } catch (err) {
    console.error(err);
    process.exitCode = 1;
  } finally {
    cleanup(); // Ensure cleanup runs even if test fails
  }
})();
