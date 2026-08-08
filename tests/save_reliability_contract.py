#!/usr/bin/env python3
"""Contract for crash-tolerant two-generation local progress persistence."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "scripts/progress_store.gd").read_text()
failures: list[str] = []
if "const MAX_SAVE_BYTES: int = 24 * 1024 * 1024" not in source:
    failures.append("progress save file cap/headroom missing")

for token in (
    "static var _loaded_from_backup: bool = false",
    "file.flush()",
    "static func _document_for_write() -> Dictionary:",
    "return _load_document().duplicate(true)",
    'static var _ephemeral_install_id: String = ""',
    "static func _read_json_document(path: String) -> Variant:",
    "var backup: Variant = _read_json_document(BACKUP_PATH)",
    'push_warning("Recovered Synestezja progress from last-good backup")',
    "if _loaded_from_backup:",
    "if FileAccess.file_exists(SAVE_PATH):",
    "DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)",
    "var rename_error: Error = DirAccess.rename_absolute(temporary_path, SAVE_PATH)",
    "_loaded_from_backup = false",
):
    if token not in source:
        failures.append(f"progress durability token missing: {token}")

copy_on_write_count = source.count("var document: Dictionary = _document_for_write()")
if copy_on_write_count < 8:
    failures.append(f"mutating save paths are not copy-on-write: count={copy_on_write_count}")

# Keeping the backup after a successful commit is intentional. A final
# remove(BACKUP_PATH) after the commit would collapse durability back to one generation.
commit_tail = source[source.find("var rename_error:") :]
if "DirAccess.remove_absolute(BACKUP_PATH)" in commit_tail:
    failures.append("last-good backup is still deleted after a successful commit")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_SAVE_RELIABILITY=FAIL count={len(failures)}")

print("SYNESTHESIA_SAVE_RELIABILITY=PASS commit=copy-on-write+flush+temp+rename backup=last-good corrupt-main=recoverable")
