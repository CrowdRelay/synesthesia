#!/usr/bin/env python3
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess
import tempfile
import time
from urllib.parse import quote
import zipfile

DEFAULT_API = "https://api.netlify.com/api/v1"
CHUNK_SIZE = 1024 * 1024
FAIL_STATES = {"error", "failed", "rejected"}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()



def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Promote a prebuilt GitHub artifact to Netlify without invoking a Netlify build."
    )
    parser.add_argument("archive", type=Path)
    parser.add_argument("--expected-source-sha")
    parser.add_argument("--timeout-seconds", type=int, default=180)
    parser.add_argument("--method", choices=("auto", "zip", "digest"), default="auto")
    parser.add_argument("--digest-threshold-mib", type=int, default=32)
    parser.add_argument("--upload-workers", type=int, default=4)
    parser.add_argument("--max-uncompressed-mib", type=int, default=256)
    return parser.parse_args()


def api_base() -> str:
    return os.environ.get("NETLIFY_API_BASE", DEFAULT_API).rstrip("/")


def curl_json(
    method: str,
    url: str,
    token: str,
    *,
    zip_upload: Path | None = None,
    json_body: dict | None = None,
) -> dict:
    if zip_upload is not None and json_body is not None:
        raise ValueError("zip_upload and json_body are mutually exclusive")
    with tempfile.NamedTemporaryFile(prefix="netlify-response-", suffix=".json", delete=False) as tmp:
        response_path = Path(tmp.name)
    body_path: Path | None = None
    try:
        command = [
            "curl", "--fail-with-body", "--silent", "--show-error",
            "--connect-timeout", "15", "--max-time", "240",
            "-X", method,
            "-H", f"Authorization: Bearer {token}",
            "-o", str(response_path),
        ]
        # Creating a deploy is not idempotent. If Netlify accepted a POST but
        # the response was lost, an automatic curl retry could create a second
        # production deploy. Reads are safe to retry; blob PUTs have their own
        # retry path in curl_file().
        if method.upper() == "GET":
            command[1:1] = ["--retry", "3", "--retry-all-errors"]
        if zip_upload is not None:
            command += ["-H", "Content-Type: application/zip", "--data-binary", f"@{zip_upload}"]
        elif json_body is not None:
            with tempfile.NamedTemporaryFile(prefix="netlify-request-", suffix=".json", delete=False) as body:
                body_path = Path(body.name)
                body.write(json.dumps(json_body, separators=(",", ":")).encode("utf-8"))
            command += ["-H", "Content-Type: application/json", "--data-binary", f"@{body_path}"]
        command.append(url)
        subprocess.run(command, check=True)
        raw = response_path.read_text(encoding="utf-8")
        try:
            return json.loads(raw)
        except json.JSONDecodeError as error:
            raise SystemExit(f"Netlify returned invalid JSON from {url}: {error}; body={raw[:1000]!r}") from error
    finally:
        response_path.unlink(missing_ok=True)
        if body_path is not None:
            body_path.unlink(missing_ok=True)


def curl_file(method: str, url: str, token: str, path: Path) -> None:
    subprocess.run(
        [
            "curl", "--fail-with-body", "--silent", "--show-error",
            "--retry", "3", "--retry-all-errors", "--connect-timeout", "15", "--max-time", "240",
            "-X", method,
            "-H", f"Authorization: Bearer {token}",
            "-H", "Content-Type: application/octet-stream",
            "--data-binary", f"@{path}",
            "-o", os.devnull,
            url,
        ],
        check=True,
    )


def validate_member_name(name: str) -> str:
    if not name or name.startswith("/") or "\\" in name:
        raise SystemExit(f"unsafe deploy ZIP entry: {name!r}")
    parts = PurePosixPath(name).parts
    if any(part in {"", ".", ".."} for part in parts):
        raise SystemExit(f"unsafe deploy ZIP entry: {name!r}")
    return PurePosixPath(*parts).as_posix()


def validate_and_extract(archive: Path, manifest: dict, destination: Path, max_total_bytes: int) -> list[dict]:
    entries = manifest.get("files")
    if not isinstance(entries, list) or not entries:
        raise SystemExit("deploy manifest has no file entries")
    expected: dict[str, dict] = {}
    for entry in entries:
        if not isinstance(entry, dict):
            raise SystemExit("deploy manifest contains a non-object file entry")
        rel = validate_member_name(str(entry.get("path", "")))
        if rel in expected:
            raise SystemExit(f"duplicate manifest path: {rel}")
        expected[rel] = entry

    declared_total = sum(int(entry.get("bytes", -1)) for entry in expected.values())
    if declared_total < 0 or declared_total != int(manifest.get("uncompressed_bytes", -1)):
        raise SystemExit("deploy manifest uncompressed_bytes does not match file entries")
    if declared_total > max_total_bytes:
        raise SystemExit(f"deploy artifact exceeds runtime safety limit: {declared_total} bytes")

    seen: set[str] = set()
    with zipfile.ZipFile(archive) as package:
        infos = package.infolist()
        if len(infos) > 25_000:
            raise SystemExit(f"deploy ZIP exceeds Netlify extraction limit: {len(infos)} files")
        for info in infos:
            if info.is_dir():
                continue
            rel = validate_member_name(info.filename)
            if rel in seen:
                raise SystemExit(f"duplicate ZIP path: {rel}")
            seen.add(rel)
            mode = (info.external_attr >> 16) & 0xFFFF
            if stat.S_ISLNK(mode):
                raise SystemExit(f"refusing symlink in deploy ZIP: {rel}")
            entry = expected.get(rel)
            if entry is None:
                raise SystemExit(f"ZIP contains file absent from manifest: {rel}")
            if info.file_size != int(entry.get("bytes", -1)):
                raise SystemExit(f"ZIP metadata size mismatch for {rel}")
            target = destination / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            sha1 = hashlib.sha1(usedforsecurity=False)
            sha256 = hashlib.sha256()
            size = 0
            with package.open(info) as source, target.open("wb") as output:
                while True:
                    chunk = source.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    output.write(chunk)
                    size += len(chunk)
                    sha1.update(chunk)
                    sha256.update(chunk)
            if size != int(entry.get("bytes", -1)):
                raise SystemExit(f"manifest size mismatch for {rel}: expected={entry.get('bytes')} actual={size}")
            if sha256.hexdigest() != entry.get("sha256"):
                raise SystemExit(f"manifest SHA-256 mismatch for {rel}")
            manifest_sha1 = entry.get("sha1")
            if manifest_sha1 is not None and sha1.hexdigest() != manifest_sha1:
                raise SystemExit(f"manifest SHA-1 mismatch for {rel}")
            entry["sha1"] = sha1.hexdigest()

    if seen != set(expected):
        missing = sorted(set(expected) - seen)
        raise SystemExit(f"manifest files missing from ZIP: {missing[:10]}")
    if int(manifest.get("file_count", -1)) != len(seen):
        raise SystemExit("deploy manifest file_count does not match ZIP")
    return [expected[path] for path in sorted(expected)]


def wait_for_deploy(deploy_id: str, token: str, timeout_seconds: int, *, wait_for_required: bool = False) -> dict:
    deadline = time.monotonic() + timeout_seconds
    last: dict = {}
    while True:
        last = curl_json("GET", f"{api_base()}/deploys/{quote(deploy_id, safe='')}", token)
        state = str(last.get("state", ""))
        if state in FAIL_STATES:
            raise SystemExit(f"Netlify deploy {deploy_id} failed in state={state}")
        if wait_for_required:
            if state == "ready" or "required" in last:
                return last
        elif state == "ready":
            return last
        if time.monotonic() >= deadline:
            raise SystemExit(f"timed out waiting for Netlify deploy {deploy_id}; last state={state}")
        time.sleep(1)


def create_zip_deploy(site_id: str, token: str, archive: Path, title: str) -> tuple[dict, int]:
    url = f"{api_base()}/sites/{quote(site_id, safe='')}/deploys?production=true&title={quote(title, safe='')}"
    return curl_json("POST", url, token, zip_upload=archive), 0


def create_digest_deploy(
    site_id: str,
    token: str,
    files: list[dict],
    extracted_root: Path,
    title: str,
    timeout_seconds: int,
    upload_workers: int,
) -> tuple[dict, int]:
    file_map = {f"/{entry['path']}": entry["sha1"] for entry in files}
    url = f"{api_base()}/sites/{quote(site_id, safe='')}/deploys?production=true&title={quote(title, safe='')}"
    deploy = curl_json("POST", url, token, json_body={"async": True, "files": file_map})
    deploy_id = str(deploy.get("id", ""))
    if not deploy_id:
        raise SystemExit(f"Netlify digest deploy response did not contain an id: {deploy}")
    if str(deploy.get("state", "")) != "ready" and "required" not in deploy:
        deploy = wait_for_deploy(deploy_id, token, timeout_seconds, wait_for_required=True)

    required = deploy.get("required", [])
    if required is None:
        required = []
    if not isinstance(required, list):
        raise SystemExit(f"Netlify digest deploy returned invalid required list: {required!r}")
    by_sha1: dict[str, str] = {}
    for entry in files:
        by_sha1.setdefault(str(entry["sha1"]), str(entry["path"]))
    uploads: list[tuple[str, Path]] = []
    for digest in sorted({str(item) for item in required}):
        rel = by_sha1.get(digest)
        if rel is None:
            raise SystemExit(f"Netlify requested unknown file digest: {digest}")
        uploads.append((rel, extracted_root / rel))

    if uploads:
        workers = max(1, min(upload_workers, 8, len(uploads)))
        with ThreadPoolExecutor(max_workers=workers, thread_name_prefix="netlify-upload") as pool:
            futures = {
                pool.submit(
                    curl_file,
                    "PUT",
                    f"{api_base()}/deploys/{quote(deploy_id, safe='')}/files/{quote(rel, safe='/')}",
                    token,
                    path,
                ): rel
                for rel, path in uploads
            }
            for future in as_completed(futures):
                rel = futures[future]
                try:
                    future.result()
                except Exception as error:
                    raise SystemExit(f"Netlify file upload failed for {rel}: {error}") from error
    return deploy, len(uploads)


def assert_zero_build_site(site_id: str, token: str) -> dict:
    site = curl_json("GET", f"{api_base()}/sites/{quote(site_id, safe='')}", token)
    build_settings = site.get("build_settings")
    repo = site.get("repo")
    linked = False
    stopped = False
    for settings in (build_settings, repo):
        if not isinstance(settings, dict):
            continue
        if any(str(settings.get(key, "")).strip() for key in ("repo_url", "repo_path", "provider")):
            linked = True
        if settings.get("stop_builds") is True:
            stopped = True
    if linked and not stopped:
        raise SystemExit(
            "Netlify Git builds are active. Stop builds in Project configuration > "
            "Build & deploy > Continuous deployment before artifact promotion."
        )
    reason = "stopped" if linked else "unlinked"
    print(f"NETLIFY_BUILD_STATUS=PASS mode={reason} zero-build=1")
    return site


def already_published(site_id: str, token: str, title: str, *, site: dict | None = None) -> tuple[bool, str]:
    if site is None:
        site = curl_json("GET", f"{api_base()}/sites/{quote(site_id, safe='')}", token)
    published = site.get("published_deploy")
    if not isinstance(published, dict) or not published.get("id"):
        return False, ""
    deploy = published
    if not deploy.get("title"):
        deploy = curl_json("GET", f"{api_base()}/deploys/{quote(str(published['id']), safe='')}", token)
    if str(deploy.get("title", "")) != title:
        return False, ""
    url = str(deploy.get("deploy_ssl_url") or deploy.get("ssl_url") or deploy.get("url") or "")
    return True, url


def smoke(url: str) -> None:
    with tempfile.NamedTemporaryFile(prefix="netlify-smoke-", suffix=".html", delete=False) as tmp:
        output = Path(tmp.name)
    try:
        subprocess.run(
            [
                "curl", "--fail", "--silent", "--show-error", "--location",
                "--retry", "3", "--retry-all-errors", "--connect-timeout", "10", "--max-time", "45",
                "-o", str(output), url.rstrip("/") + "/",
            ],
            check=True,
        )
        prefix = output.read_bytes()[:32_768].lower()
        if b"<html" not in prefix and b"<!doctype html" not in prefix:
            raise SystemExit(f"post-deploy smoke did not return HTML: {url}")
    finally:
        output.unlink(missing_ok=True)


def smoke_asset(base_url: str, relative_path: str) -> None:
    safe_path = quote(relative_path, safe="/")
    subprocess.run(
        [
            "curl", "--fail", "--silent", "--show-error", "--head", "--location",
            "--retry", "2", "--retry-all-errors", "--connect-timeout", "10", "--max-time", "30",
            base_url.rstrip("/") + "/" + safe_path,
        ],
        check=True,
        stdout=subprocess.DEVNULL,
    )


def main() -> int:
    args = parse_args()
    archive = args.archive.resolve()
    token = os.environ.get("NETLIFY_AUTH_TOKEN", "").strip()
    site_id = os.environ.get("NETLIFY_SITE_ID", "").strip()
    if not token or not site_id:
        raise SystemExit("NETLIFY_AUTH_TOKEN and NETLIFY_SITE_ID are required")
    if not archive.is_file():
        raise SystemExit(f"deploy archive does not exist: {archive}")
    if (
        args.timeout_seconds <= 0
        or args.digest_threshold_mib < 0
        or args.upload_workers <= 0
        or args.max_uncompressed_mib <= 0
    ):
        raise SystemExit("deploy timing/threshold/worker/size values must be valid")

    manifest_path = archive.with_name(archive.name + ".manifest.json")
    sha_path = archive.with_name(archive.name + ".sha256")
    if not manifest_path.is_file() or not sha_path.is_file():
        raise SystemExit("deploy archive must have sibling .manifest.json and .sha256 files")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_archive_sha = sha_path.read_text(encoding="utf-8").split()[0]
    actual_archive_sha = sha256_file(archive)
    if actual_archive_sha != expected_archive_sha or actual_archive_sha != manifest.get("archive_sha256"):
        raise SystemExit("deploy archive SHA-256 does not match provenance files")
    if args.expected_source_sha and manifest.get("source_sha") != args.expected_source_sha:
        raise SystemExit(
            f"artifact source SHA mismatch: expected {args.expected_source_sha}, got {manifest.get('source_sha')}"
        )

    source_sha = str(manifest.get("source_sha", "unknown"))
    title = f"github-{source_sha}"
    site_snapshot = assert_zero_build_site(site_id, token)
    is_current, current_url = already_published(site_id, token, title, site=site_snapshot)
    if is_current:
        if current_url:
            smoke(current_url)
        print(
            "NETLIFY_ARTIFACT_DEPLOY=SKIP reason=already-published "
            f"source_sha={source_sha} archive_sha256={actual_archive_sha} url={current_url}"
        )
        return 0

    with tempfile.TemporaryDirectory(prefix="netlify-artifact-") as tmp_dir:
        extracted_root = Path(tmp_dir)
        files = validate_and_extract(
            archive, manifest, extracted_root, args.max_uncompressed_mib * 1024 * 1024
        )
        critical_paths = [
            str(entry["path"])
            for entry in files
            if str(entry["path"]).lower().endswith((".wasm", ".pck"))
        ]
        total_bytes = int(manifest.get("uncompressed_bytes", 0))
        threshold_bytes = args.digest_threshold_mib * 1024 * 1024
        method = args.method
        if method == "auto":
            method = "digest" if total_bytes >= threshold_bytes else "zip"
        if method == "digest":
            deploy, uploaded_files = create_digest_deploy(
                site_id,
                token,
                files,
                extracted_root,
                title,
                args.timeout_seconds,
                args.upload_workers,
            )
        else:
            deploy, uploaded_files = create_zip_deploy(site_id, token, archive, title)

    deploy_id = str(deploy.get("id", ""))
    if not deploy_id:
        raise SystemExit(f"Netlify deploy response did not contain an id: {deploy}")
    if deploy.get("draft") is True:
        raise SystemExit("Netlify unexpectedly created a draft deploy instead of production")

    if str(deploy.get("state", "")) != "ready":
        deploy = wait_for_deploy(deploy_id, token, args.timeout_seconds)

    site = curl_json("GET", f"{api_base()}/sites/{quote(site_id, safe='')}", token)
    published = site.get("published_deploy")
    if isinstance(published, dict) and published.get("id") and str(published.get("id")) != deploy_id:
        raise SystemExit(
            f"deploy is ready but not published: expected={deploy_id} published={published.get('id')}"
        )

    deploy_url = str(deploy.get("deploy_ssl_url") or deploy.get("ssl_url") or deploy.get("url") or "")
    if not deploy_url:
        raise SystemExit("Netlify ready deploy did not provide a URL for smoke verification")
    smoke(deploy_url)
    for critical_path in critical_paths[:8]:
        smoke_asset(deploy_url, critical_path)
    result_line = (
        "NETLIFY_ARTIFACT_DEPLOY=PASS "
        f"method={method} uploaded_files={uploaded_files} deploy_id={deploy_id} "
        f"source_sha={manifest.get('source_sha')} archive_sha256={actual_archive_sha} url={deploy_url}"
    )
    print(result_line)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY", "").strip()
    if summary_path:
        with Path(summary_path).open("a", encoding="utf-8") as summary:
            summary.write("## Netlify artifact promotion\n\n")
            summary.write(f"- Source: `{source_sha}`\n")
            summary.write(f"- Artifact SHA-256: `{actual_archive_sha}`\n")
            summary.write(f"- Deploy ID: `{deploy_id}`\n")
            summary.write(f"- Method: `{method}`\n")
            summary.write(f"- URL: {deploy_url}\n")
            summary.write("- Netlify build: `disabled / prebuilt artifact`\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
