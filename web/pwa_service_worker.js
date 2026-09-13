'use strict';

const CACHE_NAME = 'focus-pwa-v1';

const PRECACHE = [
  './',
  './index.html',
  './main.dart.js',
  './flutter_bootstrap.js',
  './flutter.js',
  './manifest.json',
  './favicon.png',
  './icons/Icon-192.png',
  './icons/Icon-512.png',
  './icons/Icon-maskable-192.png',
  './icons/Icon-maskable-512.png',
  './assets/AssetManifest.bin.json',
  './assets/FontManifest.json',
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) =>
      cache.addAll(
        PRECACHE.map((url) => new Request(url, { cache: 'reload' }))
      ),
    ),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') {
    return;
  }

  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) {
    return;
  }

  const path = url.pathname;
  // Always prefer network for the Dart/Flutter entry bundle so deploys are not
  // stuck behind a cache-first main.dart.js from an earlier build.
  const isNetworkFirst =
    path === '/' ||
    path.endsWith('/index.html') ||
    path.endsWith('/manifest.json') ||
    path.endsWith('/version.json') ||
    path.endsWith('/main.dart.js') ||
    path.endsWith('/flutter.js') ||
    path.endsWith('/flutter_bootstrap.js') ||
    path.endsWith('/pwa_service_worker.js');

  if (isNetworkFirst) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          if (response && response.status === 200) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          }
          return response;
        })
        .catch(() => caches.match(event.request))
    );
  } else {
    event.respondWith(
      caches.match(event.request).then((cached) => {
        const network = fetch(event.request).then((response) => {
          if (response && response.status === 200) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          }
          return response;
        });
        return cached || network;
      }),
    );
  }
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes('/focus') && 'focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow('/focus/');
    })
  );
});