// Offline-first service worker for VMA Running Companion.

// 1. DYNAMIC CACHE NAME (Injected by your build script)
const CACHE_NAME = 'vma-running-cache-v1';

// 2. RELATIVE PATHS (The Fix)
// Using './' forces the browser to resolve paths relative to the Service Worker's location
// (e.g., /vma-running/service_worker.js -> /vma-running/index.html)
const CORE_ASSETS = [
  './',                     // Resolves to /vma-running/
  './index.html',           // Resolves to /vma-running/index.html
  './manifest.json',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './flutter_bootstrap.js',
  './main.dart.js',
  './assets/AssetManifest.bin.json',
  './assets/FontManifest.json',
  // Note: Check your build folder. If you have double assets, keep this.
  // If you fixed pubspec, it might be './assets/training_plans/...'
  './assets/assets/training_plans/training_example.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      // atomic: if one fails (404), the whole install fails
      return cache.addAll(CORE_ASSETS);
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key.startsWith('vma-running-cache-') && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  const isSameOrigin = url.origin === self.location.origin;

  // --- 1. Navigation (App Shell) ---
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).catch(() => {
        // FALLBACK: Look for the RELATIVE index.html
        return caches.match('./index.html');
      })
    );
    return;
  }

  // --- 2. Fonts & Canvaskit (Cache First, Graceful) ---
  if (request.destination === 'font' || url.pathname.includes('canvaskit')) {
    event.respondWith(cacheFirst(request, { graceful: true }));
    return;
  }

  // --- 3. Static Assets (Cache First) ---
  if (
    isSameOrigin &&
    (request.destination === 'script' ||
      request.destination === 'style' ||
      request.destination === 'image' ||
      request.destination === 'font' ||
      url.pathname.endsWith('.json'))
  ) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // --- 4. Default (Network First) ---
  event.respondWith(networkFirst(request));
});

// Helper: Cache First Strategy
async function cacheFirst(request, { graceful = false } = {}) {
  // caches.match(request) automatically handles full URLs 
  // so it will match the absolute keys stored during install.
  const cached = await caches.match(request);
  if (cached) return cached;
  try {
    const response = await fetch(request);
    const cache = await caches.open(CACHE_NAME);
    cache.put(request, response.clone());
    return response;
  } catch (error) {
    if (graceful) {
      return new Response('', {
        status: 200,
        headers: { 'Content-Type': 'application/octet-stream' }
      });
    }
    throw error;
  }
}

// Helper: Network First Strategy
async function networkFirst(request) {
  try {
    const response = await fetch(request);
    const cache = await caches.open(CACHE_NAME);
    cache.put(request, response.clone());
    return response;
  } catch (error) {
    const cached = await caches.match(request);
    if (cached) return cached;
    throw error;
  }
}