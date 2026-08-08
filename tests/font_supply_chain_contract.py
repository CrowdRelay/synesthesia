from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / "scripts/prepare-bundled-fonts.sh").read_text()
GITIGNORE = (ROOT / ".gitignore").read_text()

EXPECTED = {
    "SynesthesiaTitle.ttf": "ed3bac761d755b89ab3082c844d4a623d63c7d6eef85d22ba1fb6c680e6a4436",
    "SynesthesiaDisplay.ttf": "08e4623805102d819f58601e46e345648846075e363b2ceb23313c2d1c83ec73",
    "OFL-Knewave.txt": "14b3fbd06078a869cf2ba96e6dacb852d373703c86ca7ad54a4cdd6e20fbab19",
    "OFL-BebasNeue.txt": "72082f6cb4d04be2ecf7cc7d9e1e7d73787f0af8a5a278a47cade70c16b78341",
}

assert "fetch_verified" in SCRIPT
assert "verify_sha256" in SCRIPT
assert "sha256sum" in SCRIPT and "shasum -a 256" in SCRIPT
assert "raw.githubusercontent.com/google/fonts/main/" in SCRIPT
assert "mode=sha256-pinned-ofl" in SCRIPT

for filename, digest in EXPECTED.items():
    assert filename in SCRIPT, filename
    assert digest in SCRIPT, digest

assert "assets/fonts/generated/*.ttf" in GITIGNORE
assert "assets/fonts/generated/OFL-*.txt" in GITIGNORE
assert "SynesthesiaTitle.ttf" not in GITIGNORE.replace("assets/fonts/generated/*.ttf", "")

print("SYNESTHESIA_FONT_SUPPLY_CHAIN=PASS source=OFL sha256=pinned generated=git-ignored")
