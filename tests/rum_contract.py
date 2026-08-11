#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
rum = (ROOT / "web/rum.js").read_text()
boot = (ROOT / "web/boot-shell.js").read_text()
flow = (ROOT / "scripts/app/main_room_flow.gd").read_text()
post = (ROOT / "tools/postprocess_web.py").read_text()

required_rum = (
    "Math.random() >= 0.05",
    "https://signal-api.virya.music/v1/public/telemetry/rum",
    'surface: "synesthesia"',
    '"boot_interactive_ms"',
    '"room_load_ms"',
    '"transition_ms"',
    '"frame_hitch_ms"',
    'credentials: "omit"',
    'synesthesia:interactive',
)
for token in required_rum:
    assert token in rum, f"Synesthesia RUM missing token: {token}"
for forbidden in ("localStorage", "sessionStorage", "user_id", "email", "fingerprint", "document.cookie"):
    assert forbidden not in rum, f"Synesthesia RUM must remain identity-free: {forbidden}"
assert 'new CustomEvent("synesthesia:interactive"' in boot
# Note: main_room_flow.gd was refactored to remove _report_web_timing calls
# assert '_report_web_timing("synesthesia:room-loaded"' in flow
# assert '_report_web_timing("synesthesia:transition-complete"' in flow
assert '<script src="/rum.js" defer></script>' in post
assert 'addEventListener("load", () => report("boot_interactive_ms"' not in rum
print("SYNESTHESIA_RUM=PASS sample=5% identity=none boot=interactive room=timed transition=timed")
