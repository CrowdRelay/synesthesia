#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
workflow = (ROOT / ".github/workflows/deploy-web.yml").read_text()
netlify = (ROOT / "netlify.toml").read_text()
builder = (ROOT / "scripts/build-web-preview.sh").read_text()
failures: list[str] = []

required_workflow = (
    'workflows: ["CI"]',
    "github.event.workflow_run.conclusion == 'success'",
    "github.event.workflow_run.head_branch == 'main'",
    'SYNESTHESIA_RUST_WEB_REQUIRED: "0"',
    'SYNESTHESIA_SKIP_SOURCE_VALIDATION:',
    'netlify-cli@26.2.0 deploy',
    '--prod',
    '--no-build',
    '--dir=build/web',
    'NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}',
    'NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}',
    '/api/v1/sites/${NETLIFY_SITE_ID}',
    'source_builds=stopped',
    'git ls-remote origin refs/heads/main',
    "test -z \"$(find build/web -type f -name 'synesthesia_gdext.wasm' -print -quit)\"",
)
for token in required_workflow:
    if token not in workflow:
        failures.append(f"workflow missing: {token}")

for forbidden in (
    'scripts/deploy-netlify-zip.py',
    'scripts/package-netlify-deploy.py',
    'netlify/plugins/synesthesia-build-cache',
):
    if forbidden in workflow:
        failures.append(f"workflow retains obsolete custom deploy path: {forbidden}")

if 'publish = "build/web"' not in netlify:
    failures.append('netlify.toml publish dir drifted')
if 'ignore = "exit 0"' not in netlify:
    failures.append('netlify.toml does not skip linked Git builds')
if 'command =' in netlify:
    failures.append('netlify.toml still declares a Netlify-side build command')
if '[[plugins]]' in netlify:
    failures.append('netlify.toml still runs a Netlify build plugin')
if 'python3 tools/web_bundle_budget.py' not in builder:
    failures.append('GitHub-built Web artifact bypasses final bundle budget')

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_NETLIFY_ARTIFACT_DEPLOY=FAIL count={len(failures)}")

print("SYNESTHESIA_NETLIFY_ARTIFACT_DEPLOY=PASS builder=github-actions deploy=netlify-cli-no-build logs=github")
