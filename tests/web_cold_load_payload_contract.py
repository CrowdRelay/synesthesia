#!/usr/bin/env python3
"""Nothing the player never sees may sit on the Web cold-load critical path."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
post = (ROOT / "tools/postprocess_web.py").read_text()
project = (ROOT / "project.godot").read_text()
failures: list[str] = []

# Godot honours boot_splash/show_image.web=false by rendering the status splash
# with display:none, but it still exports the image and still emits its src, so
# a cold load pays the full incompressible PNG for a picture the custom boot
# shell covers. Post-processing must strip both.
if "boot_splash/show_image.web=false" not in project:
    failures.append("web-stock-splash-re-enabled")
for token in (
    'html, splash_src_removed = re.subn(',
    '<img id="status-splash"',
    'splash_image = BUILD / "index.png"',
    "splash_image.unlink()",
    "splash_src_removed",
):
    if token not in post:
        failures.append(f"splash-strip-missing:{token}")

# Editor .import sidecars are build metadata; the runtime reads the PCK.
for token in ('stray_imports = sorted(BUILD.rglob("*.import"))', "stray.unlink()"):
    if token not in post:
        failures.append(f"import-sidecar-strip-missing:{token}")

# The editor must not treat the export output as project content, otherwise it
# re-imports multi-MiB artifacts and writes sidecars back into the deploy. The
# marker is generated (build/ stays untracked), so the builder must write it.
builder = (ROOT / "scripts/build-web-preview.sh").read_text()
if "printf '' > build/.gdignore" not in builder:
    failures.append("builder-does-not-write-build-gdignore")

build_web = ROOT / "build/web"
if build_web.is_dir():
    if (build_web / "index.png").is_file():
        failures.append("built-artifact-still-ships-unrendered-splash")
    strays = [p.name for p in build_web.rglob("*.import")]
    if strays:
        failures.append(f"built-artifact-still-ships-import-sidecars:{len(strays)}")
    index_html = build_web / "index.html"
    if index_html.is_file() and 'id="status-splash"' in index_html.read_text():
        if 'src="index.png"' in index_html.read_text():
            failures.append("built-index-html-still-requests-splash")

if failures:
    raise SystemExit("SYNESTHESIA_WEB_COLD_LOAD_PAYLOAD=FAIL " + ",".join(failures))
print("SYNESTHESIA_WEB_COLD_LOAD_PAYLOAD=PASS splash=stripped import-sidecars=stripped editor=gdignored")
