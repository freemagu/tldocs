---
status: design — awaiting decisions
generated: 2026-04-30
phase: 3 — self-signup + email verification + password reset
prerequisites:
  - Phase 1 complete (commit 1861ed8c) — auth + user_account + admin gating
  - Phase 2 complete (commit b23eadcf) — encrypted Bybit creds + FE accounts page + YAML retirement
related-audits:
  - AUD-0227 (multi-user auth epic)
  - AUD-0353/0354 (secret rotation runbook — JWT secret + Fernet master key already integrated)
estimated-effort: 6-9 days end-to-end (design doc → email infra → verify → reset → self-signup → cutover)
---

# AUD-0227 Phase 3 Design — Self-Signup + Email Verification + Password Reset

## Goal

Today: every new user has to be created by the operator running
`manage_users.py create <email>` over ssh; password reset is the same
CLI (`reset-pwd`); there's no `/signup` page in the FE; there's no
email infrastructure at all.

After Phase 3:
- Public `/signup` page in the FE accepts email + password and
  immediately sends a verification email. The user is created with
  `is_verified=FALSE`; until they click the verification link they
  cannot log in.
- `/auth/forgot-password` accepts an email, generates a single-use
  reset token, and emails a `/reset-password?token=...` link. Clicking
  the link opens a "set new password" form; submitting rotates the
  password hash + revokes any active sessions.
- Email is routed through a single configurable provider (selected in
  Q1 below) with bounded retry, deliverability headers (SPF/DKIM/DMARC
  ready), and a server-side rate limit per email/IP.
- `manage_users.py` keeps its CLI subcommands as the operator escape
  hatch — they bypass the email path and remain available for cold
  recovery (forgotten password reset for a stuck user, mass migrations,
  etc.).

This is **the unlock for SaaS launch**. With Phase 3 shipped, an
external user can self-onboard end-to-end without operator intervention,
which Phases 4+ then layer on (per-user IP isolation, billing, tier-4
multi-tenant ops).

## Non-goals (deferred to Phase 4)

- 2FA (TOTP / WebAuthn / passkeys) — explicitly post-launch.
- OAuth / social login (Google, Apple, Github sign-in) — same.
- Account deletion / GDPR data export endpoints — same.
- Email-change flow (with verification) — same; for now operators do
  this via `manage_users.py` directly.
- Internationalisation of email templates — single-locale (en) for
  launch.
- Outbound transactional email (trade alerts, etc.) — Phase 3 only
  ships the auth-related transactional emails (verify, reset).

## Decisions to lock (12 questions)

For each, pick one bold option and lock it in the table at the bottom.
Open-ended commentary follows each question.

### Q1 — Email service provider

**Question:** which provider sends our outbound transactional email?

| Option | Pros | Cons | Cost (est. for 5k MAU) |
|---|---|---|---|
| **(a) Resend** | Modern API, Python SDK, generous free tier (3k/mo), DKIM auto-config, very simple integration | Newer (founded 2023), smaller deliverability moat than SES/Mailgun | $0 free → $20/mo for 50k emails |
| (b) AWS SES | Cheapest at scale ($0.10/1k), bullet-proof deliverability, AWS native | Heaviest setup (DKIM, sandbox-out, IAM, etc.); more moving parts | ~$0.50/mo for 5k |
| (c) Mailgun | Long-running provider, EU region available, good docs | More expensive than SES at our scale; v3 API ergonomics dated | ~$15/mo for 5k |
| (d) SMTP via gmail / icloud | "Free", no provider account | Rate-limited, deliverability marked as personal, no SLA, will get hard-blocked at scale | $0 |
| (e) Postmark | Best-in-class transactional deliverability + analytics | Most expensive at our scale | $15/mo for 10k |

**Recommendation: (a) Resend.** Smallest setup overhead for the
volume we'll see in soft launch (verification + reset emails — likely
<1k/mo for the first quarter). Easy migration path to SES later if cost
or deliverability becomes a concern. The `lib/tradelens/auth/email.py`
abstraction will be provider-agnostic so a future swap is one config
change.

### Q2 — Sender identity & domain

**Question:** what `From:` address does outbound auth email use? What
domain receives the bounces / DKIM signatures?

Options:
- **(a) `auth@tradelens.io`** with DKIM/SPF on `tradelens.io`. Requires
  buying / using a domain we'll keep.
- **(b) `noreply@tradelens.io`** (same domain, different mailbox alias).
- (c) Use Resend's free `onboarding@resend.dev` — only allowed for the
  sandbox account holder's email. Not viable for real users.

**Recommendation: (a) `auth@tradelens.io`.** "noreply@" trains users
to ignore replies, but auth-related email occasionally needs a human
contact (someone disputing the account exists, abuse reports). A real
mailbox forwards to operator email. Brand-consistent.

**Open sub-question:** does the operator already own `tradelens.io`?
If not, this Phase needs a domain purchase ($12/yr) before sending
anything. Verify before locking.

### Q3 — Verification token shape

**Question:** what does the email-verification token look like?

| Option | Pros | Cons |
|---|---|---|
| **(a) JWT (signed, self-contained, 24h TTL)** | No DB lookup needed to verify the token's authenticity; cryptographic guarantees | Can't be revoked early; if the user clicks within TTL, accepted; one-time-use enforced via DB flag, not cryptographically |
| (b) Random 256-bit UUID, stored in `email_verification_token` table with single-use flag | One-time-use enforced cryptographically; revocable; standard approach | One DB lookup per click |
| (c) Short 6-digit code, user types it back on a `/verify-code` page | Mobile-friendly | Surface area for brute-force (need rate limit); UX inferior to one-click |

**Recommendation: (b) random UUID with DB-backed single-use.** The cost
of one extra DB lookup at verify time is negligible vs the value of
having explicit "delete-on-use" semantics + ability to revoke if a
token leaks. Same shape used for password reset (Q6). 24h TTL.

### Q4 — Self-signup gating

**Question:** is signup open to the public on day 1 of cutover?

| Option | Pros | Cons |
|---|---|---|
| **(a) Open** — anyone with an email can sign up | Real SaaS launch posture; simplest UX; no waitlist friction | Spam signups; bot traffic creating fake accounts; need rate limiting + maybe captcha |
| (b) Invite-only — admin generates invite code, prospect uses it during signup | Controlled rollout; can throttle | More work (invite-code subsystem); operator manages invite list |
| (c) Allowlist — signup only succeeds for emails on a pre-approved list | Tightest control | Same as (b) plus zero-friction for known users; manage allowlist via CLI |
| (d) Closed — `/signup` page exists but redirects to "coming soon" until manually flipped | Lets the FE be merged before going live | Adds dead path; weird state |

**Recommendation: (b) invite-only.** Soft-launch posture. Adds an
`invite_code` table + `manage_users.py invite create / list / revoke`
subcommands. The signup form has an `invite_code` field; backend
verifies the code is unused + unexpired. After 30-90 days of
operational confidence, **flip to (a) open** by allowing signup
without an invite_code (controlled by `TRADELENS_SIGNUP_OPEN=true`
env flag — same Phase-1+2 cutover pattern).

This composes safely with rate-limiting (Q8): even open signup will
have rate limits.

### Q5 — Email template style

**Question:** what does the verify / reset email look like?

| Option | Pros | Cons |
|---|---|---|
| **(a) Plain text + minimal HTML, brand text only** | Renders everywhere; smallest deliverability footprint; trivial to maintain | Not eye-catching; some users may distrust it |
| (b) Branded HTML with logo + colored CTA button | Modern look; better engagement | More dependency on email-rendering quirks (Outlook, dark-mode); requires brand assets we don't have |
| (c) Branded HTML + plain-text fallback (multipart) | Best of both | Most maintenance |

**Recommendation: (a) plain text + minimal HTML.** No logo asset
exists; brand identity is "plain text" today (per Phase 1 D-pattern
decision). Templates live in `lib/tradelens/auth/email_templates.py`
as Python f-strings — kept simple, easy to edit. Migrate to HTML when
brand identity firms up.

### Q6 — Password-reset flow shape

**Question:** how does the user reset their password?

Options (all email-driven; the `manage_users.py reset-pwd` CLI stays as the
operator escape hatch regardless):

| Option | Steps |
|---|---|
| **(a) One-time link to `/reset-password?token=...`, lands on form, user types new password twice** | classic; everyone understands it |
| (b) Magic-link login (no password reset, just a one-click login session) — user can change their password from /settings | unified UX with email-verification; password-resets become "passwordless logins"; conflicts with our password-based auth |
| (c) Reset code mailed; user types code on /reset-password page along with new password | mobile-friendly; users distrust links from email |

**Recommendation: (a) one-time link.** Same shape as verify (Q3), same
single-use-DB-token mechanism, single FE page with "new password" /
"confirm new password" inputs. After successful reset:
- Hash + store new password
- Revoke ALL active refresh tokens for this user (force re-login on every device — important security signal)
- Send a confirmation email "your password was reset on [time/IP]"
- Redirect to /login

### Q7 — Verification UX (timing)

**Question:** when is the verification check enforced?

| Option | UX |
|---|---|
| **(a) Verify-before-login** — user signs up, must click email link before they can log in for the first time | Most secure; standard SaaS pattern |
| (b) Login-permitted-grace — user can log in immediately, but can't perform protected actions (POST /accounts, etc.) until verified; banner at the top "verify your email by [time]" | Better activation rate but more complex UI states |
| (c) Soft-encourage — user can do everything; banner pesters them; after 7 days, account locked | Worst security; best UX |

**Recommendation: (a) verify-before-login.** This is paid SaaS — users
will tolerate the verify step, and it filters bot signups before they
ever get a session. Implementation: `users.is_verified BOOLEAN NOT
NULL DEFAULT FALSE`; auth/login rejects with HTTP 403 +
`error_code=email_unverified` + a "resend verification" affordance in
the FE.

### Q8 — Rate-limiting

**Question:** what rate limits do we apply to the new endpoints?

Endpoints that take an email and send mail (the abuse vectors):
- `POST /auth/signup` (sends verification)
- `POST /auth/resend-verification`
- `POST /auth/forgot-password` (sends reset link)

Recommendation:
- **Per-IP**: 10 / hour (sliding window)
- **Per-email**: 3 / hour
- **Global**: 1000 / hour (protect provider quota)

Implemented with a simple Postgres-backed counter table
`auth_rate_limit (key TEXT, window_start TIMESTAMPTZ, count INT)` —
no Redis dependency yet (Phase 4 if scale demands). Returns HTTP 429
with `Retry-After` header on excess.

For login itself (already shipped Phase 1), Phase 3 ADDS a 5/min
per-email rate limit on `/auth/login` to slow brute-force after
verified accounts exist. (Pre-Phase-3 there are 1 user + 0 risk
of account-enumeration; post-Phase-3 there are real users.)

### Q9 — Unverified-user state

**Question:** what is the row state of an unverified signup?

Options:
- **(a) Single users table, `is_verified` flag**
- (b) Separate `pending_users` table; on verification, row is moved to `users`

**Recommendation: (a) single table + flag.** Simpler; matches
industry standard; `is_verified=FALSE` means "cannot login but
account exists, prevents email re-use, can resend verification".
Cleanup of stale unverified accounts is a future cron job
(`DELETE FROM users WHERE is_verified=FALSE AND created_at <
NOW() - INTERVAL '30 days'`); not Phase 3 scope.

### Q10 — Schema additions

Three new tables proposed (single migration `093_add_phase3_tables.sql`):

```sql
-- Single-use email-verification + password-reset tokens.
CREATE TABLE IF NOT EXISTS auth_token (
    token             VARCHAR(64) PRIMARY KEY,           -- 256-bit URL-safe random
    user_id           BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    purpose           VARCHAR(32) NOT NULL CHECK (purpose IN ('verify_email', 'reset_password')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at        TIMESTAMPTZ NOT NULL,
    used_at           TIMESTAMPTZ NULL,                  -- NULL until consumed
    used_from_ip      INET NULL,
    UNIQUE (token)
);
CREATE INDEX idx_auth_token_user_purpose ON auth_token(user_id, purpose);
CREATE INDEX idx_auth_token_expiry ON auth_token(expires_at) WHERE used_at IS NULL;

-- Invite codes for Q4 invite-only signup.
CREATE TABLE IF NOT EXISTS invite_code (
    code              VARCHAR(32) PRIMARY KEY,           -- short, human-friendly
    created_by        BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at        TIMESTAMPTZ NULL,                  -- NULL = never expires
    used_at           TIMESTAMPTZ NULL,
    used_by_user_id   BIGINT NULL REFERENCES users(id) ON DELETE SET NULL,
    note              TEXT NULL                          -- operator memo: "for John at AcmeCo"
);

-- Q8 rate limit.
CREATE TABLE IF NOT EXISTS auth_rate_limit (
    key               VARCHAR(128) NOT NULL,             -- "ip:1.2.3.4:signup" / "email:foo@bar.com:resend"
    window_start      TIMESTAMPTZ NOT NULL,
    count             INT NOT NULL DEFAULT 0,
    PRIMARY KEY (key, window_start)
);
CREATE INDEX idx_rate_limit_window ON auth_rate_limit(window_start);
```

Plus one column on `users`:
```sql
ALTER TABLE users ADD COLUMN is_verified BOOLEAN NOT NULL DEFAULT FALSE;
-- For the single existing user (operator): mark verified.
UPDATE users SET is_verified = TRUE WHERE id = 1;
```

### Q11 — Bootstrap CLI interaction

**Question:** does Phase 3 deprecate `manage_users.py` subcommands?

**Recommendation: NO.** The CLI stays as the operator escape hatch:
- `manage_users.py create` skips verification (operator-created users
  are pre-verified — equivalent to admin-issued accounts).
- `manage_users.py reset-pwd` directly rotates the hash; bypasses
  email; useful for stuck users.
- `manage_users.py invite create/list/revoke` is NEW (Q4 invite
  subsystem).
- `manage_users.py verify-email <email>` is NEW (force-mark a user
  as verified; cold recovery if email infra is down).

The CLI complements the FE; doesn't compete. Operators retain full
control over the user table.

### Q12 — Cutover strategy

Same pattern as Phase 1 / 2: feature-flag the new behaviour.
- `TRADELENS_SIGNUP_ENABLED` (default `false`) — gates the public
  `/signup` route + endpoint.
- `TRADELENS_SIGNUP_OPEN` (default `false`, only meaningful if
  `TRADELENS_SIGNUP_ENABLED=true`) — bypass the invite-code
  requirement (Q4 (a) vs (b)).
- `TRADELENS_EMAIL_PROVIDER` (`resend` / `ses` / `noop`). `noop`
  logs the email body to stdout instead of sending — used in tests
  + during initial rollout when no domain is set up yet.

Initial cutover sequence:
1. Provider config in `~/.tradelens.secrets` (RESEND_API_KEY).
2. `TRADELENS_EMAIL_PROVIDER=resend`, but
   `TRADELENS_SIGNUP_ENABLED=false`. Forgot-password route still
   works for existing users — they're verified, so they can self-serve.
3. Some soak time (~1 week). Operator-issued reset emails verified
   end-to-end.
4. Flip `TRADELENS_SIGNUP_ENABLED=true`. Soft-launch invite-only.
5. After 30-90 days of clean operation, flip
   `TRADELENS_SIGNUP_OPEN=true` for true public signup.

Rollback at any step: unset the relevant flag + `tl restart api`.

## Schema delta summary

- 1 migration: `093_add_phase3_tables.sql` (3 new tables + 1
  ALTER TABLE on `users`).
- `users.is_verified BOOLEAN NOT NULL DEFAULT FALSE`.
- `auth_token`, `invite_code`, `auth_rate_limit` tables.

## API delta summary

| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| `/api/v1/auth/signup` | POST | none | Create unverified user, send verification email |
| `/api/v1/auth/resend-verification` | POST | none | Resend verification email |
| `/api/v1/auth/verify-email` | GET | none | Consume token, mark user verified, redirect to /login |
| `/api/v1/auth/forgot-password` | POST | none | Send reset email (silently OK on unknown email) |
| `/api/v1/auth/reset-password` | POST | none | Consume token, hash new password, revoke sessions |
| `/api/v1/auth/me` | (existing, modified) | yes | Returns `is_verified` field too |
| `/api/v1/admin/invites` | GET/POST/DELETE | admin | Invite code management (admin only) |

`/api/v1/auth/login` (existing) is modified to reject unverified users
with HTTP 403 `error_code=email_unverified`.

## Frontend delta summary

| Page | New / Modified |
|---|---|
| `/signup` | NEW — email + password + invite_code form |
| `/verify-email` | NEW — landing page after click; calls verify-email endpoint |
| `/forgot-password` | NEW — single-input "email me a reset link" form |
| `/reset-password` | NEW — landing page from email; new-password + confirm form |
| `/login` | MODIFIED — banner if `error_code=email_unverified` with "resend" affordance |
| `/settings` | MODIFIED — show `is_verified` badge in user menu |
| `/settings/admin/invites` | NEW — admin-only invite-code management |

All new pages reuse the existing form components + axios layer + AuthProvider.

## Implementation sequence (8 commits)

1. **3.1 Schema migration 093** — `auth_token`, `invite_code`,
   `auth_rate_limit` tables; `users.is_verified`. Backfill operator
   user to `is_verified=TRUE`. Tests in
   `tests/integration/test_aud0227_phase3_schema.py`.
2. **3.2 Email infrastructure** — `lib/tradelens/auth/email.py`
   provider abstraction (`send_email(to, subject, body)`); `resend`
   + `noop` providers; `TRADELENS_EMAIL_PROVIDER` selector. Tests
   with the `noop` provider.
3. **3.3 Token + rate-limit modules** — `lib/tradelens/auth/tokens.py`
   (mint, verify, consume); `lib/tradelens/auth/rate_limit.py`
   (per-IP / per-email Postgres counter). Tests.
4. **3.4 Verification flow + login gate** — `/auth/signup`,
   `/auth/resend-verification`, `/auth/verify-email`. Login modified
   to reject unverified. Tests including the
   `test_unverified_user_cannot_login` regression.
5. **3.5 Password-reset flow** — `/auth/forgot-password`,
   `/auth/reset-password`. Reset MUST revoke all active sessions and
   send confirmation email. Tests.
6. **3.6 Invite-code subsystem + CLI** — `/api/v1/admin/invites`
   endpoints; `manage_users.py invite` subcommands; signup
   honours `invite_code` when `TRADELENS_SIGNUP_OPEN=false`. Tests.
7. **3.7 FE pages + AuthProvider integration** — `/signup`,
   `/verify-email`, `/forgot-password`, `/reset-password`,
   `/settings/admin/invites`; login banner; vitest coverage.
8. **3.8 Cutover** — flip `TRADELENS_EMAIL_PROVIDER=resend` + set up
   sender domain DNS + `TRADELENS_SIGNUP_ENABLED=true`. Soft-launch
   invite-only. (Open-signup flip is a future operator decision, not
   a separate commit.)

Each commit ships its own tests. The same testing-policy contract as
Phase 2 applies — `dead-code-removal` exemptions for any cleanup; all
behaviour changes ship with regression tests.

## Risks / open questions

- **Domain ownership.** If `tradelens.io` (or whatever domain Q2
  picks) isn't already operator-owned, this Phase requires a domain
  purchase + DNS setup before email can send. Block on Q2 sub-question.
- **Resend free-tier limits.** 3k emails/mo is comfortable for
  invite-only soft launch but a sudden spike (someone shares signup
  link on social media) could blow through it. Action: monitor
  `auth_rate_limit` + Resend dashboard during the first month;
  upgrade to paid ($20/mo) if needed.
- **Bot signups even with rate limit.** Sufficiently distributed
  bots can bypass per-IP limits. Mitigations available later
  (hCaptcha on signup form; email-domain blacklist for known
  disposable-email providers; SMS verification post-launch). Not
  Phase 3 scope.
- **Time-of-check vs time-of-use on tokens.** Two clicks within
  microseconds could both succeed. Mitigation: `UPDATE auth_token
  SET used_at=NOW() WHERE token=$1 AND used_at IS NULL RETURNING ...`
  — single round-trip atomic test-and-set. Standard pattern.
- **GDPR + data retention.** Stale unverified accounts holding
  verified-attempt PII (the email). Recommend a daily cron to
  delete unverified rows older than 30 days; not Phase 3 scope but
  worth noting.

## Decisions table (lock these)

| # | Question | Recommendation | Locked? |
|---|---|---|---|
| Q1 | Email provider | (a) Resend | ☐ |
| Q2 | Sender domain | (a) auth@tradelens.io — sub-question: domain ownership? | ☐ |
| Q3 | Verification token shape | (b) UUID + DB single-use, 24h TTL | ☐ |
| Q4 | Self-signup gating at cutover | (b) invite-only, with TRADELENS_SIGNUP_OPEN flag for later flip | ☐ |
| Q5 | Email template style | (a) plain text + minimal HTML | ☐ |
| Q6 | Password-reset flow | (a) one-time link, full session revoke + confirmation email | ☐ |
| Q7 | Verification UX | (a) verify-before-login | ☐ |
| Q8 | Rate limits | 10/hr per IP, 3/hr per email, 1000/hr global; 5/min per email on /login | ☐ |
| Q9 | Unverified-user state | (a) single table, is_verified flag | ☐ |
| Q10 | Schema | 1 migration: auth_token + invite_code + auth_rate_limit + users.is_verified | ☐ |
| Q11 | Bootstrap CLI | Keep + extend (manage_users.py invite + verify-email) | ☐ |
| Q12 | Cutover strategy | Feature flags: TRADELENS_EMAIL_PROVIDER, TRADELENS_SIGNUP_ENABLED, TRADELENS_SIGNUP_OPEN | ☐ |

## What ships when

| Phase | Scope | Ship date |
|---|---|---|
| **Phase 1** ✅ | Auth + login UX + admin gating | 2026-04-29 |
| **Phase 2** ✅ | Encrypted Bybit creds + FE accounts page + YAML retirement | 2026-04-29 |
| **Phase 3** | Self-signup + email verify + password reset (this doc) | After Q1-Q12 lock + 6-9 days |
| **Phase 4** | Per-user IP routing, billing, multi-tenant rate-limit isolation, 2FA, OAuth | When SaaS launch ramps |

## References

- `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-29-aud-0227-0312-auth-epic-design.md` — Phase 1 design
- `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-29-aud-0227-phase2-design.md` — Phase 2 design
- `lib/tradelens/auth/` — Phase 1+2 modules; Phase 3 extends here
- `bin/setup/manage_users.py` — operator CLI; Phase 3 adds `invite` + `verify-email` subcommands
