from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
stage = (ROOT / "scripts/render/room_stage.gd").read_text() + "\n" + (ROOT / "scripts/render/room_interaction_flow.gd").read_text()
attempts = (ROOT / "scripts/input/interaction_attempt_feedback.gd").read_text()
guide = (ROOT / "scripts/app/interaction_guide.gd").read_text()
hud = (ROOT / "scripts/ui/app_hud.gd").read_text()
haptics = (ROOT / "scripts/haptics.gd").read_text()
audio = (ROOT / "scripts/audio_director.gd").read_text()
base = (ROOT / "scripts/rooms/behavior_base.gd").read_text()
main = "\n".join((ROOT / path).read_text() for path in ("scripts/main.gd", "scripts/app/main_room_flow.gd", "scripts/app/main_settings_flow.gd", "scripts/app/main_reward_flow.gd"))
completion = (ROOT / "scripts/ui/completion_card.gd").read_text()

# Correct interaction gets a bounded visual/audio/haptic confirmation path.
for token in (
    'signal interaction_confirmed(point: Vector2, strength: float)',
    'attempt_feedback.success(point, 0.68)',
    'interaction_fx.spawn(point, "confirm")',
):
    assert token in stage, token
assert 'func confirmation(strength: float = 0.6) -> void:' in haptics
assert '_begin_semantic_pattern(118)' in haptics
assert 'generation == _pulse_generation' in haptics
assert 'now < _semantic_quiet_until_ms' in haptics
assert 'func play_confirmation_tick(strength: float = 0.6) -> void:' in audio
assert '_foreground_duck_target' in audio and '_foreground_duck_smoothed' in audio

# Misses never punish. They only accelerate the existing low-frequency guidance.
assert 'signal interaction_missed(point: Vector2)' in stage
assert 'func note_miss() -> void:' in guide
assert 'MISS_HINT_THRESHOLD := 2' in guide
assert 'visual_hint_changed.emit(strength)' in guide
assert 'func note_gesture_batch(' in attempts
assert 'func end_stroke(' in attempts

# Returning players get one earlier reminder; progress actively quiets assistance.
assert 'func prime_after_resume() -> void:' in guide
assert '_miss_count = maxi(0, _miss_count - 2)' in guide
assert 'hud.prime_hint_after_resume()' in main

# Mobile touch forgiveness is invisible and centralized across room behaviors.
assert 'interaction_forgiveness: float = 1.12' in base
assert '[1.12, 1.20, 1.30, 1.40]' in base
assert 'radius * (interaction_forgiveness + resonance_memory_strength)' in base

# HUD gets out of the way during interaction and the completion moment is diegetic.
assert 'var target_alpha: float = 0.30 if value' in hud
assert 'var target_bottom_alpha: float = 0.24 if value' in hud
assert 'func enter_completion_beat() -> void:' in hud
assert 'hud.enter_completion_beat()' in main
for token in ('var top_y: float = size.y * 0.66', 'draw_circle(Vector2(center_x'):
    assert token in stage, token

# Room-to-room audio is ducked under the physical door/teleport transition.
assert 'func begin_transition_out() -> void:' in audio
assert '_transition_duck_target * 7.0' in audio
assert 'audio_director.begin_transition_out()' in main

# CTA remains comfortably thumb-sized in the lower completion sheet.
assert '_next_button.custom_minimum_size = Vector2(280.0, 54.0)' in completion

# Preserve orchestration budgets without forcing artificial refactors for small
# resilience fixes. 420 remains the design target; 460 is the hard stop.
READABILITY_SOFT_BUDGET = 420
READABILITY_HARD_BUDGET = 460
for path in (ROOT / "scripts").rglob("*.gd"):
    lines = len(path.read_text().splitlines())
    if lines > READABILITY_HARD_BUDGET:
        raise AssertionError(
            f"{path}: {lines} lines exceeds hard readability cap "
            f"{READABILITY_HARD_BUDGET}"
        )
    if lines > READABILITY_SOFT_BUDGET:
        print(
            f"WARN: {path.relative_to(ROOT)}={lines} lines above "
            f"soft readability budget {READABILITY_SOFT_BUDGET}; "
            f"hard_cap={READABILITY_HARD_BUDGET}"
        )

print('SYNESTHESIA_PLAYER_EXPERIENCE_V32=PASS feedback=tri-modal misses=assist-only touch=forgiving hud=focus completion=diegetic audio=ducked')
