# Godot + Rust hybrid architecture

Synesthesia keeps Godot 4.7.1 as the artistic runtime and authoring environment. Rust is introduced only behind narrow deterministic boundaries where independent tests, stronger types, and native CPU performance provide a concrete benefit.

## Ownership boundary

### Godot / GDScript owns

- scenes, room composition and editor authoring;
- UI, HUD, menus and accessibility/sensory settings;
- animation, audio playback, haptics and transitions;
- shaders and the GPU reveal-mask pipeline;
- platform integration and Web export;
- presentation-facing orchestration.

### `synesthesia-core` owns

- deterministic gameplay primitives with no Godot dependency;
- the normalized gesture state machine;
- future pure state machines / validation / procedural math only when the boundary stays data-oriented.

### `synesthesia-gdext` owns

- the smallest possible Godot ↔ Rust type adapter;
- no presentation decisions and no duplicated room behavior.

The reveal mask intentionally remains on the GPU. Moving an already bounded shader workload to Rust/CPU would be an architectural regression, not an optimization.

## Runtime strategy

`interaction_router.gd` performs runtime feature detection. If `SynesthesiaGestureCore` is registered, gesture recognition uses the Rust backend. Otherwise the existing GDScript implementation is used with the same event contract and mirrored thresholds.

This gives three useful properties:

1. a missing native library never makes the game unplayable;
2. Web remains independent from experimental GDExtension/WASM support;
3. native rollout can happen incrementally without rewriting the eleven room behaviors.

The generated `synesthesia_rust.gdextension` descriptor and native binaries are ignored by Git. Merely checking out the repository therefore keeps ordinary editor sessions and Web builds extension-free.

The native workspace declares Rust **1.94** as its MSRV (matching godot-rust 0.5) and explicitly compiles against the Godot **4.6 GDExtension API**. Synesthesia targets Godot 4.7.1 at runtime; using the older stable API level intentionally keeps the extension on the compatible side of `API version <= runtime version`. CI currently builds it with Rust 1.97.1.

## Commands

```bash
# Pure Rust unit tests + adapter type-check
./scripts/build-rust-native.sh check

# Build/enable the current desktop host extension
SYNESTHESIA_RUST_PROFILE=release ./scripts/build-rust-native.sh host

# Build/enable Android arm64 after cargo-ndk + Android NDK are installed
SYNESTHESIA_RUST_PROFILE=release ./scripts/build-rust-native.sh android-arm64

# Return the working tree to the extension-free fallback path
./scripts/build-rust-native.sh disable
```

## CI policy

The main CI compiles, formats, tests and lints the Rust workspace, then builds the Linux GDExtension before running the real Godot import/lifecycle smoke. This makes the engine smoke exercise the native backend instead of merely compiling it.

Android CI builds the `arm64-v8a` Rust library after the Linux validation gate and before APK export. Web CI never generates the descriptor and therefore continues to use the proven GDScript path.

## Migration rule

Do not move code to Rust because it is "heavy-looking". Move a subsystem only when all of these are true:

- it has a small data-oriented input/output contract;
- it can be tested meaningfully without rendering a Godot scene;
- it is deterministic or CPU-sensitive enough to benefit;
- the GDScript fallback or migration story is explicit;
- no new frame-loop allocation/FFI chatter is introduced.

This keeps Rust as a performance/reliability tool rather than a second game engine hidden inside Godot.
