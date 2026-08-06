# Changelog

## 0.8.0 — Art Direction Pass

- replaces the circular debug-like stroke with an eleven-profile procedural comic brush engine;
- adds speed-sensitive width, deterministic stamp rotation, bristles, ink outlines and room-specific marks;
- upgrades Visual Snow into bounded CRT/cosmic static with scanlines, rolling bands and sparse stars;
- adds per-room static profiles, tinting and Technophobia-specific horizontal jitter;
- adds comic framing, halftone patches, chapter captions and room-specific graphic-novel accents;
- preserves the 99% cinematic reveal, reduced-motion mode and mobile rendering budgets.

## 0.7.0 — Polish, performance and resilience

- Added adaptive redraw scheduling: 60 Hz while painting or opening doors, 24–36 Hz while idle and 10 Hz in reduced-motion mode.
- Merged untouched VSS cells into horizontal strips and reduced the retained stroke budget, cutting the dominant CanvasItem draw-call load.
- Batched coverage notifications per gesture and rate-limited repeatable room interactions.
- Rebuilt balloon and mirror hit geometry after viewport resize or orientation changes.
- Added a compact two-column mobile control layout, album progress indicator, palette preview and scrollable responsive modals.
- Added durable per-room elapsed time, atomic schema-v3 progress writes and recovery from a previous save backup.
- Added bounded, deduplicated CrowdRelay requests with retry/backoff, expired-run recovery and automatic album finalisation after reconnect.
- Added a versioned PWA service worker, install manifest, cache-safe Netlify headers and a post-build asset report.
- Capped procedural audio catch-up work, added a Master hard limiter and cancelled delayed haptic pulses when sensory state changes.
- Added explicit mobile performance budgets and regression contracts to CI.

## 0.6.1 — Godot 4.7.1 renderer hotfix

- Removed the custom `draw_ellipse` helper that collided with the native `CanvasItem.draw_ellipse` introduced in Godot 4.7.
- Switched mask eyes and The Calling table to the native major/minor ellipse signature.
- Added a static regression gate forbidding custom `draw_*` helpers in the room renderer.

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
