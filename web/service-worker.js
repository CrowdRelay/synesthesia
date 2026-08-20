const CACHE_PREFIX = "virya-synesthesia-";
const CACHE_NAME = `${CACHE_PREFIX}__SYNESTHESIA_CACHE_ID__`;
const CORE = [
  "/index.html",
  "/manifest.webmanifest",
  "/icon.svg",
  "/icon-192.png",
  "/icon-512.png",
  "/menu-world.webp",
  "/fonts/SynesthesiaTitle.ttf",
  "/fonts/SynesthesiaDisplay.ttf",
  "/boot-shell.css",
  "/boot-shell.js",
  "/register-sw.js",
];
const CORE_PATHS = new Set(CORE);
const RUNTIME = __SYNESTHESIA_RUNTIME_PATHS__;

self.addEventListener("install", (event) => {
  // The offline shell is a unit. Runtime warming is opportunistic: if a CDN
  // request is interrupted, install the worker anyway and let the normal
  // cache-first runtime path fill the missing entry on demand.
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(CORE);
    await Promise.allSettled(RUNTIME.map(async (path) => {
      if (await cache.match(path)) return;
      const response = await fetch(path, { cache: "no-cache" });
      if (response.ok && response.status === 200) await cache.put(path, response);
    }));
  })());
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    const staleKeys = keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME);
    await Promise.all(staleKeys.map((key) => caches.delete(key)));
    await self.clients.claim();

    // If this activation replaced an older Synesthesia generation, any already
    // open root-page client may have started under the previous worker. Reload
    // exactly once at that deploy boundary so it cannot finish booting with a
    // mixed HTML/JS/PCK generation. First install has no stale cache and does
    // not reload. The reward flow is deliberately outside this worker scope.
    if (staleKeys.length > 0) {
      const windows = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
      await Promise.all(windows.map(async (client) => {
        try {
          const url = new URL(client.url);
          if (url.origin === self.location.origin && !url.pathname.startsWith("/reward/")) {
            await client.navigate(client.url);
          }
        } catch (_) {
          // Navigation is best-effort; the new worker still owns future requests.
        }
      }));
    }
  })());
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

// Boot-critical files are strictly network-first. Do not race a cached fallback
// against a timer: an old worker serving an old PCK to a new HTML/JS generation
// is worse than waiting for the network. Cache is used only after a real network
// failure or a transient server failure, preserving offline recovery.
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
      const { response } = await networkPromise;
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


// Runtime blobs are immutable inside a deploy generation because CACHE_NAME
// embeds the full build fingerprint. Once the current generation has fetched
// them successfully, return CacheStorage immediately on the next launch instead
// of blocking engine startup on another CDN round-trip. A new deploy gets a new
// CACHE_NAME and the activation/migration guard removes the old generation.
async function currentGenerationCacheFirst(request, event) {
  const cache = await caches.open(CACHE_NAME);
  const cached = await cache.match(request);
  if (cached) return cached;

  const network = await fetchForDeliveryAndCache(request);
  if (network.cacheCopy) {
    event.waitUntil(cache.put(request, network.cacheCopy).catch(() => undefined));
  }
  return network.response;
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
  if (/\.(?:wasm|pck)$/.test(url.pathname) || (url.pathname.endsWith(".js") && !CORE_PATHS.has(url.pathname))) {
    event.respondWith(currentGenerationCacheFirst(request, event));
    return;
  }
  if (CORE_PATHS.has(url.pathname)) {
    event.respondWith(networkFirst(request, event));
    return;
  }
  if (/\.(?:css|webmanifest|mp3|ogg|wav|ogv|svg|png|webp|woff2?|ttf)$/.test(url.pathname)) {
    event.respondWith(staleWhileRevalidate(request, event));
  }
});
