class_name SignalCtaState
extends RefCounted

# One definition of the finale's "connect this run to Signal" call to action.
#
# The full finale card and its degraded fallback card both present this CTA and
# had drifted into two separate copies of the rule. Both copies disabled the
# button whenever the server had not confirmed completion, which meant finishing
# the album while CrowdRelay was unreachable permanently removed the only route
# from the game into Signal, under a label that claimed a link was still in
# progress. The run is durable locally and the server path is idempotent, so an
# unconfirmed completion is a retry, never a dead end.

## Returns `{"disabled": bool, "text": String}` for the CTA.
##
## `handoff` and `awaiting_return` describe the short-lived handoff exchange and
## are only meaningful once the server has confirmed completion; the fallback
## card passes their neutral values.
static func resolve(
    linked: bool,
    server_completed: bool,
    retryable: bool,
    handoff: String,
    awaiting_return: bool,
) -> Dictionary:
    if linked:
        return {"disabled": false, "text": "OTWÓRZ MÓJ SYGNAŁ"}
    if not server_completed:
        if retryable:
            return {"disabled": false, "text": "PONÓW ŁĄCZENIE Z SYGNAŁEM"}
        return {"disabled": true, "text": "ŁĄCZĘ WYNIK Z SYGNAŁEM…"}
    if handoff.length() == 64 and awaiting_return:
        return {"disabled": false, "text": "PO POWROCIE: SPRAWDŹ POŁĄCZENIE"}
    return {"disabled": false, "text": "POŁĄCZ WYNIK Z SYGNAŁEM"}
