from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
guide = (ROOT / "scripts/app/interaction_guide.gd").read_text()
hud = (ROOT / "scripts/ui/app_hud.gd").read_text()

required_interactions = [
    "paint", "pop_balloons", "venetian_masks", "toast_table", "grow_tree",
    "western_duel", "repair_glitches", "crack_mirrors", "raise_phoenix",
    "intimate_bedroom", "rise_atrium",
]
for interaction in required_interactions:
    assert f'"{interaction}"' in guide, interaction

assert "FIRST_IDLE_SECONDS := 4.2" in guide
assert "FOLLOWUP_IDLE_SECONDS := 11.0" in guide
assert "visual_hint_changed.emit(0.44)" in guide
assert "PROGRESS_EPSILON" in guide
assert "hint_ready.emit" in guide
assert "func note_progress" in guide
assert "progress >= 0.99" in guide
assert "func note_interaction" in guide
assert "InteractionGuide.new()" in hud
assert "hint_ready.connect(update_discovery)" in hud
assert "_interaction_guide.configure(interaction)" in hud
assert "_interaction_guide.note_progress(normalized)" in hud
assert "_interaction_guide.note_interaction()" in hud
assert "_interaction_guide.suspend()" in hud

print("SYNESTHESIA_INTERACTION_GUIDANCE=PASS rooms=11 adaptive=idle-only fallback=paint")
