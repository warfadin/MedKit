const cacheName = 'medkit-shell-__BUILD_HASH__';
const shell = ['./','./app.js','./style.css','./config.js','./calculator.js','./cache.js','./snapshot.json'];
self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(cacheName).then((cache) => cache.addAll(shell)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((key) =>
    key.startsWith('medkit-shell-') && key !== cacheName).map((key) => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin || !shell.some((path) => new URL(path,self.registration.scope).href === url.href)) return;
  const load = async () => {
    const cache = await caches.open(cacheName);
    const saved = await cache.match(event.request);
    return saved ?? fetch(event.request);
  };
  event.respondWith(load());
});
