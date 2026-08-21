# Synesthesia

**Godot 4.7.1 + Rust hybrid runtime** for a portrait interactive-album adventure built around **Echoes Of The Modern Mind**. Eleven explorable rooms combine micro-puzzles, reactive audio, haptics and a resumable local journey.

GitHub reports this repo primarily as GDScript because scenes/UI/runtime orchestration stay in Godot. The performance-sensitive deterministic core is intentionally isolated in Rust rather than forcing a full-engine rewrite.

## Engineering snapshot

- **Narrow Rust boundary:** deterministic gameplay primitives live in pure `native/synesthesia-core`; `native/synesthesia-gdext` is a thin adapter into Godot.
- **Native Rust-primary builds:** macOS/Linux load GDExtension and Android packages an ARM64 Rust `.so`.
- **Web critical-path trade-off:** production Web uses the behavior-compatible GDScript recognizer instead of an experimental Emscripten side-module; Rust/WASM remains a fail-closed verification target.
- **Explicit runtime budgets:** current/next-room preloading, memory, idle work, shader activity and Web bundle size are contract-checked.
- **Adaptive degradation:** mask upload cadence, particles and motion are reduced before functionality is dropped under runtime pressure.
- **Immutable release path:** CI builds/verifies the Web artifact once, records source identity and deployment promotes that exact artifact rather than rebuilding it.
- **Cross-repo contract:** reward/run traffic uses the public CrowdRelay boundary and Synesthesia has an upstream compatibility gate against current `crowdrelay/main`.

See [`docs/RUST_HYBRID_ARCHITECTURE.md`](docs/RUST_HYBRID_ARCHITECTURE.md) for the Rust/Godot trade-offs.

## Runtime

- bootstrap reference: `1080×1920`; runtime `stretch=disabled`;
- Web uses Godot Adaptive canvas sizing and the app shell reads the real viewport at runtime;
- desktop keeps the portrait room undistorted and uses side space for menu/finale UI; portrait phones use the full native viewport;
- HiDPI is enabled on Web/Android/iOS/desktop;
- current + next room assets are preloaded within explicit memory budgets;
- all eleven gameplay rooms use procedural living-world motion; only the authored finale retains a lazy `720×1280 @ 24 fps` cinematic;
- adaptive performance lowers mask upload cadence, particles and motion before dropping functionality;
- room progress persists locally as bounded PNG reveal masks;
- the Web boot shell owns browser startup while native targets can retain their branded splash.

The source art stays asymmetrical by intent: background 405×720, scene/subject 675×1200, foreground 540×960. Those are texture-source sizes, not the runtime viewport. The runtime fits/crops portrait art inside a native-resolution shell while UI remains pixel-sharp.

Video provenance for the finale cinematic is retained in `assets/video/manifest.json`. Removing the five retired room loops cut about 11.7 MiB from the source/Web pack and removed their decoder/shader startup cost. Runtime files are cache-first only inside the current fingerprinted deploy generation; the offline shell remains network-first and new deploys receive a new cache namespace plus one-time handoff.

## V2 experience

V2 is intentionally more game-like than the original reveal prototype. The player promise is:

```text
notice -> manipulate -> immediate audiovisual response -> changed world state -> optional echo -> payoff
```

The paint mask remains an accessibility/reveal assist, but completion is driven by each room's own mechanic.

## CrowdRelay integration

Synesthesia is autonomous at runtime and integrates only through the public CrowdRelay contract:

```text
start run -> room ledger x11 -> complete run -> optional five-CD draw entry
```

Campaign: `virya-synesthesia-album-v1`.

Draw rules are server-enforced: 5 winners, 1 CD each, one completion/e-mail = one entry, no referral/check-in weighting. The draw does not set marketing consent and does not collect shipping data. Signal signup is a separate explicit flow through the normal `/fans` contract and never creates a Synesthesia draw entry.

## Rust hybrid core

The editor, scenes, UI, audio, haptics and GPU reveal renderer stay in Godot. Deterministic gameplay primitives live in the pure `native/synesthesia-core` crate and are exposed through `native/synesthesia-gdext`; the first migrated slice is gesture recognition.

Native production builds are Rust-primary. Web production deliberately uses the behavior-compatible GDScript recognizer on the critical startup path while `synesthesia_gdext.wasm` remains a CI/verification target. `SYNESTHESIA_RUST_WEB_REQUIRED=1` can be used locally to exercise that Rust/WASM path explicitly.

GitHub Actions is the only Web builder: CI exports and verifies `build/web`, records a source-SHA manifest and deployment promotes the exact artifact to Netlify with `--no-build`. Build products remain ignored; a clean checkout does not require committed native binaries.

## Build and validation

```bash
./scripts/validate-fast.sh
./scripts/validate-source.sh
./validate.sh

./scripts/build-web-preview.sh
./scripts/build-android-apk.sh
./scripts/build-linux-release.sh

SYNESTHESIA_RUST_WEB_REQUIRED=1 ./scripts/build-web-preview.sh
```

To share/review the repository without local caches:

```bash
./scripts/export-source.sh
```

The exporter uses `git archive`, records the exact SHA/ref and refuses dirty trees, generated build/cache paths or oversized tracked source blobs.

For local macOS development:

```bash
./run-macos.sh
```

`validate.sh` covers static contracts, renderer/audio/memory budgets, visual snapshots, a clean Godot import and runtime instantiation. CI remains the authoritative Godot/compiler gate.

## Structure

```text
assets/rooms/vertical/       layered portrait art
assets/branding/             native boot splash source/output
scenes/rooms/                one PackedScene per room
scripts/render/              GPU composite/reveal pipeline
scripts/rooms/behaviors/     per-room interactions
scripts/app/                 preload/quality/transition/diagnostics
scripts/ui/                  Signal UI, HUD, boot, Korytarz and finale
shaders/                     bounded canvas shaders
data/releases/               schema-v4 manifests
tests/                       static/runtime/visual contracts
web/                         PWA shell, CSP and pre-engine boot
native/                      pure Rust core + thin GDExtension adapter
```

New room packs must satisfy the schema encoded by `data/release_index.json`, `data/releases/*/manifest.json` and `tests/new_release_pack_contract.py`.

## Security and privacy

See [`SECURITY.md`](SECURITY.md). Run bearers are scoped to the Synesthesia lifecycle; reward entry stores only the minimum identity needed for a draw. No address, phone, location, marketing consent or gameplay brush data is sent with the draw entry.

VIRYA names, recordings and artwork remain with their respective rights holders.

## Mobile product QA

- `docs/MOBILE_CLARITY.md` — renderer/UI invariants
- `docs/MOBILE_PLAYTEST.md` — real-phone daylight/smudged-screen playtest
- `docs/PRODUCT_READABILITY_PASS_2026-08-11.md` — current product-readability architecture and telemetry
