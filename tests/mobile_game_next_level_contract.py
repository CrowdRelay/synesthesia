#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []

def read(rel: str) -> str:
    return (ROOT / rel).read_text(errors="replace")

def require(rel: str, *tokens: str) -> None:
    text = read(rel)
    for token in tokens:
        if token not in text:
            failures.append(f"{rel}: missing {token}")

require(
    "scripts/ui/settings_card.gd",
    '_close_x.name = "CloseSettingsX"',
    "add_child(_close_x)",
    "_close_x.z_index = 100",
    "Vector2(56.0, 56.0) * _ui_scale",
    "UiMetrics.safe_insets(viewport)",
)
settings = read("scripts/ui/settings_card.gd")
for forbidden in ("panel.add_child(_close_x)", "scroll.add_child(_close_x)"):
    if forbidden in settings:
        failures.append(f"settings close target returned under scroll/panel: {forbidden}")

require(
    "scripts/ui/mobile_instruction_builder.gd",
    "MobileMetaLabel",
    "REZONANS ×%d",
    "ECHA %d/%d",
    "KROK %d/3",
)
require("scripts/app/player_feedback_bridge.gd", "update_resonance_chain(0)", "update_resonance_chain(_resonance_chain)", "resonance_chain", "PEŁNA FAZA")
require("scripts/app/interaction_guide.gd", "max_resonance_chain", "_max_success_chain")
require("scripts/app/progress_metrics.gd", "max_resonance_chain", "max_chain >= 6")
require("scripts/ui/journey_pulse.gd", "TWÓJ ŚLAD", "JourneyPulseRail", "mastery_average", "personal_best_total_ms")
require("scripts/ui/experience_intro_card.gd", "JourneyPulse", "_journey_summary", "UiMetrics.safe_margin(viewport")
require("scripts/main.gd", "ProgressMetrics.menu_summary(release_entries, album_state)")
require("scripts/app/progress_metrics.gd", "static func menu_summary", "never scan 11 room saves/manifests here", "echo_archive")
require("scripts/ui/chapter_card.gd", "CEL · %s", "objective: String = \"\"", "GESTY · %s", "objective_steps: Array = []")
require("scripts/ui/completion_card.gd", "CEL WYKONANY · %s", "performance: Dictionary = {}, objective: String = \"\"", "REZONANS %s · %d/100%s")
require("scripts/app/main_room_flow.gd", "RoomObjective.goal(room_data)", "RoomObjective.steps(room_data)", "_completion_performance")
require("scripts/render/interaction_hint_layer.gd", "\"tap\":", "\"swipe\":", "\"release\":")
require("scripts/app/signal_relay_share.gd", "PODAJ SYGNAŁ DALEJ", "navigator.share", "DisplayServer.clipboard_set", "relay=grassroots")
require("scripts/ui/signal_finale_card.gd", "SignalRelayShare.add_to")
relay = read("scripts/app/signal_relay_share.gd")
for forbidden in ("handoff", "email=", "token=", "referral_code"):
    if forbidden in relay.lower():
        failures.append(f"grassroots relay must stay public/privacy-safe: {forbidden}")
finale = read("scripts/ui/signal_finale_card.gd")
if finale.index("SignalRelayShare.add_to") < finale.index("DOŁĄCZ DO LOSOWANIA 5 PŁYT"):
    failures.append("grassroots relay must remain secondary to completion/reward actions")

manifest_web = json.loads((ROOT / "web/manifest.webmanifest").read_text())
if "V2" in str(manifest_web.get("description", "")):
    failures.append("public PWA description must not expose internal V2 naming")
if "interaktywny album mobilny" not in str(manifest_web.get("description", "")):
    failures.append("public PWA description must state the mobile game/album promise")

# Every canonical room must expose a concrete mobile objective and a three-step
# authored interaction arc. This protects clarity without flattening mechanics.
index = json.loads((ROOT / "data/release_index.json").read_text())
entries = index.get("releases", index if isinstance(index, list) else [])
if not isinstance(entries, list) or len(entries) != 11:
    failures.append(f"release index expected 11 rooms, got {len(entries) if isinstance(entries, list) else 'invalid'}")
else:
    for entry in entries:
        manifest_path = ROOT / str(entry.get("manifest", "")).removeprefix("res://")
        if not manifest_path.is_file():
            failures.append(f"manifest missing: {manifest_path}")
            continue
        manifest = json.loads(manifest_path.read_text())
        room = manifest.get("room", {})
        micro = room.get("micro_interactions", {}) if isinstance(room, dict) else {}
        if not str(micro.get("goal", "")).strip():
            failures.append(f"{manifest_path.name}: mobile objective missing")
        steps = micro.get("steps", [])
        valid_steps = isinstance(steps, list) and len(steps) == 3 and all(
            isinstance(step, dict) and str(step.get("verb", "")).strip() and str(step.get("payoff", "")).strip()
            for step in steps
        )
        if not valid_steps:
            failures.append(f"{manifest_path.parent.name}: expected exactly 3 authored verb/payoff micro-interaction steps")

if failures:
    print("\n".join("FAIL: " + item for item in failures))
    raise SystemExit(f"SYNESTHESIA_NEXT_LEVEL_MOBILE=FAIL count={len(failures)}")
print("SYNESTHESIA_NEXT_LEVEL_MOBILE=PASS settings=touch-safe journey=pulse objectives=11 resonance=skill-loop relay=grassroots")
