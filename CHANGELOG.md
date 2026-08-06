# Changelog

## 0.6.1 — Godot 4.7.1 renderer hotfix

- Removed the custom `draw_ellipse` helper that collided with the native `CanvasItem.draw_ellipse` introduced in Godot 4.7.
- Switched mask eyes and The Calling table to the native major/minor ellipse signature.
- Added a static regression gate forbidding custom `draw_*` helpers in the room renderer.
- Kept all eleven rooms, audio excerpts, reward flow, haptics and web deployment contracts unchanged.

## 0.6.0 — Echoes Of The Modern Mind

- Expanded the prototype into an eleven-room playable album.
- Added separate architecture, palette, interaction and haptic behaviour for every track.
- Added Party Time balloons, Venetian masks, a dinner toast, a growing tree, a Western duel, Technophobia repair glitches, breakable mirrors, a phoenix, an intimate bedroom and a bright finale.
- Replaced the global reveal illusion with a local Visual Snow / muted-negative uncovering mask.
- Added a cinematic full reveal, music entrance and animated split doors at 99% normalized room progress.
- Added safe local excerpts for all eleven songs with bounded file sizes and gentle fades.
- Added versioned per-room and album-route persistence, including offline completion resynchronisation with preserved elapsed time.
- Added differentiated mobile haptic patterns and a persistent haptics toggle.
- Added a single-threaded Web export and Netlify-ready preview for `synesthesia.virya.music`.
- Added the optional CrowdRelay completion reward client and a separate no-store shipping form.
- Added static contracts for room order, renderers, audio, reward flow, permissions, domain and offline recovery.

## 0.3.1 — Parser hotfix

- Fixed Godot 4.7.1 failing to infer the restored room-state flag.
- Added explicit types at persistence boundaries.
- Extended runtime validation to load every gameplay script.

## 0.3.0 — Technophobia / Room Memory

- Removed editor class-cache dependent controller types.
- Added local room memory and the first real VIRYA completion excerpt.
- Added slow, low-contrast Technophobia visual glitches.

## 0.2.0 — Repository and build foundation

- Added root-level project structure, pinned CI and Linux/Web/Android export workflows.

## 0.1.0 — Calm vertical slice

- Added touch painting, traces, procedural sound, sensory modes and offline validation.
