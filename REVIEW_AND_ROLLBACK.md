# NYC Krungthai Registration V4 — Review patch (NOT DEPLOYED)

Status: **local branch prepared, not pushed, no PR, no merge, no deployment**. GitHub connector returned `403 Resource not accessible by integration` when attempting to create `fix/registration-reliability-ux-20261104` on the remote repository. `main` remains unchanged.

## Repository and baseline

- Repository: `eirchard/nyc-krungthai-registration-v4`, baseline commit `d661131bfaa4bb7f2f9d61488e626a68ebc7431e` (`main`).
- No root `AGENTS.md` was found in the GitHub tree.
- `site/` and `docs/` had identical frontend blobs on baseline. **`site/` is now canonical**; run `bash scripts/sync-site.sh sync` before pushing and `bash scripts/sync-site.sh check` to verify.
- The bank A–W header array is unchanged; compare to `bank-schema.json` and the bank-issued spreadsheet before actual submission. No claim is made that the bank has certified this exporter.
- Source contains no Apps Script `Config.gs`, no real OTP, no user records and no Cloudflare secret.

## P1 fixes

1. `site/index.html`, `site/app.js` (+ `docs/` mirrors): success result is outside hidden form; focusable and announced, contains reference. Failure keeps entered data; form disabled during submit, with timeout and stable requestId for retry.
2. `site/admin.js`: capture form reference before await, login and stats errors distinct; a stats failure retains authenticated state and offers Reload button. Network timeout and button cleanup.
3. `apps-script/Code.gs`: creates additional `RegistrationJournal` sheet on first call; locks registration attempts; persists keyed pending/committed state, reconstructs a partially written user/extra/OTP sequence; identical retry returns the same opaque reference, unrelated request ID/payload does not reveal a user. This is **not** a multi-sheet transaction. Recovery is on the same valid proof request, not by blindly removing rows.

## P2 fixes

- `Code.gs` import uses consistent A–W validation and duplicate checks: ID, Code, case-insensitive Email, nonempty Citizen ID and Passport ID. Within batches and against previous batches/existing users; `rowNumbers` preserves source row positions when blank Excel rows are skipped.
- `admin.js` import counts confirmed completed batches, shows rejected count and reasons, exports a masked error CSV; if network fails mid-batch, report explicitly labels that batch as unknown rather than claiming success.
- Export includes paginated masked exclusions for lack of consent, missing Q, invalid values and incomplete fields. It does not send files to the bank automatically.
- OTP API responds with `retryAfter` (90s) and `expiresIn` (600s); JS countdown and email-change invalidation. Backend enforces expiry, 90s cooldown, five attempts, three requests per day per address.
- `worker/index.js` + `worker/wrangler.toml`: fail-closed Cloudflare Rate Limiting bindings for login (5/min/IP) and OTP request (8/min/IP). These are *approximate edge-local limits*, not a strict global quota. IP-based limits can affect multiple users behind a school NAT; adjust after testing and use an upstream WAF/Turnstile as appropriate. Existing WAF status was **not verified**.

## Migration (additive, owner-approved deployment only)

1. Back up the live Google Sheet, Apps Script deployment version, Worker deployment version, and current GitHub commit. **Do not place the backups in a public GitHub repository.**
2. Review the pending PR; check `site/`/`docs/` sync with `bash scripts/sync-site.sh check`.
3. Deploy Apps Script `Code.gs` to the *existing bound script* (not a newly created spreadsheet). Its `init_()` creates `RegistrationJournal` if absent; it is idempotent and does not drop existing tabs. `Config.gs` remains private and unchanged. Deploy a **new version** of the existing Web App (`/exec`). Save the previous version and URL.
4. Apply `worker/wrangler.toml` to the existing Worker. Verify `LOGIN_RATE_LIMITER` and `OTP_RATE_LIMITER` are bound and your Wrangler version is >=4.36.0. The namespace IDs must be unique within your Cloudflare account. Use `npx wrangler deploy` from `worker/` only when approved, and verify existing secrets are still present. Missing limiter bindings cause login/OTP routes to return HTTP 503 deliberately; do not bypass this for production. **Check Cloudflare plan and possible usage charges** before approval; Worker Free currently caps requests at 100,000/day, Worker Paid has a minimum charge of US$5/month, and other services may have separate pricing. A precise additional price for the rate-limit binding is not asserted.
5. After backend and Worker checks, merge the reviewed PR when approved to allow GitHub Pages to publish `/docs`. We did **not** merge or deploy in this review.
6. Verify from a staging environment with synthetic addresses/people before opening to real registrants: config, fake OTP, register, repeat, failed write recovery, export validation, rate-limit binding and origin policy. Do **not** send test OTP via real MailApp.

## Rollback

- GitHub Pages: revert the reviewed commit on `main` (do not force-push); wait for Pages deploy. `site/` and `docs/` should stay in sync. If release hasn't been merged, no rollback is necessary.
- Worker: restore a previous known-good Worker version using the Cloudflare Dashboard Deployments/rollback UI or Wrangler-supported rollback command for the installed version. **Do not delete existing secrets or change origin**. If reverting only Worker but leaving the frontend that expects `retryAfter`, fallback messaging remains possible.
- Apps Script: in Deploy > Manage deployments, restore the previously recorded Web App version. Keep `Config.gs` and the bound Spreadsheet intact. **Do not delete `RegistrationJournal`**, even if the earlier code ignores it; it may be needed to reconcile interrupted submissions.
- If an in-progress request spans the rollback window, reconcile `RegistrationJournal`, `Users_A_W`, `RegistrationExtra` and `EmailOTP` manually using ID plus authenticated requests—do not simply delete suspected duplicates.
- Capture a human-approved backup and restoration checklist before production data are processed.

## Known limits

- A backend timeout leaves the most recent in-flight batch outcome unknown until the admin checks actual records; the UI reports only prior batches as confirmed.
- Cross-sheet recovery works when the identical valid OTP-backed request is retried and the registration fields/options have not been changed. A failed request cannot be safely rolled back transactionally by Apps Script.
- MailApp provider-specific quota and delivery, real Cloudflare binding availability, WAF configuration, accessibility audit with assistive technology, and real bank import compatibility remain unverified.
- The numeric `namespace_id` values in the configuration are examples reserved for this application; verify uniqueness across other Workers on your account.

## Tests

Run `bash tests/test.sh` for Node syntax, mocked Apps Script/Worker regressions, and site/docs sync. Run `python tests/browser_check.py` with Chromium and Python Playwright installed (the browser uses in-memory mock API, not live network). Screen widths checked: 360, 768, 1280. All seeded identities and email addresses are synthetic.
