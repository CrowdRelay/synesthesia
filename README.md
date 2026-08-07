## 0.11.11 — macOS Godot 4.7.1 importer crash hotfix

- removes the legacy `settings-gear.svg` that could segfault Godot 4.7.1 during the headless editor reimport on macOS
- draws the Settings gear procedurally in GDScript, so the icon no longer depends on SVG or font/emoji import support
- ignores the legacy `assets/ui` SVG directory on overlay installs and purges only its stale `.godot/imported` cache before `run-macos.sh` starts the editor scan
- retains the runtime audio-before-HUD ordering and self-healing HUD references from the previous runtime hotfix

## 0.11.11 — Runtime Shader / Clean Loops / Settings Gear Hotfix

- Fixes Godot 4.7.1 shader compilation by keeping every `TEXTURE` sample inside `fragment()` instead of referencing the CanvasItem builtin from a helper function.
- Rebuilds all cinematic ping-pong loops after removing the final 8 AI outro/watermark frames from the forward pass; Hybrid keeps its earlier editorial cut.
- Replaces the font-dependent menu glyph with a bundled SVG gear icon so Settings renders consistently on macOS, mobile and Web.
- Keeps 720×1280 / 24 fps lazy Ogg Theora playback, themed post-processing, Unmasked eye glow and the stronger Echoes finale form cover.

## 0.11.9 — playback/layout hotfix

Cinematic room videos now use direct `VideoStreamTheora` runtime streams, and the two persistent HUD cards are laid out side by side in a single header row.

## 0.11.8 cinematic reveal

Completed rooms now cross from the exact painted still into a lazy-loaded 720×1280 Theora loop. Each clip uses a restrained thematic post-process to unify AI-generated motion with the original artwork; Unmasked additionally burns out the generated slit pupils with a dedicated additive eye-glow pass. The final Echoes animation is blended with the original cover and sits behind a denser Signal claim sheet.

## 0.11.7 — Living Rooms / Sensory Pass

- Moves the act banner into an independent top-right safe slot so it cannot overlap the instruction panel.
- Adds a quiet thematic ambience bed for every one of the 11 rooms, plus room-specific interaction SFX.
- Makes room transitions explicitly door-like: paneled leaves, handles, close/open sounds and a perspective zoom/suck teleport through the threshold.
- Keeps every fully revealed room alive instead of freezing: alternating waves, rising balloons and light, glowing/opening masks, banquet toast motion, twisting Seed tree, first-person Hybrid duel, Technophobia glitches, simultaneous Invaluable mirror burst, phoenix take-off, bedroom lamp/window wind, and Rise ascent into the window light.
- Makes the Echoes finale skull disintegrate much more aggressively with denser dust and leftward particle streaks.
- Adds regression coverage for thematic audio assets, living-room animation hooks, door teleport state and HUD non-overlap.

## 0.11.5 — Audio / HUD / CI hotfix

- Room music uses Godot resource resolution again, including exported/imported MP3 and OGG assets.
- Persistent act marker is right-aligned in the lower HUD.
- Atmosphere drawing is safe before particle configuration, fixing runtime validation in CI.

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

# VIRYA: Synestezja

A portrait Godot 4.7.1 experience that turns **Echoes Of The Modern Mind** into eleven playable, cover-inspired rooms. The player uncovers each scene with a textured comic brush while Visual Snow, cosmic CRT static and soft ASMR pink noise recede; at 99% the filter disappears and only the full room excerpt remains.

## 0.11.2 — Godot 4.7.1 parser hotfix

This release turns the 0.10 renderer into a tighter production runtime rather than adding another decorative layer:

- exact raster reveal persistence (`png-mask-v2`) so long sessions never lose old painted areas after restart;
- retained L8 brush mask backed by a byte buffer, avoiding per-pixel `Image.set_pixel()` calls and stroke-history replay;
- lower decoded room-layer budget: **8.22 MiB active / 16.44 MiB current+next** under the static contract;
- asymmetric 2.5D art sizes (405×720 background, 675×1200 scene/subject, 540×960 foreground) matched to what is actually visible;
- adaptive Balanced mode that reduces atmosphere, mask-upload cadence and shader motion under sustained frame or memory pressure, then recovers;
- consumed threaded preloads for the next room's PackedScene, four image layers and audio instead of leaving resources queued;
- cinematic GPU reveal from the final brush point, subtle subject lift, film grain and bounded interaction VFX;
- chapter cards, act banners, discovery toasts, auto-hiding HUD and an unobtrusive completion sheet that lets the full image/music breathe;
- a dedicated responsive settings card with instant sensory changes, debounced persistence and Android/back navigation;
- cached audio-effect updates, exact zero-volume music control and richer room-specific haptics;
- immediate release of the previous room/audio/haptics on transitions, stale-save-timer cancellation and bounded persisted-mask input;
- stdlib-only WebP memory gate, production-polish contract and stronger runtime mask round-trip validation.

The logical viewport remains **540×960**. The production source layers are intentionally asymmetric to reduce RAM/VRAM while keeping the scene/subject oversampled relative to the phone viewport. The renderer uses linear filtering without requesting mipmapped sampling for these full-screen 2D plates.

## Album route

1. Wave of Uncertainty — a wave breaking into an interior.
2. Party Time — a photorealistic comic party room with balloons and confetti.
3. Unmasked — a ceremonial Venetian mask chamber.
4. The Calling — a monochrome dinner and red-wine toast.
5. Seed of Doubt — an oppressive room split by a growing tree.
6. Hybrid — a first-person Western duel.
7. Technophobia — a cyber-organic CRT nightmare.
8. Invaluable — a gallery of breakable mirrors.
9. From the Ashes — a phoenix assembling from ash and embers.
10. Waves — an intimate bedroom in warm half-light.
11. Rise — a confident, luminous album finale.

Each room has a unique brush profile, three story traces, three acts, interaction state, haptics, materials, atmosphere and a local VIRYA excerpt.

## Run on macOS

```bash
./run-macos.sh
```

The script uses `GODOT_BIN`, `/Applications/Godot.app/Contents/MacOS/Godot`, or a Godot executable on `PATH`.

## Validate

```bash
./validate.sh
```

The gate runs Python contracts, renderer/audio budgets, visual asset snapshots, generator regression tests, a clean Godot import and runtime instantiation of every room. Fatal parser, compile, resource and runtime diagnostics fail the gate.

Optional room captures:

```bash
godot --path . --script res://tests/capture_rooms.gd
```

Captures are written to `user://synesthesia-room-captures`.

## Web preview

```bash
./scripts/build-web-preview.sh
python3 -m http.server 8080 --directory build/web
```

The output is a single-threaded installable PWA. Hosting and DNS are intentionally a separate later step; this release only prepares the verified static build.

## Repository structure

```text
assets/rooms/vertical/       five-layer portrait room assets
scenes/rooms/                one PackedScene per room
scripts/render/              composite stage, reveal mask, atmosphere
scripts/brush/               deterministic textured brush engine
scripts/rooms/behaviors/     room-specific acts and interactions
scripts/app/                 quality, preload, transition, diagnostics
scripts/ui/                  HUD and shared UI factory
data/releases/               schema-v4 room manifests
tests/                       static, runtime and visual contracts
```

## Safety and privacy

The game works offline. Network access is used only for the optional physical-album reward. Shipping details are collected later through a separate no-store page and are never placed in Signal, outbox or webhook payloads. There are no ads, analytics, forced sharing, strobe effects or jumpscares.

## Rights

Project source follows the repository licence. VIRYA names, logos, recordings, excerpts, lyrics and artwork remain the property of their respective rights holders and are not relicensed by the source-code licence.
