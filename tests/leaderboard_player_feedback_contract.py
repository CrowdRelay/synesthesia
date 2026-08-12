from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "scripts/ui/signal_leaderboard_panel.gd").read_text()
required = [
    "_own_alias",
    "_own_rank",
    "_own_best_elapsed_ms",
    '"▶ " if own else ""',
    '"TWÓJ RANK · #%d · PB %s"',
]
missing = [token for token in required if token not in source]
assert not missing, f"leaderboard own-player feedback missing: {missing}"
print("SYNESTHESIA_LEADERBOARD_PLAYER_FEEDBACK=PASS")
