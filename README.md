# VIRYA: Synestezja

A portrait Godot 4.7.1 experience that turns **Echoes Of The Modern Mind** into eleven playable, cover-inspired rooms. The player uncovers each scene with a textured comic brush while Visual Snow, cosmic CRT static and soft ASMR pink noise recede; at 99% the filter disappears and only the full room excerpt remains.

## 0.10.0 — Production Renderer

This release replaces the prototype renderer with a production-oriented mobile pipeline:

- native portrait room plates instead of stretched horizontal images;
- five-layer 2.5D scenes: blurred background, architecture/scene, central subject, foreground and atmosphere;
- a low-resolution retained reveal mask composited by one GPU shader;
- Photoshop-like deterministic brush stamps written once to the mask, not replayed every frame;
- room-owned PackedScenes and behavior scripts with three narrative acts each;
- quality profiles for Battery, Balanced and High;
- static stereo pink-noise loop plus music gain, low-pass and space reveal;
- compact HUD that recedes while painting, separate audio/VSS/haptics controls and reduced-motion support;
- schema-v4 atomic progress checkpoints and ordered offline reward synchronization;
- next-room threaded preloading, diagnostics overlay and stronger CI/runtime contracts.

The logical viewport is **540×960**. Final room art is authored at **810×1440**, giving a clean 9:16 presentation without wasting four times the pixel work on mobile.

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
