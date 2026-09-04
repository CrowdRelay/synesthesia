# Synesthesia

**Godot 4.7.1 + Rust hybrid runtime for a portrait interactive-album adventure built around _Echoes Of The Modern Mind_.**

Eleven explorable rooms turn the album into something you play rather than watch: each room has its own mechanic, reactive audio and haptics, and the journey resumes locally where you left it. Completing a run may enter a five-CD draw through the public CrowdRelay contract; the game itself owns no fan, consent or fulfillment state.

## Features

- eleven rooms with distinct mechanics and audiovisual responses;
- procedural living-world motion and reactive audio/haptics;
- resumable local progress with bounded reveal masks;
- optional five-CD draw entry on completion;
- Web boot shell and branded native startup;
- adaptive performance that degrades expensive effects before functionality;
- explicit asset, memory and release-package contracts.

## Tech stack

Godot 4.7.1 owns scenes, UI, audio, haptics and the GPU reveal renderer. Deterministic gameplay primitives live in the pure `native/synesthesia-core` Rust crate and are exposed through `native/synesthesia-gdext`.

Native production builds are Rust-primary. Web production uses the behavior-compatible GDScript recognizer on the critical startup path while the Rust/WASM path remains a CI verification target.

GitHub Actions builds and verifies the Web artifact; deployment promotes the exact verified artifact. Android builds produce a Play Store AAB with per-tenant keystore signing. Build products remain ignored.

## CrowdRelay integration

A completed run can create one draw entry in campaign `virya-synesthesia-album-v1`. Server-side rules enforce five winners, one CD each, and one entry per valid completion/e-mail. Draw participation does not grant marketing consent or collect shipping data.

## Security and privacy

Run bearers are scoped to the Synesthesia lifecycle. Reward entry stores only the minimum identity needed for the draw; gameplay data and unnecessary personal data stay local.

See [`SECURITY.md`](SECURITY.md).

## License

See [`LICENSE`](LICENSE).
