# Contributing

VIRYA: Synestezja is currently an exploratory artistic prototype. Contributions should preserve the project's calm, opt-in character and its separation from Virya's production systems.

## Development setup

1. Install Godot 4.7.1.
2. Open the root `project.godot`.
3. Run `./validate.sh` from the repository root before submitting changes.
4. Test touch-related changes on a real mobile device when possible.

## Pull request expectations

A focused pull request should explain:

- the player-facing change;
- the sensory impact;
- how the calm mode behaves;
- which devices or targets were tested;
- whether a release-pack schema changed;
- why the change does not introduce tracking, pressure mechanics, or production-system coupling.

Do not commit private music stems, signing keys, secrets, analytics identifiers, exported binaries, or `.godot/` import data.

## Creative and safety constraints

Changes must not introduce strobing, jumpscares, forced loudness, high-frequency tinnitus simulation, compulsory engagement loops, or irreversible sensory sequences.

Every stronger effect needs a clear opt-out and a restrained fallback.
