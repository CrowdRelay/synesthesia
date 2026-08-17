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

# current_room_index is persisted while a room completes, but only advances when
# the next room loads. Resuming on the raw saved index therefore drops a player
# who left at the completion card back into the room they had just finished,
# which on web is the ordinary reload/restored-tab path.
main_source = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
metrics_source = (ROOT / "scripts/app/progress_metrics.gd").read_text(encoding="utf-8")
if "resume_room_index(" not in metrics_source:
    failures.append("resume must skip rooms that are already completed")
else:
    resume_body = metrics_source.split("static func resume_room_index(", 1)[1].split("\nstatic func ", 1)[0]
    if "completed_room_ids" not in resume_body:
        failures.append("resume must consult completed_room_ids, not just the saved index")
    if 'entry.get("id"' not in resume_body:
        failures.append("resume must match release entries on their release identifier")
    load_body = main_source.split("album_state = ProgressStoreScript.load_album()", 1)[1][:600]
    if "resume_room_index(" not in load_body:
        failures.append("the resume index must be resolved when album state is loaded")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_SAVE_RELIABILITY=FAIL count={len(failures)}")

print("SYNESTHESIA_SAVE_RELIABILITY=PASS commit=copy-on-write+flush+temp+rename backup=last-good corrupt-main=recoverable resume=skips-completed")
