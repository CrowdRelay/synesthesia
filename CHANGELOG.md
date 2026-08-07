## 0.11.4 — Cinematic Inner Rooms / UX Pass

- Fixes chapter, act and discovery-toast layouts so long Polish copy keeps a usable horizontal measure instead of collapsing to one-character columns.
- Restyles story bubbles as asymmetric album panels and keeps them clear of the artwork while painting.
- Adds a short balloon POP SFX on top of the existing haptic feedback.
- Makes the pink-noise/music balance directly proportional to reveal: 20% reveal = 80/20 noise/music, 50% = 50/50, 80% = 20/80, and 99% = music only.
- Adds room-specific post-unlock motion loops and a restrained cinematic left/right camera drift, with reduced-motion support.
- Dresses every artwork as a subtle “room of consciousness” using edge architecture, threshold perspective and an unlocked doorway without covering the central scene.
- Replaces room-to-room fades with a door-close → neural inner-corridor teleport → door-open transition.
- Rebuilds the final “Sygnał dotarł” claim as an album-styled bottom sheet over an animated Echoes Of The Modern Mind dissolving-skull background.
- Keeps the finale cover dynamically loaded only at the end; active room and current+next memory budgets remain bounded.
- Extends lifecycle smoke tests to audio POP, chapter/act/toast widths, completion/finale layout and door-transition instantiation.

## 0.11.3 — UX, local reset and runtime asset hotfix

- fixes narrow ScrollContainer layouts that could wrap labels one character per line;
- adds safe whole-journey local reset from the finished-album UI and Settings;
- adds `./run-macos.sh --reset` / `--reset-only` for local development;
- always imports source assets before launching, fixing false missing MP3/OGG warnings after `.godot` cleanup;
- keeps Godot import cache after validated overlay install;
- drains threaded preload work and cancels pending reward HTTP on shutdown to avoid exit leaks;
- overlay carries all 11 music excerpts plus the pink-noise loop as a repair contract.

## 0.11.2 — Godot 4.7.1 parser hotfix

- Replaced shader-only `step()` calls in `RevealMask` with a typed GDScript threshold helper.
- Removed ambiguous integer division from the same hot path and Technophobia behavior.
- Added a repository gate forbidding shader-only globals in `.gd` files.
- No art, gameplay, reward, audio curve, or persistence semantics changed.

# Changelog

## 0.11.1 — Godot 4.7.1 compatibility hotfix

- Replaced the unsupported `Color.with_alpha()` calls with the Godot 4.7.1-compatible `Color(existing_color, alpha)` constructor across UI, transitions, renderer, atmosphere, interaction FX, and room behaviors.
- Added a static regression gate that rejects `Color.with_alpha()` anywhere in GDScript.
- No gameplay, art, persistence, reward, or audio behavior changes.


## 0.11.0 — Production Polish / Release-Candidate Pass

- Persists the reveal as an exact bounded PNG mask instead of a capped stamp history, with migration from older stamp/segment state.
- Reworks reveal painting around a `PackedByteArray` and dirty texture uploads; removes per-pixel `Image.set_pixel()` and historical stroke redraw.
- Reduces active decoded room art to 8.22 MiB and current+next to 16.44 MiB under a dependency-free WebP memory budget.
- Resizes 2.5D layers by visual role and switches the composite shader to linear non-mipmapped sampling.
- Adds adaptive frame/memory pressure handling for Balanced quality with automatic degradation and recovery.
- Makes threaded next-room preloads consumable by room scenes, image layers and audio.
- Adds cinematic radial final reveal, subject lift, bounded brush glow, film grain and room-specific interaction VFX.
- Adds chapter cards, act banners, discovery toasts, focus-mode HUD and a delayed bottom-sheet completion moment.
- Extracts sensory controls into a responsive settings card and adds Android/escape back navigation.
- Debounces settings writes, stops stale room-save timers during transitions and immediately releases old room/audio/haptics nodes.
- Caches audio bus effect updates, permits true 0% music and lets discoveries contribute gently to the audio reveal.
- Adds mask payload limits, runtime mask PNG round-trip validation, production-polish contracts and stdlib-only CI memory checks.
- Updates the future-room generator to produce role-correct 9:16 placeholder dimensions.

## 0.10.0 — Production Renderer and Room Identity

- Replaces stretched horizontal plates with native portrait 810×1440 room art.
- Adds a five-layer 2.5D stack: background, scene, central subject, foreground and atmosphere.
- Replaces retained stroke redraw with a dirty-upload L8 reveal mask and one GPU composite shader.
- Adds deterministic speed-sensitive comic brush stamps with bounded history and profile-specific texture.
- Splits all eleven rooms into PackedScenes and behavior modules with three narrative acts each.
- Adds Battery, Balanced and High quality profiles around a 540×960 logical viewport.
- Replaces procedural pink noise with a seamless stereo OGG and reveals music gain, bandwidth and space.
- Adds a receding portrait HUD, independent music/noise/VSS/haptics controls and reduced-motion support.
- Adds threaded next-room preload, schema-v4 atomic checkpoints and a debug diagnostics overlay.
- Adds visual layer snapshots, generator regression, room pipeline contracts and runtime room instantiation tests.
- Removes the legacy paint renderer, standalone Visual Snow shader and horizontal room JPGs.

## 0.9.2 — Pink-noise reveal mix and cumulative installer

- Adds a soft runtime-generated ASMR pink-noise bed to every room.
- Crossfades continuously from noise-dominant to music-dominant as painting reveals the scene.
- Mutes the noise completely at the 99% cinematic reveal, leaving only the room track.
- Keeps calm and quiet modes effective across both noise and music.
- Makes the overlay cumulative from a clean 0.8.0 rollback state.
- Includes the 0.9.0 scene-fidelity pass, the validator scope fix and the 1080×1920 portrait viewport.

## 0.9.0 — Cover Fidelity / Scene Pass

- Eleven concrete cinematic room tableaux grounded in VIRYA cover art and track narratives.
- Photorealistic-comic material plates under the VSS reveal mask.
- Subtle parallax, vignette and narrative light pass per room.
- Scene assets stay offline, compressed and mobile-budgeted.

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
