# VIRYA: Synestezja

A portrait Godot 4.7.1 experience that turns **Echoes Of The Modern Mind** into eleven playable, cover-inspired rooms. The player uncovers each scene with a textured comic brush while Visual Snow, cosmic CRT static and soft ASMR pink noise recede; at 99% the filter disappears and only the full room excerpt remains.

## 0.11.0 — Production Polish / RC pass

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
