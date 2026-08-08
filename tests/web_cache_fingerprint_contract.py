#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
worker = (ROOT / 'web/service-worker.js').read_text()
boot = (ROOT / 'web/boot-shell.js').read_text()
post = (ROOT / 'tools/postprocess_web.py').read_text()
failures: list[str] = []

for label, text in (("service worker", worker), ("boot shell", boot)):
    if '__SYNESTHESIA_CACHE_ID__' not in text:
        failures.append(f'{label} cache fingerprint token missing')
if 'key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME' not in worker:
    failures.append('service worker bounded cache eviction missing')

for token in (
    'import hashlib',
    'path.suffix.lower() in {".pck", ".wasm"}',
    'static_shell_js = {"service-worker.js", "register-sw.js", "boot-shell.js"}',
    'path.suffix.lower() == ".js" and path.name not in static_shell_js',
    'fingerprint_files = sorted(',
    'BUILD.rglob("*")',
    'path.name != "asset-report.txt"',
    'deploy_hash = hashlib.sha256()',
    'path.relative_to(BUILD).as_posix().encode()',
    'handle.read(1024 * 1024)',
    'cache_id = f"{VERSION}-{deploy_hash.hexdigest()[:12]}"',
    'for relative_path in ("service-worker.js", "boot-shell.js")',
    'source.replace("__SYNESTHESIA_CACHE_ID__", cache_id)',
):
    if token not in post:
        failures.append(f'postprocess deploy fingerprint missing: {token}')
if '__SYNESTHESIA_VERSION__' in worker:
    failures.append('service-worker cache namespace still depends only on semantic VERSION')
if 'runtime_hash = hashlib.sha256()' in post:
    failures.append('cache namespace still fingerprints only runtime files')

if failures:
    for failure in failures:
        print(f'FAIL: {failure}')
    raise SystemExit(f'SYNESTHESIA_WEB_CACHE_FINGERPRINT=FAIL count={len(failures)}')

print('SYNESTHESIA_WEB_CACHE_FINGERPRINT=PASS namespace=version+whole-deploy-sha eviction=bounded hash=streaming shell=version-coupled')
