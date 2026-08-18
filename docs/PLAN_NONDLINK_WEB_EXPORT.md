# Plan: ship a non-dlink Web engine

Status: not started. Measured, scoped, not implemented.

## Why

`export_presets.cfg` sets `variant/extensions_support=true` unconditionally, which
forces Godot's **dlink** Web template and splits the engine into `index.wasm` +
`index.side.wasm`. But `ci.yml` builds the deployed artifact with
`SYNESTHESIA_RUST_WEB_REQUIRED: "0"` and asserts `synesthesia_gdext.wasm` is
absent. Production therefore pays for dynamic linking to load **zero** extensions.

Measured directly from the cached 4.7.1 templates (no export needed):

| | dlink (shipping) | non-dlink | delta |
|---|---|---|---|
| engine wasm, raw | 43.5 MiB | 37.7 MiB | **-5.8 MiB** |
| engine js, raw | 2.7 MiB | 0.3 MiB | **-2.5 MiB** |
| over the wire, gzip | 10.9 MiB | 9.7 MiB | **-1.2 MiB** |

The wire saving is modest (~3% of a ~41 MiB cold load). The real prize is
**8.3 MiB less raw wasm to parse and compile** plus no dynamic-linking
relocation at startup — a mobile CPU/memory win, not a bandwidth one.

Reproduce the measurement:

```bash
cd "$(mktemp -d)" && unzip -q .../templates.tpz templates/web_nothreads_release.zip
# compare against .cache/godot-4.7.1-stable/web-templates/*/web_dlink_nothreads_release.zip
```

## Constraint

`build.yml`'s Rust-primary verification path genuinely needs
`extensions_support=true` — it loads `synesthesia_gdext.wasm`. Only the
production path can drop it. So this is conditional, not a flat flip.

## Steps

1. **Make extension support conditional.** Prefer having
   `scripts/build-web-preview.sh` set `variant/extensions_support` from
   `SYNESTHESIA_RUST_WEB_REQUIRED` before invoking Godot, over duplicating the
   preset — a second preset will drift from the first.
2. **Template set.** `WEB_TEMPLATE_NAMES` (build-web-preview.sh ~line 179) is
   hardcoded to the two dlink zips. Add `web_nothreads_release.zip` /
   `web_nothreads_debug.zip` for the non-rust path. The allowlist `case` in
   `verify_web_template_manifest_at` (~line 198) must accept them too, and
   `.synesthesia-web-templates.sha256` covers the whole set, so the manifest
   changes.
3. **Contracts.** `grep -rn web_dlink scripts/ tests/ .github/` — the toolchain,
   build-cache and CI-cache contracts assert template names. Update, do not relax.
4. **Cache key.** `build.yml` caches the dlink zips by path; add the new ones.

## Verification (all of it, before trusting this)

```bash
SYNESTHESIA_RUST_WEB_REQUIRED=0 ./scripts/build-web-preview.sh
ls build/web/*.wasm            # exactly one, no index.side.wasm
python3 tools/web_bundle_budget.py
./scripts/validate-source.sh
```

Then **actually boot it** — a smaller engine that does not run is worse than a
big one:

```bash
cd build/web && python3 -m http.server 8899
# load http://127.0.0.1:8899/?cachebust=N, confirm the menu renders,
# check console for errors, confirm one .wasm in the resource timeline
```

Finally re-run the Rust-primary path (`SYNESTHESIA_RUST_WEB_REQUIRED=1`) and
confirm it still produces the dlink build with `synesthesia_gdext.wasm`.

## Risk

If any scene or script expects a GDExtension to be loadable at runtime on Web,
non-dlink breaks it. Production already ships zero extensions, so this should be
inert — but the boot check above is what proves it, not this paragraph.
