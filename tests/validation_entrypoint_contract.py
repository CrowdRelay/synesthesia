#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source_gate = (ROOT / 'scripts/validate-source.sh').read_text()
validate = (ROOT / 'validate.sh').read_text()
web = (ROOT / 'scripts/build-web-preview.sh').read_text()
linux = (ROOT / 'scripts/build-linux-release.sh').read_text()
ci = (ROOT / '.github/workflows/ci.yml').read_text()
build = (ROOT / '.github/workflows/build.yml').read_text()
failures: list[str] = []

critical = (
    'tests/static_validate.py',
    'tools/memory_budget.py',
    'tests/runtime_hot_path_contract.py',
    'tests/save_reliability_contract.py',
    'tests/service_worker_consistency_contract.py',
    'tests/web_cache_fingerprint_contract.py',
    'tests/export_surface_contract.py',
    'tests/android_pipeline_contract.py',
)
for token in critical:
    if token not in source_gate:
        failures.append(f'canonical source gate missing: {token}')

# Every platform-independent Python contract belongs to the canonical source
# gate. This prevents new regression tests from silently existing outside CI.
for contract in sorted((ROOT / 'tests').glob('*_contract.py')):
    token = f'tests/{contract.name}'
    if token not in source_gate:
        failures.append(f'canonical source gate missing contract: {token}')
for name, text in (
    ('validate.sh', validate),
    ('build-web-preview.sh', web),
    ('build-linux-release.sh', linux),
    ('ci.yml', ci),
):
    if './scripts/validate-source.sh' not in text:
        failures.append(f'{name}: bypasses canonical source validation entrypoint')

if 'if [[ ! -f "$ROOT/synesthesia_rust.gdextension" ]]' not in validate or './scripts/build-rust-native.sh disable >/dev/null' not in validate:
    failures.append('validate.sh: stale generated GDExtension registration is not purged for source-only validation')
if 'res://tests/gdscript_parse_smoke.gd' not in validate or 'SYNESTHESIA_GDSCRIPT_PARSE=PASS' not in validate:
    failures.append('validate.sh: repository-wide GDScript parse sweep is missing')
if 'tests/netlify_artifact_deploy_contract.py' not in source_gate:
    failures.append('validate-source.sh: zero-build Netlify artifact contract is missing')
if 'preload("res://scripts/app/diagnostics_overlay.gd")' in (ROOT / 'scripts/main.gd').read_text():
    failures.append('main.gd: optional diagnostics overlay is a hard parser dependency')
if 'ResourceLoader.exists(DIAGNOSTICS_OVERLAY_PATH)' not in (ROOT / 'scripts/main.gd').read_text():
    failures.append('main.gd: optional diagnostics overlay lacks guarded dynamic load')
diagnostics = (ROOT / 'scripts/app/diagnostics_overlay.gd').read_text()
if 'var preload:' in diagnostics:
    failures.append('diagnostics_overlay.gd: reserved GDScript preload identifier reused as a variable')


if 'tests/font_glyph_smoke.gd' not in validate or 'SYNESTHESIA_FONT_GLYPHS=PASS' not in validate:
    failures.append('validate.sh: bundled title font Polish glyph coverage is not runtime-gated')

# Tagged/manual release validates once before cache/toolchain setup, then delegates
# platform-specific work to builders with source validation explicitly skipped.
for builder in ('./scripts/build-web-preview.sh', './scripts/build-android-apk.sh'):
    if builder not in build:
        failures.append(f'build.yml: missing canonical platform builder {builder}')
if build.count('./scripts/validate-source.sh') < 2:
    failures.append('build.yml: desktop-web and Android jobs must each fail-fast through canonical source validation')
if build.find('./scripts/validate-source.sh') > build.find('Cache bounded Web build inputs'):
    failures.append('build.yml: desktop-web source validation runs after cache restore')
if 'SYNESTHESIA_SKIP_SOURCE_VALIDATION: "1"' not in build:
    failures.append('build.yml: platform builder re-runs canonical source suite')

if web.find('./scripts/validate-source.sh') > web.find('if [[ -z "$GODOT_BIN" ]]'):
    failures.append('Web source validation runs after heavyweight Godot setup')
if ci.find('./scripts/validate-source.sh') > ci.find('Cache Rust dependency sources'):
    failures.append('CI canonical source validation runs after dependency cache restore')
if 'if [[ "${SYNESTHESIA_SKIP_SOURCE_VALIDATION:-0}" != "1" ]]' not in web:
    failures.append('Web builder cannot skip duplicate source validation after an outer fail-fast gate')
android = (ROOT / 'scripts/build-android-apk.sh').read_text()
if android.find('./scripts/validate-source.sh') > android.find('sdkmanager_bin='):
    failures.append('Android source validation runs after heavyweight SDK setup')
if 'SYNESTHESIA_SKIP_SOURCE_VALIDATION=1 GODOT_BIN="$GODOT_BIN" ./validate.sh' not in android:
    failures.append('Android real-engine gate re-runs the full source suite')
if 'SYNESTHESIA_SKIP_SOURCE_VALIDATION: "1"' not in ci:
    failures.append('CI real-engine gate re-runs the full source suite')

# Guard against another hand-maintained copy slowly diverging.
if 'python3 tests/static_validate.py' in ci or 'python3 tests/static_validate.py' in web:
    failures.append('duplicated source contract list remains outside validate-source.sh')

if failures:
    for failure in failures:
        print(f'FAIL: {failure}')
    raise SystemExit(f'SYNESTHESIA_VALIDATION_ENTRYPOINT=FAIL count={len(failures)}')

print('SYNESTHESIA_VALIDATION_ENTRYPOINT=PASS source=canonical local+ci+web+release=shared')
