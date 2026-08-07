# Security

## Boundary

Synesthesia owns local gameplay state only. CrowdRelay owns the optional completion/draw ledger. Marketing consent, winner selection, inventory and fulfillment are outside the game runtime.

## Data sent to CrowdRelay

Before draw entry: random installation identifier hash, run bearer, app version/locale, ordered room IDs and bounded client elapsed times. The game does not upload brush masks, artwork interaction coordinates, device location or contacts.

For an optional draw entry: e-mail, policy version and locale. The endpoint does not update marketing consent or collect address/phone data. Shipping is requested only from selected winners through the existing CrowdRelay fulfillment boundary.

## Web

The static host applies CSP, `nosniff`, no-referrer and restrictive permissions. Reward/lifecycle calls are limited to `https://signal-api.virya.music`. The service worker handles static assets only; API writes are never an offline cache authority.

Run tokens are bearer capabilities. They are stored with local progress and must not be logged, placed in URLs, analytics, crash reports or referrers.

Report security issues privately to the repository owner rather than opening a public issue with secrets or personal data.
