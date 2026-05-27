// Retire legacy Flutter PWA workers that can keep an older application build
// active after a deployment. Current Flutter web builds no longer register a
// worker for new sessions, but previously installed workers still update here.
const flutterCachePrefix = 'flutter-';

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const cacheKeys = await caches.keys();
    await Promise.all(
      cacheKeys
        .filter((key) => key.startsWith(flutterCachePrefix))
        .map((key) => caches.delete(key)),
    );
    await self.registration.unregister();

    const windows = await self.clients.matchAll({type: 'window'});
    await Promise.all(windows.map((client) => client.navigate(client.url)));
  })());
});
