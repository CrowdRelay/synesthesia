# Mobile clarity contract

Synesthesia is a phone-first game. Art direction may stay dark, noisy and cinematic, but interaction must remain legible in daylight and on imperfect screens.

## Product invariants

- Do not globally brighten authored room art. Lift only the final mobile presentation enough to preserve dark-tone detail.
- Portrait presentation reduces visual-snow opacity rather than adding another rendering pass.
- The first encounter with an interaction verb gets a strong diegetic cue immediately and a textual fallback within about three seconds of inactivity.
- The mobile instruction surface is a primary gameplay affordance: large type, full-width safe-area-aware placement and at most two short semantic lines.
- Desktop may remain subtler; mobile guidance may be stronger without changing game rules.
- Any future readability effect must reuse the existing room composite pass unless profiling proves another pass is justified.

## Performance budget

The clarity path must add no texture fetch, no new viewport, no polling timer and no per-frame allocation. It may use bounded scalar/vector math in the existing shader and event-driven UI updates.
