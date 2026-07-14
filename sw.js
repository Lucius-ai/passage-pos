// Passage POS Service Worker v3 — NUKE ALL CACHES
const CACHE = 'passage-pos-v3';

self.addEventListener('install', e => {
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.map(k => {
        console.log('[SW] Deleting cache:', k);
        return caches.delete(k);
      }))
    ).then(() => {
      console.log('[SW] All caches cleared');
      return self.clients.claim();
    })
  );
});

// Pass all requests through without caching
self.addEventListener('fetch', e => {
  e.respondWith(fetch(e.request).catch(() => fetch(e.request)));
});
