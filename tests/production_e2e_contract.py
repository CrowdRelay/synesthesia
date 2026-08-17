#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ci = (ROOT / ".github/workflows/ci.yml").read_text(errors="replace")
deploy = (ROOT / ".github/workflows/deploy-web.yml").read_text(errors="replace")
driver = (ROOT / "tests/e2e/full_game_web.py").read_text(errors="replace")
reward_flow = (ROOT / "scripts/app/main_reward_flow.gd").read_text(errors="replace")

failures: list[str] = []

# Keep the real-pointer suite available for explicit diagnostics. It is useful
# evidence, but the physics/reveal simulation is not deterministic enough to be
# a source/release gate.
for token in (
    "page.mouse.down()",
    "x.kind === 'completion'",
    "SYNESTHESIA_SIGNAL_CONVERSION_E2E=PASS",
    "SYNESTHESIA_AUDIO_STATE_E2E=PASS",
):
    if token not in driver:
        failures.append(f"manual E2E driver lost capability: {token}")

for forbidden in (
    "Run full-game Web E2E against exact build artifact",
    "Upload full-game E2E diagnostics",
    "python3 -m playwright install --with-deps chromium",
):
    if forbidden in ci:
        failures.append(f"automatic CI still depends on full-game E2E: {forbidden}")

for forbidden in (
    "Install production E2E runner",
    "Deploy exact artifact to isolated Netlify preview",
    "Full-game preview E2E before production promotion",
    "Full-game production E2E",
    "Upload production E2E diagnostics",
    "SYNESTHESIA_PREPROD_E2E=PASS",
    "SYNESTHESIA_PROD_E2E=PASS",
):
    if forbidden in deploy:
        failures.append(f"production promotion still depends on full-game E2E: {forbidden}")

guard = reward_flow.split("func arm_finale_guard()", 1)[1].split(
    "func _reward_panel_ready()", 1
)[0]
for required in ("_show_reward_panel()", "_force_reward_panel_visible()"):
    if required not in guard:
        failures.append(f"finale guard lost immediate actionable UI: {required}")
if "get_tree().create_timer(0.80)" not in guard:
    failures.append("finale guard lost watchdog timer")
elif "_show_reward_panel()" in guard:
    if guard.index("_show_reward_panel()") > guard.index("get_tree().create_timer(0.80)"):
        failures.append("finale form is still first shown after watchdog timer")

if failures:
    for failure in failures:
        print("FAIL:", failure)
    raise SystemExit(
        f"SYNESTHESIA_PRODUCTION_E2E_CONTRACT=FAIL count={len(failures)}"
    )

print(
    "SYNESTHESIA_PRODUCTION_E2E_CONTRACT=PASS "
    "mode=manual-diagnostic release-gate=off finale=immediate-actionable"
)
