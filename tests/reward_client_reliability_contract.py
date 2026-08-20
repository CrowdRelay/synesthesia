#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "scripts/reward_client.gd").read_text(encoding="utf-8")
signup = (ROOT / "scripts/app/signal_signup_client.gd").read_text(encoding="utf-8")

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

# The lighter-weight finale signup transport must have the same resilience
# properties as reward mutations: GET is safe to replay, POST keeps one stable
# idempotency key, transient failures are bounded/jittered, and Retry-After is
# capped so a server cannot strand the finale indefinitely.
for token in (
    "MAX_RETRY_ATTEMPTS: int = 3",
    "RETRY_BASE_SECONDS: float = 0.8",
    "RETRY_MAX_SECONDS: float = 6.0",
    "RETRY_JITTER_SECONDS: float = 0.35",
    "MAX_RETRY_AFTER_SECONDS: float = 8.0",
    "func _retry_delay",
    "func _retry_after_seconds",
    "func _is_transient_failure",
    "func _valid_email",
    "func _valid_slug",
    "Idempotency-Key: %s",
):
    assert token in signup, token

signup_call = signup.split("func signup", 1)[1].split("\nfunc _begin_request", 1)[0]
assert "normalized_email" in signup_call
assert "normalized_city" in signup_call
assert "normalized_policy" in signup_call
assert "_valid_email(normalized_email)" in signup_call
assert "_valid_slug(normalized_city)" in signup_call
assert '"idempotency_key": key' in signup_call

signup_failure = signup.split("func _handle_failure", 1)[1].split("\nfunc _retry_delay", 1)[0]
assert "_is_transient_failure(response_code)" in signup_failure
assert "_attempt < MAX_RETRY_ATTEMPTS" in signup_failure
assert "_retry_delay(_attempt, headers)" in signup_failure

signup_delay = signup.split("func _retry_delay", 1)[1].split("\nfunc _retry_after_seconds", 1)[0]
assert "pow(2.0, float(attempt - 1))" in signup_delay
assert "get_instance_id()" in signup_delay
assert "Time.get_ticks_msec()" in signup_delay
assert "RETRY_JITTER_SECONDS" in signup_delay

print("SYNESTHESIA_REWARD_CLIENT_RELIABILITY=PASS reward=bounded+jitter+retry-after signup=validated+idempotent+bounded-jitter+retry-after")
