# Offline test results — NYC V4 reliability/UX patch

| Category | Result | Notes |
|---|---|---|
| Node syntax (site/admin/worker) and Apps Script parse | PASS | `node --check`; no deployment |
| Existing mocked Apps Script tests | PASS | registration, option edits, bank export validation |
| Mocked Worker suite | PASS | origin, login, token signature, OTP proxy, 429 and missing binding 503 |
| Register idempotency and partial write recovery | PASS | simulated failure between Users and RegistrationExtra, verified recovery and one user row |
| Wrong/expired OTP and cooldown | PASS | mock time, OTP proof and retryAfter |
| Import duplicate within file and between batches | PASS | ID, case-insensitive Email, Citizen ID, source Excel row number |
| Report of exclusions | PASS | backend excludes invalid or non-consenting entries; mocked UI exposes CSV controls |
| Browser 360/768/1280 no overflow | PASS | headless Chromium with in-page API mocks, no external network |
| Browser failure then success, message, reference, focus, form preservation | PASS | synthetic data, no real submit |
| Admin success/incorrect password and stats failure | PASS | mocked JSON 401/200/502 and retry control |
| Live Apps Script, Cloudflare, GitHub Pages | NOT TESTED | prohibited by user / no deploy permission |
| Actual Cloudflare rate-limit namespace and WAF status | NOT VERIFIED | requires owner Cloudflare settings |
| Real MailApp/OTP email delivery | NOT TESTED | explicitly excluded |
| Real bank import/certification of A–W CSV | NOT VERIFIED | structural headers preserved; no bank validation service used |
| Assistive technology and mobile-device physical testing | NOT TESTED | keyboard/focus and headless checks only |

**No OTP sent; no record inserted into production Sheets; no secret committed.**
