# Google Play production release — Synesthesia

The Android release pipeline is designed so source/artifact validation stays in GitHub and only account/policy actions that cannot safely live in source control remain in Play Console.

## One-time setup

1. Enable the Google Play Android Developer API in the Google Cloud project used for publishing.
2. Give the publishing service account access only to `music.virya.synesthesia` and the testing/production release permissions it needs.
3. Configure repository/environment variables `GOOGLE_PLAY_WIF_PROVIDER` and `GOOGLE_PLAY_SERVICE_ACCOUNT`. Production publishing and rollout promotion deliberately fail closed without WIF.
4. Complete every Play Console App content item required for this app/account: privacy policy, Data safety, Ads, Content rating, Target audience/content, App access, and any additional Play policy declarations shown by the console.
5. Complete the Main store listing: app name, short and long description, icon, feature graphic, phone screenshots, category/contact details and privacy-policy URL.
6. Enable/confirm Play App Signing and keep the upload-key material only in GitHub Actions secrets.
7. Complete any Play account-level testing history / production-access approval that Google requires for this developer account.

## First production release

1. Merge the intended source to `main` and wait for canonical **CI** to pass on that exact SHA.
2. Run **Android Google Play** manually from `main` with `play_track=production`.
3. The workflow validates source contracts, requires the exact green CI run, verifies WIF and signing secrets, checks CrowdRelay Synesthesia capabilities plus the live psychiatric-ward surface, builds the signed AAB, binds it to the exact source SHA and uploads it at **10% staged rollout**.
4. If Play Console requires a review/submit action for the release, review the generated release and click the required submit/send-for-review control. Do not rebuild the AAB.

## Rollout

Use **Android Google Play rollout** to move the existing active production release through **10% → 25% → 50% → 100%**. The same workflow can `halt` a rollout.

The rollout controller is intentionally constrained:

- `main` only;
- protected `production` GitHub environment;
- WIF only, with no JSON-key fallback;
- checks live CrowdRelay capabilities and `menu-world.webp` before changing exposure;
- only edits an existing `inProgress`/`halted` production release;
- optionally pins to an expected versionCode;
- refuses ambiguous active releases and rollout-percentage decreases;
- stores a 90-day receipt.

## Release notes

Localized user-facing notes live in:

- `distribution/whatsnew/whatsnew-pl-PL`
- `distribution/whatsnew/whatsnew-en-US`

Update them before each public release.

## Intentionally manual

Policy declarations, Data safety answers, content rating, target-audience decisions, production-access applications and store-listing visual approval remain manual. They are legal/product/account choices, not CI configuration.
