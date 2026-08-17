class_name SignalLinkState
extends RefCounted

# Tracks whether linking this run to Signal has failed, independently of which
# finale panel is currently mounted.
#
# Connecting a finished run to Signal is the game's primary conversion path, and
# the CTA used to be disabled whenever the server had not confirmed completion.
# Finishing the album while CrowdRelay was unreachable therefore removed the only
# route into Signal permanently, under a label claiming a link was in progress.
#
# Two shapes made that easy to reintroduce, so both are avoided here:
#   * enumerating the operations that count as a failure, which missed start_run
#     and complete_album, the two that actually fail when the backend is down;
#   * storing the state on the panel, which loses it when the full finale card is
#     replaced by its degraded fallback after the failure has been reported.
#
# The run is durable locally and the server path is idempotent, so an
# unconfirmed completion is always a retry.

var _failed: bool = false

func has_failed() -> bool:
    return _failed

## Latch a failed link and restore the CTA on the panel that is mounted now.
func mark_failed(panel) -> void:
    _failed = true
    apply(panel)

## Server-confirmed completion clears the latch.
func clear() -> void:
    _failed = false

## Re-apply the latched state to a freshly installed panel.
func apply(panel) -> void:
    if not _failed or panel == null or not is_instance_valid(panel):
        return
    if panel.has_method("set_signal_link_retryable"):
        panel.set_signal_link_retryable(true)
