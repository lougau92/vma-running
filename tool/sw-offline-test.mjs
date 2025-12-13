/* eslint-env node */
import { chromium } from 'playwright';
import { join } from 'path';
import { spawn } from 'child_process';
import { createServer, Socket } from 'net'; // Used to check if port is ready
import treeKill from 'tree-kill';

const root = join(process.cwd(), 'build', 'web');

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

const port = process.env.SW_TEST_PORT || await getFreePort();
const server = spawn(npmCmd, ['http-server', root, '-p', `${port}`], {
  stdio: 'inherit',
});

function stopServer() {
  if (server && server.pid) {
    treeKill(server.pid, 'SIGKILL', (err) => {
      if (err) console.error('Failed to kill server:', err);
    });
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
        socket.connect(port, 'localhost', () => {
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
  console.log('Waiting for server...');

  console.log(`Starting server on port: ${port}`);

  await waitForServer(port);

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ baseURL: `http://localhost:${port}` });
  const page = await context.newPage();

  const consoleErrors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });

  // 3. Robust Navigation
  await page.goto('/', { waitUntil: 'domcontentloaded' }); // 'networkidle' can be flaky with SWs

  // Wait for Service Worker activation
  await page.waitForFunction(() => navigator.serviceWorker?.ready);

  // 4. Replaced waitForTimeout(500)
  // Instead of waiting blindly, we try to ensure the specific resource is cached
  // or simply proceed if your SW caches on 'install/activate'. 
  // If you must wait for the cache to populate, try waiting for a specific console log 
  // from your SW or a specific network state.

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
  stopServer();
})().catch((err) => {
  stopServer();
  console.error(err);
  process.exit(1);
});