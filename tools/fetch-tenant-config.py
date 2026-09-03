#!/usr/bin/env python3
"""Fetch a tenant's Synesthesia app configuration from the CrowdRelay Control Plane.

Outputs a JSON object with everything the per-tenant Synesthesia build needs:
  - slug, display_name
  - package_id (music.{slug}.synesthesia)
  - app_name ({display_name}: Synesthesia)
  - branding_palette (10-color palette or null)
  - play_store_url (the tenant's Synesthesia Play Store URL or null)

Usage:
  python3 tools/fetch-tenant-config.py \
      --tenant virya \
      --control-plane-url https://control.virya.music \
      --token $CONTROL_PLANE_ADMIN_TOKEN
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


def fetch_tenant(base_url: str, slug: str, token: str) -> dict[str, Any]:
    url = f"{base_url.rstrip('/')}/api/v1/tenants/{slug}"
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=15.0) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace") if exc.fp else ""
        print(f"ERROR: control plane returned {exc.code}: {body}", file=sys.stderr)
        raise SystemExit(1) from exc
    except urllib.error.URLError as exc:
        print(f"ERROR: could not reach control plane at {url}: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc


def derive_config(tenant: dict[str, Any]) -> dict[str, Any]:
    slug = tenant["slug"]
    display_name = tenant["displayName"]
    package_id = f"music.{slug}.synesthesia"
    app_name = f"{display_name}: Synesthesia"
    palette = tenant.get("brandingPalette")
    play_store_url = tenant.get("synesthesiaPlayStoreUrl")

    return {
        "slug": slug,
        "displayName": display_name,
        "packageId": package_id,
        "appName": app_name,
        "brandingPalette": palette,
        "playStoreUrl": play_store_url,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tenant", required=True, help="Tenant slug")
    parser.add_argument("--control-plane-url", required=True, help="Control Plane API base URL")
    parser.add_argument("--token", default=os.environ.get("CONTROL_PLANE_ADMIN_TOKEN", ""), help="Platform admin token")
    parser.add_argument("--output", default="-", help="Output path (- for stdout)")
    args = parser.parse_args()

    if not args.token:
        print("ERROR: --token or CONTROL_PLANE_ADMIN_TOKEN env var is required", file=sys.stderr)
        raise SystemExit(2)

    tenant = fetch_tenant(args.control_plane_url, args.tenant, args.token)
    config = derive_config(tenant)

    output = json.dumps(config, indent=2, separators=(",", ": "))
    if args.output == "-":
        print(output)
    else:
        Path(args.output).write_text(output + "\n", encoding="utf-8")
        print(f"Wrote tenant config to {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
