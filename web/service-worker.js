const CACHE_PREFIX = "virya-synesthesia-";
const CACHE_NAME = `${CACHE_PREFIX}__SYNESTHESIA_CACHE_ID__`;
const NETWORK_HEADER_TIMEOUT_MS = 3500;
const CORE = [
  "/index.html",
  "/manifest.webmanifest",
  "/icon.svg",
  "/icon-192.png",
  "/icon-512.png",
  "/boot-shell.css",
  "/boot-shell.js",
  "/register-sw.js",
];

self.addEventListener("install", (event) => {
  // The offline shell is a unit: do not activate a worker with a silently
  // partial CORE cache. A later install retry is safer than a broken PWA.
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CORE)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys
        .filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME)
        .map((key) => caches.delete(key))
    ))
  );
  self.clients.claim();
});

function sameValidator(cached, response) {
  if (!cached || !response) return false;
  const cachedEtag = cached.headers.get("etag");
  const responseEtag = response.headers.get("etag");
  if (cachedEtag && responseEtag) return cachedEtag === responseEtag;
  const cachedModified = cached.headers.get("last-modified");
  const responseModified = response.headers.get("last-modified");
  return Boolean(cachedModified && responseModified && cachedModified === responseModified);
}

// Clone a cache candidate immediately when fetch resolves, before the original
// Response body is handed to Godot/browser consumption. Cloning later can race
// a disturbed/locked body on large streaming PCK responses.
function fetchForDeliveryAndCache(request) {
  return fetch(request).then((response) => ({
    response,
    cacheCopy: response.ok && response.status === 200 ? response.clone() : null,
  }));
}

function networkHeaderTimeout() {
  return new Promise((resolve) => setTimeout(() => resolve(null), NETWORK_HEADER_TIMEOUT_MS));
}

// Return the network response as soon as headers arrive. CacheStorage consumes
// the already-cloned response concurrently under event.waitUntil instead of
// delaying Godot startup until a large PCK/WASM has been fully written to disk.
function networkFirst(request, event, navigationFallback = false) {
  const cachePromise = caches.open(CACHE_NAME);
  const cachedPromise = cachePromise.then((cache) => cache.match(request));
  const networkPromise = fetchForDeliveryAndCache(request);
  const cacheWrite = Promise.all([cachePromise, cachedPromise, networkPromise])
    .then(async ([cache, cached, network]) => {
      if (network.cacheCopy && !sameValidator(cached, network.response)) {
        await cache.put(request, network.cacheCopy);
      }
    })
    .catch(() => undefined);
  event.waitUntil(cacheWrite);

  return (async () => {
    const cache = await cachePromise;
    const cached = await cachedPromise;
    const shell = navigationFallback ? await cache.match("/index.html") : null;
    const fallback = cached || shell;
    try {
      // A cached generation is already integrity-scoped by CACHE_NAME. On a
      // flaky connection, do not make a returning player wait indefinitely for
      // response headers. The real fetch continues under cacheWrite and can
      // refresh the cache after we immediately serve last-good.
      const network = fallback
        ? await Promise.race([networkPromise, networkHeaderTimeout()])
        : await networkPromise;
      if (network === null) return fallback;
      const { response } = network;
      // Preserve the last known-good runtime on transient origin/CDN failures,
      // but never mask a deliberate 4xx/removal with an obsolete cached asset.
      if (response.ok || !fallback || (response.status !== 429 && response.status < 500)) {
        return response;
      }
      return fallback;
    } catch (error) {
      if (fallback) return fallback;
      throw error;
    }
  })();
}

function staleWhileRevalidate(request, event) {
  const cachePromise = caches.open(CACHE_NAME);
  const cachedPromise = cachePromise.then((cache) => cache.match(request));
  const networkPromise = fetchForDeliveryAndCache(request);
  const cacheWrite = Promise.all([cachePromise, cachedPromise, networkPromise])
    .then(async ([cache, cached, network]) => {
      if (network.cacheCopy && !sameValidator(cached, network.response)) {
        await cache.put(request, network.cacheCopy);
      }
    })
    .catch(() => undefined);
  event.waitUntil(cacheWrite);

  return cachedPromise.then(async (cached) => {
    if (cached) return cached;
    return (await networkPromise).response;
  });
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin || url.pathname.startsWith("/reward/")) return;
  // CacheStorage cannot safely represent partial responses. Let the browser/CDN
  // own byte-range semantics for future streamed media or engine requests.
  if (request.headers.has("range")) return;
  if (request.mode === "navigate") {
    event.respondWith(networkFirst(request, event, true));
    return;
  }
  if (/\.(?:wasm|pck|js)$/.test(url.pathname)) {
    event.respondWith(networkFirst(request, event));
    return;
  }
  if (/\.(?:css|webmanifest|mp3|ogg|wav|ogv|svg|png|webp|woff2?|ttf)$/.test(url.pathname)) {
    event.respondWith(staleWhileRevalidate(request, event));
  }
});
