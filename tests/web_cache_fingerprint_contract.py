#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
worker = (ROOT / 'web/service-worker.js').read_text()
post = (ROOT / 'tools/postprocess_web.py').read_text()
failures: list[str] = []

for token in (
    '__SYNESTHESIA_CACHE_ID__',
    'key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME',
):
    if token not in worker:
        failures.append(f'service worker cache fingerprint token missing: {token}')
for token in (
    'import hashlib',
    'path.suffix.lower() in {".pck", ".wasm"}',
    'static_shell_js = {"service-worker.js", "register-sw.js", "boot-shell.js"}',
    'path.suffix.lower() == ".js" and path.name not in static_shell_js',
    'runtime_hash = hashlib.sha256()',
    'handle.read(1024 * 1024)',
    'cache_id = f"{VERSION}-{runtime_hash.hexdigest()[:12]}"',
    'replace("__SYNESTHESIA_CACHE_ID__", cache_id)',
):
    if token not in post:
        failures.append(f'postprocess runtime fingerprint missing: {token}')
if '__SYNESTHESIA_VERSION__' in worker:
    failures.append('service-worker cache namespace still depends only on semantic VERSION')

if failures:
    for failure in failures:
        print(f'FAIL: {failure}')
    raise SystemExit(f'SYNESTHESIA_WEB_CACHE_FINGERPRINT=FAIL count={len(failures)}')

print('SYNESTHESIA_WEB_CACHE_FINGERPRINT=PASS namespace=version+runtime-sha eviction=bounded hash=streaming')
