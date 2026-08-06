# Architecture

## Product boundary

Synestezja is a standalone Godot application. It does not embed Virya Signal, n8n or the Virya site. The only public integration is the optional CrowdRelay completion-reward API.

## Runtime modules

- `main.gd` is a route/orchestration shell: room loading, modal flow, persistence and reward coordination.
- `app_hud.gd` owns the portrait HUD and fades it during painting.
- `room_stage.gd` owns input, the reveal mask, composite material, collectibles, door animation and the behavior contract.
- `reveal_mask.gd` rasterizes deterministic stamps once into a bounded L8 image and uploads only while dirty.
- `brush_engine.gd` converts gesture speed into spaced textured stamps.
- `room_composite.gdshader` performs the single scene/VSS/reveal composite.
- `behavior_base.gd` plus `behaviors/*.gd` implement three acts and signature room interactions.
- `audio_director.gd` reveals gain, frequency range and space while removing the static pink-noise bed.
- `progress_store.gd` atomically stores schema-v4 state.
- `asset_preloader.gd` requests the next room and media asynchronously.
- `quality_manager.gd` provides Battery, Balanced and High budgets.

Controllers preload scripts directly. Active runtime scripts do not depend on editor class-name cache resolution.

## Five-layer 2.5D renderer

Every room manifest declares this exact stack:

1. `background` — 540×960 blurred depth plate;
2. `scene` — 810×1440 architecture/material plate;
3. `subject` — alpha-cut central narrative object;
4. `foreground` — alpha-cut near plane;
5. `atmosphere` — bounded runtime particles and room behavior lines.

The shader applies separate parallax to all image planes. The central subject and foreground move more than the architecture; reduced-motion scales the entire displacement down.

## Reveal model

The brush does not retain thousands of CanvasItem lines. Each input sample creates at most four deterministic stamps. Stamps are rasterized once into an L8 mask sized by the quality profile:

- Battery: 180×320;
- Balanced: 270×480;
- High: 360×640.

The mask texture is uploaded only when dirty. One shader combines the mask with the five scene layers, hidden-image desaturation/negative, cosmic static, scanlines, rolling noise, halftone and ink response. Physical coverage is normalized against `completion_coverage`; normalized progress of 0.99 triggers the cinematic full reveal, avoiding a final-pixel hunt.

## Room identity

Each room is a separate `PackedScene` and behavior script. The shared behavior contract is:

```text
configure(data)
acts() -> three titles
on_paint(point, radius, progress) -> interaction events
render(canvas, viewport, progress, phase)
export_state()
restore_state(state)
```

Progress is divided into three acts: recognition (0–30%), confrontation/transformation (30–70%) and release (70–99%).

## Audio reveal

A pre-rendered seamless stereo OGG pink-noise loop replaces per-frame procedural sample generation. Music is present from the beginning but initially quiet, low-pass filtered and more reverberant. Painting:

- lowers the noise;
- raises the music;
- opens the low-pass filter toward 19.5 kHz;
- dries the reverb and restores directness.

At 99% the noise is silent and only the room excerpt remains. A hard limiter remains on Master.

## Persistence

`progress_store.gd` caches one schema-v4 document and writes release plus album state in one atomic checkpoint. It uses a temporary file, backup recovery and rename. The reveal mask persists compact deterministic stamps rather than a full bitmap; schema-v3/v2/v1 state is migrated.

## Performance model

The logical viewport is 540×960. This is one quarter of the pixel count of a 1080×1920 internal render while preserving the same phone proportions. Quality profiles bound mask resolution, atmosphere particles, shader detail and upload cadence. Historical strokes are never redrawn. The next room is requested in a background loader before transition.

## Validation

CI checks:

- exact schema, route and resource contracts;
- renderer/audio budgets;
- room scene/behavior/act correspondence;
- 44 visual layer hashes;
- room generator regression;
- clean Godot import;
- runtime instantiation/configure/export/restore for all eleven rooms.

An optional Godot capture script creates portrait screenshots for visual review.

## Reward boundary

CrowdRelay remains authoritative for the physical reward. It enforces ordered room completion, server-side elapsed-time constraints, idempotency, stock and e-mail confirmation. The app remains playable offline and resynchronizes acknowledged rooms in order. Shipping data is outside client progress, Signal, outbox and webhook payloads.
