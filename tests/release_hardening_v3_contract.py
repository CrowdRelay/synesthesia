#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
worker = (ROOT / "web/service-worker.js").read_text()
register = (ROOT / "web/register-sw.js").read_text()
progress = (ROOT / "scripts/progress_store.gd").read_text()
atmosphere = (ROOT / "scripts/render/atmosphere_layer.gd").read_text()
finale = (ROOT / "scripts/ui/echoes_finale_background.gd").read_text()
failures = []

checks = {
    "resilient offline shell install": "Promise.allSettled(assets.map((path) => warmAsset(path)))" in worker and "install skipped" in worker and "cache.addAll(" not in worker and '  "/",' not in worker,
    "scoped cache eviction": "key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME" in worker,
    "range bypass": 'request.headers.has("range")' in worker,
    "generation runtime cache first": "currentGenerationCacheFirst(request, event)" in worker and "const RUNTIME = __SYNESTHESIA_RUNTIME_PATHS__;" in worker,
    "shell remains network first": "CORE_PATHS.has(url.pathname)" in worker and "networkFirst(request, event)" in worker,
    "no timer-selected stale runtime": "NETWORK_HEADER_TIMEOUT_MS" not in worker and "Promise.race([networkPromise" not in worker,
    "offline css+manifest": '(?:css|webmanifest|mp3|ogg|wav|ogv|svg|png|webp|woff2?|ttf)' in worker,
    "early response clone": "function fetchForDeliveryAndCache(request)" in worker and "cacheCopy: response.ok && response.status === 200 ? response.clone() : null" in worker,
    "service worker update bypasses http cache": 'updateViaCache: "none"' in register,
    "bounded save input/output": "const MAX_SAVE_BYTES: int = 24 * 1024 * 1024" in progress and "file.get_length() > MAX_SAVE_BYTES" in progress and "serialized.to_utf8_buffer().size() > MAX_SAVE_BYTES" in progress,
    "backup auto-heal": "Heal a corrupt current generation immediately" in progress and "if not _write_document(recovered):" in progress,
    "packed atmosphere particles": "PackedVector4Array" in atmosphere and "PackedFloat32Array" in atmosphere and "particle.get(" not in atmosphere,
    "finale static palette": "const MEMORY_ACCENTS := [" in finale and "var accents:" not in finale,
}
for name, ok in checks.items():
    if not ok:
        failures.append(name)
if failures:
    raise SystemExit("SYNESTHESIA_RELEASE_HARDENING_V3=FAIL missing=" + ",".join(failures))
print("SYNESTHESIA_RELEASE_HARDENING_V3=PASS pwa=resilient+scoped+generation-runtime-cache save=bounded+self-healing draw=packed+static")
