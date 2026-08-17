#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source_gate = (ROOT / 'scripts/validate-source.sh').read_text()
fast_gate = (ROOT / 'scripts/validate-fast.sh').read_text()
canonical_gates = source_gate + '\n' + fast_gate

# The canonical source gate owns each executable contract exactly once. The
# fast suite is delegated as a unit, while the full suite adds independent
# build/release/resilience contracts. Historical exploratory contracts are not
# required to remain executable forever.
def contract_tokens(text: str) -> set[str]:
    return {
        raw.strip().rstrip('\\')
        for raw in text.splitlines()
        if raw.strip().startswith(('tests/', 'tools/'))
        and raw.strip().rstrip('\\').endswith(('.py',))
    }

fast_contracts = contract_tokens(fast_gate)
source_contracts = contract_tokens(source_gate)
if 'export PYTHONDONTWRITEBYTECODE=1' not in fast_gate or 'PYTHONPYCACHEPREFIX="$PYCACHE_DIR" python3 -m compileall' not in fast_gate:
    raise SystemExit('SYNESTHESIA_VALIDATION_ENTRYPOINT=FAIL fast gate writes Python cache into source tree')

duplicated_fast_contracts = sorted(fast_contracts & source_contracts)
validate = (ROOT / 'validate.sh').read_text()
web = (ROOT / 'scripts/build-web-preview.sh').read_text()
linux = (ROOT / 'scripts/build-linux-release.sh').read_text()
ci = (ROOT / '.github/workflows/ci.yml').read_text()
build = (ROOT / '.github/workflows/build.yml').read_text()
failures: list[str] = []

for contract in duplicated_fast_contracts:
    failures.append(f'validate-source.sh duplicates fast-gate contract: {contract}')

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
    if token not in canonical_gates:
        failures.append(f'canonical source gate missing: {token}')




# New contracts may be diagnostic or historical; canonical ownership is explicit
# and reviewed instead of being inferred from every *_contract.py file on disk.
for name, text in (
    ('validate.sh', validate),
    ('build-web-preview.sh', web),
    ('build-linux-release.sh', linux),
    ('ci.yml', ci),
):
    if './scripts/validate-source.sh' not in text:
        failures.append(f'{name}: bypasses canonical source validation entrypoint')

if 'if [[ -f "$ROOT/synesthesia_rust.gdextension" ]]' not in validate or './scripts/build-rust-native.sh disable >/dev/null' not in validate:
    failures.append('validate.sh: stale generated GDExtension registration is not purged for source-only validation')
if 'source "$ROOT/config/toolchains.env"' not in validate:
    failures.append('validate.sh: native runtime refresh does not load pinned toolchain configuration')
refresh = 'RUSTUP_TOOLCHAIN="$RUST_NATIVE_TOOLCHAIN"'
if refresh not in validate or './scripts/build-rust-native.sh host' not in validate:
    failures.append('validate.sh: existing native runtime is not rebuilt from current source with the pinned toolchain')
if refresh in validate and validate.find(refresh) > validate.find('run_godot_checked import'):
    failures.append('validate.sh: native runtime refresh happens after Godot import')
if 'res://tests/gdscript_parse_smoke.gd' not in validate or 'SYNESTHESIA_GDSCRIPT_PARSE=PASS' not in validate:
    failures.append('validate.sh: repository-wide GDScript parse sweep is missing')
if 'tests/netlify_artifact_deploy_contract.py' not in canonical_gates:
    failures.append('validate-source.sh: zero-build Netlify artifact contract is missing')
main_source = (ROOT / 'scripts/main.gd').read_text()
warmup_source = (ROOT / 'scripts/app/main_warmup_flow.gd').read_text()
if 'preload("res://scripts/app/diagnostics_overlay.gd")' in main_source or 'preload("res://scripts/app/diagnostics_overlay.gd")' in warmup_source:
    failures.append('startup path: optional diagnostics overlay is a hard parser dependency')
if 'ResourceLoader.exists(DIAGNOSTICS_OVERLAY_PATH)' not in warmup_source or 'call_deferred("install_diagnostics")' not in warmup_source:
    failures.append('main warmup: optional diagnostics overlay lacks guarded post-menu dynamic load')
diagnostics = (ROOT / 'scripts/app/diagnostics_overlay.gd').read_text()
if 'var preload:' in diagnostics:
    failures.append('diagnostics_overlay.gd: reserved GDScript preload identifier reused as a variable')


if 'tests/font_glyph_smoke.gd' not in validate or 'SYNESTHESIA_FONT_GLYPHS=PASS' not in validate:
    failures.append('validate.sh: bundled title font Polish glyph coverage is not runtime-gated')
if validate.count('./scripts/prepare-bundled-fonts.sh') < 1:
    failures.append('validate.sh: skipped source validation can leave generated font inputs absent')
if 'repair_missing_font_import_remaps' not in validate or 'SYNESTHESIA_FONT_IMPORT_ARTIFACTS=PASS' not in validate:
    failures.append('validate.sh: stale tracked font remaps are not repaired and verified before glyph smoke')

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
