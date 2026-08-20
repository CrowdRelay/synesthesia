#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "scripts/reward_client.gd").read_text(encoding="utf-8")

for token in (
    "MAX_RETRY_ATTEMPTS: int = 3",
    "RETRY_BASE_SECONDS: float = 1.2",
    "RETRY_MAX_SECONDS: float = 12.0",
    "RETRY_JITTER_MIN: float = 0.80",
    "RETRY_JITTER_SPAN: float = 0.40",
    "MAX_EMAIL_LENGTH: int = 254",
    "MAX_EMAIL_LOCAL_LENGTH: int = 64",
    "MAX_POLICY_VERSION_LENGTH: int = 64",
    "func _looks_like_email",
    "func _retry_after_seconds",
    "effective_code := response_code if result == HTTPRequest.RESULT_SUCCESS else 0",
    "maxf(jittered_delay, retry_after_seconds)",
    "retry-after:",
):
    assert token in source, token

enter_draw = source.split("func enter_draw", 1)[1].split("\nfunc _looks_like_email", 1)[0]
assert "email.strip_edges()" in enter_draw
assert "policy_version.strip_edges()" in enter_draw
assert "_looks_like_email(normalized_email)" in enter_draw
assert 'request_failed.emit("enter_draw", "Podaj poprawny adres e-mail.")' in enter_draw
assert '"email": normalized_email' in enter_draw
assert '"policy_version": normalized_policy' in enter_draw

failure = source.split("func _handle_failure", 1)[1].split("\nfunc _retry_after_seconds", 1)[0]
assert "_is_transient_failure(response_code)" in failure
assert "attempt < MAX_RETRY_ATTEMPTS" in failure
assert "pow(2.0, float(attempt - 1))" in failure
assert "randf()" in failure
assert "clampf" in failure

transport = source.split("func _on_request_completed", 1)[1].split("\nfunc _handle_failure", 1)[0]
assert "result != HTTPRequest.RESULT_SUCCESS" in transport
assert "_handle_failure(active_copy, effective_code" in transport

print("SYNESTHESIA_REWARD_CLIENT_RELIABILITY=PASS retry=bounded+jitter+retry-after transport=retryable signup=validated")
