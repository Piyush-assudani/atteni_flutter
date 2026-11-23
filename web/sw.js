const CACHE_NAME = 'atteni-v7';
const ASSETS_TO_CACHE = [
  '/',
  './pages/main',
  './pages/admin',
  './pages/supermaster',
  './pages/attendance',
  './pages/parent',
  './pages/reception',
  './pages/game',
  './pages/profile_card',
  './pages/changes',
  '/offline',
  './pages/faq',
  './assets/js/app-state.js',
  './assets/images/logo.jpeg',
  './assets/images/me.jpeg',
  './assets/images/img.png',
  'https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css',
  'https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&display=swap',
  './assets/js/firebase-config.js',
  './assets/js/revert.js'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE).catch(err => console.log('Partial cache failure: ', err));
    })
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cache) => {
          if (cache !== CACHE_NAME) {
            return caches.delete(cache);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Helper: Normalize URL to the clean cache key path (e.g. no .html, no search parameters, index.html -> /)
function getNormalizedUrl(requestUrl) {
  const url = new URL(requestUrl);
  const isLocal = url.hostname === 'localhost' || url.hostname === '127.0.0.1';
  let pathname = url.pathname;
  if (pathname === '/' || pathname === '/index.html') {
    pathname = '/';
  } else if (pathname.endsWith('.html') && !isLocal) {
    pathname = pathname.substring(0, pathname.length - 5);
  }
  return `${url.origin}${pathname}`;
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;
  if (!request.url.startsWith('http')) return;

  // Logic for HTML/API Navigation (Stale-While-Revalidate for Instant Load)
  if (request.mode === 'navigate' || (request.headers.get('accept') && request.headers.get('accept').includes('text/html'))) {
    const cacheKey = getNormalizedUrl(request.url);
    event.respondWith(
      caches.match(cacheKey).then((cachedResponse) => {
        return fetchPromiseHelper(request, cachedResponse);
      })
    );
    return;
  }

  // Static Assets (Cache-First)
  event.respondWith(
    caches.match(request).then((cachedResponse) => {
      if (cachedResponse) return cachedResponse;

      return fetch(request)
        .then(response => {
          if (response && response.status === 200) {
            const responseToCache = response.clone();
            caches.open(CACHE_NAME).then(cache => cache.put(request, responseToCache));
          }
          return response;
        })
        .catch(async () => {
          // If fetch fails (e.g. offline), try cache again just in case, then fallback
          const cachedFallback = await caches.match(request);
          if (cachedFallback) return cachedFallback;
          return new Response('Asset not available offline', { status: 404 });
        });
    })
  );
});

function fetchPromiseHelper(request, cachedResponse) {
  const url = new URL(request.url);
  
  // If the requested path ends with .html or is /index.html, fetch the normalized path to avoid server redirects (308)
  const isLocal = url.hostname === 'localhost' || url.hostname === '127.0.0.1';
  let normalizedPath = url.pathname;
  if (normalizedPath === '/index.html') {
    normalizedPath = '/';
  } else if (normalizedPath.endsWith('.html') && !isLocal) {
    normalizedPath = normalizedPath.substring(0, normalizedPath.length - 5);
  }
  const cleanUrl = `${url.origin}${normalizedPath}${url.search}`;

  // Fetch the clean URL (safe from redirects, string URL avoids navigate-mode restrictions in fetch)
  const fetchPromise = fetch(cleanUrl);
  
  // Use a shorter timeout (3s) to return cache fast if we have it. Otherwise use a longer timeout (10s) to give it a chance.
  const timeoutMs = cachedResponse ? 3000 : 10000;
  
  return Promise.race([
    fetchPromise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('TIMEOUT')), timeoutMs))
  ])
  .then(networkResponse => {
    if (networkResponse && networkResponse.status === 200) {
      const responseToCache = networkResponse.clone();
      const cacheKey = getNormalizedUrl(request.url);
      caches.open(CACHE_NAME).then(cache => cache.put(cacheKey, responseToCache));
    }
    return networkResponse;
  })
  .catch(err => {
    console.warn("SW Fetch failed, using cache if available:", err);
    return cachedResponse || caches.match('/offline');
  });
}
