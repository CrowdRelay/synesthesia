# Release pack schema v3

`data/release_index.json` defines one ordered album route. Each entry points to `data/releases/<id>/manifest.json`.

## Required manifest fields

- `schema_version`: exactly `3`;
- `release_id`: lower-case hyphenated identifier;
- `story_order`: zero-based route position;
- `artist`, `title`, `subtitle`;
- `room`: visual and interaction configuration;
- `sensory`: safe visual, audio and haptic bounds;
- `audio`: local completion excerpt;
- `collectibles`: exactly three narrative traces;
- `intro`, `completion_title`, `completion_message`.

## Room contract

```json
{
  "name": "Visible room name",
  "visual_style": "renderer-key",
  "interaction": "interaction-key",
  "base_color": "#101827",
  "floor_color": "#080c14",
  "accent_color": "#71afff",
  "secondary_color": "#ff5f7c",
  "paint_palette": ["#71afff", "#ffffff"],
  "completion_coverage": 0.44,
  "cinematic_reveal_at": 0.99
}
```

`completion_coverage` is the physical grid coverage required for a practical completion. `cinematic_reveal_at` remains `0.99` so the runtime releases the last one percent automatically.

## Audio contract

```json
{
  "mode": "procedural_then_excerpt",
  "title": "Track title",
  "completion_excerpt": "res://assets/audio/example-room-outro.mp3",
  "completion_volume_db": -13.0,
  "source": "VIRYA — Echoes Of The Modern Mind"
}
```

Excerpts are local, short, gently faded and statically limited to 50 KB–2 MB. `safe_audio_ceiling_db` in `sensory` must be at most `-6 dB`.

## Sensory contract

- Visual Snow: `0.0..0.12`;
- haptic amplitude: `0.0..0.65`;
- calm mode is the default;
- every effect must remain meaningful when haptics are unavailable;
- no strobe or sudden loudness spike.

## Adding a room

```bash
python3 tools/new_release_pack.py new-room \
  --title "VIRYA: New Room" \
  --room "Room name" \
  --style custom-style
```

The scaffold creates schema v3 data and an empty excerpt placeholder path. A new visual style must also be implemented and added to static contracts before CI can pass.

## v0.8 art-direction fields

Every room now owns two additional data-only objects inside `room`:

```json
{
  "brush": {
    "profile": "ink",
    "min_width": 20,
    "max_width": 52,
    "opacity": 0.86,
    "texture": 0.64,
    "outline": 0.86,
    "spacing": 0.54
  },
  "art_direction": {
    "style": "dark_comic",
    "caption": "MASKI NIE MÓWIĄ PRAWDY",
    "ink_strength": 0.82,
    "halftone_strength": 0.30
  }
}
```

The sensory object also controls bounded CRT/cosmic static through `visual_snow_tint`, `scanline_strength`, `roll_strength`, `sparkle_density`, `horizontal_jitter`, `static_motion_calm` and `static_motion_full`. These values are data only and are clamped by the runtime and static validator.
