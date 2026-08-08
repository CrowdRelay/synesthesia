# Runtime performance architecture

Synesthesia optimizes for **stable frame time, bounded memory and low idle power**, not benchmark numbers in isolation. Visual fidelity, authored timing and audio continuity are product constraints.

## Hot-path rules

- No Rust/Godot FFI call while the gesture recognizer is idle. Pointer count and last positions are mirrored locally in Godot; Rust receives only pointer events and hold ticks while a pointer is down.
- Room behaviors sleep unless they have active semantic motion or a cinematic clock. Static rooms do not execute behavior state updates every frame.
- Audio control runs at at most ~60 Hz. Playback remains native/audio-thread driven; only volume/effect target updates are rate-limited.
- Reveal texture uploads remain cadence-bounded and GPU-owned. Pixel-mask migration to Rust is intentionally rejected unless profiling proves the existing shader/raster boundary is the bottleneck.
- Adaptive quality responds to sustained frame-time/hitch pressure with cooldown/hysteresis. A single resume frame or isolated hitch must not permanently lower quality.
- The explicit `battery` profile caps rendering at 60 FPS on high-refresh phones; balanced/high keep the platform refresh policy. This turns the battery mode into a real thermal/power policy rather than only a shader/mask-quality preset.

## Save-state rules

The reveal mask is revisioned. PNG serialization is cached until the mask actually changes, so a settings/collectible/room metadata save cannot recompress an unchanged mask. A valid same-size PNG restore reuses its already-validated bytes as the initial export cache and skips the otherwise redundant clear/upload + first autosave re-encode. `ProgressStore` mutates a deep copy of the last committed in-memory document, flushes it before the atomic temp→rename commit and keeps two generations: current plus a durable last-good backup. A missing or corrupt current JSON can recover from that backup before any new write is attempted.

## Lifecycle rules

Entering the app background freezes both visual roots plus the room subtree and suspends audio/adaptive sampling while preserving their previous process/visibility state. Returning restores only what was active before; a room already sleeping behind the main menu stays asleep. The finale and its cinematic decoder are visibility-gated as well, so returning from the archive to a room cannot leave hidden video work alive.

Room transitions distinguish **critical preload** (scene + authored art needed to enter) from **deferred preload** (for example the completion excerpt). The transition grace period waits only for critical resources; completion audio is consumed only with the non-blocking `take_if_ready()` path and attaches later on the audio director's bounded control tick. A slow outro audio decode therefore cannot reappear as a hidden main-thread join during room construction. Blocking fallback for genuinely critical resources remains instrumented and visible in diagnostics.

## Web release consistency

Godot runtime filenames are stable across releases. Therefore `.js`, `.wasm` and `.pck` use network-first service-worker handling plus `max-age=0, must-revalidate` browser caching. Unchanged files can validate via ETag/304, but a new HTML shell cannot silently pair with an old PCK/WASM. Navigation alone may fall back to cached HTML; runtime/media requests never receive an HTML response with the wrong MIME type. Transient 429/5xx responses can use an already-cached last-good runtime, while deliberate 4xx/removals are never hidden by stale binaries.

The CacheStorage namespace is fingerprinted from the final runtime PCK/WASM/generated JS, not only the semantic app version. A runtime change therefore creates a new bounded cache generation even if the marketing version string did not move. Revalidation also compares ETag/Last-Modified before writing, avoiding repeated 40+ MiB PCK rewrites when the asset is unchanged. CacheStorage writes run via `event.waitUntil()` on a cloned response, so the engine receives the network response immediately instead of waiting for a large PCK/WASM cache write to finish.

## Build/cache policy

Allowed persistent cache inputs are bounded and reproducible: Cargo registry/git sources, pinned toolchains where the platform manages them, verified Godot editor archives and only the target-specific export templates. Web streams only the two dynamic-link no-thread entries out of the verified multi-platform pack and keeps only those selected files; Android likewise streams and keeps only its debug/release APK templates; tagged Linux releases keep only `linux_release.x86_64`. Netlify treats these as **verified checkpoints**: the selected Web templates carry their own SHA-256 manifest and are persisted even after a later build failure, while incomplete/corrupt downloads are never promoted into cache. Never cache or commit `native/target`, `.godot`, build outputs, full multi-platform Godot template trees, APKs, WASM/ELF/dylib products or local Webpack caches as source artifacts.

Production export presets explicitly exclude `tests/*` and `tools/*`. The Web budget distinguishes the small Rust GDExtension side-module (≤2 MiB) from Godot's engine WASM; the engine is governed by the whole-artifact budget rather than an impossible extension-sized cap. The initial whole-Web ceiling is 96 MiB and should be tightened after the first measured production baseline, not guessed below an unmeasured Godot engine payload. Source validation is centralized in `scripts/validate-source.sh` and runs **before** heavyweight Godot/Android/toolchain setup, so a source regression fails in seconds rather than after gigabytes of downloads. Platform builders then add only their real-engine/export proof. Tagged releases use the same Rust-primary Web builder plus a selected-template Linux exporter, rather than downloading a second full multi-platform template tree through a generic export action.

## Media policy

Current cinematic runtime files are already encoded assets. Do not transcode the 1080×1920 runtime OGV files again merely to shrink them: their recorded provenance is 720×1280, so another lossy generation would trade quality for size. A future media pass should start from original masters and benchmark decode time, thermal load, payload and visual quality on representative Android devices.

## Measurement before further migration

The next substantial optimization should be driven by Android/Web profiling: p95/p99 frame time, longest transition stall, peak resident memory, mask-save encode count and cold/warm startup. Add `sccache` only if compilation—not downloads/import/export—remains the dominant CI cost after bounded input caching.

## V3 release hardening

- PWA shell installation is atomic and cache eviction is scoped to Synesthesia namespaces only; Range requests bypass CacheStorage.
- Network responses are cloned for background caching immediately on fetch resolution, avoiding a large-body clone race after browser/Godot consumption starts. Returning sessions with a valid fingerprinted cache use a 3.5 s response-header budget on flaky networks while the update fetch continues in the background.
- Local progress reads/writes are bounded to 24 MiB (room-mask worst-case + headroom) and a recovered last-good generation is healed opportunistically.
- Atmosphere particles use packed numeric arrays rather than per-particle Dictionaries in the redraw hot loop; finale palette allocation is static.
