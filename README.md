# VIRYA: Synestezja

**An evolving multisensory music experience by Virya.**

*Synestezja* is the current working title; the repository and parent directory use the technical name `synesthesia`.

VIRYA: Synestezja is a calm, exploratory mobile experience in which players enter symbolic rooms, paint their surfaces, discover hidden traces, and gradually reveal layers of Virya's music. Each future single or release can add a new room, sensory language, and chapter to the same growing world.

The project is designed as an alternative to high-pressure social feeds: no streaks, no rankings, no forced account, and no attention traps. Interaction should feel intimate, optional, and rewarding in itself.

> **Project status:** early playable vertical slice. The current build validates the core interaction model before production music, backend integration, or release-scale content are added.

## The experience

A session follows a simple loop:

1. Enter a room.
2. Paint and touch its surfaces.
3. Reveal sound layers and visual details.
4. Find narrative traces connected to a release.
5. Calm, transform, or complete the room.
6. Leave whenever you choose.

The current prototype includes:

- touch and mouse painting with gesture-sensitive brush width;
- three hidden narrative collectibles;
- a quiet procedural soundscape that opens with progress;
- restrained mobile haptics with rate limiting;
- calm and full sensory modes;
- a permanent **Calm the room** control;
- a low-contrast, optional visual-noise layer;
- data-driven release manifests for future singles and albums;
- no network dependency, login, analytics, advertising, or telemetry.

## Creative direction

The building is a fictional, metaphorical interior space rather than a literal medical simulation. Rooms explore perception, memory, overload, silence, and the inner life of Virya's releases.

Future chapters may use:

- color and paint as musical controls;
- adaptive stems from released tracks;
- spatial ambience and restrained ASMR textures;
- tactile patterns synchronized with rhythm or material;
- optional visual-snow-inspired filters;
- concert or physical-release codes that reveal alternate room states.

The experience is not a diagnostic, therapeutic, or clinical product.

## Design principles

### Calm by default

The default mode reduces motion, visual noise, haptic intensity, and audio density. Stronger sensory treatment is opt-in.

### Immediate agency

The player can calm the room at any time. Haptics and sensory effects must remain individually disableable as the project grows.

### Music as discovery, not advertising

Virya's music is revealed through interaction. Streaming links and release information belong after the experience, never as interruptions.

### No engagement pressure

No daily streaks, scarcity timers, rankings, loot systems, or compulsory sharing.

### Content, not rewrites

New releases should normally arrive as release packs rather than changes to the core runtime.

## Technology

- **Engine:** Godot 4.7.1
- **Language:** GDScript
- **Renderer:** GL Compatibility for broad mobile support
- **Content model:** JSON release index and release manifests
- **Audio:** Godot audio buses and a procedural prototype generator
- **Haptics:** Godot handheld vibration abstraction; native Android/iOS extensions may follow after device testing
- **CI/CD:** GitHub Actions validation, Linux/Web exports, and Android debug APK exports

The game remains deliberately separate from Virya Signal, CrowdRelay, n8n, and the existing mail flow. Integration can be added later through explicit, versioned boundaries.

## Repository layout

```text
synesthesia/
├── .github/workflows/
│   ├── ci.yml
│   └── build.yml
├── README.md
├── CONTRIBUTING.md
└── virya-synestezja/
    ├── project.godot
    ├── export_presets.cfg
    ├── scenes/
    ├── scripts/
    ├── shaders/
    ├── data/
    │   ├── release_index.json
    │   └── releases/
    ├── tests/
    ├── tools/
    └── docs/
```

## Quick start

Install Godot **4.7.1**, then open:

```text
virya-synestezja/project.godot
```

Run the project with **F6** or **F5** and paint with a pointer or touch input.

Offline validation:

```bash
cd virya-synestezja
./validate.sh
```

When a `godot` executable is available in `PATH`, validation also loads the project and main scene headlessly.

## GitHub Actions

### Continuous integration

`.github/workflows/ci.yml` runs on pushes and pull requests. It:

- checks Python helper syntax;
- validates release manifests and safety contracts;
- downloads the exact Godot 4.7.1 editor build;
- verifies its SHA-256 checksum;
- imports the project headlessly;
- loads the main scene and validation script.

### Build artifacts

`.github/workflows/build.yml` can be started manually from the **Actions** tab. Choose:

- `desktop-web` for Linux and Web builds;
- `android` for a debug APK;
- `all` for every current target.

A tag matching `v*`, for example `v0.2.0`, builds all targets and creates or updates the corresponding GitHub Release.

Detailed instructions are in [`virya-synestezja/docs/BUILDING.md`](virya-synestezja/docs/BUILDING.md).

## Adding a release chapter

Create a data-driven pack without modifying the core gameplay:

```bash
cd virya-synestezja
python3 tools/new_release_pack.py brak-sygnalu \
  --title "VIRYA: Signal Lost" \
  --room "Transmission Room" \
  --activate
```

This creates a manifest plus audio and texture directories and registers the pack in `data/release_index.json`.

See [`RELEASE_PACK_SCHEMA.md`](virya-synestezja/docs/RELEASE_PACK_SCHEMA.md) for the current schema.

## Sensory safety

The prototype intentionally avoids:

- strobing and rapid flashes;
- jumpscares;
- high-frequency tinnitus imitation;
- sudden loudness changes;
- mandatory headphones;
- uninterruptible sensory sequences.

Any future use of visual-noise, ASMR, spatial audio, or stronger haptics must preserve clear controls, calm defaults, and device testing. Production audio should be loudness-managed and protected by a limiter.

## Roadmap

The next useful milestones are intentionally small:

1. Test painting and haptics on several Android devices.
2. Replace procedural layers with stems from one suitable Virya track.
3. Tune the calm/full modes with real users.
4. Build one visually finished room.
5. Add signed downloadable release packs only after the offline experience is enjoyable.

## License

The original project code and artistic concept are copyright © 2026 Wojciech Bator / Virya. All rights reserved unless a file states otherwise.

Godot Engine is distributed separately under the MIT License.
