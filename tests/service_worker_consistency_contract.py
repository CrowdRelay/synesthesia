#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
worker = (ROOT / 'web/service-worker.js').read_text()
headers = (ROOT / 'web/_headers').read_text()
boot = (ROOT / 'web/boot-shell.js').read_text()
project = (ROOT / 'project.godot').read_text()
boot_sequence = (ROOT / 'scripts/ui/boot_sequence.gd').read_text()
failures: list[str] = []

for token in (
    'const CACHE_PREFIX = "virya-synesthesia-"',
    'const CACHE_NAME = `${CACHE_PREFIX}__SYNESTHESIA_CACHE_ID__`',
    'const CORE_PATHS = new Set(CORE)',
    'function networkFirst(request, event, navigationFallback = false)',
    'const RUNTIME = __SYNESTHESIA_RUNTIME_PATHS__;',
    'const assets = [...CORE, ...RUNTIME];',
    'Promise.allSettled(assets.map((path) => warmAsset(path)))',
    'function currentGenerationCacheFirst(request, event)',
    '/\\.(?:wasm|pck)$/.test(url.pathname)',
    'CORE_PATHS.has(url.pathname)',
    'event.respondWith(networkFirst(request, event, true))',
    'event.respondWith(networkFirst(request, event))',
    'const shell = navigationFallback ? await cache.match("/index.html") : null;',
    'const { response } = await networkPromise;',
    'throw error;',
    '.catch(() => undefined)',
    'function sameValidator(cached, response)',
    '!sameValidator(cached, network.response)',
    'event.waitUntil(cacheWrite)',
    'function fetchForDeliveryAndCache(request)',
    'cacheCopy: response.ok && response.status === 200 ? response.clone() : null',
    'request.headers.has("range")',
    'response.status !== 429 && response.status < 500',
    'key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME',
    'staleKeys.length > 0',
    'self.clients.matchAll({ type: "window", includeUncontrolled: true })',
    'await client.navigate(client.url)',
):
    if token not in worker:
        failures.append(f'missing service-worker contract: {token}')

for stale in (
    'const NETWORK_HEADER_TIMEOUT_MS',
    'Promise.race([networkPromise, networkHeaderTimeout()])',
    'async function cacheFirst',
    'return (await cache.match(request)) || (await cache.match("/index.html"))',
):
    if stale in worker:
        failures.append(f'unsafe stale-runtime path still present: {stale}')

if headers.count('Cache-Control: public, max-age=0, must-revalidate') < 3:
    failures.append('runtime HTTP revalidation headers missing')
if 'Cross-Origin-Embedder-Policy: require-corp' not in headers:
    failures.append('COEP missing for extension-capable Godot Web template')
if 'boot_splash/show_image.web=false' not in project:
    failures.append('stock Godot splash is still enabled on Web')
for token in (
    'call_deferred("_release_web_shell_after_first_frame")',
    'await RenderingServer.frame_post_draw',
    'window.synesthesiaBootReady && window.synesthesiaBootReady();',
):
    if token not in boot_sequence:
        failures.append(f'Godot-to-HTML boot handoff missing: {token}')

for token in (
    'const CACHE_ID = "__SYNESTHESIA_CACHE_ID__"',
    'navigator.serviceWorker.controller',
    'clearSynesthesiaCaches()',
    'unregisterSynesthesiaWorkers()',
    'location.reload()',
    'synesthesiaBootFailed',
    '12000',
):
    if token not in boot:
        failures.append(f'web boot recovery contract missing: {token}')

if failures:
    for failure in failures:
        print(f'FAIL: {failure}')
    raise SystemExit(f'SYNESTHESIA_SW_CONSISTENCY=FAIL count={len(failures)}')

print('SYNESTHESIA_SW_CONSISTENCY=PASS runtime=generation-cache-first+install-warm shell=network-first deploy=mixed-version-guard boot=recoverable isolation=coep')
