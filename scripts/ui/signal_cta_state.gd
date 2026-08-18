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

## Server TTL for a handoff is 15 minutes. Stop offering one a little early so a
## code is never handed to My Signal in the same minute the API retires it.
const HANDOFF_LOCAL_TTL_MS: int = 12 * 60 * 1000
const HANDOFF_CODE_LENGTH: int = 64

## Returns `{"disabled": bool, "text": String}` for the CTA.
##
## `handoff` is a locally held, still-valid handoff code and `awaiting_return`
## says the player has already been sent to My Signal with it. Both are only
## meaningful once the server has confirmed completion.
##
## Every state above the in-flight one is actionable, and each label names what
## the press actually does. A completed run always has a route forward: request
## a link, open the link, check the link, or open My Signal once it is linked.
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
    if is_usable_handoff(handoff):
        if awaiting_return:
            return {"disabled": false, "text": "PO POWROCIE: SPRAWDŹ POŁĄCZENIE"}
        return {"disabled": false, "text": "OTWÓRZ MÓJ SYGNAŁ · ŁĄCZE GOTOWE"}
    return {"disabled": false, "text": "POŁĄCZ WYNIK Z SYGNAŁEM"}

static func is_usable_handoff(handoff: String) -> bool:
    return handoff.length() == HANDOFF_CODE_LENGTH

## One destination for both finale cards.
##
## Only the short-lived single-fan completion handoff travels in the fragment.
## Fan/session credentials never leave the API cookie/native secure store.
static func my_signal_url(handoff: String, source: String = "synesthesia") -> String:
    var url: String = "https://virya.music/pl/my-signal/?source=%s" % source.uri_encode()
    if is_usable_handoff(handoff):
        url += "#handoff=%s" % handoff.uri_encode()
    return url
