from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "scripts" / "audio" / "menu_soundscape.gd").read_text()
main = "\n".join((ROOT / path).read_text() for path in ("scripts/main.gd", "scripts/app/main_room_flow.gd", "scripts/app/main_settings_flow.gd", "scripts/app/main_reward_flow.gd"))
runtime = (ROOT / "scripts" / "app" / "soundscape_runtime.gd").read_text()

tracks = re.findall(r'"res://assets/audio/[^\"]+-room-outro\.mp3"', source)
assert len(tracks) == 11, len(tracks)
for token in (
    '_menu_roll_made',
    '_rng.randf() < 0.5',
    'func enter_menu() -> void:',
    'func enter_outro() -> void:',
    'func leave_soundscape() -> void:',
    'MENU_MUSIC_DB := -21.0',
    'OUTRO_MUSIC_DB := -15.0',
    'PINK_NOISE_PATH',
    '_start_random_track(_current_track_index)',
):
    assert token in source, token

for token in (
    'SoundscapeRuntime.install',
    'SoundscapeRuntime.suspend_for_menu',
    'SoundscapeRuntime.resume_room',
    'SoundscapeRuntime.enter_outro',
    'SoundscapeRuntime.apply_audio_levels',
):
    assert token in main, token
for token in (
    'MenuSoundscapeScript',
    'soundscape.enter_menu()',
    'soundscape.leave_soundscape()',
    'soundscape.enter_outro()',
    'MenuRuntimeGuard.suspend',
    'MenuRuntimeGuard.resume',
):
    assert token in runtime, token

assert source.count('_rng.randf() < 0.5') == 1

ready = source[source.index('func _ready() -> void:'):source.index('func set_user_levels')]
assert 'load(' not in ready, 'menu soundscape performs synchronous resource load in _ready'
for token in ('load_threaded_request', 'load_threaded_get_status', 'load_threaded_get', '_pending_noise', '_pending_track_index'):
    assert token in source, token
print('SYNESTHESIA_MENU_SOUNDSCAPE=PASS menu=50/50-per-run outro=random-always tracks=11 load=post-menu-threaded fade=bounded')
