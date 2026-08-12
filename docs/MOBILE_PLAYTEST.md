# Mobile playtest protocol

Synesthesia is judged on a real phone, not only on a clean desktop preview. Use this checklist after room-art, guidance or shader changes.

## Test conditions

Run each changed room in at least these conditions:

1. portrait phone, brightness around 50%, normal indoor light;
2. portrait phone near a bright window or outdoors in shade;
3. portrait phone with a realistically smudged screen;
4. `Czytelność: kinowa` and `Czytelność: wysoka`;
5. reduced motion on once, to ensure guidance does not depend on animation alone.

Do not increase display brightness to rescue an unclear room during the test.

## Three-second test

On first entry, without explaining the mechanic, ask the player what they want to touch or move. Within roughly three seconds they should identify the correct actionable region even if they cannot yet name the exact gesture.

Record only the outcome, not personal identity:

- correct target identified;
- wrong target / no target;
- first successful interaction time;
- misses before success;
- highest assist level;
- whether the room was abandoned.

The sampled gameplay RUM already reports the timing/assist summary. Qualitative target identification remains a manual playtest observation.

## Priority rooms

Use `Technophobia`, `Seed of Doubt` and `Rise` as readability references. Pay extra attention to `Party Time`, `Hybrid`, `The Calling` and `Invaluable`; these rooms intentionally remain dark but should not hide their interaction language.

## Acceptance rule

Do not solve a readability failure by globally brightening every room or adding another render pass. Prefer, in order:

1. authored subject/readability profile;
2. local actionable affordance;
3. stronger existing hint layer;
4. touch forgiveness after misses;
5. high-readability user preference.

Only add renderer complexity after profiling proves the existing single-pass path cannot deliver the required result.
