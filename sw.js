// Passage POS Service Worker v2
// Clear old cache that had CSP issues
const CACHE = 'passage-pos-v2';

self.addEventListener('install', e => {
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  // Delete ALL old caches
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  // Pass everything through — no caching interference
  e.respondWith(fetch(e.request));
});
