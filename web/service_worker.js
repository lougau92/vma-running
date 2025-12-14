// Offline-first service worker for VMA Running Companion.
// Caches core shell assets and serves navigation requests from cache when offline.

const CACHE_NAME = 'vma-running-cache-v1';
const CORE_ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './flutter_bootstrap.js',
  './main.dart.js',
  './assets/AssetManifest.bin.json',
  './assets/FontManifest.json',
  './assets/assets/training_plans/training_example.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(CORE_ASSETS)),
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key.startsWith('vma-running-cache-') && key !== CACHE_NAME)
          .map((key) => caches.delete(key)),
      ),
    ),
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  const isSameOrigin = url.origin === self.location.origin;

  // Fonts (including Google Fonts): cache-first with graceful fallback to avoid noisy errors offline.
  if (request.destination === 'font' || url.hostname.includes('fonts.gstatic.com')) {
    event.respondWith(cacheFirst(request, { graceful: true }));
    return;
  }

  // App shell / navigation
  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        try {
          const networkResponse = await fetch(request);
          return networkResponse;
        } catch (error) {
          // CHANGE: Match relative path
          const cachedShell = await caches.match('./index.html');
          return cachedShell;
        }
      })()
    );
    return;
  }

  // Static assets: cache-first.
  if (
    isSameOrigin &&
    (request.destination === 'script' ||
      request.destination === 'style' ||
      request.destination === 'image' ||
      request.destination === 'font')
  ) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // Training plan JSON: prefer cache to keep offline availability consistent.
  if (url.pathname.endsWith('training_plans/training_example.json')) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // Remote JSON (e.g., training plan) and other GETs: network-first with cache fallback.
  event.respondWith(networkFirst(request));
});

async function cacheFirst(request, { graceful = false } = {}) {
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
        headers: { 'Content-Type': request.destination === 'font' ? 'font/woff2' : 'application/octet-stream' },
      });
    }
    throw error;
  }
}

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
