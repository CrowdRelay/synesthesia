#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
deploy = (ROOT / ".github/workflows/deploy-web.yml").read_text()
ci = (ROOT / ".github/workflows/ci.yml").read_text()
netlify = (ROOT / "netlify.toml").read_text()
builder = (ROOT / "scripts/build-web-preview.sh").read_text()
failures: list[str] = []

for token in (
    'workflows: ["CI"]',
    "github.event.workflow_run.conclusion == 'success'",
    "github.event.workflow_run.head_branch == 'main'",
    "actions/download-artifact@",
    "run-id: ${{ steps.source.outputs.run_id }}",
    "synesthesia-web-${{ steps.source.outputs.sha }}",
    "artifact_manifest.py verify",
    "rebuild=false",
    "netlify-cli@26.2.0 deploy",
    "--prod",
    "--no-build",
    "--dir=promoted/build/web",
    'NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}',
    'NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}',
    "/api/v1/sites/${NETLIFY_SITE_ID}",
    "source_builds=stopped",
):
    if token not in deploy:
        failures.append(f"deploy workflow missing: {token}")

for forbidden in (
    "actions/checkout@",
    "build-web-preview.sh",
    "prepare-bundled-fonts.sh",
    "Cache verified Godot",
    "rustup toolchain install",
    "cargo build",
    "emsdk",
):
    if forbidden in deploy:
        failures.append(f"deploy workflow must not rebuild source: {forbidden}")

for token in (
    "Build production Web artifact once",
    'SYNESTHESIA_RUST_WEB_REQUIRED: "0"',
    'SYNESTHESIA_SKIP_SOURCE_VALIDATION: "1"',
    "tools/artifact_manifest.py create",
    "tools/artifact_manifest.py verify",
    "actions/upload-artifact@",
    "synesthesia-web-${{ github.sha }}",
):
    if token not in ci:
        failures.append(f"CI promotion artifact missing: {token}")

for obsolete in (
    "scripts/deploy-netlify-zip.py",
    "scripts/package-netlify-deploy.py",
    "netlify/plugins/synesthesia-build-cache",
):
    if (ROOT / obsolete).exists():
        failures.append(f"obsolete custom deploy path still exists: {obsolete}")

if 'publish = "build/web"' not in netlify:
    failures.append("netlify.toml publish dir drifted")
if 'ignore = "exit 0"' not in netlify:
    failures.append("netlify.toml does not skip linked Git builds")
if "command =" in netlify:
    failures.append("netlify.toml still declares a Netlify-side build command")
if "[[plugins]]" in netlify:
    failures.append("netlify.toml still runs a Netlify build plugin")
if "python3 tools/web_bundle_budget.py" not in builder:
    failures.append("GitHub-built Web artifact bypasses final bundle budget")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_NETLIFY_ARTIFACT_DEPLOY=FAIL count={len(failures)}")

print("SYNESTHESIA_NETLIFY_ARTIFACT_DEPLOY=PASS build=ci-once deploy=exact-artifact netlify=zero-build")
