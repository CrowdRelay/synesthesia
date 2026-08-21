#!/usr/bin/env python3
"""Every origin the game talks to at runtime must be allowed by the Web CSP.

The API host lives in three independent places: the release index the reward
and signup clients are configured from, the GDScript telemetry endpoint and the
Web RUM shim. `connect-src` in `web/_headers` is a fourth. Native and Android
ignore the CSP entirely, so a host that moves in one of the first three ships
green everywhere and fails only in the browser, at runtime, as a blocked
request the player sees as a dead Signal.
"""
import json
import re
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def origin(url: str) -> str:
    parts = urlsplit(url)
    return f"{parts.scheme}://{parts.netloc}" if parts.scheme and parts.netloc else ""


headers = (ROOT / "web/_headers").read_text(encoding="utf-8")
policy = re.search(r"Content-Security-Policy:\s*(.+)", headers)
if policy is None:
    raise SystemExit("SYNESTHESIA_WEB_CONNECT_ORIGIN=FAIL reason=no-csp")

directives = {
    part.split()[0]: part.split()[1:]
    for part in (segment.strip() for segment in policy.group(1).split(";"))
    if part
}
connect_src = directives.get("connect-src")
if connect_src is None:
    failures.append("CSP has no connect-src directive")
    connect_src = []
for source in connect_src:
    if "*" in source:
        failures.append(f"connect-src must stay exact, not a wildcard: {source}")
allowed = {source for source in connect_src if source.startswith("https://")}

runtime_origins: dict[str, str] = {}

index = json.loads((ROOT / "data/release_index.json").read_text(encoding="utf-8"))
reward = index.get("reward") if isinstance(index.get("reward"), dict) else {}
api_url = str(reward.get("api_url", ""))
if not api_url:
    failures.append("release index has no reward.api_url")
else:
    runtime_origins["data/release_index.json reward.api_url"] = origin(api_url)

telemetry = (ROOT / "scripts/app/gameplay_telemetry.gd").read_text(encoding="utf-8")
endpoint = re.search(r'ENDPOINT\s*:=\s*"([^"]+)"', telemetry)
if endpoint is None:
    failures.append("gameplay_telemetry.gd has no ENDPOINT constant")
else:
    runtime_origins["scripts/app/gameplay_telemetry.gd ENDPOINT"] = origin(endpoint.group(1))

# Any absolute origin a Web shim reaches for is subject to the same CSP.
for shim in sorted((ROOT / "web").glob("*.js")):
    for url in re.findall(r'"(https://[^"\s]+)"', shim.read_text(encoding="utf-8")):
        runtime_origins[f"web/{shim.name} {url}"] = origin(url)

for source, value in sorted(runtime_origins.items()):
    if not value:
        failures.append(f"{source}: not an absolute https origin")
    elif value not in allowed:
        failures.append(f"{source}: {value} is not in connect-src")

distinct = sorted(set(runtime_origins.values()))
if failures:
    print("SYNESTHESIA_WEB_CONNECT_ORIGIN=FAIL")
    for failure in failures:
        print(f"- {failure}")
    raise SystemExit(1)
print(
    f"SYNESTHESIA_WEB_CONNECT_ORIGIN=PASS sources={len(runtime_origins)} "
    f"origins={len(distinct)} wildcards=0"
)
