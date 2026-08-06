# Godot project

This directory contains the playable Godot 4.7.1 runtime for **VIRYA: Synestezja**.

The full concept, product principles, roadmap, and GitHub Actions instructions are documented in the [repository README](../README.md).

## Run

Open `project.godot` in Godot 4.7.1 and press **F6** or **F5**.

## Validate

```bash
./validate.sh
```

## Create a release pack

```bash
python3 tools/new_release_pack.py release-id \
  --title "VIRYA: Release title" \
  --room "Room title" \
  --activate
```

## Build

Local and GitHub Actions build instructions are available in [`docs/BUILDING.md`](docs/BUILDING.md).
