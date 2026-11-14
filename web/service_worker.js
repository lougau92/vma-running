// The release build stamps this name before Flutter copies the web assets.
const CACHE_NAME = 'vma-running-cache-v1';
const CORE_ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './app_update.js',
  './flutter_bootstrap.js',
  './main.dart.js',
  './version.json',
  './assets/AssetManifest.bin.json',
  './assets/FontManifest.json',
  './assets/fonts/MaterialIcons-Regular.otf',
  './assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
  './assets/assets/feedback.json',
  './assets/assets/enjambee_img/logo-header-minimized.png',
  './assets/assets/training_plans/training_example.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    // A new cache must contain the new release, even while the browser's HTTP
    // cache still considers yesterday's scripts fresh.
    await cache.addAll(CORE_ASSETS.map((asset) => new Request(
      new URL(asset, self.registration.scope), { cache: 'reload' }
    )));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys
      .filter((key) => key.startsWith('vma-running-cache-') && key !== CACHE_NAME)
      .map((key) => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  const scope = new URL(self.registration.scope);
  const appAsset = url.origin === scope.origin && url.pathname.startsWith(scope.pathname);
  const renderingAsset = request.destination === 'font' ||
    url.hostname === 'fonts.gstatic.com' || url.pathname.includes('/canvaskit/');
  // Keep the renderer/fonts available offline; leave remote APIs and other
  // applications to their own network/cache policies.
  if (!appAsset && !renderingAsset) return;

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        if (response.ok) return response;
      } catch (_) {
        // Fall back to the shell of the installed release when offline.
      }
      const cache = await caches.open(CACHE_NAME);
      return (await cache.match(new URL('index.html', scope))) || Response.error();
    })());
    return;
  }

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    // CacheStorage.match searches legacy Flutter caches too. Restrict reads to
    // this release so they cannot silently supply an obsolete main.dart.js.
    // package_info_plus adds a timestamp query; its displayed version must
    // still describe the installed code, including during offline startup.
    const releaseMetadata = url.pathname === `${scope.pathname}version.json`;
    const cached = await cache.match(request, { ignoreSearch: releaseMetadata });
    if (cached) return cached;
    // Lazy-loaded app assets also belong to this release; an HTTP-cache hit
    // from the previous release is just as stale as an old CacheStorage entry.
    const response = await fetch(request, appAsset ? { cache: 'reload' } : {});
    if (response.ok || response.type === 'opaque') {
      try {
        await cache.put(request, response.clone());
      } catch (error) {
        // Quota/storage errors must not discard a successful download.
        console.debug('Asset could not be cached:', error);
      }
    }
    return response;
  })());
});
