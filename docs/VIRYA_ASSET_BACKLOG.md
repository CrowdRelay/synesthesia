# VIRYA Asset Backlog

This backlog tracks the authored upgrades needed to fully realize the VIRYA world. Slot names and the 900 KiB per-room runtime budget are enforced by `data/room_asset_slots.json`; this document describes production priority.

## Priority 0 — shared foundation

- Preserve editable 1080 x 1920 masters and separated background, subject, foreground, and prop/FX layers.
- Maintain the shared signal-ring, signal-glitch, and surface-scratches textures.
- Verify alpha edges, mobile readability, parallax overscan, compression, and runtime memory after every export.
- Keep character/costume anchors replaceable without flattening them into scene art.

## Priority 1 — hero readability

- Strengthen central human silhouettes in Unmasked, Technophobia, Invaluable, Waves, and Rise.
- Clarify the performer-to-phoenix relationship in From the Ashes and the guitarist-duelist read in Hybrid.
- Give The Calling a readable ritual ensemble and Wave of Uncertainty a strong figure-versus-water composition.
- Increase foreground depth in Party Time and Seed of Doubt without obscuring interaction targets.

## Priority 2 — room props and effects

Produce each slot listed in `data/room_asset_slots.json` as an isolated, animation-ready asset. Atlas small particles and decals; favor transform, mask, and shader motion over full-frame video. Validate each completed room with `./validate.sh` and a portrait touch-device playthrough.

## Definition of done

An asset is complete when its source is retained, runtime export fits the room budget, alpha and compression are clean, semantic targets remain legible, motion has a reduced-cost path, and the final composition follows the palette and lighting rules in `VIRYA_ART_BIBLE.md`.
