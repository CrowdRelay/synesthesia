# Security

## Client

- Never place operator keys, Netlify tokens, CrowdRelay staff tokens or mail credentials in this repository.
- The completion run token is random, scoped to one album run and stored locally. It is not an account credential.
- The client never stores or receives shipping details.
- Reward requests use HTTPS and bounded JSON payloads.
- Gameplay remains functional when the network or reward API fails.

## Reward page

- The confirmation token is removed from the visible URL immediately with `history.replaceState`.
- The page uses `Cache-Control: no-store`, `noindex` and a restrictive CSP.
- Shipping data posts directly to CrowdRelay and is not proxied through analytics or the Virya site.

## Backend expectations

Use the matching CrowdRelay overlay. It hashes run/install/confirmation tokens, validates room order and server elapsed time, separates shipping storage, rate-limits operational delivery through the existing outbox, and keeps address/phone out of webhook payloads.

Report vulnerabilities privately to the project owner. Do not open a public issue containing a live run token, confirmation link, address, phone number, staff credential or deployment secret.
