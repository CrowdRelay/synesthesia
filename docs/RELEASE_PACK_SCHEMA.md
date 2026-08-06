# Release pack schema v4

Each room lives in `data/releases/<id>/manifest.json` and is referenced in exact story order by `data/release_index.json`.

## Required top-level fields

```text
schema_version = 4
release_id
story_order
artist
title
subtitle
room
sensory
audio
collectibles (exactly three)
intro
completion_title
completion_message
```

## Room contract

```json
{
  "id": "room-id",
  "name": "Visible room name",
  "scene_path": "res://scenes/rooms/room-id.tscn",
  "behavior_script": "res://scripts/rooms/behaviors/room-id.gd",
  "render_pipeline": "mask-gpu-v1",
  "visual_style": "renderer-key",
  "interaction": "paint",
  "completion_coverage": 0.44,
  "cinematic_reveal_at": 0.99,
  "brush": {
    "profile": "ink",
    "min_width": 22,
    "max_width": 58,
    "opacity": 0.82,
    "texture": 0.52,
    "outline": 0.72,
    "spacing": 0.58
  },
  "art_direction": {
    "style": "dark_comic",
    "material_pass": "production-2.5d",
    "scene_image": "res://assets/rooms/vertical/room-id-scene.webp",
    "background_image": "res://assets/rooms/vertical/room-id-bg.webp",
    "subject_image": "res://assets/rooms/vertical/room-id-subject.webp",
    "foreground_image": "res://assets/rooms/vertical/room-id-foreground.webp",
    "layers": ["background", "scene", "subject", "foreground", "atmosphere"],
    "background_parallax": 0.004,
    "scene_parallax": 0.010,
    "subject_parallax": 0.016,
    "foreground_parallax": 0.025
  }
}
```

Production WebP dimensions are 810×1440 for scene/subject/foreground and 540×960 for the blurred background.

## Audio contract

```json
{
  "mode": "pink_noise_reveal_mix",
  "completion_excerpt": "res://assets/audio/room-id-room-outro.mp3",
  "noise_loop": "res://assets/audio/pink-noise-asmr-loop.ogg",
  "pink_noise_start_db": -5.0,
  "hidden_music_db": -44.0,
  "completion_volume_db": -8.0,
  "lowpass_start_hz": 1000.0,
  "lowpass_final_hz": 19500.0,
  "stereo_reveal": true,
  "dynamic_space_reveal": true
}
```

The sensory safe ceiling must be at most −6 dB. No room may introduce strobe or a sudden loudness jump.

## Adding a room

```bash
python3 tools/new_release_pack.py new-room \
  --title "VIRYA: New Room" \
  --room "Room name" \
  --style uncertainty \
  --position 2
```

The generator creates schema-v4 data, a PackedScene, behavior with three acts and all five placeholder layers, then atomically updates every `story_order`. Replace placeholders and provide the excerpt before adding the room to the production route. Run `tools/update_visual_snapshots.py` only after an approved art change.
