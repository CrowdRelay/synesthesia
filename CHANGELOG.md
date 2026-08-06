# Changelog

## 0.3.1 — Parser hotfix

- Fixed Godot 4.7.1 failing to infer the `restored` room-state flag from a dynamically typed controller call.
- Added explicit types at persistence boundaries to avoid Variant inference regressions.
- Extended runtime validation to load every gameplay script explicitly before instantiating the main scene.
- Added a static regression contract for the restored-state boolean.

## 0.3.0 — Technophobia / Room Memory

- Fixed Godot 4.7.1 startup parsing by removing editor class-cache dependent member types.
- Added explicit integer typing for collectible counts.
- Reframed the first room around **Technophobia** with slow, low-contrast visual glitches.
- Added a 36-second completion excerpt of VIRYA's “Technophobia” with safe fades.
- Added local, versioned room memory under `user://` and a clean reset path.
- Strengthened static and runtime validation for audio and parser regressions.

## 0.2.0 — repository and build foundation

- professional English project documentation;
- pinned GitHub Actions continuous integration;
- verified Godot 4.7.1 headless validation;
- Linux and Web export artifacts;
- Android arm64 debug APK export;
- tagged GitHub Release publishing;
- explicit build and signing guidance;
- Godot export presets for current prototype targets.

## 0.1.0 — first calm vertical slice

- touch and mouse painting;
- three narrative collectibles;
- procedural layered soundscape;
- calm/full sensory modes;
- immediate room calming control;
- release index and reusable release-pack scaffold;
- offline validation and no backend dependency.
