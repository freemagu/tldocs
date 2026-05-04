# Checkpoint: AUD-0227 Phase 1 + Phase 2 fully shipped — encrypted Bybit creds + login UX live; 2.8 YAML deletion deferred for soak

**Saved:** 2026-04-29 20:45:05 UTC
**Working dir:** /app/syb/tradesuite/tradelens
**Git:** master @ 346e77b7
**Session:** a055b490-af04-4e69-86b6-6529c0d0ba86
**Active task:** none (last closed: 20260429-224236-aud0227-phase2-c10-cache-invalidation → 346e77b7)

## Handover Statement

You are picking up a tradelens session that just finished shipping the entirety of AUD-0227 Phase 1 (auth epic — login + cookie-based JWT + middleware + RequireAuth/RequireAdmin gating) and the entirety of AUD-0227 Phase 2 minus the final YAML-deletion commit (2.8). All 24 in-scope commits are on `origin/master` and the live api on rocky-8gb is running with `TRADELENS_REQUIRE_AUTH='true'` AND `TRADELENS_ACCOUNTS_FROM_DB='true'`. Bybit credentials for all 3 accounts (`bybit_main`, `bybit_sub`, `bybit_demo`) are now Fernet-encrypted at rest in the `accounts` table; `accounts.yml` is on disk but no longer read at runtime. The frontend has a `/login` page, a `/settings/accounts` page that lets the operator self-manage Bybit creds, and the topbar UserMenu (gear + logout). The Bybit binding (uid + parent_uid via `/v5/user/query-api`) is populated for all 3 accounts and shown in the FE row.

The single most important piece of state to know right now: **the user said "looks good" at 22:43 UTC after the cache-invalidation fix (`346e77b7`), then ran `/t-done`, then ran `/t-checkpoint`. They are NOT mid-task. The final follow-up they were satisfied with was the AccountContext cache invalidation that ensures /settings/accounts edits propagate to the dropdown without restarting api.** Do NOT re-open any of the shipped work to "improve" it.

What to Read FIRST, in order:
1. The "Decisions made" section of this checkpoint — it captures every Q1-Q10 decision for both Phase 1 and Phase 2 with the user's exact phrasing.
2. The "Files touched" section — there are ~30 files changed this session across backend (`lib/tradelens/auth/`, `lib/tradelens/api/accounts.py`, `lib/tradelens/api/auth.py`, `lib/tradelens/auth/middleware.py`, `lib/tradelens/core/account_context.py`, `bin/setup/manage_users.py`, `bin/setup/migrate_accounts_to_encrypted.py`, `bin/setup/populate_bybit_uids.py`, etc), frontend (`frontend/web/src/lib/auth-context.tsx`, `auth-api.ts`, `accounts-api.ts`, `pages/login.tsx`, `pages/settings-accounts.tsx`, `components/require-auth.tsx`, etc), and ops (`migrations/089-092`, `~/.tradelens.secrets` on both hosts, `bin/lib/autorestart.sh`).
3. The "Surprises / gotchas" section — at least four things bit us this session and the next session will hit them again if it doesn't know.

Known landmines to avoid:
- The `~/.tradelens.secrets` file holds plaintext-equivalent secrets. NEVER cat it back to the user; redact when referencing.
- The Bash tool runs non-interactive shells; `.bashrc`'s `[[ $- != *i* ]] && return` guard means `source ~/.bashrc` skips the body. Use `bash -lc` or explicit `source /app/syb/tradesuite/sourceme.sh && ...` chains.
- `tl`-launched services are nohup + PID-file (NOT systemd). PPID=1 only means orphaned/reparented; check `/proc/$PID/cgroup` to confirm. The autorestart wrapper now self-sources `sourceme.sh` so env-loss crash-loops can't recur (commit `92b3df06`).
- `BybitClient._request` strips the retCode envelope and returns `data["result"]` directly. Code that checks `response.get("retCode") != 0` post-call is broken (was a real bug we shipped + fixed today). Use `ExchangeError` (raised by `_request` on retCode != 0) as the success/failure signal.
- Migration numbering collides if two sessions create migrations in parallel — we hit this with 091 (mine vs another session's `091_rename_tbe_to_auto_trailing_be.sql`). Always grep first; the `IF NOT EXISTS` pattern in 092 is the resilient template.
- `forward-reference type strings in FastAPI route annotations` — `response_model=List["AccountInfo"]` fails at decoration time because pydantic can't resolve later-defined classes. Define classes BEFORE any `@router.X` decorator that references them.

What NOT to do:
- Do NOT ship 2.8 (YAML deletion) yet — the user explicitly wants it deferred until a 24h+ soak completes (per Q6 override). 2.8 deletes `accounts.yml`, `bin/setup/sync_accounts.py`, the YAML-reading code path, and the `accounts.yml` line in `.gitignore`. Irrevocable.
- Do NOT push to origin without user OK — they OK'd pushes during the session each time but the standing rule is to ask.
- Do NOT add the testnet account_type back — confirmed retired, "Bybit's testnet endpoint isn't reachable from this deployment".
- Do NOT add a "reveal API secret" button — Q8 invariant: never reveal `api_secret`. The api_key IS surfaced (it's not the cryptographic secret).

The exact next action the user is expecting: **none — they ran /t-done then /t-checkpoint to wind down.** When they come back, the menu they last saw was: A (ship 2.8 after soak), B (AUD-0353/0354 Phase B secret rotation runbook execution), C (Phase 3 design doc), D (AUD-0344 Suspicious-status verification), E (stop for the day). I told them E was the right call given the day's volume.

## User note

(none — `/t-checkpoint` invoked without a free-form note)

## Session context

### User's stated goal (verbatim where possible)

The session opened with the user asking "whats the status of the audit fixes" — pure status query. After I gave a full breakdown they pivoted to deeper questions: "is claude waiting for me to make decisions before he can complete everything?", "tell me about [AUD-0227]". From there: "ok whats next for the config flippling" → "yes" (proceed with auth-epic exploration) → "i would say I am actually planning possibly in the next six months have this this application trade lens would be software as a service so it will be multi users potentially hundreds of users" — that single message reframed everything from "small auth bolt-on" to "Phase 1 of a SaaS-ready epic". They said "OK so you accept all of your recommendations except for [Q6]" which kicked off Phase 1 implementation. After Phase 1 they said simply "start Phase 2" and accepted my recommendations again with the same Q6 override (delete accounts.yml at cutover instead of keeping as seed). Mid-Phase-2 the user provided three concrete UX corrections: (a) "I would like the API key and subaccount (if applicable) to be visible on both the overview and edit popup", (b) "Also test account no longer works on bybit so that can be removed entirely" → clarified to "I mean testnet" → "demo IS Valid, Testnet is not", (c) "I dont see the subaccount shown for bybit_sub" — leading to my offer to do A+B Bybit UID verification, accepted with "do both", (d) "i just changed bybit_sub subaccount label to flowsub1 but its not reflected on the account dropdown at the top of the screen, that still show flowsub12" — leading to the cache invalidation fix.

### User preferences and corrections established this session

1. **"I no longer want to discuss before editing/ I want you to run unattended with sensible gates"** (already in memory but exercised heavily this session — 24 commits without per-commit approval).
2. **Q6 override (Phase 2): delete `accounts.yml` at cutover, do NOT keep as seed.** Their words: "i want this file deleted once we have cutover". This forced 2.8 to be split as a separate post-soak commit with explicit irrevocability warning.
3. **Testnet account_type retired entirely.** Their words: "test account no longer works on bybit so that can be removed entirely" → "I mean testnet" → "demo IS Valid, Testnet is not". The `Literal["real", "demo"]` shape is now load-bearing across BE + FE.
4. **api_key is NOT to be hidden; only api_secret is.** They corrected my original Q8-derived "never reveal" stance after they saw the masked overview: "I would like the API key and subaccount (if applicable) to be visible on both the overview and edit popup". I justified this as: the api_key is the X-BAPI-API-KEY header value, not the HMAC secret — it travels in cleartext on every Bybit request anyway. Q8 invariant narrowed to: api_secret never returned, api_key returned + editable.
5. **Bybit UID verification was their idea.** After they entered "flowsub12" as a subaccount_ref label and noticed nothing rejected it: "but it does not complain. I see no way to verify if its connected ok to that account". I offered "Option A — query-api on validate" and "Option B — store + display uid" and they said "do both".
6. **Cache invalidation gap surfaced by user.** After option-A+B shipped, they immediately tested the dropdown and noticed staleness: "i just changed bybit_sub subaccount label to flowsub1 but its not reflected on the account dropdown at the top of the screen, that still show flowsub12". This led directly to the AccountContext.reload() fix in `346e77b7`.
7. **Today's standing autonomy contract:** after each design-doc / decisions table, user accepts the recommendations as a block ("all recs" or "i accept all of your recommendations except for [N]") and expects me to ship 7-9 commits sequentially with no per-commit confirmation. Tests passing + push to origin + smoke test on rocky-8gb after each commit is the contract; only deviation is to flag and ask.

### Working environment

- **rocky-8gb (rocky-8gb / `10.50.0.3`)**: api PID 1248604+, dashboard PID 1247857+, all 14 tl-managed services running, postgresql up. `TRADELENS_REQUIRE_AUTH='true'`, `TRADELENS_ACCOUNTS_FROM_DB='true'`. Living on `~/.tradelens.secrets` are: `TRADELENS_PG_PASSWORD`, `TRADELENS_JWT_SECRET`, `TRADELENS_ENCRYPTION_KEY`, `TRADELENS_DEFAULT_ACCOUNT='bybit_main'`, `TRADELENS_SIGNAL_ACCOUNT='bybit_main'`, `TRADELENS_COOKIE_SECURE='false'`, `BYBIT_MAIN_KEY` etc., `OPENAI_API_KEY`, `DISCORD_INGEST_API_KEY`, `WEB_PUSH_VAPID_PRIVATE_KEY`, `PUSHOVER_*`, `TELEGRAM_API_ID`/`HASH`, `DISCORD_TOKEN=''`. NEVER cat the secrets file back.
- **rocky2 (rocky2 / `10.50.0.2`)**: mdsync_pg only, restarted at session start to pick up env-driven secrets after Phase A/B. Currently on the same flag state as rocky-8gb. The 3 local config overrides per `memory/project_rocky2_mdsync_host.md` (database.host=10.50.0.3, postgresql.host=10.50.0.3, rate_limit_rps=20) are preserved in the working tree of `tradelens/etc/config.yml` (gitignored).
- **PostgreSQL** (port 5432 on rocky-8gb, accessed remotely from rocky2 via 10.50.0.3): `tradelens` (production) and `tradelens_test` (test DB) both on migrations 089, 090, 091_rename_tbe_to_auto_trailing_be (committed by another session as `8c5d1301`), 092. The `accounts` table has all 5 Phase-2 columns + the 2 new bybit_user_id/parent_uid columns populated for all 3 rows. The `users` table has 1 row (you, `guy_freeman@mac.com`, is_admin=TRUE, user_id=1). The `user_account` join has 3 rows binding user_id=1 to all 3 accounts.
- **Test environment**: `tests/conftest.py` force-overrides `TRADELENS_REQUIRE_AUTH='false'` and `TRADELENS_ACCOUNTS_FROM_DB='false'` so the suite runs against the YAML loader and best-effort middleware. Phase-2 DB-mode tests monkeypatch back to `true`.
- **Uncommitted state on rocky-8gb (`git status --short`)**: ` M lib/tradelens/api/open_orders.py` (NOT mine — must be a parallel session's WIP), `?? docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` (untracked, pre-existing all session). Do not stage either.

## Objective

The objective at session start was a status check on the broader audit campaign: 366 findings from a 2026-04-22 audit, 281 already Resolved entering today, 79 remaining of which only 2 actually need user judgment (AUD-0227 Auth and AUD-0218 resume_trade). The user identified AUD-0227 as the path forward because they're planning a SaaS launch in ~6 months and need real auth before then.

The scope explicitly approved across the day: (a) AUD-0227 Phase 1 — auth epic (users + login + middleware + dep rollout + cutover); (b) AUD-0227 Phase 2 — self-managed Bybit credentials with at-rest encryption; (c) follow-ups requested in the moment (api_key visibility, testnet removal, Bybit UID verification, AccountContext cache invalidation). Phase 3 (self-signup + email verification + password reset) and Phase 4 (per-user IP routing, billing, multi-tenant ops) are explicitly OUT of scope and deferred.

The success criteria was: every shipped commit individually passes the BE test gate (`scripts/check-tests.sh`) plus FE `tsc --noEmit` and `npm test`; live api on rocky-8gb stays healthy after each restart; user can log in via the FE and see their accounts. All criteria met.

## Narrative: how we got here

Session opened ~11:00 UTC with `whats the status of the audit fixes`. I read `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` and reported: 380 findings, 281 Resolved, 65 Confirmed, etc. User followed up with "is claude waiting for me to make decisions before he can complete everything?" which I answered with: 2 real product decisions blocking (AUD-0227 Auth model, AUD-0218 resume_trade), 2 operator-only executions (AUD-0353/0354 Phase B), 1 verification (AUD-0344). The rest is just scheduling.

User picked AUD-0227 to discuss. I gave a deep dive: "What the audit found", "Why fixing it really means one big issue", "5-step epic", "Decisions you'll need to make". User then dropped the SaaS-aspirational pivot: planning 6-month SaaS launch with potentially hundreds of users, wants login UX, says "tying the bybit accounts to my user would be the right approach because that will definitely be used going forward". This single message turned the work from a "single-user defensive bolt-on" into "Phase 1 of a real auth epic", and I produced a high-level design with options for tenancy, identity provider (build vs buy), auth shape, data isolation, feature gating, migration phases. User said "ok whats next" → "OK lets work on the design for that and also for the UX design can you give me the UX design options" → I gave A/B/C/D/D pattern → user picked "A1. B1.C2. D1. Email service — defer to phase 3 with a 'use the bootstrap-CLI to reset' workaround. Logo / brand — plain text fine for now. Color scheme - yes there is already a design theme so follow that".

I wrote the Phase 1 design doc (`2026-04-29-aud-0227-0312-auth-epic-design.md`, commit `48f5975a`), all 6 open questions answered + locked. User said "start the implementation now". I shipped the 9 Phase-1 commits in order: schema (`bfc1a927`), CLI + password helpers (`e3c67c50`), auth backend (`d5123034`), middleware + feature flag (`e7c3a5d8`), `verify_account_access` rollout (`67b46b7e` — 43 sites across 11 files via a Python sed-script-style bulk edit), `require_admin` sweep (`ab3bdaef`), AUD-0112 sentinel replacement (`71752b70`), frontend login + AuthProvider + axios CSRF/401 + RequireAuth (`959a9880`), cutover (`1861ed8c` — flipped `TRADELENS_REQUIRE_AUTH='true'` in `~/.tradelens.secrets`).

Mid-Phase-1 we hit a real production crash: after `tl restart api` from a stale ssh session, the autorestart wrapper inherited an empty env, uvicorn crashed at `tradelens.core.config.load_config` with `KeyError: TRADELENS_PG_PASSWORD not set`, and autorestart kept respawning. User pasted the log line. I traced it to the AUD-0260 raise-on-missing guard fronting an env-driven config.yml + a wrapper that didn't self-source the secrets. Fix shipped as `92b3df06`: `bin/lib/autorestart.sh` now self-sources `sourceme.sh` at the top before any logic. Defence-in-depth duplicate in `bin/server/run_api.sh`. This is now memorialised in `memory/reference_tl_service_launch.md`.

Also mid-Phase-1, the user asked me to script the curl-based login round-trip. I wrote `bin/test/test_auth_flow.sh` (commit `dda7c308`). First run failed — login OK 200, /me 401. I diagnosed: the api was setting Secure cookies (`TRADELENS_COOKIE_SECURE` defaults true) but curl over HTTP doesn't send Secure cookies on follow-up. Fix: added `TRADELENS_COOKIE_SECURE='false'` to `~/.tradelens.secrets` (production runs over plain HTTP locally, no TLS termination yet). User confirmed login round-trip green.

Phase 1 cutover (`1861ed8c`) flipped the flag and broke 100+ existing tests that didn't authenticate. I added a force-override to `tests/conftest.py`: `os.environ["TRADELENS_REQUIRE_AUTH"] = "false"`. 2614 passing post-fix. User then ran the full `bin/test/test_auth_flow.sh` end-to-end via the FE and confirmed "login works fine. ship #9 now" (already shipped at that point).

User said "we are good. start Phase 2". Same flow: I wrote the design doc (`d606028d`), gave 10 Q&A options, user said "i accept all of your recommendations except for [Q6]" with the YAML-deletion override. Phase 2 shipped as 7 commits in order: schema migration adding 5 columns to `accounts` (`a5d7506e`, migration 090), Fernet encryption module (`4fcafa26` — `lib/tradelens/auth/encryption.py`), one-shot YAML→encrypted DB migration script (`85d7ce9f` — `bin/setup/migrate_accounts_to_encrypted.py`, idempotent, ran cleanly on production), AccountContext refactor with `TRADELENS_ACCOUNTS_FROM_DB` flag (`c1c30ed1`), accounts CRUD API (`d2ee5d36` — POST/PATCH/DELETE/me, creator-only, Bybit-validated at create), FE settings page (`0010b3c0` — `frontend/web/src/pages/settings-accounts.tsx`, list + add + edit + delete modals, no api_secret reveal), cutover (`998747ed` — flipped the flag).

Then the four follow-ups in rapid succession driven by user's hands-on testing of the FE: (1) api_key visibility + testnet drop (`1eaa7fa3`), (2) Bybit query-api UID verification + bybit_user_id/parent_uid columns + populate-uids one-shot script + FE display (`75b64bf9` — uncovered the `BybitClient._request` retCode-stripping bug as a side-effect; fixed in same commit), (3) AccountContext cache invalidation after CRUD (`346e77b7` — last commit of the day).

Throughout, two persistent issues surfaced and required mitigation: (a) cross-session contention — at least three times another session committed mid-flight while I had files staged, sweeping my work into their commits with the wrong commit messages (the AUD-0176 / 092 migration cases); (b) Migration 091 number collision — I created `091_add_bybit_user_id...` while another session shipped `091_rename_tbe...` simultaneously. Resolution: rename mine to 092 + add `IF NOT EXISTS` for re-apply safety. Both DBs converged cleanly.

The day closed with the cache invalidation fix, user said "looks good. whats next?", I gave the A/B/C/D/E menu, user ran `/t-done` then `/t-checkpoint`. We are at a clean stop boundary.

## Work done so far

1. **Read AUDIT_TRACKER.md, mapped 79 remaining items into "blocked on user judgment" vs "blocked on operator action" vs "just scheduling"**, identified AUD-0227 as the prime candidate for Phase 1 work.
2. **Wrote `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-29-aud-0227-0312-auth-epic-design.md`** (commit `48f5975a`) with 6 Q&A decisions all locked.
3. **Migration 089** (`tradelens/migrations/089_add_users_user_account_revoked_token.sql`, commit `bfc1a927`) — added `users`, `user_account`, `revoked_token` tables. Live on tradelens + tradelens_test.
4. **Bootstrap CLI** at `tradelens/bin/setup/manage_users.py` (commit `e3c67c50`) with `create / reset-pwd / set-admin / disable / reactivate / grant / revoke / list` subcommands. argon2id password hashing in `tradelens/lib/tradelens/auth/password.py`.
5. **Auth backend** at `tradelens/lib/tradelens/api/auth.py` (commit `d5123034`) — POST `/api/v1/auth/login`, POST `/refresh`, POST `/logout`, GET `/me`. Cookie helpers in `tradelens/lib/tradelens/auth/cookies.py`. JWT helpers in `tradelens/lib/tradelens/auth/jwt.py`. Revocation helpers in `tradelens/lib/tradelens/auth/revocation.py`.
6. **AuthMiddleware** at `tradelens/lib/tradelens/auth/middleware.py` (commit `e7c3a5d8`) — feature-flagged via `TRADELENS_REQUIRE_AUTH`. Two skip-list types: `_SKIP_PREFIXES` (auth/login, auth/refresh, auth/logout, /docs, /redoc, /openapi.json, /favicon.ico) and `_SKIP_EXACT` (`/api/v1/health`, `/api/v1/discord-ingest`).
7. **Authz deps** at `tradelens/lib/tradelens/auth/deps.py` (commit `e7c3a5d8`) — `get_current_user`, `verify_account_access` (flag-aware: pass-through in best-effort mode), `require_admin` (flag-aware too).
8. **Hardened launch chain** (commit `92b3df06`) — `tradelens/bin/lib/autorestart.sh` and `tradelens/bin/server/run_api.sh` now self-source `/app/syb/tradesuite/sourceme.sh`. Discovered after a real prod crash-loop.
9. **`bin/test/test_auth_flow.sh`** (commit `dda7c308`) — interactive curl-based smoke covering login → /me → /refresh → /logout → /me-after-logout-401. Color-coded output. The auth-epic design doc gained a TRADELENS_COOKIE_SECURE operator note in this commit.
10. **`verify_account_access` rollout to 11 files / 43 occurrences** (commit `67b46b7e`) — bulk-converted `account_name: Optional[str] = Query(None, description="...")` to `Depends(verify_account_access)`. Done via a Python regex script in a single Bash invocation. Flag-aware so tests don't break.
11. **`require_admin` sweep** (commit `ab3bdaef`) — applied router-level `Depends(require_admin)` to `system_monitor.py`, `services.py`, `mdsync.py`. Per-route to `health.py` (NOT `/health`), `discord_ingest.py` (NOT POST /discord-ingest). Refined middleware skip-list to `_SKIP_EXACT` so sub-paths don't inherit skip.
12. **AUD-0112 sentinel replacement** (commit `71752b70`) — `tests/unit/test_aud0111_0113_trades_cluster.py:211` was previously a parked sentinel asserting `TradeSubmitRequest` had no `account_name` field. Replaced with `test_aud0112_submit_trade_binding_via_verify_account_access` that asserts the binding-check is wired through `verify_account_access`.
13. **Frontend auth scaffolding** (commit `959a9880`) — new files: `frontend/web/src/lib/auth-context.tsx` (AuthProvider + useAuth), `lib/auth-api.ts` (login/refresh/logout/me wrappers), `components/require-auth.tsx` (RequireAuth + RequireAdmin route wrappers), `pages/login.tsx`. Modified: `lib/api.ts` (withCredentials:true, CSRF interceptor, 401 → silent refresh → /login redirect), `app.tsx` (AuthProvider wraps tree, top-level routes split /login from chrome'd /*), `components/layout/topbar.tsx` (UserMenu with email + logout button), `components/layout/sidebar.tsx` (`adminOnly: true` flag on System nav item, filter excludes when `!user.is_admin`).
14. **Phase 1 cutover** (commit `1861ed8c`) — flipped `TRADELENS_REQUIRE_AUTH='true'` in `~/.tradelens.secrets` on rocky-8gb + rocky2. Added `os.environ["TRADELENS_REQUIRE_AUTH"] = "false"` force-override in `tests/conftest.py`. Updated design doc with cutover record + backout plan.
15. **Phase 2 design doc** (commit `d606028d`) — `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-29-aud-0227-phase2-design.md`. 10 Q&A decisions locked, with Q6 operator override (delete YAML at cutover, not keep as seed).
16. **Migration 090** (`tradelens/migrations/090_add_encrypted_credentials_to_accounts.sql`, commit `a5d7506e`) — added `api_key_encrypted`, `api_secret_encrypted`, `created_by_user_id`, `credentials_key_version`, `credentials_updated_at` to `accounts`. FK on `created_by_user_id` to `users(id)` ON DELETE SET NULL. Index on `created_by_user_id`. Updated `bin/setup/setup_database_pg.py` and `etc/schema.md` per the schema policy. Test in `tests/integration/test_aud0227_phase2_schema.py` (9 cases).
17. **Encryption module** at `tradelens/lib/tradelens/auth/encryption.py` (commit `4fcafa26`) — Fernet wrapper with `encrypt_secret`, `decrypt_secret`, `rotate_master_key(conn, new_key, old_key=None)`, `generate_key`. Master key from `$TRADELENS_ENCRYPTION_KEY` (added to `~/.tradelens.secrets`). `cryptography>=41.0.0` declared explicitly in `pyproject.toml`. Tests: `tests/unit/test_aud0227_phase2_encryption.py` (15 cases) + `tests/integration/test_aud0227_phase2_rotate_key.py` (6 cases).
18. **Migration script** at `tradelens/bin/setup/migrate_accounts_to_encrypted.py` (commit `85d7ce9f`) — idempotent YAML→encrypted DB migration. Ran cleanly on production: `bybit_main`, `bybit_sub`, `bybit_demo` all encrypted. Tests: `tests/integration/test_aud0227_phase2_migrate_script.py` (5 cases).
19. **AccountContext refactor** (commit `c1c30ed1`) — added `_load_accounts_from_db` method to `tradelens/lib/tradelens/core/account_context.py:101+`. Honours `TRADELENS_ACCOUNTS_FROM_DB` flag. Default + signal accounts come from `TRADELENS_DEFAULT_ACCOUNT` / `TRADELENS_SIGNAL_ACCOUNT` env vars (added to `~/.tradelens.secrets`). Tests: `tests/integration/test_aud0227_phase2_account_context_db.py` (7 cases).
20. **Accounts CRUD API** (commit `d2ee5d36`) — appended to `tradelens/lib/tradelens/api/accounts.py`: `AccountCreateRequest`, `AccountUpdateRequest`, `AccountInfo` Pydantic models, `_validate_bybit_credentials` helper, `GET /me`, `POST ""`, `PATCH /{id}`, `DELETE /{id}`. Tests: `tests/integration/test_aud0227_phase2_accounts_api.py` (12 cases).
21. **FE settings page** (commit `0010b3c0`) — `frontend/web/src/pages/settings-accounts.tsx`, `lib/accounts-api.ts`. Wired into `app.tsx` route + Topbar gear icon. Per Q8 no api_secret reveal.
22. **Phase 2 cutover** (commit `998747ed`) — flipped `TRADELENS_ACCOUNTS_FROM_DB='true'` in `~/.tradelens.secrets` on both hosts. Added `os.environ["TRADELENS_ACCOUNTS_FROM_DB"] = "false"` force-override in `tests/conftest.py`. accounts.yml stays on disk during the soak.
23. **api_key visibility + testnet drop** (commit `1eaa7fa3`) — added `api_key` field to AccountInfo response (decrypted at GET /me time + populated at POST/PATCH); pre-fill api_key + subaccount_ref in edit modal; show api_key in mono-font on overview row + subaccount badge; dropped testnet from `Literal["real", "demo"]`, validation regex `^(real|demo)$`, FE Select options, url_map.
24. **Bybit UID verification** (commit `75b64bf9`) — migration 092 added `bybit_user_id` + `bybit_parent_uid` VARCHAR(32) columns. `BybitClient.query_api_info()` wraps `/v5/user/query-api`. `_validate_bybit_credentials` now returns `{user_id, parent_uid, is_master, permissions}` dict. Create + PATCH (on rotation) populate the columns. /me selects + returns. FE row shows "Bybit UID: 29337834" with "[sub of 29337834]" badge for subaccounts. One-shot `bin/setup/populate_bybit_uids.py` populated all 3 existing accounts on production. **Bug uncovered + fixed**: `BybitClient._request` strips the retCode envelope — checks like `result.get("retCode") != 0` post-call were always-false on success. Fixed using `ExchangeError` (raised by `_request` on retCode != 0) as the success/failure signal.
25. **AccountContext cache invalidation after CRUD** (commit `346e77b7`) — `AccountContext.reload()` now honours `TRADELENS_ACCOUNTS_FROM_DB` flag. POST/PATCH/DELETE on /accounts each call `get_account_context().reload()` after the DB write. Triggered by user observation that `subaccount_ref` changes via FE didn't propagate to the dropdown.

## Decisions made (and why)

### Phase 1 (auth epic)

1. **Decision:** Multi-account-per-user model now, designed for full multi-tenant SaaS later.
   **Proposed by:** jointly — user said "potentially hundreds of users" + "tying the bybit accounts to my user", I framed it as "single-user-locked" vs "multi-account-per-user" vs "full multi-tenant", user took the middle path.
   **Rationale:** Today the operator is alone but explicitly aspires to SaaS; single-tenant would lock in the wrong shape; full multi-tenant SaaS adds rate-limit isolation, cost accounting, billing-prep work the operator doesn't need yet. Multi-account-per-user is single-tenant in shape but capable in schema.
   **Alternatives considered:** single-user-locked (rejected: blocks SaaS path); full multi-tenant (rejected: premature, drags in IP routing + billing + tenant isolation).
   **Revisit if:** SaaS launch slips beyond 12 months or pivots to single-operator-only.
   **Affects:** users + user_account schema; verify_account_access dep checks `account_id ∈ user.account_ids`; all 43 endpoints.

2. **Decision:** Roll our own auth (FastAPI + passlib + python-jose), not hosted.
   **Proposed by:** Claude.
   **Rationale:** At hundreds-of-users scale we're below the per-MAU cost crossover for hosted; FastAPI auth is well-trodden; the JWT-cookie shape is portable to hosted later if needed.
   **Alternatives considered:** Auth0/Clerk/Supabase (rejected: per-MAU cost, vendor lock); Cognito (rejected: AWS-vendor-specific).
   **Revisit if:** Operator decides to graduate to hosted at SaaS launch — JWT shape + cookie names + middleware skip-list are documented clearly enough to migrate.

3. **Decision:** A1 (email + password) + B1 (dedicated /login page) + C2 (silent refresh) + D1 (no remember-me checkbox).
   **Proposed by:** Claude offered options, user picked the recommended set.
   **Rationale:** A1 cheapest + most familiar; B1 standard SaaS pattern; C2 keeps trader logged in across the working day; D1 is simpler — refresh token always 30d.
   **Alternatives considered:** A2 magic-link (rejected: requires email infra in Phase 1, deferred to Phase 3); A3 hybrid (rejected: same); A4 username (rejected: SaaS users expect email); B2 modal (rejected: tradelens has no marketing landing); B3 inline-on-/ (rejected: ugly with chrome); C1 hard-expiry (rejected: kicks user mid-trade); C3 sliding (rejected: inconsistent UX); D2 checkbox (rejected: unnecessary complexity).
   **Revisit if:** Per-user defaults become important.
   **Affects:** Login.tsx, AuthProvider, axios silent-refresh interceptor.

4. **Decision:** Email service deferred to Phase 3; password reset via bootstrap CLI in Phase 1.
   **Proposed by:** Claude recommended, user accepted.
   **Rationale:** Email infra is heavy (SES/Mailgun/SMTP+templates); operator can ssh in and run `manage_users.py reset-pwd <email>` for now.
   **Affects:** No `/auth/forgot-password` endpoint; manage_users.py is the escape hatch.

5. **Decision:** TRADELENS_REQUIRE_AUTH=true cutover at commit #9.
   **Proposed by:** Claude (mirroring the Phase-1 design doc's explicit cutover commit pattern).
   **Rationale:** Off-by-default through commit #8 means tests stay green and the FE can land before the BE enforces; flipping is one env var.
   **Revisit if:** Production breakage on day 1 — backout is `unset; tl restart api` (no code revert).

### Phase 2 (encrypted credentials)

6. **Decision:** Q1 Fernet (AES-128-CBC + HMAC-SHA256) for at-rest encryption.
   **Proposed by:** Claude recommended, user accepted.
   **Rationale:** Stdlib-grade simplicity, well-vetted, version-tagged ciphertext, key rotation built-in via MultiFernet (we don't use that for now but the option is there).
   **Alternatives considered:** AES-256-GCM (rejected: lower-level API, no automatic version tag); age (rejected: file-format-oriented, asymmetric, overkill).
   **Revisit if:** Compliance audit demands GCM AEAD specifically.

7. **Decision:** Q2 master key in `$TRADELENS_ENCRYPTION_KEY` in `~/.tradelens.secrets`. Rotation bundled with AUD-0353/0354 Phase B.
   **Proposed by:** Claude.
   **Rationale:** Matches established pattern (JWT secret); single trust root; rotation = re-encrypt-all script (already shipped as `rotate_master_key()`).

8. **Decision:** Q3 add columns to `accounts` table (api_key_encrypted, api_secret_encrypted, created_by_user_id, credentials_key_version, credentials_updated_at).
   **Proposed by:** Claude.
   **Rationale:** Single cred per account at this scale, no rotation history needed; smaller schema diff than a separate table; simpler queries.
   **Alternatives considered:** Separate `account_credential` table with FK + history (rejected: overkill for current scale; can be added later if rotation history matters).

9. **Decision:** Q4 ownership via `accounts.created_by_user_id` only — no `user_account.role` enum yet. Sharing semantics deferred to Phase 4.
   **Affects:** PATCH/DELETE check `created_by_user_id == user.user_id`.

10. **Decision:** Q5 validate against Bybit `get_account_balance` (later expanded to also call `query_api_info`) before persist.
    **Rationale:** Fail-fast UX. One Bybit roundtrip is fine. Caught typo'd creds before write.

11. **Decision (USER OVERRIDE on Q6):** `accounts.yml` DELETED at cutover, NOT kept as seed.
    **Proposed by:** user, overrode Claude's recommendation (b).
    **Their words:** "i want this file deleted once we have cutover".
    **Rationale:** Single source of truth = DB. Cold-recovery path = DB backup + master key. Operator-decided 2026-04-29.
    **Affects:** Rollout sequence split — 2.7 = cutover (still reversible), 2.8 = YAML deletion (irrevocable, post-soak).
    **Revisit if:** Operator changes their mind during soak — easy, just don't ship 2.8.

12. **Decision:** Q7 one-shot `bin/setup/migrate_accounts_to_encrypted.py`, idempotent.
13. **Decision:** Q8 NEVER reveal `api_secret`. (Later narrowed: api_key IS surfaced; only api_secret is masked. User correction.)
14. **Decision:** Q9 validate against URL implied by account_type (real → api.bybit.com, demo → api-demo). (Later narrowed: testnet retired entirely.)
15. **Decision:** Q10 feature-flag cutover via `TRADELENS_ACCOUNTS_FROM_DB`. Mirrors Phase 1 #9 pattern.

### Mid-Phase-2 user-driven adjustments

16. **Decision:** Surface api_key in /accounts/me + POST + PATCH responses; mask api_secret forever.
    **Proposed by:** user — "I would like the API key and subaccount (if applicable) to be visible on both the overview and edit popup".
    **Rationale:** api_key is the X-BAPI-API-KEY header, not the cryptographic secret; travels in cleartext on every Bybit request; visible value lets operator sanity-check binding.
    **Affects:** AccountInfo model gains `api_key: Optional[str]`; /me decrypts on read.

17. **Decision:** Retire testnet account_type entirely.
    **Proposed by:** user — "test account no longer works on bybit so that can be removed entirely" → "I mean testnet" → "demo IS Valid, Testnet is not".
    **Rationale:** Bybit's testnet endpoint isn't reachable from this deployment.
    **Affects:** `Literal["real", "demo"]` in models/account.py; pattern `^(real|demo)$` in api/accounts.py request schemas; FE Select options drop "Testnet"; url_map drops the testnet branch. `is_testnet` property left in place returning always-False for backward compat with `model_dump_safe` consumers.

18. **Decision:** Bybit-side UID verification at create + rotation time (+ display in FE).
    **Proposed by:** user — "I see no way to verify if its connected ok to that account" → I offered Option A (call query-api on validate) + Option B (store + display uid) → "do both".
    **Rationale:** subaccount_ref is just a label; query-api gives the authoritative binding (userID + parentUid).
    **Affects:** migration 092; BybitClient.query_api_info; AccountInfo gains bybit_user_id + bybit_parent_uid; FE row shows "Bybit UID: X (sub of Y)".

19. **Decision:** Invalidate AccountContext cache after every CRUD on accounts.
    **Proposed by:** user — "i just changed bybit_sub subaccount label to flowsub1 but its not reflected on the account dropdown at the top of the screen".
    **Rationale:** AccountContext is process-singleton, in-memory cache survives DB writes. Without invalidation, dropdown is stale until api restart.
    **Affects:** AccountContext.reload() honours TRADELENS_ACCOUNTS_FROM_DB; POST/PATCH/DELETE call reload() in try/except.
    **Caveat documented:** Standalone daemons (mdsync_pg, alert-engine) hold their own AccountContext; they won't see changes until daemon restart. Fan-out invalidation deferred.

## Rejected approaches (and why)

1. **Approach:** Hosted auth provider (Auth0/Clerk/Supabase) for Phase 1.
   **Who proposed it:** Claude listed as option, user implicitly rejected by accepting "roll our own".
   **Why rejected:** Per-MAU cost at hundreds-of-users scale outweighs the operational savings; vendor lock-in concern.
   **Would we reconsider if:** SaaS launch hits >1000 MAU and password-reset / 2FA volume becomes a maintenance burden.

2. **Approach:** "Always-enforcing deps" (`verify_account_access` raises 401 if no user, regardless of feature flag) for the Phase 1 #5 rollout.
   **Who proposed it:** Claude considered both Option A (flag-aware) and Option B (always-enforcing).
   **Why rejected:** Adopting always-enforcing deps in 43 endpoints would have broken every existing test that didn't authenticate (multi-day fix). Flag-aware Option A let tests + FE behaviour stay unchanged through commit #8, with cutover (#9) flipping the flag for one-shot enforcement.
   **Would we reconsider if:** A future cleanup wave wants to remove the feature flag entirely after sufficient soak time.

3. **Approach:** Single AccountInfo response across all four endpoints with the same shape.
   **Who proposed it:** Claude originally — the AccountInfo model didn't include api_key (Q8 strict reading).
   **Why rejected:** User correctly pointed out "API key and subaccount (if applicable) to be visible". Q8's "never reveal" was about `api_secret` (the cryptographic secret), not `api_key` (the public-ish identifier). Adding api_key to AccountInfo doesn't violate Q8.
   **Would we reconsider if:** Compliance audit specifically requires api_key to be hidden.

4. **Approach:** Keep testnet as a valid account_type even though it doesn't currently work.
   **Who proposed it:** Claude initially kept it; user explicitly retired it.
   **Why rejected:** Bybit testnet endpoint isn't reachable from this deployment; demo covers all non-prod testing needs; keeping it is dead config.
   **Would we reconsider if:** Bybit changes the testnet endpoint or this deployment moves networks.

5. **Approach:** Store decrypted api_key + api_secret in AccountContext's in-memory cache (for performance).
   **Who proposed it:** Claude (already decided in commit 2.4).
   **Why rejected (for the api_secret return path):** Memory is the same trust boundary as the master key, so caching decrypted forms isn't a leak. But api_secret never flows to the FE — that decryption stays internal-only.
   **Would we reconsider if:** Performance profiling shows decrypt-on-read for /me is a bottleneck (it's not at 3 accounts).

6. **Approach:** Reveal api_secret with a click-to-reveal button.
   **Who proposed it:** Hypothetical Q8 option (b) in the design doc.
   **Why rejected:** Reveal is a leak vector; users can re-enter rather than read.
   **Would we reconsider if:** Operator-only "show secret for debugging" mode becomes important.

7. **Approach:** Push the Phase-1 commits before pulling on rocky2 (vs reset working tree and pull).
   **Who proposed it:** Claude considered both for the rocky2 propagation.
   **Why rejected:** rocky-8gb's local 4 unpushed commits included unrelated session-mate work; pushing first was simpler; user authorised.

8. **Approach:** Fix the cross-session migration 091 collision via revert + recommit.
   **Who proposed it:** Claude considered briefly.
   **Why rejected:** The other session's `091_rename_tbe...` commit was already on master; reverting it would have stomped their work. Renaming mine to 092 + adding `IF NOT EXISTS` was strictly better.

9. **Approach:** Have the dropdown source from /accounts/me (which queries DB directly) instead of fixing AccountContext cache.
   **Who proposed it:** Claude considered.
   **Why rejected:** Many other consumers of AccountContext beyond the dropdown (bybit_client cache; the 43 account-scoped endpoints) would still see stale data. Fixing the cache invalidation centrally was the right level.

## Files touched or about to touch

(Comprehensive list across all 24 commits. All committed unless marked otherwise.)

### Backend — auth package (new)
1. `lib/tradelens/auth/__init__.py` — re-exports password + encryption helpers. Status: edited-saved (`d51230340 → 4fcafa26`).
2. `lib/tradelens/auth/password.py` — argon2id wrapper. Status: edited-saved (`e3c67c50`).
3. `lib/tradelens/auth/jwt.py` — JWT issuance + verification. HS256, $TRADELENS_JWT_SECRET, ACCESS_TOKEN_TTL=1h, REFRESH_TOKEN_TTL=30d. Status: edited-saved (`d5123034`).
4. `lib/tradelens/auth/cookies.py` — set_access_cookie / set_refresh_cookie / set_csrf_cookie / clear_auth_cookies. Honours `$TRADELENS_COOKIE_SECURE`. Status: edited-saved (`d5123034 → e7c3a5d8`).
5. `lib/tradelens/auth/revocation.py` — revoke_jti / is_jti_revoked / purge_expired wrappers. Status: edited-saved (`d5123034`).
6. `lib/tradelens/auth/middleware.py` — AuthMiddleware. _SKIP_PREFIXES + _SKIP_EXACT split (commit `ab3bdaef` introduced _SKIP_EXACT to fix /discord-ingest sub-path inheritance). Status: edited-saved.
7. `lib/tradelens/auth/deps.py` — get_current_user + verify_account_access (flag-aware) + require_admin (flag-aware). Status: edited-saved.
8. `lib/tradelens/auth/encryption.py` — Fernet wrapper. encrypt_secret / decrypt_secret / rotate_master_key / generate_key. Status: edited-saved (`4fcafa26`).

### Backend — auth API
9. `lib/tradelens/api/auth.py` — login/refresh/logout/me endpoints. Status: edited-saved (`d5123034`).

### Backend — accounts API (Phase 2)
10. `lib/tradelens/api/accounts.py` — heavily extended over 5 commits (`d2ee5d36, 1eaa7fa3, 75b64bf9, 346e77b7`). Now contains: AccountCreateRequest, AccountUpdateRequest, AccountInfo (with api_key + bybit_user_id + bybit_parent_uid fields), `_validate_bybit_credentials` (returns dict with user_id/parent_uid/is_master/permissions), GET /accounts/me, POST /accounts (validates Bybit, encrypts, persists, calls AccountContext reload), PATCH /accounts/{id} (creator-only, refreshes Bybit binding on rotation, calls reload), DELETE /accounts/{id} (creator-only, soft-delete, calls reload). Status: edited-saved.

### Backend — adapter changes
11. `lib/tradelens/adapters/bybit_client.py` — added `query_api_info()` method wrapping `/v5/user/query-api`. Status: edited-saved (`75b64bf9`).

### Backend — core
12. `lib/tradelens/core/account_context.py` — `_load_accounts_from_db` method added (`c1c30ed1`); `reload()` updated to honour TRADELENS_ACCOUNTS_FROM_DB (`346e77b7`). Status: edited-saved.
13. `lib/tradelens/main.py` — wired in AuthMiddleware via `install(app)` after CORS. Auth router included at index 1 after health. Status: edited-saved.
14. `lib/tradelens/models/account.py` — `Literal["real", "demo"]` (testnet retired); `is_testnet` left in place returning always-False. Status: edited-saved (`1eaa7fa3`).

### Backend — admin gating sweep
15. Various `lib/tradelens/api/*.py` — 11 files gained `Depends(verify_account_access)` for the 43 account_name endpoints (`67b46b7e`); 5 files gained admin gating (`ab3bdaef` — system_monitor.py / services.py / mdsync.py at router level; health.py / discord_ingest.py per-route). Status: edited-saved.

### Backend — bin/setup
16. `bin/setup/manage_users.py` — bootstrap CLI. Status: edited-saved (`e3c67c50`).
17. `bin/setup/migrate_accounts_to_encrypted.py` — idempotent YAML→DB migration. Status: edited-saved (`85d7ce9f`). Ran cleanly on production.
18. `bin/setup/populate_bybit_uids.py` — one-shot UID populate for legacy rows. Status: edited-saved (`75b64bf9`). Ran cleanly on production: `bybit_main` 29337834 (master), `bybit_sub` 54472084 (sub of 29337834), `bybit_demo` 524268079.
19. `bin/setup/setup_database_pg.py` — kept in sync with migrations 089, 090, 092. Status: edited-saved.
20. `bin/lib/autorestart.sh` + `bin/server/run_api.sh` — self-source sourceme.sh (`92b3df06`). Status: edited-saved.
21. `bin/test/test_auth_flow.sh` — interactive smoke. Status: edited-saved (`dda7c308`).

### Migrations
22. `migrations/089_add_users_user_account_revoked_token.sql` — Phase 1 schema. Applied to both DBs.
23. `migrations/090_add_encrypted_credentials_to_accounts.sql` — Phase 2 column additions. Applied.
24. `migrations/092_add_bybit_user_id_to_accounts.sql` — UID columns, IF NOT EXISTS for re-apply safety. Applied.

### Frontend
25. `frontend/web/src/lib/api.ts` — withCredentials:true, CSRF interceptor (reads tl_csrf cookie, sends X-CSRF-Token header on mutations), 401 → silent refresh once → /login redirect. Status: edited-saved.
26. `frontend/web/src/lib/auth-api.ts` — login/refresh/logout/me wrappers. Status: edited-saved.
27. `frontend/web/src/lib/auth-context.tsx` — AuthProvider + useAuth. /me on mount; login/logout mutate state. Status: edited-saved.
28. `frontend/web/src/lib/accounts-api.ts` — accountsApi (listMine/create/update/delete). Status: edited-saved.
29. `frontend/web/src/components/require-auth.tsx` — RequireAuth + RequireAdmin route wrappers. Status: edited-saved.
30. `frontend/web/src/pages/login.tsx` — login form. Status: edited-saved.
31. `frontend/web/src/pages/settings-accounts.tsx` — list + add modal + edit modal + delete modal; api_key visibility; Bybit UID display. Status: edited-saved.
32. `frontend/web/src/app.tsx` — AuthProvider wraps tree; top-level routes split /login from /* AppShell; Settings route added. Status: edited-saved.
33. `frontend/web/src/components/layout/topbar.tsx` — UserMenu (email + Settings gear icon + Logout). Status: edited-saved.
34. `frontend/web/src/components/layout/sidebar.tsx` — adminOnly flag on System nav item; filter excludes when !user.is_admin. Status: edited-saved.

### Tests
35. `tests/conftest.py` — _TEST_ENV_DEFAULTS for 9 secret env vars; TRADELENS_REQUIRE_AUTH force-override; TRADELENS_ACCOUNTS_FROM_DB force-override. Status: edited-saved.
36. `tests/integration/test_aud0227_phase1_schema.py` — schema regression for 089. Status: edited-saved.
37. `tests/integration/test_aud0227_auth_endpoints.py` — login/me/refresh/logout integration. Status: edited-saved.
38. `tests/integration/test_aud0227_middleware.py` — middleware best-effort + enforce mode. Status: edited-saved.
39. `tests/integration/test_aud0227_verify_account_access.py` — dep enforcement tests. Status: edited-saved.
40. `tests/integration/test_aud0227_require_admin.py` — admin gating tests. Status: edited-saved.
41. `tests/integration/test_aud0227_manage_users_cli.py` — CLI integration. Status: edited-saved.
42. `tests/integration/test_aud0227_phase2_schema.py` — schema regression for 090. Status: edited-saved.
43. `tests/integration/test_aud0227_phase2_rotate_key.py` — rotation integration. Status: edited-saved.
44. `tests/integration/test_aud0227_phase2_migrate_script.py` — migrate-script tests. Status: edited-saved.
45. `tests/integration/test_aud0227_phase2_account_context_db.py` — DB-mode AccountContext tests. Status: edited-saved.
46. `tests/integration/test_aud0227_phase2_accounts_api.py` — accounts CRUD tests with stub_bybit_ok / stub_bybit_reject fixtures. Status: edited-saved.
47. `tests/unit/test_aud0227_password_hashing.py` — argon2 unit tests. Status: edited-saved.
48. `tests/unit/test_aud0227_jwt.py` — JWT unit tests. Status: edited-saved.
49. `tests/unit/test_aud0227_phase2_encryption.py` — Fernet unit tests. Status: edited-saved.
50. `tests/unit/test_aud0111_0113_trades_cluster.py:211` — sentinel replaced. Status: edited-saved.
51. `frontend/web/src/__tests__/aud0227-auth-frontend.test.tsx` — vitest for AuthProvider + RequireAuth + RequireAdmin. Status: edited-saved.

### Docs
52. `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-29-aud-0227-0312-auth-epic-design.md` — Phase 1 design + cutover record + backout plan + what's-now-enforced table.
53. `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-29-aud-0227-phase2-design.md` — Phase 2 design + cutover record + 2.8 deferred note.

### Memory
54. `~/.claude/projects/-app-syb-tradesuite/memory/reference_tl_service_launch.md` — `tl` services are nohup + PID-file (NOT systemd); env inherited from launching shell at `tl start` time. Created mid-session after the env-loss crash-loop diagnosis.

### Operator state (NOT in git)
55. `~/.tradelens.secrets` on rocky-8gb + rocky2 — 9 new env vars added across the day: TRADELENS_PG_PASSWORD, TRADELENS_JWT_SECRET, TRADELENS_ENCRYPTION_KEY, TRADELENS_COOKIE_SECURE, TRADELENS_DEFAULT_ACCOUNT, TRADELENS_SIGNAL_ACCOUNT, TRADELENS_REQUIRE_AUTH, TRADELENS_ACCOUNTS_FROM_DB, plus pre-existing BYBIT_*, OPENAI_API_KEY, etc. Mirrored across hosts via scp.

### Files NOT mine but in working tree
56. `lib/tradelens/api/open_orders.py` — modified by another session (not in any commit yet). Do NOT touch.
57. `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md` — untracked all session, pre-existing. Do not stage.

## Open threads

1. **Thread:** AUD-0227 Phase 2 commit 2.8 — delete accounts.yml + sync_accounts.py + YAML-reading code path. **State:** deferred, pending 24h+ soak. **Context needed to resume:** `2026-04-29-aud-0227-phase2-design.md` step 2.8 description; verify nothing's drifted in `tradelens` DB during soak; ensure `accounts.yml` content is identical to what migration script saw. **Expected resolution:** when user gives the word, delete the 3 files + the YAML branch in `account_context.py:_load_accounts`. Single commit, irrevocable.

2. **Thread:** AUD-0353/0354 Phase B — physical key rotation runbook execution. **State:** runbook ready at `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-aud-0353-0354-security-runbook.md`. Operator-only. Now bundled with TRADELENS_JWT_SECRET + TRADELENS_ENCRYPTION_KEY rotation as a follow-on (rotate_master_key() ready). **Context needed:** runbook §B.1; the Phase B steps for Bybit / PG / Discord-ingest / VAPID / Pushover. **Expected resolution:** operator runs through the runbook, rotates each credential family, including the two new Phase 1+2 secrets.

3. **Thread:** AUD-0344 Suspicious-status verification. **State:** flagged in tracker, not yet investigated. Symbol/date concatenated into file path AND DuckDB SQL in `breach_analysis/...`. ~30 min investigation. **Context needed:** path the user provided in the menu (option D).

4. **Thread:** Phase 3 design (self-signup + email verification + password reset). **State:** design doc not started. ~30 min. **Context needed:** Phase 1 design doc as template; Phase 3 entry-point notes at the bottom of the Phase 1 doc.

5. **Thread:** Daemons holding their own AccountContext aren't cache-invalidated. **State:** documented as caveat in the cache-invalidation commit (`346e77b7`). Pub/sub or PG NOTIFY out of scope. **Expected resolution:** if the user notices a daemon showing stale subaccount_ref, `tl restart <daemon>` is the manual fix.

6. **Thread:** `lib/tradelens/api/open_orders.py` is modified in working tree but not by this session. **State:** another session's WIP. Do not touch. **Expected resolution:** the other session commits or reverts it.

7. **Thread:** `accounts.yml` has commented-out subaccount_ref examples for `bybit_sub` (`flowsub1`). User typed `flowsub12` initially, then `flowsub1`. The DB now has `flowsub1`. accounts.yml on disk is unchanged (still has the comment).

## Surprises / gotchas

1. **Finding:** `BybitClient._request` strips the retCode envelope and returns `data["result"]` directly. Code that checks `response.get("retCode") != 0` after a successful call is always-false on success (the wrapper IS gone). 
   **How we discovered it:** Live POST /accounts returned 400 with `retCode=None` repeatedly during integration tests for the original validator. Stack trace pointed to `_validate_bybit_credentials`'s post-call check.
   **Time cost:** ~15 min chasing through the test failures before reading bybit_client._request line 484: `return data.get("result", {})`.
   **Implication:** Always trust ExchangeError as the success/failure signal — `_request` raises on retCode != 0, so the absence of an exception means success.
   **Where it's documented:** Comments in `lib/tradelens/api/accounts.py:_validate_bybit_credentials` explaining the contract.

2. **Finding:** The Bash tool runs non-interactive shells, so `.bashrc` body is skipped (the `[[ $- != *i* ]] && return` guard). `source ~/.bashrc` from the Bash tool is a no-op for env-var loading. Have to use `bash -lc` for login-shell behaviour OR explicit `source /app/syb/tradesuite/sourceme.sh && ...` chains.
   **How we discovered it:** When verifying TELEGRAM_API_ID/HASH had moved to .tradelens.secrets, my `bash -lc 'echo $OPENAI_API_KEY'` test on rocky2 returned len=0 even though the user could log in interactively and see the value. After tracing to `[[ $- != *i* ]] && return` in rocky2's `.bashrc`, used `bash -ic` (interactive flag) to confirm.
   **Time cost:** ~10 min.
   **Implication:** Always test env-var behaviour with `-i` flag or interactive ssh, not Bash tool invocations.

3. **Finding:** `tl`-managed services are nohup + PID file (NOT systemd). PPID=1 only means orphan/reparented; the cgroup is `session-NNNN.scope` (login session) for nohup, not `system.slice/<unit>.service`.
   **How we discovered it:** I claimed mdsync_pg "runs under systemd" based on PPID=1 in pstree output. User pushed back: "i asked another claude session about mdsync and systemd: and he said it does not use systemd, its a plain nohip with PID-file wrapper". Verified via `cat /proc/$PID/cgroup` showing `session-3360.scope`. User was right.
   **Time cost:** ~5 min plus public-correction cost.
   **Implication:** Memorialised in `memory/reference_tl_service_launch.md`. Don't claim systemd without checking cgroup.

4. **Finding:** `nohup`-launched services inherit env from launching shell at `tl start` time. If that shell didn't have `TRADELENS_PG_PASSWORD` set (e.g. operator restarted from a stale session), the autorestart wrapper inherits the empty env and uvicorn crash-loops at `load_config()` due to AUD-0260's raise-on-missing.
   **How we discovered it:** User pasted "[2026-04-29 19:12:08] [autorestart:api] Process crashed (exit code 1, ran 1s). Restart #3 in 20s..." Live log showed `KeyError: "Environment variable 'TRADELENS_PG_PASSWORD' not set"`.
   **Time cost:** ~15 min including writing the fix in `bin/lib/autorestart.sh` + `bin/server/run_api.sh` to self-source `sourceme.sh`.
   **Implication:** Defensive self-sourcing in autorestart.sh + run_api.sh. env -i smoke test confirms the fix works against a fully clean environment.

5. **Finding:** Cookies with `Secure=True` are NOT sent over HTTP by curl OR browsers. The first `bin/test/test_auth_flow.sh` run failed: login OK 200, /me 401, because the api was setting Secure cookies and curl on plain HTTP refused to send them on the follow-up GET.
   **How we discovered it:** Log analysis after the test_auth_flow failure.
   **Time cost:** ~5 min.
   **Implication:** `TRADELENS_COOKIE_SECURE='false'` added to `~/.tradelens.secrets` for plain-HTTP local-dev. Documented in design doc.

6. **Finding:** FastAPI route `response_model=List["AccountInfo"]` (forward-ref string) fails at decoration time because pydantic can't resolve later-defined classes. PydanticUserError "is not fully defined".
   **How we discovered it:** Live test failure on `/accounts/me` after I'd appended new endpoints below the AccountInfo class definition. PydanticUserError: `TypeAdapter[typing.Annotated[typing.List[ForwardRef('AccountInfo')], ...]]` is not fully defined`.
   **Time cost:** ~10 min.
   **Implication:** Define request/response Pydantic models BEFORE any `@router.X` decorator that references them, or use full type imports.

7. **Finding:** Cross-session contention — at least 3 times another session committed mid-flight while I had files staged, sweeping my work into their commits with their commit message. Specifically: AUD-0176 OrderClassifier commit swept my `sourceme.sh` edit (post-mortem in `memory/...decisions-pending.md`); AUD-0381 ship landed `091_rename_tbe...` while I was creating `091_add_bybit_user_id...`.
   **How we discovered it:** `git status` post-commit didn't match the staged diff; later `git log` showed unrelated work bundled with mine.
   **Implication:** Always verify commit content via `git show <SHA> --stat` post-commit. Renaming migration to 092 + IF NOT EXISTS pattern was the resilient fix.

## Commands that mattered

1. **Command:** ```python3 bin/setup/migrate_accounts_to_encrypted.py```
   **Output (relevant portion):**
   ```
   Owner: user_id=1 email=guy_freeman@mac.com
   Found 3 account(s) in accounts.yml
     + migrated 'bybit_main' (account_id=1)
     + migrated 'bybit_sub'  (account_id=2)
     + migrated 'bybit_demo' (account_id=3)
   Summary: migrated=3, skipped=0, not_in_db=0
   ```
   **What we inferred:** Phase 2 migration succeeded on production; all 3 accounts encrypted in DB; ready for cutover.

2. **Command:** ```bash -c "source /app/syb/tradesuite/sourceme.sh && python3 -c 'from tradelens.auth.encryption import decrypt_secret; ...'"```
   **Output:**
   ```
   bybit_main  key_len=18  v=1  owner=1
   bybit_sub   key_len=18  v=1  owner=1
   bybit_demo  key_len=18  v=1  owner=1
   ```
   **What we inferred:** Round-trip decrypt confirmed; api_key length 18 matches the original Bybit key shapes.

3. **Command:** ```python3 bin/setup/populate_bybit_uids.py```
   **Output:**
   ```
   + set 'bybit_main' bybit_user_id=29337834 (master)
   + set 'bybit_sub' bybit_user_id=54472084 sub_of=29337834
   + set 'bybit_demo' bybit_user_id=524268079 (master)
   Summary: succeeded=3, failed=0
   ```
   **What we inferred:** Bybit binding confirmed: bybit_sub IS actually a subaccount of bybit_main (parent_uid=29337834 matches bybit_main's user_id). The verification system works as designed.

4. **Command:** ```/app/syb/tradesuite/scripts/check-tests.sh```
   **Output (final at session end):**
   ```
   2673 passed, 4 skipped, 13 warnings in 110.98s
   ✅ check-tests: all green
   ```
   **What we inferred:** Full BE suite green at session end. Started at 2149 this morning.

5. **Command:** ```cd /app/syb/tradesuite/tradelens/frontend/web && npm test```
   **Output:** `193 passed`. Started at 186 this morning. New tests in `__tests__/aud0227-auth-frontend.test.tsx` (7 cases).

6. **Command:** ```env -i HOME=/app/syb /app/syb/tradesuite/tradelens/bin/lib/autorestart.sh --name self-test -- env | grep TRADELENS```
   **Output:** All TRADELENS_* env vars present despite starting with `env -i`.
   **What we inferred:** autorestart.sh self-sourcing fix verified end-to-end.

## Schema / API / data facts worth preserving

- **`BybitClient._request` returns `data["result"]` directly** (strips retCode envelope on success; raises ExchangeError on retCode != 0). Evidence: `lib/tradelens/adapters/bybit_client.py:484`. Why it matters: any caller checking `response.get("retCode") != 0` post-call is broken.
- **Bybit's `/v5/user/query-api` response shape** (returned by `query_api_info()`, unwrapped to result dict): `{userID, parentUid, isMaster, permissions, apiKey, note, ips, deadlineDay, expiredAt, ...}`. parentUid="0" means master account; non-zero means subaccount. Evidence: live response captured in populate_bybit_uids.py output.
- **Bybit subaccount confirmation:** `bybit_main` userID=29337834 (master, parentUid="0", isMaster=True); `bybit_sub` userID=54472084 (subaccount of 29337834, isMaster=False); `bybit_demo` userID=524268079 (separate demo, parentUid="0", isMaster=False — demo subs sometimes report parentUid="0" instead of the master's uid).
- **`accounts` table columns post-Phase-2:** account_id (int IDENTITY PK), name (varchar 64 UNIQUE), exchange (varchar 16), account_type (varchar 16, real|demo), subaccount_ref (varchar 128 NULL), is_active (bool NOT NULL), created_at + updated_at (timestamptz NOT NULL), api_key_encrypted (text NULL), api_secret_encrypted (text NULL), created_by_user_id (bigint NULL FK to users.id), credentials_key_version (int NOT NULL DEFAULT 1), credentials_updated_at (timestamptz NULL), bybit_user_id (varchar 32 NULL), bybit_parent_uid (varchar 32 NULL).
- **Cookie names:** `tl_access` (HttpOnly+Secure+SameSite=Lax, path=/), `tl_refresh` (HttpOnly+Secure+SameSite=Strict, path=/api/v1/auth/refresh), `tl_csrf` (NOT HttpOnly, Secure+SameSite=Lax, path=/, session-cookie no max-age).
- **Skip-list paths in middleware:** `_SKIP_PREFIXES` = `/api/v1/auth/login`, `/api/v1/auth/refresh`, `/api/v1/auth/logout`, `/docs`, `/redoc`, `/openapi.json`, `/favicon.ico`. `_SKIP_EXACT` = `/api/v1/health`, `/api/v1/discord-ingest` (exact-match prevents sub-paths from inheriting skip).
- **Migrations 089+090+091+092 applied on tradelens + tradelens_test.** 091 is `091_rename_tbe_to_auto_trailing_be.sql` (committed by another session, NOT mine).

## Next steps

1. (when the operator chooses) **Ship 2.8 — accounts.yml deletion.** Read `2026-04-29-aud-0227-phase2-design.md` step 2.8 for the exact sequence: rm accounts.yml on rocky-8gb + rocky2; remove `tradelens/etc/accounts.yml` from `.gitignore`; delete `bin/setup/sync_accounts.py`; remove the `_load_accounts()` (YAML path) from `account_context.py:101+` and the branch in `__init__` that selects it; update `accounts.yml.example` (or delete). Single commit. Verify via `tl restart api` that everything still works in DB-mode (which is now the only mode).
2. (when ready) **AUD-0353/0354 Phase B execution.** See runbook at `docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-aud-0353-0354-security-runbook.md` §B.1. Now bundle the rotation of `TRADELENS_JWT_SECRET` and `TRADELENS_ENCRYPTION_KEY`; for the latter, run `from tradelens.auth.encryption import rotate_master_key` against the live DB. Operator-only.
3. (optional) **Phase 3 design doc** — self-signup + email verification + password reset. Use Phase 1 design doc as template. Mainly: pick email service (SES/Mailgun/SMTP), design verification token flow, password-reset token shape. ~30 min.
4. (optional) **AUD-0344 verification** — investigate `breach_analysis/...` symbol/date concatenation. Read the file, see if symbol is operator-controlled or external; classify Resolved or open as a real fix.
5. **Don't touch `lib/tradelens/api/open_orders.py`** (modified in working tree by another session) — leave it alone.
6. **Don't touch `tradelens/docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md`** (untracked, pre-existing).

## Verification checklist for the next session

- [ ] git HEAD is still `346e77b7` on master (run: `cd /app/syb/tradesuite && git rev-parse --short HEAD`). If different, somebody committed in the meantime — check.
- [ ] `tradelens/etc/accounts.yml` still exists on disk (this is the soak state; 2.8 removes it). `ls /app/syb/tradesuite/tradelens/etc/accounts.yml`.
- [ ] api process env still has `TRADELENS_REQUIRE_AUTH=true` and `TRADELENS_ACCOUNTS_FROM_DB=true`. Run: `for pid in $(pgrep -f 'uvicorn.*tradelens'); do cat /proc/$pid/environ | tr '\0' '\n' | grep TRADELENS_REQUIRE_AUTH; done`.
- [ ] `accounts` table has all 3 rows with `api_key_encrypted IS NOT NULL` and `bybit_user_id IS NOT NULL`. `psql -h 127.0.0.1 -U tradelens -d tradelens -c "SELECT name, account_type, is_active, bybit_user_id, bybit_parent_uid FROM accounts ORDER BY account_id;"`.
- [ ] `users` table has user_id=1 (`guy_freeman@mac.com`, is_admin=TRUE) and user_account binds them to all 3 accounts.
- [ ] `~/.tradelens.secrets` on rocky-8gb has all 9 TRADELENS_* env vars + the BYBIT_*_KEY/SECRET pairs. `grep -c '^export' ~/.tradelens.secrets` should be ~14+.
- [ ] No active claude-task. `claude-task has-active && echo "WARN: task still active" || echo "OK"`.
- [ ] `lib/tradelens/api/open_orders.py` is still modified-uncommitted (another session's WIP). `git status --short | grep open_orders`. If it disappeared, the other session committed; if it's gone different, leave it.
- [ ] Test gate green: `/app/syb/tradesuite/scripts/check-tests.sh` should report `2673 passed, 4 skipped`.
