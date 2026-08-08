#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
worker = (ROOT / 'web/service-worker.js').read_text()
headers = (ROOT / 'web/_headers').read_text()
failures: list[str] = []

for token in (
    'const CACHE_PREFIX = "virya-synesthesia-"',
    'const CACHE_NAME = `${CACHE_PREFIX}__SYNESTHESIA_CACHE_ID__`',
    'function networkFirst(request, event, navigationFallback = false)',
    '/\\.(?:wasm|pck|js)$/.test(url.pathname)',
    'event.respondWith(networkFirst(request, event, true))',
    'event.respondWith(networkFirst(request, event))',
    'const shell = navigationFallback ? await cache.match("/index.html") : null;',
    'throw error;',
    '.catch(() => undefined)',
    'function sameValidator(cached, response)',
    '!sameValidator(cached, network.response)',
    'event.waitUntil(cacheWrite)',
    'function fetchForDeliveryAndCache(request)',
    'cacheCopy: response.ok && response.status === 200 ? response.clone() : null',
    'request.headers.has("range")',
    'cache.addAll(CORE)',
    'const NETWORK_HEADER_TIMEOUT_MS = 3500',
    'Promise.race([networkPromise, networkHeaderTimeout()])',
    'response.status !== 429 && response.status < 500',
    'key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME',
):
    if token not in worker:
        failures.append(f'missing service-worker contract: {token}')

if 'async function cacheFirst' in worker:
    failures.append('runtime cache-first path is still present')
if 'return (await cache.match(request)) || (await cache.match("/index.html"))' in worker:
    failures.append('runtime cache miss can still receive index.html')
if headers.count('Cache-Control: public, max-age=0, must-revalidate') < 3:
    failures.append('runtime HTTP revalidation headers missing')

if failures:
    for failure in failures:
        print(f'FAIL: {failure}')
    raise SystemExit(f'SYNESTHESIA_SW_CONSISTENCY=FAIL count={len(failures)}')

print('SYNESTHESIA_SW_CONSISTENCY=PASS runtime=network-first+streaming-cache-write+validator-aware offline=typed-cache-fallback transient=last-good navigation=shell-fallback version=scoped-eviction')
