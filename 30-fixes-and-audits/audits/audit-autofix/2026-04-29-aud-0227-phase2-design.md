---
status: phase-2-cutover-shipped (TRADELENS_ACCOUNTS_FROM_DB=true since 2026-04-29; YAML deletion 2.8 pending soak)
generated: 2026-04-29
decisions-locked: 2026-04-29
phase-2-cutover: 2026-04-29
phase-2-commits:
  - a5d7506e (2.1 schema migration)
  - 4fcafa26 (2.2 encryption module)
  - 85d7ce9f (2.3 migrate accounts.yml → encrypted DB rows)
  - c1c30ed1 (2.4 AccountContext reads encrypted creds from DB)
  - d2ee5d36 (2.5 accounts CRUD API endpoints)
  - 0010b3c0 (2.6 FE settings page)
  - <THIS COMMIT> (2.7 cutover — TRADELENS_ACCOUNTS_FROM_DB=true + conftest test default)
  - <PENDING>     (2.8 YAML deletion — operator-gated post-soak)
phase: 2 — self-managed Bybit credentials + FE accounts page
prerequisites:
  - Phase 1 complete (commit 1861ed8c) — auth + user_account binding + admin gating
related-audits:
  - AUD-0227 follow-up (per-user credential ownership)
  - Touches accounts.yml (currently gitignored, holds Bybit api_key/secret)
estimated-effort: 5-8 days
---

# AUD-0227 Phase 2 Design — Self-Managed Bybit Credentials

## Goal

Move Bybit credentials from `accounts.yml` (one operator-managed file)
into encrypted-at-rest DB rows owned per-user. Operators self-manage
their own accounts via a new FE settings page.

Today: `accounts.yml` holds api_key/api_secret in plaintext for 3
accounts (bybit_main / bybit_sub / bybit_demo). AccountContext loads
the YAML at process start. Every Bybit-touching service reads creds
through AccountContext.

After Phase 2:
  * Credentials live in `accounts.api_key_encrypted` /
    `api_secret_encrypted` columns. Encrypted at rest with Fernet
    (AES-128-CBC + HMAC-SHA256) using a master key from
    `$TRADELENS_ENCRYPTION_KEY` in `~/.tradelens.secrets`.
  * `accounts.yml` becomes seed-only (operator first-boot bootstrap);
    after migration, the DB is authoritative.
  * Users add/edit/delete their own accounts via `/settings/accounts`
    in the FE. Form validates creds against Bybit before persist.

## Non-goals (deferred to Phase 3 / 4)

- Multi-user-per-account sharing roles (owner / trader / viewer)
- Tier 4: per-user Bybit IP routing / rate-limit isolation
- Self-signup / email verification / password reset (Phase 3)
- Audit log of credential edits

## Decisions (locked 2026-04-29)

| # | Decision |
|---|---|
| **Q1 Encryption algorithm** | **Fernet** (AES-128-CBC + HMAC-SHA256). Stdlib-grade simplicity, well-vetted, key rotation built into the library. |
| **Q2 Master-key storage + rotation** | `$TRADELENS_ENCRYPTION_KEY` in `~/.tradelens.secrets`. Rotates alongside JWT secret in AUD-0353/0354 Phase B. Rotation = re-encrypt all stored secrets with new key (one-shot script). |
| **Q3 Schema shape** | Add columns `api_key_encrypted` + `api_secret_encrypted` + `created_by_user_id` + `credentials_key_version` to `accounts` table. |
| **Q4 Account ownership** | `accounts.created_by_user_id` only. Sharing/roles deferred to Phase 4. |
| **Q5 Credential validation at create** | Call Bybit `get_wallet_balance` before persist; reject 401/403. Fail-fast UX. |
| **Q6 `accounts.yml` lifecycle** | **DELETE post-cutover.** Single source of truth = DB. Cold-recovery path = DB backup + master key. Operator-decided 2026-04-29 — overrides the design's initial recommendation (b). The deletion is split into a post-soak commit (2.8) so the cutover (2.7) remains reversible while soaking. |
| **Q7 Existing-data migration** | One-shot `bin/setup/migrate_accounts_to_encrypted.py` (idempotent). Skip rows where `api_key_encrypted IS NOT NULL`. |
| **Q8 FE reveal-secret affordance** | **Never reveal.** Masked forever; user re-enters secret to update. |
| **Q9 Bybit validation testnet/demo** | Validate against the URL implied by `account_type` (demo → api-demo.bybit.com, testnet → api-testnet). Uniform. |
| **Q10 Cutover strategy** | Feature flag `$TRADELENS_ACCOUNTS_FROM_DB=true` mirroring Phase-1 commit-#9 pattern. Off by default until ready. |

## Schema (proposed — pending Q3/Q4 decisions)

Migration 090 (Phase 2.1 commit):

```
ALTER TABLE accounts ADD COLUMN api_key_encrypted    TEXT NULL;
ALTER TABLE accounts ADD COLUMN api_secret_encrypted TEXT NULL;
ALTER TABLE accounts ADD COLUMN created_by_user_id   BIGINT NULL
    REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE accounts ADD COLUMN credentials_updated_at TIMESTAMPTZ NULL;

-- key_version supports future rotation. Defaults to 1; rotation script
-- bumps it after re-encrypt-all with new master key.
ALTER TABLE accounts ADD COLUMN credentials_key_version INT NOT NULL DEFAULT 1;
```

After successful migration of existing 3 rows, the encrypted columns are
populated. The legacy YAML stays on disk (per Q6 recommendation) but
runtime never reads it once the cutover flag flips.

## Encryption module

New module `lib/tradelens/auth/encryption.py`:

```python
def encrypt_secret(plain: str, *, key_version: int = 1) -> str:
    """Encrypt with current master key; returns Fernet token (base64 string)."""

def decrypt_secret(token: str, *, key_version: int = 1) -> str:
    """Decrypt; raises InvalidToken on bad key/tampered ciphertext."""

def rotate_master_key(conn) -> int:
    """One-shot: re-encrypt every accounts row with the new key.
    Returns row count. Bumps credentials_key_version."""
```

Master key from `$TRADELENS_ENCRYPTION_KEY`; raise on missing — same
contract as `$TRADELENS_JWT_SECRET`. Generate via
`python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`.

## AccountContext refactor

Single change point: `_load_accounts_from_yaml()` becomes
`_load_accounts_from_db()` in enforce mode (controlled by Q10's
`TRADELENS_ACCOUNTS_FROM_DB` flag). Method shape unchanged — still
populates the in-memory dict that bybit_client reads from. Decrypts
api_key + api_secret on load and caches the decrypted form in memory
(Q2 recommendation: process memory is the same trust boundary as the
master key anyway).

## API endpoints (new)

| Method | Path | Auth | Body |
|---|---|---|---|
| GET | `/api/v1/accounts/me` | RequireAuth | — | List the caller's accounts (NO secrets — masked) |
| POST | `/api/v1/accounts` | RequireAuth | `{name, exchange, account_type, api_key, api_secret, subaccount_ref?}` | Create. Validates against Bybit before persist (Q5). Returns the row without secrets. |
| PATCH | `/api/v1/accounts/{id}` | RequireAuth + ownership | `{name?, account_type?, api_key?, api_secret?}` | Update creator-owned account. Re-validate if creds changed. |
| DELETE | `/api/v1/accounts/{id}` | RequireAuth + ownership | — | Soft-delete (mark inactive) — preserves trade history FKs. |

The existing `/api/v1/accounts` (GET, list-all) becomes admin-only
(per Phase 1's admin gating pattern; not a behaviour change since
non-admin users were already implicitly trusted).

## FE design

New page `/settings/accounts`. Linked from Topbar's user menu (next to
logout). Layout:

```
┌────────────────────────────────────────────────┐
│ My Accounts                       [+ Add Acct] │
├────────────────────────────────────────────────┤
│ bybit_main  · real    · created 2026-04-29     │
│   API key: ••••••••                            │
│   [Edit credentials]  [Delete]                 │
├────────────────────────────────────────────────┤
│ bybit_sub   · real    · created 2026-04-29     │
│   ...                                          │
└────────────────────────────────────────────────┘
```

Form for add/edit:
- name (unique-per-user)
- exchange (dropdown — bybit only for v1)
- account_type (dropdown — real / demo / testnet)
- api_key (visible field)
- api_secret (password field — masked)
- subaccount_ref (optional)
- Submit → validates against Bybit → persist → toast "Account validated and saved"

Edit mode shows current name + type + masked secrets; user re-enters
both api_key and api_secret to change them (Q8 recommendation: no
reveal). Skipping the secret fields preserves existing creds.

Delete: confirmation modal warning that delete is irreversible and
will sever ties to historical trades.

## Migration strategy

Order matters:

1. **2.1 Schema** — migration 090 + setup_database_pg.py update (Phase 1 pattern).
2. **2.2 Encryption module** — encrypt/decrypt helpers + tests; unit-only, no DB.
3. **2.3 Migrate-script** — `bin/setup/migrate_accounts_to_encrypted.py` reads accounts.yml, encrypts, writes encrypted columns + sets credentials_updated_at + created_by_user_id=1. Idempotent — safe to re-run after a key rotation.
4. **2.4 AccountContext refactor** — feature-flagged via `$TRADELENS_ACCOUNTS_FROM_DB`. Off by default; YAML path still works.
5. **2.5 API endpoints** — `/accounts/me`, POST/PATCH/DELETE; gated behind RequireAuth + ownership check.
6. **2.6 FE settings page** — list + form + delete modal.
7. **2.7 Cutover** — `TRADELENS_ACCOUNTS_FROM_DB=true` in `~/.tradelens.secrets`, restart services. **accounts.yml stays on disk during the soak** — backout path is `unset TRADELENS_ACCOUNTS_FROM_DB; tl restart api`.
8. **2.8 YAML deletion (post-soak)** — once cutover has soaked successfully (operator's call on duration; minimum 24h recommended), this commit physically deletes `accounts.yml` from rocky-8gb + rocky2, removes its `.gitignore` entry, deletes `bin/setup/sync_accounts.py` (dead code post-cutover), updates `accounts.yml.example` to reflect that it's purely a one-time bootstrap reference, and removes the YAML-reading code path from `account_context.py`. **This commit is the irrevocable point** — backout after this requires re-creating accounts via the FE.

Each is its own commit with tests. Pre-cutover and during soak, both
paths exist (YAML + DB); the cutover (2.7) is one env var flip; the
deletion (2.8) is the goodbye-YAML cleanup once you're confident.

## Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Master key loss → all stored creds become unreadable | Low (it's in `~/.tradelens.secrets`, backed up the same way as JWT secret) | Document in operator-runbook: backup the encryption key alongside backups of `accounts.yml`. Until accounts.yml is deleted (Q6), it's the recovery option |
| Encryption module bug → wrong cipher / bad nonce | Low | Use Fernet (vetted); never roll our own. Tests round-trip every algorithm path |
| Migration script run twice → double-encryption | Low (idempotency check: skip rows where api_key_encrypted IS NOT NULL) | Idempotent by design |
| FE leaks decrypted secret in network response | Low | API contracts enforce `secret_encrypted` is NEVER returned. Source-presence test pins this |
| Bybit validation at create-time fails for legitimate creds (network blip, rate limit) | Medium | Show actionable error message; don't black-hole the form |
| Cutover breaks production if migration didn't run on rocky2 | Medium | Migrate-script is part of Phase 2.3 commit; runbook says "run on each host before flipping flag" |

## Test strategy

- **Unit:** encryption module round-trip, raises on missing/bad key, key-version handling.
- **Integration:** API endpoints — create + list + update + delete; ownership enforcement (user A cannot see user B's accounts); secret never appears in any response body; Bybit validation called at create time (mocked).
- **Migration:** test_migrate_accounts_to_encrypted.py — idempotent, encrypts existing rows, doesn't double-encrypt.
- **Frontend:** vitest for form validation, list rendering, edit-without-changing-secret preserves cred.
- **Smoke:** end-to-end `bin/test/test_accounts_flow.sh` — login as admin, create new test account, validate, delete.

## What's NOT changing in Phase 2

- AccountContext API surface (callers still do `ctx.get_account(name)`)
- bybit_client constructor (`BybitClient(account_name=...)`)
- Existing 43 account-scoped endpoints
- Phase-1 user_account binding (it stays as the read-access grant for
  account-scoped endpoints)
- Sharing semantics — a user with `user_account` row for account X
  can still trade against X; only the CREATOR can edit credentials

## Estimated effort

~5-8 days, sequenced as 7 commits (mirrors Phase 1's commit-per-area pattern).

## Decision lock

Once you weigh in on Q1-Q10, this doc gets updated with the decisions
table at the top (matching the Phase 1 doc's pattern), the open-
questions section gets struck through, and implementation starts.
