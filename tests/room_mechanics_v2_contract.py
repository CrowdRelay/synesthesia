from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
behaviors = ROOT / "scripts" / "rooms" / "behaviors"
expected = {
    "wave-of-uncertainty.gd": ("calmness", "horizon"),
    "party-time.gd": ("popped", "BALLOONS"),
    "unmasked.gd": ("cracks", "removed"),
    "the-calling.gd": ("poured", "toast"),
    "seed-of-doubt.gd": ("growth", "crown"),
    "hybrid.gd": ("aim_strength", "duel"),
    "technophobia.gd": ("screens", "signal_locked"),
    "invaluable.gd": ("cracked", "shattered"),
    "from-the-ashes.gd": ("swirl", "phoenix"),
    "waves.gd": ("closeness", "shared_rhythm"),
    "rise.gd": ("light_tap", "final_gesture"),
}

for filename, tokens in expected.items():
    text = (behaviors / filename).read_text()
    assert "func mechanic_progress() -> float:" in text, filename
    for token in tokens:
        assert token in text, (filename, token)

stage = (ROOT / "scripts" / "render" / "room_stage.gd").read_text() + "\n" + (ROOT / "scripts" / "render" / "room_interaction_flow.gd").read_text() + "\n" + (ROOT / "scripts" / "render" / "room_state_flow.gd").read_text()
assert 'MechanicProgress.resolve' in stage
resolver = (ROOT / 'scripts' / 'rooms' / 'mechanic_progress.gd').read_text()
assert 'behavior.mechanic_progress()' in resolver
assert 'mask_value * weight' in resolver
assert 'weight = clampf(float(behavior.brush_assist_weight()), 0.0, 0.35)' in resolver
assert 'cannot complete an interactive room' in resolver

base = (ROOT / "scripts" / "rooms" / "behavior_base.gd").read_text()
assert 'func brush_assist_weight() -> float:' in base
assert 'return 0.22' in base

party = (behaviors / "party-time.gd").read_text()
paint_pos = party.index('func on_paint(')
assert 'return []' in party[paint_pos:paint_pos + 360]

tech = (behaviors / "technophobia.gd").read_text()
assert 'state.get("screens", []).size() >= 5' in tech

hud = (ROOT / "scripts" / "ui" / "app_hud.gd").read_text()
assert 'ŚLAD DŁONI' in hud
assert 'GŁÓWNY RYTUAŁ ROZPRASZA SZUM' in hud

print('SYNESTHESIA_ROOM_MECHANICS_V2=PASS rooms=11 progress=mechanic-first brush=assist-only')
