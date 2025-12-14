/* eslint-env node */
import { chromium } from 'playwright';
import { join } from 'path';
import { spawn } from 'child_process';
import { createServer, Socket } from 'net';
import { existsSync, symlinkSync, unlinkSync, rmSync } from 'fs'; // Added cleanup imports
import treeKill from 'tree-kill';

const root = join(process.cwd(), 'build', 'web');
const host = '127.0.0.1';

// 1. Detect Base Path
// Defaults to '/vma-running/' if not set in env
const rawBasePath = process.env.BASE_PATH || process.env.BASE_HREF || '/vma-running/';
const normalizedBasePath = rawBasePath.replace(/\/+$/, '').replace(/^\/+/, '');
const basePath = normalizedBasePath ? `/${normalizedBasePath}` : '';
const mountDir = normalizedBasePath ? join(root, normalizedBasePath) : null;

// 2. Cross-platform spawn
const npmCmd = process.platform === 'win32' ? 'npx.cmd' : 'npx';

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

// 3. Create Symlink (The "Mock" Subdirectory)
if (mountDir && !existsSync(mountDir)) {
  console.log(`Creating symlink for testing: ${mountDir} -> ${root}`);
  try {
    symlinkSync(root, mountDir, process.platform === 'win32' ? 'junction' : 'dir');
  } catch (e) {
    console.warn('Warning: Could not create symlink. Test might fail if base-href is required.', e);
  }
}

const port = process.env.SW_TEST_PORT || await getFreePort();
const server = spawn(npmCmd, ['http-server', root, '-p', `${port}`], {
  stdio: 'inherit',
});

function cleanup() {
  // KILL SERVER
  if (server && server.pid) {
    treeKill(server.pid, 'SIGKILL', (err) => {
      if (err) console.error('Failed to kill server:', err);
    });
  }

  // REMOVE SYMLINK (CRITICAL FOR DEPLOY)
  if (mountDir && existsSync(mountDir)) {
    console.log('Cleaning up symlink...');
    try {
      // unlinkSync works for symlinks, but on Windows junctions sometimes act like dirs
      // rmSync is safer for recursive cleanup if needed, but unlink usually suffices
      unlinkSync(mountDir);
    } catch (e) {
      // Fallback if unlink fails (e.g. treated as directory)
      try { rmSync(mountDir, { recursive: true, force: true }); } catch (e2) { }
    }
  }
}

// Ensure cleanup happens on exit
process.on('SIGINT', () => { cleanup(); process.exit(); });
process.on('SIGTERM', () => { cleanup(); process.exit(); });

const waitForServer = async (port) => {
  const retryInterval = 100;
  const maxRetries = 50;
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
      return;
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
    // IMPORTANT: Base URL includes the path now!
    const context = await browser.newContext({ baseURL: `http://${host}:${port}${basePath}` });
    const page = await context.newPage();

    const consoleErrors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    // Navigate to relative root (which is now /vma-running/ because of baseURL)
    await page.goto('./', { waitUntil: 'domcontentloaded' });

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
    console.error('Test Failed:', err);
    process.exitCode = 1;
  } finally {
    cleanup(); // Always run cleanup even if test fails
  }
})();