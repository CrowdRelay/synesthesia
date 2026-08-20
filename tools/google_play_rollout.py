#!/usr/bin/env python3
"""Safely advance or halt the active Synesthesia Google Play production rollout."""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

API = "https://androidpublisher.googleapis.com/androidpublisher/v3"
PACKAGE = "music.virya.synesthesia"
MAX_RESPONSE_BYTES = 2 * 1024 * 1024
TARGETS: dict[str, float | None] = {"25": 0.25, "50": 0.50, "100": 1.0, "halt": None}


def request_json(method: str, url: str, token: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    data = None if body is None else json.dumps(body, separators=(",", ":")).encode()
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "synesthesia-play-rollout/1",
        },
    )
    with urllib.request.urlopen(request, timeout=20.0) as response:
        raw = response.read(MAX_RESPONSE_BYTES + 1)
        if len(raw) > MAX_RESPONSE_BYTES:
            raise RuntimeError("Google Play response exceeded size limit")
        return json.loads(raw) if raw else {}


def active_release(track: dict[str, Any], expected_version_code: str | None) -> tuple[int, dict[str, Any]]:
    releases = track.get("releases")
    if not isinstance(releases, list):
        raise RuntimeError("production track has no releases array")
    candidates: list[tuple[int, dict[str, Any]]] = []
    for index, release in enumerate(releases):
        if not isinstance(release, dict) or release.get("status") not in {"inProgress", "halted"}:
            continue
        version_codes = [str(value) for value in release.get("versionCodes", [])]
        if expected_version_code and expected_version_code not in version_codes:
            continue
        candidates.append((index, release))
    if not candidates:
        suffix = f" for versionCode {expected_version_code}" if expected_version_code else ""
        raise RuntimeError(f"no active staged production release{suffix}")
    if len(candidates) != 1:
        raise RuntimeError("multiple active staged releases found; provide --expected-version-code")
    return candidates[0]


def updated_track(track: dict[str, Any], target: str, expected_version_code: str | None) -> tuple[dict[str, Any], dict[str, Any]]:
    index, release = active_release(track, expected_version_code)
    current_status = str(release.get("status", ""))
    current_fraction = float(release.get("userFraction", 0.0) or 0.0)
    updated = json.loads(json.dumps(track))
    target_release = updated["releases"][index]

    if target == "halt":
        if current_status == "halted":
            raise RuntimeError("rollout is already halted")
        target_release["status"] = "halted"
        target_release.pop("userFraction", None)
        next_fraction: float | None = current_fraction if current_fraction > 0 else None
    else:
        fraction = TARGETS[target]
        assert fraction is not None
        if fraction < 1.0:
            if current_status == "inProgress" and current_fraction >= fraction:
                raise RuntimeError(
                    f"refusing non-forward rollout change: current={current_fraction:.2f} requested={fraction:.2f}"
                )
            target_release["status"] = "inProgress"
            target_release["userFraction"] = fraction
            next_fraction = fraction
        else:
            target_release["status"] = "completed"
            target_release.pop("userFraction", None)
            next_fraction = 1.0

    receipt = {
        "schema": 1,
        "checkedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "packageName": PACKAGE,
        "track": "production",
        "versionCodes": [str(value) for value in target_release.get("versionCodes", [])],
        "previousStatus": current_status,
        "previousUserFraction": current_fraction or None,
        "target": target,
        "nextStatus": target_release.get("status"),
        "nextUserFraction": next_fraction,
    }
    return updated, receipt


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=TARGETS, required=True)
    parser.add_argument("--expected-version-code")
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--output", type=Path, default=Path("artifacts/google-play-rollout.json"))
    args = parser.parse_args()
    try:
        if args.expected_version_code and not args.expected_version_code.isdigit():
            raise RuntimeError("expected versionCode must be numeric")
        if args.fixture:
            track = json.loads(args.fixture.read_text())
            updated, receipt = updated_track(track, args.target, args.expected_version_code)
            print(json.dumps({"track": updated, "receipt": receipt}, sort_keys=True))
            return 0

        token = os.environ.get("GOOGLE_OAUTH_ACCESS_TOKEN", "").strip()
        if not token:
            raise RuntimeError("GOOGLE_OAUTH_ACCESS_TOKEN is required")
        package = urllib.parse.quote(PACKAGE, safe="")
        edit = request_json("POST", f"{API}/applications/{package}/edits", token, {})
        edit_id = str(edit.get("id", ""))
        if not edit_id:
            raise RuntimeError("Google Play edit id missing")
        encoded_edit = urllib.parse.quote(edit_id, safe="")
        base = f"{API}/applications/{package}/edits/{encoded_edit}"
        track_url = f"{base}/tracks/production"
        track = request_json("GET", track_url, token)
        updated, receipt = updated_track(track, args.target, args.expected_version_code)
        request_json("PUT", track_url, token, updated)
        committed = request_json("POST", f"{base}:commit", token, {})
        receipt["editId"] = edit_id
        receipt["committedEditId"] = str(committed.get("id", edit_id))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
        print(
            "SYNESTHESIA_GOOGLE_PLAY_ROLLOUT=PASS "
            f"target={receipt['target']} status={receipt['nextStatus']} "
            f"fraction={receipt['nextUserFraction']} versionCodes={','.join(receipt['versionCodes'])}"
        )
        return 0
    except (RuntimeError, ValueError, OSError, json.JSONDecodeError, urllib.error.URLError, urllib.error.HTTPError) as error:
        print(f"SYNESTHESIA_GOOGLE_PLAY_ROLLOUT=FAIL detail={error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
