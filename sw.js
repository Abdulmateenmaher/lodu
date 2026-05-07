// Custom Service Worker for Lodu PWA
// Handles offline audio playback and proper caching

const PRECACHE = 'lodu-precache-v1';
const RUNTIME = 'lodu-runtime-v1';
const AUDIO_CACHE = 'lodu-audio-v1';

// Precache these critical assets
const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/assets/images/bg.png',
  '/assets/images/starting.png',
  '/assets/images/app_icon.png',
];

// All audio files that need offline support
const AUDIO_URLS = [
  '/assets/sounds/start_game.mp3',
  '/assets/sounds/rolling.mp3',
  '/assets/sounds/six_four.mp3',
  '/assets/sounds/extra_turn.mp3',
  '/assets/sounds/no_move_chance.mp3',
  '/assets/sounds/moving_piece.mp3',
  '/assets/sounds/reach_goal.mp3',
  '/assets/sounds/block_border.mp3',
  '/assets/sounds/hit_piece.mp3',
  '/assets/sounds/wining.mp3',
];

// Install: Precache critical assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(PRECACHE).then((cache) => {
      return cache.addAll(PRECACHE_URLS).catch((err) => {
        console.warn('Precache failed:', err);
      });
    }).then(() => {
      // Cache audio files separately
      return caches.open(AUDIO_CACHE).then((cache) => {
        // Use addAll but don't fail install if some audio fails
        return cache.addAll(AUDIO_URLS).catch((err) => {
          console.warn('Audio precache failed:', err);
        });
      });
    }).then(() => {
      return self.skipWaiting();
    })
  );
});

// Activate: Clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== PRECACHE && cacheName !== RUNTIME && cacheName !== AUDIO_CACHE) {
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      return self.clients.claim();
    })
  );
});

// Fetch: Handle requests with proper strategies
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Skip cross-origin requests (like analytics, etc.)
  if (url.origin !== self.location.origin) {
    return;
  }

  // Audio files: Cache-first, never go to network if cached
  if (url.pathname.startsWith('/assets/sounds/') || url.pathname.endsWith('.mp3')) {
    event.respondWith(
      caches.match(event.request).then((cachedResponse) => {
        if (cachedResponse) {
          return cachedResponse;
        }
        // If not cached, try network and cache for future
        return fetch(event.request).then((networkResponse) => {
          if (networkResponse.ok) {
            const responseClone = networkResponse.clone();
            caches.open(AUDIO_CACHE).then((cache) => {
              cache.put(event.request, responseClone);
            });
          }
          return networkResponse;
        }).catch(() => {
          // If both cache and network fail, return a valid response
          // The browser will handle the missing audio gracefully
          return new Response('', { status: 503, statusText: 'Offline' });
        });
      })
    );
    return;
  }

  // Navigation requests: Network-first, fallback to cache
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).then((networkResponse) => {
        // Update cache with fresh page
        const responseClone = networkResponse.clone();
        caches.open(RUNTIME).then((cache) => {
          cache.put(event.request, responseClone);
        });
        return networkResponse;
      }).catch(() => {
        return caches.match('/index.html');
      })
    );
    return;
  }

  // Other requests: Cache-first for known assets, network for others
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) {
        return cachedResponse;
      }
      return fetch(event.request).then((networkResponse) => {
        // Cache successful GET requests
        if (event.request.method === 'GET' && networkResponse.ok) {
          const responseClone = networkResponse.clone();
          caches.open(RUNTIME).then((cache) => {
            cache.put(event.request, responseClone);
          });
        }
        return networkResponse;
      }).catch(() => {
        // If it's a resource we expect to have, but don't, just fail gracefully
        return new Response('', { status: 503, statusText: 'Offline' });
      });
    })
  );
});

// Listen for skipWaiting message
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
