from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
panel = (ROOT / "scripts/ui/signal_leaderboard_panel.gd").read_text()
finale = (ROOT / "scripts/ui/signal_finale_card.gd").read_text()

required_panel = [
    "_own_alias",
    "_own_rank",
    "_own_best_elapsed_ms",
    '"▶ " if own else ""',
    '"TWÓJ RANK · #%d · PB %s"',
    'LeaderboardIdentity.effective_name()',
    'Ranking nie wymaga maila ani konta Signal.',
    '_publish.disabled = not _timed_run_complete',
    'func set_leaderboard_publish_enabled(value: bool) -> void:',
]
missing = [token for token in required_panel if token not in panel and token not in finale]
assert not missing, f"leaderboard own-player/privacy feedback missing: {missing}"

assert "Konto Signal i e-mail nie są wymagane." in finale, (
    "finale must state that leaderboard publishing is independent from Signal/email"
)
assert "połącz ten przebieg z My Signal albo e-mailem" not in finale, (
    "stale leaderboard copy still requires Signal/email before publishing"
)

print("SYNESTHESIA_LEADERBOARD_PLAYER_FEEDBACK=PASS privacy=anonymous signal=optional")
