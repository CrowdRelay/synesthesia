#!/usr/bin/env python3
"""Contract tests for the per-tenant Synesthesia build pipeline.

Verifies that:
1. fetch-tenant-config.py exists and has the expected CLI interface.
2. build-tenant-app.sh exists and is syntactically valid bash.
3. generate-tenant-branding.py exists and has the expected CLI interface.
4. The CI workflow exists and accepts the expected inputs.
5. The package ID derivation follows the music.{slug}.synesthesia pattern.
"""
from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FETCHER = ROOT / "tools/fetch-tenant-config.py"
BUILDER = ROOT / "scripts/build-tenant-app.sh"
BRANDING_GEN = ROOT / "tools/generate-tenant-branding.py"
WORKFLOW = ROOT / ".github/workflows/tenant-app-build.yml"
ONBOARDER = ROOT / "scripts/onboard-tenant-app.sh"
KEYSTORE_GEN = ROOT / "scripts/generate-tenant-keystore.sh"


class TenantBuildContract(unittest.TestCase):
    def test_fetcher_exists_and_has_cli(self) -> None:
        self.assertTrue(FETCHER.exists(), "fetch-tenant-config.py is missing")
        source = FETCHER.read_text(encoding="utf-8")
        self.assertIn("--tenant", source)
        self.assertIn("--control-plane-url", source)
        self.assertIn("--token", source)

    def test_fetcher_derives_package_id(self) -> None:
        source = FETCHER.read_text(encoding="utf-8")
        self.assertIn("music.{slug}.synesthesia", source)
        self.assertIn("packageId", source)

    def test_builder_exists_and_is_valid_bash(self) -> None:
        self.assertTrue(BUILDER.exists(), "build-tenant-app.sh is missing")
        result = subprocess.run(
            ["bash", "-n", str(BUILDER)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, f"bash syntax error: {result.stderr}")

    def test_builder_calls_fetcher_and_branding_gen(self) -> None:
        source = BUILDER.read_text(encoding="utf-8")
        self.assertIn("fetch-tenant-config.py", source)
        self.assertIn("generate-tenant-branding.py", source)
        self.assertIn("build-rust-native.sh", source)
        self.assertIn("export-release", source)

    def test_builder_backs_up_and_restores_presets(self) -> None:
        source = BUILDER.read_text(encoding="utf-8")
        self.assertIn(".bak", source)
        self.assertIn("trap", source)
        self.assertIn("RESTORE", source)

    def test_branding_gen_exists_and_has_cli(self) -> None:
        self.assertTrue(BRANDING_GEN.exists(), "generate-tenant-branding.py is missing")
        source = BRANDING_GEN.read_text(encoding="utf-8")
        self.assertIn("--config", source)
        self.assertIn("--output-dir", source)
        self.assertIn("Pillow", source)

    def test_workflow_exists_and_accepts_tenant_slug(self) -> None:
        self.assertTrue(WORKFLOW.exists(), "tenant-app-build.yml is missing")
        content = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("tenant_slug", content)
        self.assertIn("version", content)
        self.assertIn("version_code", content)
        self.assertIn("workflow_dispatch", content)

    def test_workflow_calls_build_script(self) -> None:
        content = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("build-tenant-app.sh", content)
        self.assertIn("CONTROL_PLANE_ADMIN_TOKEN", content)

    def test_workflow_auto_populates_play_url(self) -> None:
        content = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("Auto-populate Play Store URL", content)
        self.assertIn("/mobile-apps", content)

    def test_onboarder_exists_and_is_valid_bash(self) -> None:
        self.assertTrue(ONBOARDER.exists(), "onboard-tenant-app.sh is missing")
        result = subprocess.run(
            ["bash", "-n", str(ONBOARDER)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, f"bash syntax error: {result.stderr}")

    def test_keystore_gen_exists_and_is_valid_bash(self) -> None:
        self.assertTrue(KEYSTORE_GEN.exists(), "generate-tenant-keystore.sh is missing")
        result = subprocess.run(
            ["bash", "-n", str(KEYSTORE_GEN)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, f"bash syntax error: {result.stderr}")


if __name__ == "__main__":
    unittest.main()
