from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / "scripts/prepare-bundled-fonts.sh").read_text()
GITIGNORE = (ROOT / ".gitignore").read_text()

SHA256_EXPECTED = {
    "SynesthesiaDisplay.ttf": "08e4623805102d819f58601e46e345648846075e363b2ceb23313c2d1c83ec73",
    "OFL-BebasNeue.txt": "72082f6cb4d04be2ecf7cc7d9e1e7d73787f0af8a5a278a47cade70c16b78341",
}
GIT_BLOB_EXPECTED = {
    "SynesthesiaTitle.ttf": "2b7993d3c19d303b4f05b06983479e415972f93a",
    "OFL-NewRocker.txt": "60e277905418d159e4b90f57773754e9fb909df2",
}

assert "fetch_verified" in SCRIPT
assert "fetch_verified_git_blob" in SCRIPT
assert "git_blob_sha1" in SCRIPT
assert "verify_sha256" in SCRIPT
assert "raw.githubusercontent.com/google/fonts/main/" in SCRIPT
assert "title=NewRocker" in SCRIPT
assert "latin-ext=required" in SCRIPT
assert "Knewave-Regular.ttf" not in SCRIPT
assert "OFL-Knewave.txt" not in SCRIPT

for filename, digest in SHA256_EXPECTED.items():
    assert filename in SCRIPT, filename
    assert digest in SCRIPT, digest
for filename, digest in GIT_BLOB_EXPECTED.items():
    assert filename in SCRIPT, filename
    assert digest in SCRIPT, digest

assert "assets/fonts/generated/*.ttf" in GITIGNORE
assert "assets/fonts/generated/OFL-*.txt" in GITIGNORE
assert "SynesthesiaTitle.ttf" not in GITIGNORE.replace("assets/fonts/generated/*.ttf", "")

print("SYNESTHESIA_FONT_SUPPLY_CHAIN=PASS title=NewRocker display=BebasNeue source=OFL content=pinned")
