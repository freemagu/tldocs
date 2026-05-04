---
status: phase-1-shipped (TRADELENS_REQUIRE_AUTH=true since 2026-04-29)
generated: 2026-04-29
decisions-locked: 2026-04-29
phase-1-cutover: 2026-04-29
phase-1-commits:
  - bfc1a927 (#1 schema)
  - e3c67c50 (#2 manage_users CLI + password helpers)
  - d5123034 (#3 auth backend — login/refresh/logout/me)
  - e7c3a5d8 (#4 middleware + feature flag + authz deps)
  - 92b3df06 (env hardening — autorestart self-sources sourceme.sh)
  - dda7c308 (test_auth_flow.sh end-to-end smoke)
  - 67b46b7e (#5 verify_account_access rollout — 43 sites / 11 files)
  - ab3bdaef (#6 require_admin sweep — system / services / mdsync / health / discord-ingest config)
  - 71752b70 (#7 replace AUD-0112 sentinel with real binding-check guard)
  - 959a9880 (#8 frontend — login + AuthProvider + axios CSRF/401 + RequireAuth + UserMenu)
  - <THIS COMMIT> (#9 cutover — TRADELENS_REQUIRE_AUTH=true in operator secrets file + conftest force-default false for tests)
related-audits:
  - AUD-0227 (Major/Security): no user-scoped authz; every endpoint trusts client-supplied account_name
  - AUD-0312 (Major/Security): zero auth headers in frontend; reinforces 0227
  - AUD-0112 (Critical/Security): submit_trade trusts cached preview's account_name (partial fix shipped 2026-04-29 in `1442a238`; full fix gated on this epic)
trigger-tests:
  - tests/unit/test_aud0111_0113_trades_cluster.py::test_aud0112_parked_pending_aud0227_auth_epic
estimated-effort: 3-5 days
---

# AUD-0227 / 0312 — Auth Epic Phase 1 Design

## Decisions (locked 2026-04-29)

| Choice | Decision |
|---|---|
| **Tenancy model** | Per-user, no organization layer. SaaS-aspirational (~hundreds of users in 6 months). |
| **Identity provider** | Roll our own (FastAPI + passlib + python-jose). Hosted (Auth0/Clerk) deferred. |
| **Login mechanism** | A1 — classic email + password. |
| **Page layout** | B1 — dedicated `/login` page. |
| **Session lifecycle** | C2 — silent refresh. 1h access JWT, 30d refresh JWT, transparent rotation. Explicit "Log out" button. |
| **Remember-me checkbox** | D1 — no checkbox. Always 30d refresh token. |
| **Password reset** | Phase 3 (deferred). Phase 1 ships a bootstrap CLI for password reset. |
| **Branding** | Plain text app name on login page. |
| **Color scheme** | Use existing FE design system. |
| **Email service** | Deferred to Phase 3. |
| **Browser-extension auth** | Unchanged. `DISCORD_INGEST_API_KEY` stays as a pipeline secret, separate from user auth. |
| **JWT secret rotation policy** | Bundle with Phase B of AUD-0353/0354 runbook. Single rotation event invalidates all sessions — documented + acceptable. |
| **First-admin bootstrap** | Manual `manage_users.py create` invocation. NO auto-seed script. |
| **`/health` (basic) response shape** | Unchanged — current `{"status":"ok"}` (or equivalent) stays public for load balancers. AUD-0266 split preserved. |
| **Disabled-user revocation** | Check `users.disabled_at IS NULL` on **refresh only**. Existing access tokens (max 1h) keep working until they expire. |
| **Middleware skip-list** | Includes `/api/v1/discord-ingest/*` — extension's POST stays gated by `DISCORD_INGEST_API_KEY` shared secret, NOT user auth. |
| **`accounts.owner_user_id`** | NOT added in Phase 1. Phase 2 designs its own schema for self-managed Bybit creds. |
| **Cookie `Secure` attribute default** | Default `true` (HTTPS prod). Operator overrides via `TRADELENS_COOKIE_SECURE=false` in `~/.tradelens.secrets` for plain-HTTP deployments (current rocky-8gb / rocky2 setup until TLS lands). Without this, curl + browsers drop Secure cookies on HTTP follow-up requests and `/me` 401s right after a successful `/login`. Verified via `bin/test/test_auth_flow.sh`. |

## What this epic does NOT do

- Self-signup / registration UI (Phase 3)
- Password reset via email (Phase 3 — bootstrap CLI is Phase 1's escape hatch)
- 2FA / MFA
- OAuth (Google/GitHub login)
- Per-account roles / sharing / delegation
- Audit logs of user actions
- Billing / Stripe
- Org/team layer
- Per-user Bybit credential storage (Phase 2 — `accounts.yml` stays as creds-source)
- Per-user Bybit IP routing / rate-limit isolation (Phase 4)

## Schema (one migration)

```
users
├── id           BIGSERIAL PRIMARY KEY
├── email        VARCHAR(254) NOT NULL UNIQUE   (lowercased at insert; CITEXT also acceptable)
├── password_hash VARCHAR(128) NOT NULL          (argon2id via passlib)
├── is_admin    BOOLEAN NOT NULL DEFAULT FALSE
├── created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
├── updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
└── disabled_at TIMESTAMPTZ NULL                  (soft-delete; NULL = active)

INDEX users_email_lower_idx ON users (lower(email))    -- case-insensitive lookup
```

```
user_account
├── user_id     BIGINT NOT NULL  REFERENCES users(id)    ON DELETE CASCADE
├── account_id  BIGINT NOT NULL  REFERENCES accounts(id) ON DELETE CASCADE
├── created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
└── PRIMARY KEY (user_id, account_id)

INDEX user_account_account_id_idx ON user_account (account_id)
```

```
revoked_token       -- for explicit logout invalidation
├── jti          VARCHAR(36) PRIMARY KEY    (JWT id claim)
├── user_id      BIGINT NOT NULL REFERENCES users(id)
├── revoked_at   TIMESTAMPTZ NOT NULL DEFAULT now()
└── expires_at   TIMESTAMPTZ NOT NULL                  -- the token's original exp; row purged after this

INDEX revoked_token_expires_at_idx ON revoked_token (expires_at)   -- for purge job
```

`accounts` table is **not modified** in Phase 1. The `user_account` join is the binding. Phase 2 may add `accounts.owner_user_id` for self-managed accounts, but Phase 1 doesn't need it.

## Auth backend

### Endpoints

| Method | Path | Purpose | Auth required |
|---|---|---|---|
| POST | `/api/v1/auth/login` | Email + password → set access + refresh + CSRF cookies | No |
| POST | `/api/v1/auth/logout` | Revoke current session (add to revoked_token) | Yes (any session) |
| POST | `/api/v1/auth/refresh` | Use refresh-cookie to mint new access JWT | Yes (refresh token) |
| GET | `/api/v1/auth/me` | Return `{user_id, email, is_admin, account_ids}` | Yes |

### JWT shape

```
access JWT (1h):
  {
    "sub": user_id,           // standard subject
    "email": "...",
    "is_admin": bool,
    "account_ids": [...],     // cached for the access window — short-lived so staleness is bounded
    "jti": uuid4,             // unique token id (for revocation)
    "iat": ..., "exp": ...,
    "typ": "access"
  }

refresh JWT (30d):
  { "sub": user_id, "jti": uuid4, "iat": ..., "exp": ..., "typ": "refresh" }
```

Access token carries `account_ids` to avoid a per-request DB hit for the authz check. Trade-off: account changes (additions/removals) take up to 1h to propagate. Acceptable for Phase 1 — accounts don't change often. Phase 2 may switch to a request-time DB lookup if needed.

### Cookie shape

| Cookie | Path | HttpOnly | Secure | SameSite | Lifetime |
|---|---|---|---|---|---|
| `tl_access`  | `/`                     | yes | yes | Lax    | 1h |
| `tl_refresh` | `/api/v1/auth/refresh`  | yes | yes | Strict | 30d |
| `tl_csrf`    | `/`                     | **no** (must be readable by FE) | yes | Lax | session |

CSRF token is a UUID4 sent as cookie + must echo as `X-CSRF-Token` header on all mutating requests. Standard double-submit cookie pattern.

### Password hashing

`argon2id` via `passlib`. Tuning: m=64MB, t=3, p=4 (passlib's default is fine; no need to over-tune at hundreds-of-users scale).

### JWT secret management

New env var: `TRADELENS_JWT_SECRET`. Generated via `python3 -c "import secrets; print(secrets.token_urlsafe(64))"`. Stored in `~/.tradelens.secrets`, sourced by `sourceme.sh` (the AUD-0354 plumbing already gives this for free).

```bash
# Add to ~/.tradelens.secrets:
export TRADELENS_JWT_SECRET='<64-byte token>'
```

Same approach for `TRADELENS_CSRF_SECRET` if we go with HMAC-signed CSRF tokens; or use plain UUID4 with the double-submit pattern (simpler, no additional secret needed).

## Middleware

One global FastAPI middleware (`lib/tradelens/auth/middleware.py`):

```
Per-request flow:
  1. Skip auth for: /api/v1/auth/login, /api/v1/auth/refresh, /api/v1/health (basic),
                    static assets, OpenAPI doc paths
  2. Read tl_access cookie. If absent or invalid → 401.
  3. Validate signature, exp, jti not in revoked_token. → 401 if any fail.
  4. Attach to request.state.user = User(id, email, is_admin, account_ids)
  5. For mutating methods (POST/PUT/PATCH/DELETE): verify X-CSRF-Token header == tl_csrf cookie.
     → 403 if mismatch.
```

## Authorization dependencies

Two FastAPI deps (`lib/tradelens/auth/deps.py`):

```python
def get_current_user(request: Request) -> User:
    # Pulled from request.state.user; raises 401 if missing
    ...

def verify_account_access(
    account_name: str = Query(...),
    user: User = Depends(get_current_user),
) -> Account:
    account = resolve_account(account_name)
    if account.id not in user.account_ids:
        raise HTTPException(403, "account not owned by user")
    return account

def require_admin(user: User = Depends(get_current_user)) -> User:
    if not user.is_admin:
        raise HTTPException(403, "admin only")
    return user
```

### Where each dep applies

- `Depends(get_current_user)` — every endpoint not in the auth-skip list.
- `Depends(verify_account_access)` — every endpoint that takes `account_name`. Replaces today's bare `account_name: str = Query(...)`.
- `Depends(require_admin)` — admin-only endpoints (full list below).

The 177 endpoint sites that currently take `account_name` get a one-line dep change. Mechanical — could be a sub-agent task.

## Admin-only endpoint list (gated by `require_admin`)

Per user decision 2026-04-29 — system internals stay admin-only:

| Module | Endpoints | Notes |
|---|---|---|
| `api/system_monitor.py` | All | Whole module gated. |
| `api/health.py` | `/deep-health` only | `/health` (basic 200) stays public — preserves AUD-0266 split for load balancers. |
| Metrics endpoints (any `/metrics`) | All | |
| `api/discord_ingest.py` (admin config endpoints) | All except the extension-ingest path which uses `DISCORD_INGEST_API_KEY` | The extension's POST endpoint stays gated by the shared-secret API key; it's a pipeline boundary, not a user request. |
| Telegram signal-source admin endpoints | All | Same shape as Discord. |
| Services management (`bin/api`, `bin/dashboard` HTTP control surfaces if any) | All | |
| Account-management (Phase 2) | TBD | When users self-manage Bybit creds. |

A grep-and-decorate pass at implementation time will produce the exhaustive list. The pattern is: anything a regular trader doesn't need access to → admin-only.

## Bootstrap CLI

New script: `bin/setup/manage_users.py`. Subcommands:

```
manage_users.py create       <email> [--admin]    # interactive password prompt (getpass)
manage_users.py reset-pwd    <email>              # interactive password prompt
manage_users.py set-admin    <email> <true|false>
manage_users.py disable      <email>              # sets disabled_at = now()
manage_users.py reactivate   <email>              # sets disabled_at = NULL
manage_users.py grant        <email> <account_name>   # adds row to user_account
manage_users.py revoke       <email> <account_name>   # removes row from user_account
manage_users.py list                              # tabular: email, is_admin, accounts, disabled
```

Reads PG creds via `core.config.load_config()` — uses the same `${VAR}` expansion path AUD-0260 ships. Operator must source `sourceme.sh` first (same as `migrate_parser_inbox.py`).

This is the password-reset escape hatch in Phase 1: forgot password → ssh in → `manage_users.py reset-pwd you@example.com` → done.

## Bootstrap migration

One SQL migration plus a one-shot CLI invocation:

```sql
-- migration NNN_users_user_account.sql
CREATE TABLE users (...);
CREATE TABLE user_account (...);
CREATE TABLE revoked_token (...);
-- (indexes)
```

Then operator runs:
```bash
python3 bin/setup/manage_users.py create you@example.com --admin
# (prompts for password)
python3 bin/setup/manage_users.py grant you@example.com bybit_main
python3 bin/setup/manage_users.py grant you@example.com bybit_sub
python3 bin/setup/manage_users.py grant you@example.com bybit_demo
```

After this, you log in, you own all 3 Bybit accounts.

Could be automated by a `bin/setup/seed_initial_admin.py` that reads email from `$TRADELENS_ADMIN_EMAIL` and password from interactive prompt — open question, see "Open questions" below.

## Frontend changes

### New routes

| Route | Component | Auth |
|---|---|---|
| `/login` | `<Login />` | Public |
| All others | `<RequireAuth>{...}</RequireAuth>` | Authenticated |
| Admin routes (services, monitor, ingest config) | `<RequireAdmin>{...}</RequireAdmin>` | Admin |

### New modules

| File | Purpose |
|---|---|
| `frontend/web/src/pages/Login.tsx` | Login form (email + password + submit) |
| `frontend/web/src/auth/AuthContext.tsx` | React context: current user, login(), logout(), isAuthenticated, isAdmin |
| `frontend/web/src/auth/useAuth.ts` | Hook |
| `frontend/web/src/auth/RequireAuth.tsx` | Route wrapper — redirects to `/login` if not authenticated |
| `frontend/web/src/auth/RequireAdmin.tsx` | Route wrapper — redirects to `/` if authenticated but not admin |
| `frontend/web/src/lib/api.ts` (modified) | Axios interceptor: read `tl_csrf` cookie, send as `X-CSRF-Token` header on mutating requests; 401 handler → redirect to `/login` |

### Top-right user menu

Existing top-nav gets a user-menu in the right corner:
- Email displayed
- "Log out" button → calls `/api/v1/auth/logout`, clears in-memory auth state, redirects to `/login`

### Admin vs non-admin UI in Phase 1

Phase 1: only you exist, so this is largely defensive. The UI guards are `<RequireAdmin>` wrappers that hide nav items + protect routes. When a non-admin user hits an admin-only route directly via URL, they see the dashboard fallback.

### Silent refresh (C2)

Axios interceptor:
1. On 401 from any endpoint, attempt `POST /api/v1/auth/refresh`.
2. If refresh succeeds, retry the original request.
3. If refresh fails, redirect to `/login`.

Standard pattern; widely-used libraries handle this (e.g. axios + `axios-auth-refresh`).

## Testing strategy

| Test | Type | What it asserts |
|---|---|---|
| Login happy path | Integration | POST /auth/login with correct creds → 200 + cookies set |
| Login wrong password | Integration | 401, no cookies set |
| Login disabled user | Integration | 401, no cookies set |
| Authenticated request without cookie | Integration | 401 |
| Authenticated request with valid cookie | Integration | 200 |
| Account-access denied (other user's account) | Integration | 403 |
| Admin-only endpoint as non-admin | Integration | 403 |
| CSRF mismatch on POST | Integration | 403 |
| Logout invalidates token | Integration | Subsequent request with same cookie → 401 |
| Refresh issues new access token | Integration | New `tl_access` cookie set |
| Expired refresh token | Integration | Forces re-login |
| Bootstrap CLI: create + login round-trip | Integration | E2E |
| Sentinel test (`test_aud0112_parked_pending_aud0227_auth_epic`) replacement | Unit | Real binding-check regression test for `submit_trade` |
| Source-presence guards | Unit | Every endpoint that takes `account_name` has `Depends(verify_account_access)` |
| Source-presence guards | Unit | Every admin-only endpoint has `Depends(require_admin)` |

The two source-presence guards are critical — they're the regression mechanism that prevents new endpoints from forgetting to add the dep.

## Implementation sequence

Recommended commit cadence (each commit independently shippable, with own tests):

1. **Schema migration** — `users`, `user_account`, `revoked_token` tables. No code uses them yet. Tests: schema-shape assertions.
2. **Bootstrap CLI** — `manage_users.py` create/grant/list/reset-pwd/set-admin. Tests: CLI E2E against test DB.
3. **Auth backend** — `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/me`. JWT issuance + cookies. No middleware yet (so this commit doesn't break anything). Tests: each endpoint + cookie shape.
4. **Middleware (off by default)** — wire it in but as a no-op pass-through. Add a feature flag (env var `TRADELENS_REQUIRE_AUTH=true`). Tests: middleware unit tests.
5. **`Depends(verify_account_access)` migration** — sweep across the 177 endpoints. Mechanical. Tests: source-presence guard.
6. **Admin gating sweep** — apply `Depends(require_admin)` to the admin-only list. Tests: source-presence guard + per-endpoint integration test.
7. **Replace AUD-0112 sentinel** — sentinel test in `test_aud0111_0113_trades_cluster.py` becomes a real binding-check regression test.
8. **Frontend auth context + login page + axios interceptor** — visible auth flow. Tests: vitest where infra exists; manual smoke for the redirect flow.
9. **Flip the feature flag on** — `TRADELENS_REQUIRE_AUTH=true` in `~/.tradelens.secrets` on rocky-8gb. Smoke test all running services. This is the cutover.

This sequencing means: every commit before #9 is safe to ship and runs alongside the existing trust-the-query-param behavior. Commit #9 is the irrevocable flip; back-out plan is `unset TRADELENS_REQUIRE_AUTH` + redeploy. After ~24h of soak-time, remove the feature flag (commit #10).

## Risks / open questions

### Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Endpoint missed during the 177-site sweep → leaks data cross-account | Medium | Source-presence test + middleware as defence-in-depth |
| Rotation of `TRADELENS_JWT_SECRET` invalidates everyone's session | High | Acceptable — rare event. Document the impact. |
| Cookie/CSRF on browser extension | Low | Extension uses its own shared-secret API key, not user cookies — already separate |
| Phase 2 schema migration (per-user Bybit creds) breaks Phase 1 binding | Low | Phase 2 design should explicitly preserve `user_account` as the join table |
| Browser back-button after logout shows cached page | Medium | Standard SaaS issue. Mitigated by axios 401-redirect on next API call. Don't try to clear the back-button cache. |

### Open questions

All resolved 2026-04-29 — see the Decisions table at the top. No outstanding design questions.

## Cutover record (2026-04-29 commit #9)

The cutover is **two env-var settings + a conftest-defaults-tweak**:

  1. ``~/.tradelens.secrets`` on rocky-8gb + rocky2:
     ``export TRADELENS_REQUIRE_AUTH='true'``
  2. Restart api + dashboard from a sourced shell.
  3. ``tests/conftest.py`` force-overrides ``TRADELENS_REQUIRE_AUTH=false``
     for the test suite (otherwise 100+ existing integration tests that
     don't authenticate would 401-storm against the gate).

### Backout plan

If anything breaks in production:

```bash
# Edit ~/.tradelens.secrets and flip the flag:
sed -i "s/^export TRADELENS_REQUIRE_AUTH='true'$/export TRADELENS_REQUIRE_AUTH='false'/" \
    ~/.tradelens.secrets

# Re-source + restart:
source /app/syb/tradesuite/sourceme.sh
tl restart api
ssh rocky2 "source /app/syb/tradesuite/sourceme.sh && tl restart mdsync_pg"
```

After the flip back to ``false``, the middleware reverts to best-effort
mode (attaches request.state.user when valid cookie present, but doesn't
block anything). Frontend ``RequireAuth`` still gates routes — that
behaviour is independent of the backend flag (the FE always requires a
session). Operators expecting unauthenticated FE access would also need
to comment out ``<AuthProvider/>``'s /me bootstrap call, which is a
larger code change.

### Cutover smoke test on rocky-8gb (2026-04-29 19:58 UTC):

```
curl /api/v1/health                                  → 200 (skip-listed)
curl /api/v1/portfolio?account_name=bybit_main       → 401 (no auth)
curl /api/v1/system-monitor                          → 401 (admin endpoint, no auth)
curl /api/v1/auth/me                                 → 401 (no cookie)
curl POST /api/v1/discord-ingest (empty body)        → 422 (skip-listed,
                                                       extension API key
                                                       check separate)
test gate: 2614 passed, 4 skipped — green.
```

### What's now enforced

| Endpoint class | Pre-cutover | Post-cutover (this commit) |
|---|---|---|
| /api/v1/auth/{login,refresh,logout} | open | open (skip-listed) |
| /api/v1/health (basic) | open | open (skip-listed; AUD-0266 split preserved) |
| POST /api/v1/discord-ingest (extension) | gated by DISCORD_INGEST_API_KEY | unchanged — same shared-secret gate |
| GET /api/v1/auth/me | open (cookie-checked at endpoint) | 401 unauth, 200 authed |
| GET /api/v1/portfolio etc (43 account-scoped endpoints) | open | 401 unauth, 403 unowned account, 200 owned |
| GET/POST /api/v1/system-monitor, /services, /mdsync, /pool-stats, /cache-*, /vwap-engine-status, /discord-ingest/health, /discord-ingest/config (admin-only) | open | 401 unauth, 403 non-admin, 200 admin |
| All other authenticated endpoints | open | 401 unauth, 200 authed |
| Mutating requests (POST/PUT/PATCH/DELETE) | no CSRF | X-CSRF-Token must match tl_csrf cookie or 403 |

### Phase 2 entry point

Phase 2 is the FE Account-Management page (operators self-manage their
own Bybit credentials). The Phase-1 schema (``user_account`` join +
``users.is_admin`` flag) is the foundation; Phase 2 will add an
``accounts.owner_user_id`` (or similar) and migrate ``accounts.yml``
into encrypted-at-rest DB rows. Out of scope for this epic.

## What ships when

| Phase | What | Ship target |
|---|---|---|
| **Phase 1 — this design** | Users + auth + login UI + admin gating | 3-5 days |
| **Phase 2** | FE account-management page; users add their own Bybit creds; encrypted storage | After phase 1 soak (~weeks) |
| **Phase 3** | Self-signup, email verification, password reset via email | When SaaS launch is closer |
| **Phase 4** | Per-user rate-limit accounting, IP routing, billing, multi-tenant ops | Pre-SaaS launch |

## References

- AUDIT_TRACKER entry for AUD-0227: `docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` line 293
- AUD-0312 entry: same file, line 380
- Sentinel test: `tests/unit/test_aud0111_0113_trades_cluster.py:211`
- Today's foundational secrets work: `4223f4aa` (sourceme.sh + secrets file), `0dab9dee` (AUD-0260 expansion), `dede1709` (Phase A.5/6/7), `c1525493` (PG_PASSWORD removal)
- AUD-0266 (`/health` public/admin split): already shipped — keep the split intact
