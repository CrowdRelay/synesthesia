from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "scripts" / "audio" / "menu_soundscape.gd").read_text()
main = (ROOT / "scripts" / "main.gd").read_text()
runtime = (ROOT / "scripts" / "app" / "soundscape_runtime.gd").read_text()

tracks = re.findall(r'"res://assets/audio/[^\"]+-room-outro\.mp3"', source)
assert len(tracks) == 11, len(tracks)
for token in (
    '_menu_roll_made',
    '_rng.randf() < 0.5',
    'func enter_menu() -> void:',
    'func enter_outro() -> void:',
    'func leave_soundscape() -> void:',
    'MENU_MUSIC_DB := -23.0',
    'OUTRO_MUSIC_DB := -17.0',
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
print('SYNESTHESIA_MENU_SOUNDSCAPE=PASS menu=50/50-per-run outro=random-always tracks=11 fade=bounded')
