#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
workflow = (ROOT / ".github/workflows/android-play.yml").read_text()
promotion = (ROOT / ".github/workflows/android-play-promote.yml").read_text()
runbook = (ROOT / "docs/google-play-production-release.md").read_text()

for token in (
    "options: [internal, production]",
    'play_status="inProgress"',
    'user_fraction="0.10"',
    "production-requires-wif",
    "Require exact main CI before manual production release",
    "synesthesia_runs_v1",
    "synesthesia_rewards_v1",
    "synesthesia_leaderboard_v1",
    "synesthesia_recovery_v1",
    "whatsNewDirectory: distribution/whatsnew",
):
    assert token in workflow, token

# Runtime values written through GITHUB_ENV are unavailable to Actions' `if:`
# expression evaluation. Production-only steps must key directly off the event
# input, not `env.SYNESTHESIA_PLAY_TRACK`.
assert "if: env.SYNESTHESIA_PLAY_TRACK == 'production'" not in workflow
assert "if: github.event_name == 'workflow_dispatch' && inputs.play_track == 'production'" in workflow

for token in (
    'options: ["25", "50", "100", "halt"]',
    "GOOGLE_PLAY_WIF_PROVIDER",
    "GOOGLE_PLAY_SERVICE_ACCOUNT",
    "token_format: access_token",
    "production",
    "synesthesia_runs_v1",
    "menu-world.webp",
):
    assert token in promotion, token
assert "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" not in promotion

for locale in ("pl-PL", "en-US"):
    text = (ROOT / "distribution/whatsnew" / f"whatsnew-{locale}").read_text().strip()
    assert text and len(text) <= 500, locale

for token in ("10% staged rollout", "10% → 25% → 50% → 100%", "Data safety", "Play App Signing"):
    assert token in runbook, token

spec = importlib.util.spec_from_file_location("google_play_rollout", ROOT / "tools/google_play_rollout.py")
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

track = {
    "track": "production",
    "releases": [
        {"versionCodes": ["100"], "status": "completed"},
        {"versionCodes": ["200"], "status": "inProgress", "userFraction": 0.10, "releaseNotes": [{"language": "pl-PL", "text": "x"}]},
    ],
}
updated, receipt = module.updated_track(track, "25", "200")
assert updated["releases"][1]["userFraction"] == 0.25
assert updated["releases"][1]["releaseNotes"] == track["releases"][1]["releaseNotes"]
assert receipt["nextUserFraction"] == 0.25

try:
    module.updated_track(updated, "25", "200")
except RuntimeError as error:
    assert "non-forward" in str(error)
else:
    raise AssertionError("rollout regression must be refused")

completed, _ = module.updated_track(track, "100", "200")
assert completed["releases"][1]["status"] == "completed"
assert "userFraction" not in completed["releases"][1]

print("SYNESTHESIA_GOOGLE_PLAY_PRODUCTION=PASS initial=10pct promotion=forward-only wif=required notes=localized")
