# Godot + Rust hybrid architecture

Synesthesia keeps Godot 4.7.1 as the artistic runtime and authoring environment. Rust sits behind narrow deterministic boundaries where independent tests, stronger types and predictable CPU behavior provide a concrete benefit. It is not a second game engine inside the project.

## Ownership boundary

### Godot / GDScript owns

- scenes, room composition and editor authoring;
- UI, HUD, menus and sensory/accessibility settings;
- animation, audio playback, haptics and transitions;
- shaders and the GPU reveal-mask pipeline;
- asset streaming and platform lifecycle;
- presentation-facing orchestration.

### `synesthesia-core` owns

- deterministic gameplay primitives with no Godot dependency;
- the normalized gesture state machine;
- future pure state machines / validation / procedural math only when the boundary stays data-oriented.

### `synesthesia-gdext` owns

- the smallest possible Godot ↔ Rust type adapter;
- no presentation decisions and no duplicated room behavior.

The reveal mask intentionally remains on the GPU. Moving an already bounded shader workload to Rust/CPU would increase copies and FFI work rather than improve performance.

The gesture boundary is also deliberately **idle-zero-FFI**: Godot mirrors active pointer IDs/positions locally and calls Rust only for semantic pointer events or hold advancement while a pointer is actually down. The Rust core stores the usual one/two active pointers in a preallocated contiguous vector instead of a tree/map.

## Runtime matrix

| Target | Production backend | Artifact | Fallback / verification policy |
| --- | --- | --- | --- |
| macOS / Linux | Rust GDExtension | `.dylib` / `.so` | explicit disable only |
| Android | Rust GDExtension | `arm64-v8a/libsynesthesia_gdext.so` | explicit emergency switch only |
| Web / Netlify | GDScript recognizer | no Rust side-module in production | Rust/WASM remains an explicit CI verification path |

`interaction_router.gd` performs runtime feature detection and keeps the same event contract in both implementations. Native release pipelines fail closed when their required Rust artifact is absent. Web intentionally takes the opposite production tradeoff: the behavior-compatible GDScript backend stays on the browser critical path, while the Rust/WASM adapter is compiled and exported in verification builds so capability does not silently rot.

Web verification uses `wasm32-unknown-emscripten`, Emscripten 3.1.74 and the Godot dynamic-link **nothreads** template. The build pins both the SDK version and the emsdk manager commit, and bindgen is forced onto the active Emscripten sysroot so Linux CI cannot accidentally mix glibc headers into a Web target. The export remains extension-capable, so Web hosting keeps the cross-origin isolation headers required by Godot even when the production build does not package the side-module.

The generated `synesthesia_rust.gdextension`, its UID sidecar and all native/Web build products are ignored by Git. A clean checkout therefore contains source only; build scripts materialize the descriptor/artifact for the selected target.

The native workspace declares Rust **1.94** as its MSRV (matching godot-rust 0.5) and explicitly compiles against the Godot **4.6 GDExtension API**. Synesthesia targets Godot 4.7.1 at runtime; keeping `API version <= runtime version` is intentional. CI formats/tests/lints with Rust 1.97.1, while the optional Web side-module uses the pinned nightly required for `-Zbuild-std`.

## Commands

```bash
# Pure Rust unit tests + adapter type-check/lint
./scripts/build-rust-native.sh check

# Desktop host extension
SYNESTHESIA_RUST_PROFILE=release ./scripts/build-rust-native.sh host

# Android arm64 after cargo-ndk + Android NDK are installed
SYNESTHESIA_RUST_PROFILE=release ./scripts/build-rust-native.sh android-arm64

# Web/WASM verification after emsdk activation
SYNESTHESIA_RUST_PROFILE=release ./scripts/build-rust-native.sh web

# Full Web verification export with the side-module required
SYNESTHESIA_RUST_WEB_REQUIRED=1 ./scripts/build-web-preview.sh

# Explicit fallback / source-clean state
./scripts/build-rust-native.sh disable
```

## CI / deployment policy

- Main CI: format, unit-test, check and `clippy -D warnings`; then build the host extension and run real Godot import/lifecycle smoke.
- Android: Rust is required, the APK is opened as a ZIP and must physically contain `libsynesthesia_gdext.so`.
- Web verification: `build-web-preview.sh` with `SYNESTHESIA_RUST_WEB_REQUIRED=1` must produce and export `synesthesia_gdext.wasm`.
- Web production: Netlify sets `SYNESTHESIA_RUST_WEB_REQUIRED=0`; the script disables generated native state before import/export and uses the proven GDScript recognizer. This avoids experimental side-module startup failures and removes Rust/emsdk compilation from the production Netlify critical path.
- Netlify connected-Git integration is the sole automatic Web deployment authority. Deploy previews/branch builds are intentionally skipped; GitHub Web workflow is verification only.
- Build caches contain dependency sources and selected verified Godot inputs, never `native/target`, full template packs or generated application artifacts.

## Performance rule

Do not move code to Rust because it looks heavy. Move a subsystem only when all of these are true:

- it has a small data-oriented input/output contract;
- it can be tested meaningfully without rendering a Godot scene;
- it is deterministic or CPU-sensitive enough to benefit;
- the GDScript fallback or migration story is explicit;
- the boundary does not introduce per-pixel or high-volume frame-loop FFI chatter.

This keeps Rust as a performance/reliability tool while Godot remains the authoring, rendering and sensory runtime.
