---
status: runbook-ready-for-user-execution
generated: 2026-04-26
authors: claude-orchestrator-via-subagent
related-audits:
  - AUD-0353 (rotate keys + history-rewrite for committed secrets file)
  - AUD-0354 (convert plaintext secrets to env-var substitution)
execution-mode: USER-ONLY (Claude does NOT execute destructive steps)
prerequisites:
  - Operator has admin access to Bybit account dashboards
  - Operator has access to PostgreSQL admin (for DB password rotation if applicable)
  - Operator has commit access to the relevant remote(s)
  - All collaborators are notified of upcoming force-push (window agreed)
---

# AUD-0353 + AUD-0354 — Security Runbook (Operator-Executed)

> **Claude does not execute the destructive steps in this runbook.** This document is decision-input
> and step-by-step instructions for the operator. Every command is meant to be run BY THE OPERATOR
> on the operator's own checkout, against the operator's own remotes and dashboards.

## 0. Legend / placeholders

In every command and snippet below, the following placeholders are used. The operator substitutes
real values at run time. **Do not** paste real secret values into this document, into chat, into
issue trackers, or anywhere else that gets archived.

| Placeholder | Meaning |
|---|---|
| `<BYBIT_API_KEY_OLD>` | The currently exposed Bybit API key (in git history). |
| `<BYBIT_API_SECRET_OLD>` | The currently exposed Bybit API secret (in git history). |
| `<BYBIT_API_KEY_NEW>` | The new Bybit API key issued by rotation in B.1. |
| `<BYBIT_API_SECRET_NEW>` | The new Bybit API secret issued by rotation in B.1. |
| `<PG_PASSWORD_OLD>` | The currently exposed PostgreSQL password (in git history). |
| `<PG_PASSWORD_NEW>` | The new PostgreSQL password chosen during rotation. |
| `<DISCORD_INGEST_KEY_OLD>` | The current Discord-ingest shared-secret API key. |
| `<DISCORD_INGEST_KEY_NEW>` | The new Discord-ingest shared-secret API key. |
| `<VAPID_PRIVATE_KEY_OLD>` / `<VAPID_PUBLIC_KEY_OLD>` | Current web-push VAPID keypair. |
| `<PUSHOVER_USER_KEY_OLD>` / `<PUSHOVER_APP_TOKEN_OLD>` | Current Pushover credentials. |
| `<DISCORD_TOKEN>` | Discord bot/user token (already env-var-driven in `etc/config.yml`). |

Anywhere you see a literal `tradelens_poc`, `test12345`, or any base64-looking blob in this document,
treat it as a placeholder for "the value at that line in the file at the time of the audit." The
runbook never echoes real values, even though the values are in git history; that's the audit
finding, not a license to proliferate them further.

## 1. Threat model

### What is exposed

Two separate exposures, both confirmed by AUD-0353 and AUD-0354:

| File | Tracked since | Exposed values | Reach |
|---|---|---|---|
| `tradelens/etc/config.yml.bkup-20251110223555` | commit `7fdbcd8b`, **2025-11-13** ("Reorganize bin/ directory and complete multi-account migration") | `bybit.api_key` (live), `bybit.api_secret` (live), `database.db_password: "test12345"` | Anyone with read on the remote, plus anyone who ever cloned the repo since 2025-11-13. |
| `tradelens/etc/config.yml` (HEAD) | currently tracked | `database.password` (line 19), `postgresql.password` (line 27), `discord_ingest.api_key` (line 483), `web_push.vapid_private_key` / `vapid_public_key` (lines 133-134), `pushover.user_key` / `pushover.app_token` (lines 140-141) | Same as above — every revision of this file in git history exposes whatever values were at HEAD at the time. |

`etc/config.yml.bkup-20251110223555` is matched by the existing `.gitignore` rule `*.yml.bkup*`,
but the file was committed before the rule was applied or before it covered that path, so git
continues to track it. Adding a gitignore rule does NOT remove it from history; only a history
rewrite (Phase B) does that.

`tradelens/etc/config.yml` is **not currently in `.gitignore`** at all. It is actively tracked
and changes to it are committed regularly. This is the Phase A ("safe") problem to fix.

### Who has access

Operator should answer the following BEFORE proceeding. The answers materially affect blast radius
and decide whether `git push --force-with-lease` is sufficient or whether GitHub-side cache purges
and external rotation are also required.

- [ ] Is the repo on `github.com` (public), `github.com` (private), self-hosted GitLab, internal
      GitLab/Gitea, or a single bare repo on a private host? **Write the answer here:** ___________
- [ ] Are there any read-only mirrors (CI artifact stores, Sourcegraph indexers, internal code-search,
      backups)? Each one is a separate cache that has to be invalidated. **List them:** ___________
- [ ] Have any collaborators ever cloned the repo? Even one stale clone keeps the secret alive after
      a force-push. **List collaborator clones:** ___________
- [ ] Has the Bybit key ever been used from an IP outside the operator's trusted set? (Check Bybit
      account "API key usage" log in dashboard.)
- [ ] Has `test12345` been used as the password for any other system? If yes, those need separate
      rotations (out of scope for this runbook; track separately).

If any answer above is "yes, public" or "yes, mirrored externally," **assume the secret is fully
public** and treat rotation (B.1) as the load-bearing mitigation. The history rewrite (B.2-B.3) is
hygiene; rotation is the actual fix.

### Since when

Conservatively: **2025-11-13** (the commit that introduced `etc/config.yml.bkup-20251110223555`).
The plaintext values in `etc/config.yml` itself may be older — that's tracked across many commits
and any of them could have leaked the values at the time. Phase B's `git filter-repo` will scrub
**all** historical revisions of the targeted files, not just the current one.

## 2. Pre-flight checklist

The operator runs each of these checks BEFORE starting Phase A.

### 2.1 Enumerate exposed values

This is a **read-only** inventory step. Run it with the file open in a private editor; do NOT
commit the inventory anywhere.

```bash
# From the repo root. Each command lists the LINE NUMBERS only — do NOT
# screenshot or copy the values themselves out of these files.
grep -nE "(password|api_key|api_secret|secret|token|user_key|app_token|vapid_private_key|vapid_public_key)" \
    tradelens/etc/config.yml
grep -nE "(password|api_key|api_secret)" \
    tradelens/etc/config.yml.bkup-20251110223555
```

Expected (as of 2026-04-26 audit):

```
tradelens/etc/config.yml:
  19:  password: "<PG_PASSWORD_OLD>"          # database.password
  27:  password: "<PG_PASSWORD_OLD>"          # postgresql.password (separate pool, same DB)
 133:  vapid_private_key: "<VAPID_PRIVATE_KEY_OLD>"
 134:  vapid_public_key: "<VAPID_PUBLIC_KEY_OLD>"
 140:  user_key: "<PUSHOVER_USER_KEY_OLD>"
 141:  app_token: "<PUSHOVER_APP_TOKEN_OLD>"
 391:  token: "${DISCORD_TOKEN}"               # already env-var, leave alone
 483:  api_key: "<DISCORD_INGEST_KEY_OLD>"
 488:  api_key: "${OPENAI_API_KEY}"            # already env-var, leave alone

tradelens/etc/config.yml.bkup-20251110223555:
  14:  api_key: "<BYBIT_API_KEY_OLD>"
  15:  api_secret: "<BYBIT_API_SECRET_OLD>"
  25:  db_password: "<PG_PASSWORD_OLD>"        # same value as config.yml
```

Tick each one off the operator's password manager: every value should be captured in 1Password /
Bitwarden / etc. with a `rotated: pending` tag.

### 2.2 Verify Bybit dashboard access

```
- Operator can sign in to https://www.bybit.com → Profile → API Management.
- Operator can see the existing key (verify by partial match on first 4 chars of `<BYBIT_API_KEY_OLD>`).
- Operator has 2FA / phone access required to create new keys.
```

### 2.3 Take a fresh full backup of the repo

`git filter-repo` rewrites history irreversibly on the local clone. Make a tar snapshot of the
repo root **including `.git/`** so a full restore is possible if the rewrite goes wrong.

```bash
# Run from the directory ABOVE the repo. Adjust path if the repo lives elsewhere.
DATE=$(date -u +%Y%m%dT%H%M%SZ)
tar -czf /tmp/tradesuite-pre-aud0353-${DATE}.tgz \
    --exclude='tradesuite/venv' \
    --exclude='tradesuite/node_modules' \
    --exclude='tradesuite/tradelens/data' \
    --exclude='tradesuite/tradelens/logs' \
    --exclude='tradesuite/tradelens/cache' \
    tradesuite/
ls -lh /tmp/tradesuite-pre-aud0353-${DATE}.tgz
```

Verify the tarball lists `.git/`:

```bash
tar -tzf /tmp/tradesuite-pre-aud0353-${DATE}.tgz | grep -c '\.git/' | head -1
# Expect a non-zero number. If zero, the backup is incomplete — DO NOT proceed.
```

### 2.4 Notify collaborators

If any collaborators exist, send the notice ahead of time (template in section B.4). Block on
acknowledgement; a force-push without coordination corrupts other clones silently.

If you are the only person with a clone, skip this — write "solo operator, no collaborators" in
the operator's own notes and proceed.

### 2.5 Verify clean working tree on operator's main clone

```bash
# Run on the operator's main clone (not in a Claude worktree).
cd /app/syb/tradesuite
git status
# Expect: "nothing to commit, working tree clean".
git fetch origin
git log --oneline origin/master..HEAD   # local commits not yet pushed
git log --oneline HEAD..origin/master   # remote commits not yet pulled
# Both expected empty before starting.
```

If either log is non-empty, sort that out first — do not start the runbook with a divergent local
master.

## 3. Phase A — AUD-0354: convert `etc/config.yml` secrets to env-var substitution

This phase is **safe and reversible**. No history rewrite, no force-push, no rotation needed yet.
It removes plaintext secrets from the working file going forward.

### A.1 Decide the env-var names

Append these to the operator's secret-loading file (created in A.3). The variable names are a
contract — once `etc/config.yml` references `${TRADELENS_PG_PASSWORD}`, every shell that runs
TradeLens must export that exact name.

| Config field (line) | Env var | Notes |
|---|---|---|
| `database.password` (19) | `TRADELENS_PG_PASSWORD` | Main pool. |
| `postgresql.password` (27) | `TRADELENS_PG_PASSWORD` | Same DB, same value, same env var. |
| `discord_ingest.api_key` (483) | `DISCORD_INGEST_API_KEY` | Already documented as overridable in the inline comment. |
| `web_push.vapid_private_key` (133) | `WEB_PUSH_VAPID_PRIVATE_KEY` | Sensitive — server-side signing key. |
| `web_push.vapid_public_key` (134) | `WEB_PUSH_VAPID_PUBLIC_KEY` | Less sensitive (public by design) but keep symmetric. |
| `pushover.user_key` (140) | `PUSHOVER_USER_KEY` | |
| `pushover.app_token` (141) | `PUSHOVER_APP_TOKEN` | |

Already env-var-driven (leave alone): `discord.token` (391, `${DISCORD_TOKEN}`),
`openai.api_key` (488, `${OPENAI_API_KEY}`).

### A.2 Verify the codebase already supports `${VAR}` expansion for all target keys

Tradelens has at least three implementations of `${VAR}` expansion (per AUD-0260): in
`account_context.py`, `batch_ideas.py`, and `discord_ingest.py`. Before flipping any value, confirm
the loader for **each** target field expands `${VAR}` syntax. Run a sample with a non-existent
value to make sure the loader doesn't silently swallow a missing var:

```bash
# Test pattern (operator runs against a SCRATCH copy of config.yml,
# NOT the live one):
cp tradelens/etc/config.yml /tmp/config-test.yml
sed -i 's|password: "tradelens_poc"|password: "${PROBE_VAR_DOES_NOT_EXIST}"|' /tmp/config-test.yml
# Then load /tmp/config-test.yml with the relevant TradeLens module and observe:
#   - For account_context.py: should RAISE ConfigurationError (per AUD-0260).
#   - For discord_ingest.py: silently defaults to "" (semantic gap — see AUD-0260).
# If any path silently defaults to "", ROUTE THE FIX THROUGH AUD-0260 FIRST so you don't
# end up with a "successful" startup that's pointed at an empty password.
```

> **Decision the operator must make BEFORE proceeding to A.3:** are all the target config
> fields read by loaders that *raise* on missing vars, or do any of them silently default to
> the empty string? If any silently default, do AUD-0260 first (lift one canonical
> raising loader to module scope; replace the silent variants); only then come back to A.3.
> Empty-password connections to PostgreSQL will fail noisily in dev but might match a
> production user with no password — tighten this first.

### A.3 Create `~/.tradelens.secrets` (operator-managed, gitignored)

```bash
# DO NOT commit this file. It lives in $HOME, not in the repo.
cat > ~/.tradelens.secrets <<'EOF'
# TradeLens secrets — sourced by sourceme.sh. NEVER commit this file.
# Permissions must be 600.

# PostgreSQL
export TRADELENS_PG_PASSWORD='<fill in current value of database.password>'

# Discord ingest shared secret (extension <-> backend)
export DISCORD_INGEST_API_KEY='<fill in current value of discord_ingest.api_key>'

# Web push (VAPID)
export WEB_PUSH_VAPID_PRIVATE_KEY='<fill in current value of web_push.vapid_private_key>'
export WEB_PUSH_VAPID_PUBLIC_KEY='<fill in current value of web_push.vapid_public_key>'

# Pushover
export PUSHOVER_USER_KEY='<fill in current value of pushover.user_key>'
export PUSHOVER_APP_TOKEN='<fill in current value of pushover.app_token>'

# Discord bot/user token (already referenced as ${DISCORD_TOKEN} in config.yml)
export DISCORD_TOKEN='<fill in current value used in production>'

# OpenAI (already referenced as ${OPENAI_API_KEY} in config.yml)
export OPENAI_API_KEY='<fill in current value used in production>'
EOF
chmod 600 ~/.tradelens.secrets
ls -l ~/.tradelens.secrets   # expect: -rw------- 1 <user> <group>
```

> **Decision the operator must make:** during Phase A, the value pasted into
> `TRADELENS_PG_PASSWORD` is still the **old** value (`tradelens_poc`). That's fine — Phase A
> only changes the source of truth, not the value. Phase B.1 will rotate it.

### A.4 Update `sourceme.sh` to load the secrets file

Edit `sourceme.sh` to source the secrets file if it exists. Keep this minimal — silent failure if
the file is absent (so CI / sandboxes that don't need secrets aren't blocked):

```bash
# Append to sourceme.sh (do NOT overwrite the existing content).
cat >> sourceme.sh <<'EOF'

# Operator-managed secrets file. Not in git. See
# tradelens/docs/30-fixes-and-audits/audits/audit-autofix/2026-04-26-aud-0353-0354-security-runbook.md
# for the canonical list of variables it must export.
if [ -f "$HOME/.tradelens.secrets" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.tradelens.secrets"
fi
EOF
```

> **Open question for the operator:** `sourceme.sh` currently exports
> `SybAdminPwd=test12345` directly (line 19). Should that be moved to `~/.tradelens.secrets`
> too? It's a different consumer (`app_lock.py` fallback) but the same exposure pattern.
> Flag this in the commit message; either fix it as part of A.4 or open an AUD- follow-up.

### A.5 Edit `etc/config.yml` to reference env vars

```bash
# Operator runs each line individually and verifies the diff before saving.
# Do NOT use replace-all blindly — `password:` occurs twice (line 19, 27)
# and you want both, but watch for any future occurrence.

# database.password (line 19) and postgresql.password (line 27) — same value:
#   password: "tradelens_poc"
# becomes:
#   password: "${TRADELENS_PG_PASSWORD}"

# discord_ingest.api_key (line 483):
#   api_key: "<DISCORD_INGEST_KEY_OLD>"
# becomes:
#   api_key: "${DISCORD_INGEST_API_KEY}"

# web_push.vapid_private_key (line 133):
#   vapid_private_key: "<VAPID_PRIVATE_KEY_OLD>"
# becomes:
#   vapid_private_key: "${WEB_PUSH_VAPID_PRIVATE_KEY}"

# web_push.vapid_public_key (line 134):
#   vapid_public_key: "<VAPID_PUBLIC_KEY_OLD>"
# becomes:
#   vapid_public_key: "${WEB_PUSH_VAPID_PUBLIC_KEY}"

# pushover.user_key (line 140):
#   user_key: "<PUSHOVER_USER_KEY_OLD>"
# becomes:
#   user_key: "${PUSHOVER_USER_KEY}"

# pushover.app_token (line 141):
#   app_token: "<PUSHOVER_APP_TOKEN_OLD>"
# becomes:
#   app_token: "${PUSHOVER_APP_TOKEN}"
```

### A.6 Add `etc/config.yml` to `.gitignore` and stop tracking it

This is the part that diverges from "just edit it." Going forward, `etc/config.yml` is operator-
local. `etc/config.yml.example` (next step) is the committed template.

```bash
# Add to root .gitignore (alongside the existing tradelens/etc/accounts.yml line):
echo "tradelens/etc/config.yml" >> .gitignore

# Stop tracking the file but keep the working copy:
git rm --cached tradelens/etc/config.yml

# Verify:
git check-ignore -v tradelens/etc/config.yml
# Expected: ".gitignore:NN:tradelens/etc/config.yml  tradelens/etc/config.yml"
git ls-files tradelens/etc/config.yml
# Expected: empty.
```

> **Caveat the operator must accept:** removing `etc/config.yml` from tracking does NOT remove
> it from history. Past revisions still expose past values. Phase B.2 (`git filter-repo`) is
> what scrubs history. A.6 only changes "what's in HEAD going forward."

### A.7 Create `etc/config.yml.example` (committed template)

```bash
# Copy the now-edited config.yml to .example, replacing every secret value
# with an obvious placeholder if it isn't already a ${VAR} reference.
cp tradelens/etc/config.yml tradelens/etc/config.yml.example

# Manually verify .example contains only ${VAR} placeholders for secrets:
grep -nE "(password|api_key|api_secret|user_key|app_token|vapid_private_key|vapid_public_key|token).*:" \
    tradelens/etc/config.yml.example
# Every match should be of the form:
#     foo: "${SOMETHING}"
# If any match shows a literal value, FIX IT in .example and re-run the grep.

# Optionally sanitize comments — if a comment says "Your Pushover app token (set via env var)"
# and the line is now `${PUSHOVER_APP_TOKEN}`, the comment is fine. If a comment includes a real
# value (it doesn't, in current config.yml, but worth one more eyeball pass), redact it.
```

### A.8 Phase A verification

```bash
# 1. The example file has no plaintext secrets:
grep -EvnH '(\$\{[A-Z_]+\}|^[[:space:]]*#|^[[:space:]]*$)' tradelens/etc/config.yml.example \
    | grep -E "(password|api_key|api_secret|user_key|app_token|vapid_(private|public)_key)"
# Expected: empty output. Any line shown is a still-plaintext leak.

# 2. The live config.yml is no longer tracked:
git ls-files tradelens/etc/config.yml
# Expected: empty.

# 3. The example file IS tracked (after `git add`):
git ls-files tradelens/etc/config.yml.example
# Expected: tradelens/etc/config.yml.example

# 4. Boot smoke test — services come up reading env vars:
source ./sourceme.sh   # this should now also source ~/.tradelens.secrets
./tradelens/bin/api restart
tail -n 50 tradelens/logs/api.log
# Expected: API starts, no "psycopg2.OperationalError: password authentication failed"
# If the password env var is missing or wrong, the API will fail on the FIRST DB query.
```

### A.9 Phase A commit

```bash
git add .gitignore sourceme.sh tradelens/etc/config.yml.example
git rm --cached tradelens/etc/config.yml   # if not already staged from A.6
git status   # verify ONLY the four files above are staged
git commit -m "$(cat <<'EOF'
docs(security): AUD-0354 — convert config.yml secrets to env-var substitution + add config.yml.example

# tests: exempt — config-only

Per AUDIT_TRACKER AUD-0354 (Critical/Security). Replaces inline plaintext
secrets in tradelens/etc/config.yml with ${VAR} substitutions, moves the
file out of git tracking, and ships tradelens/etc/config.yml.example as
the committed template. Operator-managed secrets now live in
~/.tradelens.secrets (gitignored, 600 perms), sourced by sourceme.sh.

Pairs with AUD-0353 runbook (history rewrite + key rotation) — that work
is operator-executed and not part of this commit.

Variables introduced:
  TRADELENS_PG_PASSWORD, DISCORD_INGEST_API_KEY,
  WEB_PUSH_VAPID_PRIVATE_KEY, WEB_PUSH_VAPID_PUBLIC_KEY,
  PUSHOVER_USER_KEY, PUSHOVER_APP_TOKEN
(DISCORD_TOKEN and OPENAI_API_KEY were already env-var-driven.)

Note: this commit does NOT change the secret VALUES. Rotation is
covered by the AUD-0353 phase-B runbook.
EOF
)"
```

### A.10 Push Phase A normally (no force)

```bash
git push origin master
```

This is a **fast-forward push**. Collaborators pull as normal. No force-push needed yet.

### A.11 Phase A rollback (if needed)

Phase A is fully reversible:

```bash
# If A.9 has been pushed:
git revert <SHA-of-A.9>
git push origin master
# The reverted commit re-adds the plaintext secrets. The revert message should
# document why and link to the next attempt.

# If A.9 has not yet been pushed:
git reset --hard HEAD~1
# (Operator must explicitly OK this; reset --hard is destructive on local work.)
```

This rollback is only valid as long as Phase B.1 has NOT yet been run. Once secrets are rotated,
rolling back A.9 reintroduces the OLD values in `etc/config.yml`, which no longer work, so the
running services will break. Phase A reverts only make sense before Phase B.

## 4. Phase B — AUD-0353: rotate keys, then rewrite history

This phase is **destructive on the remote** (B.3 is a force-push). Rotation in B.1 is irreversible
in the sense that the old key is gone forever. Order matters: **B.1 BEFORE B.2 BEFORE B.3**.

### Why rotation comes before history rewrite

Even after `git filter-repo` succeeds and a force-push lands, every clone that existed before the
force-push still has the secret in their local `.git/objects/`. There is no way to reach into other
clones and remove it. The only mitigation that works against those clones (and against any external
mirror, indexer, backup, or attacker who has already copied the secret) is **invalidating the
secret itself**. That's rotation. The history rewrite is hygiene; rotation is the lock change.

### B.1 Rotate exposed credentials

#### B.1.1 Bybit API key + secret

1. Sign in to https://www.bybit.com.
2. Profile menu (top-right) → **API**, or directly: https://www.bybit.com/app/user/api-management.
3. Locate the entry whose first 4 characters match the first 4 of `<BYBIT_API_KEY_OLD>`.
4. Click **Edit** to confirm the IP whitelist + permissions on the existing key (so you can
   recreate them on the new one). Take a screenshot of the permission set, kept locally only.
5. Click **Delete** on the old key. Confirm via 2FA.
6. Click **Create New Key** with the same permissions and IP whitelist as the deleted one.
7. Bybit shows the new `api_key` and `api_secret` **once**. Copy both into the operator's password
   manager and into `~/.tradelens.secrets` immediately:

   ```bash
   # Edit ~/.tradelens.secrets and add (or update if already present):
   export BYBIT_API_KEY='<BYBIT_API_KEY_NEW>'
   export BYBIT_API_SECRET='<BYBIT_API_SECRET_NEW>'
   ```

   > **Decision needed BEFORE B.1.1:** Bybit values were not in scope of Phase A (they live in
   > `etc/config.yml.bkup-...`, not the live `etc/config.yml`). Where does the LIVE app currently
   > read its Bybit credentials from? If from `etc/config.yml.bkup-*` directly (unlikely — that
   > file is a stale backup), trace the loader; if from `accounts.yml` (likely — see
   > `tradelens/etc/accounts.yml`, also gitignored), update there. **The operator must answer
   > this before rotating** — otherwise a successful rotation could orphan the live application.
   > Recommended check: `grep -RIn 'api_key\|api_secret' tradelens/lib tradelens/bin tradelens/etc | head`.

8. Verify the new key works with a smoke test (operator's own scratch script — do not commit):

   ```python
   # /tmp/bybit_smoke.py — DO NOT commit.
   import os
   from pybit.unified_trading import HTTP
   client = HTTP(
       testnet=False,
       api_key=os.environ["BYBIT_API_KEY"],
       api_secret=os.environ["BYBIT_API_SECRET"],
   )
   print(client.get_wallet_balance(accountType="UNIFIED"))
   ```

   ```bash
   source ./sourceme.sh
   python3 /tmp/bybit_smoke.py
   # Expected: a JSON dict with retCode=0 and a list of balances. Non-zero retCode = key
   # is wrong / not yet active / IP not whitelisted.
   rm /tmp/bybit_smoke.py
   ```

#### B.1.2 PostgreSQL password

1. Connect as a superuser (the operator's normal admin account, NOT the `tradelens` role itself):

   ```bash
   psql -h 127.0.0.1 -p 5432 -U postgres -d tradelens
   # Or whichever superuser is configured for this host.
   ```

2. Rotate. Use a strong random value — do NOT reuse the password from any other system.

   ```sql
   -- In psql.
   ALTER ROLE tradelens WITH PASSWORD '<PG_PASSWORD_NEW>';
   \q
   ```

3. Update `~/.tradelens.secrets`:

   ```bash
   # Edit ~/.tradelens.secrets:
   #   export TRADELENS_PG_PASSWORD='<PG_PASSWORD_NEW>'
   ```

4. Smoke test — restart the API and verify connection succeeds:

   ```bash
   source ./sourceme.sh
   ./tradelens/bin/api restart
   tail -n 50 tradelens/logs/api.log
   # Expected: clean startup, no "FATAL: password authentication failed for user \"tradelens\"".
   curl -s http://127.0.0.1:8088/api/v1/health
   # Expected: {"status":"ok"} or equivalent.
   ```

5. Also rotate `SybAdminPwd` (legacy fallback in `sourceme.sh:19`). Either:
   - Update the role used by `app_lock.py` (`hkeep` per current `sourceme.sh`) to a new password and
     update both `~/.tradelens.secrets` and `sourceme.sh` to read from env, OR
   - Confirm the role isn't actually used in production today and remove the fallback entirely.

   This is an open question — the operator must decide before B.2 because B.2 will scrub the value
   `test12345` from history (which is also `SybAdminPwd`'s current value).

#### B.1.3 Discord-ingest API key

1. Generate a new value:

   ```bash
   python3 -c "import secrets; print(secrets.token_urlsafe(32))"
   ```

2. Update `~/.tradelens.secrets`:

   ```bash
   #   export DISCORD_INGEST_API_KEY='<DISCORD_INGEST_KEY_NEW>'
   ```

3. Update the **browser extension's** "API Key" setting (extension UI → Settings → API Key field)
   to the same new value. Both ends must match.

4. Smoke test: open the extension, click "Refresh Channels," verify it succeeds (uses the API key
   for auth on `/api/v1/discord-ingest/config`).

#### B.1.4 Web-push VAPID keypair

VAPID keys are less time-critical (their compromise is annoying — an attacker could send push
notifications spoofed as TradeLens — but does not let them log in or move money). Rotate if there's
even a small chance of public exposure; otherwise the operator may defer.

If rotating:

1. Generate a new keypair:

   ```bash
   pip install py-vapid   # or whichever lib tradelens uses; check requirements
   python3 -c "from py_vapid import Vapid01; v=Vapid01(); v.generate_keys(); v.save_key('/tmp/vapid_priv.pem'); print('OK')"
   # Then derive the base64url-encoded public key per RFC 8292 — see web-push docs.
   ```

2. Update `~/.tradelens.secrets` with the new keys.
3. **Important:** existing browser subscriptions are tied to the OLD public key. Rotating VAPID keys
   invalidates every existing push subscription. Users must re-subscribe. If that's unacceptable,
   defer the rotation and treat AUD-0353 as "Bybit + PG only, VAPID risk accepted."

#### B.1.5 Pushover credentials

1. Sign in to https://pushover.net.
2. Generate a new application token at https://pushover.net/apps/build (or rotate the existing app's
   token if Pushover supports that — check the app's settings page).
3. The user_key is **per-Pushover-account** and rotating it requires deleting / recreating the user
   account, which is overkill for this exposure level. The operator may accept the user_key as
   "rotated only if Pushover account compromise is suspected"; otherwise just rotate the app_token.
4. Update `~/.tradelens.secrets`.
5. Smoke test: send a test notification via the relevant TradeLens code path or via curl:

   ```bash
   curl -s --form-string "token=$PUSHOVER_APP_TOKEN" \
            --form-string "user=$PUSHOVER_USER_KEY" \
            --form-string "message=AUD-0353 rotation smoke test" \
            https://api.pushover.net/1/messages.json
   # Expect: {"status":1,"request":"..."}
   ```

#### B.1.6 Rotation completion checkpoint

Before moving to B.2, the operator MUST confirm in writing (in their own notes — not in this doc):

```
[ ] Bybit api_key + api_secret rotated, smoke test passed.
[ ] PG `tradelens` role password rotated, API smoke test passed.
[ ] (Optional) PG `hkeep` role password rotated.
[ ] Discord-ingest API key rotated, extension updated, smoke test passed.
[ ] (Optional) VAPID keypair rotated, push subscriptions accepted to be invalidated.
[ ] Pushover app token rotated, smoke test passed.
[ ] All NEW values are stored in operator password manager AND ~/.tradelens.secrets.
[ ] All OLD values are CRYPTOGRAPHICALLY DEAD (Bybit API panel shows the old key gone;
    psql with the old PG password fails with "password authentication failed").
```

If any item is "[ ]" or "[uncertain]", DO NOT proceed to B.2.

### B.2 Rewrite git history with `git filter-repo`

`git filter-repo` is the modern, supported tool for this. `git filter-branch` is deprecated and
substantially slower. Verify it's installed:

```bash
git filter-repo --version
# If "command not found": pip install git-filter-repo (or apt/brew install git-filter-repo).
```

#### B.2.1 Pre-rewrite snapshot tag

```bash
# On the operator's main clone, on master, with a clean working tree.
git tag pre-aud0353-rewrite-snapshot
git tag -l 'pre-aud0353-rewrite-snapshot' -n1
# Expected: pre-aud0353-rewrite-snapshot  (commit message of HEAD)
```

This is a **local-only anchor**. It lets the operator restore THEIR LOCAL clone to pre-rewrite
state if anything goes wrong before B.3. It does NOT help any other clone.

#### B.2.2 Run `git filter-repo`

```bash
# Files to scrub. Both have committed real secrets at some point in history.
# - tradelens/etc/config.yml.bkup-20251110223555: the AUD-0353 backup file.
# - tradelens/etc/config.yml: every historical revision contained inline secrets.
git filter-repo \
    --invert-paths \
    --path 'tradelens/etc/config.yml.bkup-20251110223555' \
    --path 'tradelens/etc/config.yml' \
    --force
```

`--invert-paths` means "remove these paths from history" (default is "keep only these paths").

`--force` is required because the working tree, while clean, may contain other untracked or
worktree-specific state that filter-repo's freshness check doesn't recognize. Read filter-repo's
output carefully — it lists which commits were touched and which removed.

> **Decision the operator must make BEFORE running B.2.2:** do you also want to scrub the
> string `test12345` from message bodies / blob contents in OTHER files (e.g. `sourceme.sh`)?
> If yes, additionally pass `--replace-text /tmp/aud0353-replacements.txt` where the file
> contains lines like `test12345==>***REMOVED***`. CAUTION: this rewrites every commit
> that ever contained that string, not just the offending files. It's a much bigger blast
> radius. Recommended: do NOT use `--replace-text`; the value `test12345` is a low-entropy
> placeholder anyway, and rotating the PG password (B.1.2) makes the string non-load-bearing.

#### B.2.3 Verify the rewrite

```bash
# (1) The targeted files no longer appear in any commit:
git log --all --full-history -- 'tradelens/etc/config.yml.bkup-20251110223555'
# Expected: empty.
git log --all --full-history -- 'tradelens/etc/config.yml'
# Expected: empty (modulo any commits that ADD the .example file, if you accidentally
# named it the same — sanity check).

# (2) The exposed Bybit api_key string is no longer findable in any blob:
git rev-list --all | xargs git grep -l '<BYBIT_API_KEY_OLD>' 2>/dev/null
# Expected: empty.
git rev-list --all | xargs git grep -l '<BYBIT_API_SECRET_OLD>' 2>/dev/null
# Expected: empty.
git log --all --full-history --grep='<BYBIT_API_KEY_OLD>'
# Expected: empty (no commit messages mention it either).

# (3) The PG password string:
git rev-list --all | xargs git grep -l 'test12345' 2>/dev/null
# Expected: maybe some hits in sourceme.sh (line 19 still hardcodes it as
# SybAdminPwd) — those are OUT OF SCOPE for filter-repo and require the
# B.1.2 step's "also rotate hkeep" decision. Decide before pushing.

# (4) The repo is healthy:
git fsck --full
# Expected: no errors. If "dangling commit" warnings, those are normal post-filter-repo.

# (5) HEAD commit count vs pre-rewrite — informational only:
git rev-list --count master
# Compare to the count from before filter-repo ran. Should be similar (a few commits may
# have been dropped if they ONLY touched the scrubbed files).
```

#### B.2.4 Reconfigure the remote

`git filter-repo` removes the `origin` remote by default (to prevent accidental push of the rewritten
history before the operator is ready). Add it back:

```bash
git remote -v
# Expected: empty.

git remote add origin <REMOTE_URL>
# Replace <REMOTE_URL> with the actual URL — the operator should have it noted; or recover
# it from /tmp/tradesuite-pre-aud0353-*.tgz/.git/config if needed.

git remote -v
# Expected: origin appears twice (fetch + push).
```

### B.3 Force-push the rewritten history

#### B.3.1 Final pre-flight before force-push

```bash
# 1. Confirm rotation is COMPLETE (B.1 checklist all green).
# 2. Confirm collaborators have ack'd the force-push window.
# 3. Confirm the operator is on master:
git rev-parse --abbrev-ref HEAD
# Expected: master
# 4. Confirm the local snapshot tag exists:
git tag -l 'pre-aud0353-rewrite-snapshot'
# Expected: pre-aud0353-rewrite-snapshot
```

#### B.3.2 Force-push with lease

```bash
git push --force-with-lease origin master
```

`--force-with-lease` refuses the push if the remote has commits the operator's local clone hasn't
seen. That's the "did somebody else push while I was rewriting?" guard. If the push fails with
"stale info," DO NOT switch to `--force` — instead `git fetch origin master`, review what arrived,
re-tag, re-rewrite (filter-repo is fast), and try again.

#### B.3.3 Push tags too (so the snapshot is preserved if the operator wants it remote-side)

The pre-rewrite snapshot tag is local. If the operator wants a remote-side anchor (so the team can
verify against the OLD history if needed), push it:

```bash
git push origin pre-aud0353-rewrite-snapshot
# This pushes a tag that points at a commit that is NO LONGER on master. That's fine; the tag
# anchors the old object graph (which still exists in the remote until GC runs).
```

> **Decision:** some operators prefer NOT to push the snapshot tag, on the principle that the
> point of the rewrite is to remove old state from the remote. If the operator agrees with
> that principle, skip B.3.3 and keep the snapshot purely local.

#### B.3.4 Branches other than master

If the repo has long-lived branches (release-*, develop, etc.), `git filter-repo` rewrites ALL of
them. Force-push each one explicitly:

```bash
git branch -a | grep -v 'remotes/' | grep -v '*'
# For each local branch listed:
git push --force-with-lease origin <branchname>
```

If there are remote branches the operator doesn't have locally, fetch and rewrite them too (or
delete remote-side if they're stale):

```bash
git fetch origin
git branch -a   # review
# Decide per-branch: rewrite (bring local, push --force-with-lease) or delete (git push origin :branchname).
```

### B.4 Notify collaborators

Post-rewrite message (operator sends to the team via whatever channel they coordinated on):

> **Subject:** TradeSuite — history rewritten on master (AUD-0353 secret scrub)
>
> I just completed a `git filter-repo` rewrite of master (and other branches) to remove
> committed secrets per audit AUD-0353. Bybit + PostgreSQL + Discord-ingest credentials
> have been rotated; the old values are dead.
>
> **What you need to do:**
>
> 1. Stop any running tradelens services that came from your clone.
> 2. Either:
>    - **Easy path (recommended):** delete your local checkout and `git clone` fresh.
>    - **Manual path:** `git fetch origin && git reset --hard origin/master`. Repeat for
>      every long-lived branch you have local. Any local commits that built on the old
>      history will need to be cherry-picked manually onto the new master.
> 3. If you maintain `~/.tradelens.secrets`, refresh it with the new credential values
>    (DM me for the new Bybit + PG + Discord-ingest secrets — DO NOT paste them in
>    chat history).
> 4. Confirm by replying "rebased OK" once your clone has been refreshed.
>
> Force-pushed tag: `pre-aud0353-rewrite-snapshot` anchors the old history if you need to
> verify anything against pre-rewrite state. (May be omitted depending on operator decision
> in B.3.3.)

## 5. Rollback notes

| Phase | Reversible? | Mechanism |
|---|---|---|
| A.5–A.9 (config.yml → ${VAR}) | **Yes**, before B.1. `git revert` the Phase A commit and force-pull. After B.1, no — old values won't work. |
| A.10 (push) | **Yes**, fast-forward, plain revert + push. |
| B.1.1 Bybit rotation | **No** — old key is permanently invalid the moment Bybit deletes it. Recovery = generate yet another new key (B.1.1 again). |
| B.1.2 PG password rotation | **Reversible by setting the password back** to `<PG_PASSWORD_OLD>` via `ALTER ROLE`. But that defeats the purpose. Treat as one-way. |
| B.1.3 Discord-ingest key | Same as B.1.2. Reversible technically but undermines the rotation. |
| B.2 filter-repo | **Locally reversible** until B.3 runs: `git reset --hard pre-aud0353-rewrite-snapshot && git remote add origin <REMOTE_URL>`. After B.3 (force-push), the OLD history is gone from the remote. The local snapshot tag (or the tarball backup from §2.3) is the only path back, and "back" only fixes ONE clone. **Other clones, mirrors, indexers, and external archives still have the old history.** That's why B.1 has to be done first. |
| B.3 force-push | **Not reversible on the remote.** The pre-rewrite history is purged from the default branch's reachable graph. Some remotes (e.g. GitHub) keep the old commit objects retrievable by SHA for a window (~90 days) — those need a separate purge request (see §6). |

## 6. Post-flight checklist

The operator runs each of these AFTER B.3.

### 6.1 Application is running with new credentials

```bash
# Restart all services from a clean shell (so env reload from sourceme.sh + ~/.tradelens.secrets
# is verified):
unset BYBIT_API_KEY BYBIT_API_SECRET TRADELENS_PG_PASSWORD DISCORD_INGEST_API_KEY \
      WEB_PUSH_VAPID_PRIVATE_KEY WEB_PUSH_VAPID_PUBLIC_KEY \
      PUSHOVER_USER_KEY PUSHOVER_APP_TOKEN
exec bash -l   # fresh shell

cd /app/syb/tradesuite
source ./sourceme.sh

# Sanity-check that env vars made it through:
echo "BYBIT_API_KEY set: $([ -n "$BYBIT_API_KEY" ] && echo yes || echo NO)"
echo "TRADELENS_PG_PASSWORD set: $([ -n "$TRADELENS_PG_PASSWORD" ] && echo yes || echo NO)"
echo "DISCORD_INGEST_API_KEY set: $([ -n "$DISCORD_INGEST_API_KEY" ] && echo yes || echo NO)"
# Expected: all "yes". Any "NO" = ~/.tradelens.secrets isn't being sourced.

./tradelens/bin/api restart
./tradelens/bin/dashboard restart
# tl restart for any other service per CLAUDE.md service-management policy.

# Smoke test against actual endpoints:
curl -s http://127.0.0.1:8088/api/v1/health
curl -s http://127.0.0.1:8088/api/v1/portfolio   # whichever endpoint hits Bybit
# Expected: 200 OK. A 401/403/500 indicates wrong credentials or stale env.
```

### 6.2 History is clean

```bash
# Re-run the verification commands from B.2.3:
git log --all --full-history -- 'tradelens/etc/config.yml.bkup-20251110223555'
git log --all --full-history -- 'tradelens/etc/config.yml'
git rev-list --all | xargs git grep -l '<BYBIT_API_KEY_OLD>' 2>/dev/null
# All expected: empty.

# Bonus: search commit messages too.
git log --all --grep='test12345'
# Expected: empty, OR returns ONLY this runbook (which references the literal as documentation).
# If it returns the runbook, that's acceptable — the runbook is a planning document, not a leak.
```

### 6.3 Old credentials are dead

```bash
# Bybit: from a fresh shell with OLD key in env:
BYBIT_API_KEY='<BYBIT_API_KEY_OLD>' BYBIT_API_SECRET='<BYBIT_API_SECRET_OLD>' \
    python3 -c "from pybit.unified_trading import HTTP; \
                import os; \
                c = HTTP(api_key=os.environ['BYBIT_API_KEY'], api_secret=os.environ['BYBIT_API_SECRET']); \
                print(c.get_wallet_balance(accountType='UNIFIED'))"
# Expected: retCode!=0, message indicates invalid API key. If retCode==0, the OLD key is still
# alive — rotation FAILED. STOP and re-do B.1.1.

# PostgreSQL: from a fresh shell:
PGPASSWORD='<PG_PASSWORD_OLD>' psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -c '\q' 2>&1
# Expected: "FATAL: password authentication failed for user \"tradelens\"". Anything else =
# rotation FAILED. STOP and re-do B.1.2.

# Discord-ingest: from a fresh shell:
curl -s -H 'Authorization: Bearer <DISCORD_INGEST_KEY_OLD>' http://127.0.0.1:8088/api/v1/discord-ingest/config
# Expected: 401 Unauthorized (or whatever the endpoint returns for bad auth). If 200, the OLD
# key is still accepted — rotation FAILED.
```

### 6.4 Remote-side cache purge

GitHub (and similar) retains rewritten objects via the "reflog"-style `objects/pack/` for a window
(~90 days). For maximum hygiene:

- **GitHub:** open a support ticket (https://support.github.com/contact) requesting cached views
  of the affected blobs be purged. Reference SHAs from BEFORE the rewrite (use the snapshot tag
  to retrieve them). GitHub usually performs this within 24-48h.
- **Self-hosted (GitLab/Gitea):** SSH to the server, `cd` into the bare repo, run
  `git gc --prune=now --aggressive`. This purges unreachable objects immediately.
- **Mirrors / Sourcegraph / internal indexers:** trigger re-index per each tool's docs.

Document each cache purge in the operator's own notes:

```
[ ] GitHub blob-cache purge requested (ticket #_____)
[ ] GitLab gc --prune=now --aggressive on bare repo
[ ] <other mirror> re-indexed
```

### 6.5 The example template is committed; the live config is not

```bash
git ls-files tradelens/etc/config.yml.example
# Expected: tradelens/etc/config.yml.example
git ls-files tradelens/etc/config.yml
# Expected: empty.
git check-ignore -v tradelens/etc/config.yml
# Expected: ".gitignore:NN:tradelens/etc/config.yml ..."
```

### 6.6 Pre-commit / secret-scanning hook (optional — recommended)

Install a hook that prevents future drift:

```bash
# Option 1: git-secrets (https://github.com/awslabs/git-secrets)
git secrets --install
git secrets --register-aws   # AWS patterns; not strictly relevant but harmless
git secrets --add 'password\s*[:=]\s*["'\''][^"'\''$][^"'\'']{6,}["'\'']'   # plaintext password literals
git secrets --add 'api_key\s*[:=]\s*["'\''][^"'\''$][^"'\'']{20,}["'\'']'

# Option 2: pre-commit framework hook (https://pre-commit.com/) with detect-secrets
pre-commit install
# Then add detect-secrets hook to .pre-commit-config.yaml.
```

Either approach is opt-in for the operator. AUD-0260 (next step) is the right place to standardize
this across the repo.

## 7. Things to revisit later

- **AUD-0260 (`${VAR}` expansion duplication, T2 in tracker):** there are three implementations of
  env-var expansion in the codebase (`account_context.py`, `batch_ideas.py`, `discord_ingest.py`)
  with subtly different missing-var semantics (raise vs silent default to ""). Phase A above
  references this in §A.2. Until AUD-0260 is closed, every new `${VAR}` expansion in `etc/config.yml`
  is a small landmine — make sure every consumer raises on missing rather than silently using "".
- **AUD-0359 (already resolved):** intentionally left `etc/config.yml.bkup-20251110223555` in place
  pending this runbook. After B.3 succeeds, AUD-0359's deferred-cleanup note can be marked
  satisfied.
- **Quarterly password rotation:** even after this fix, schedule a calendar reminder to rotate the
  PG password every 90 days. Same for the Discord-ingest key. Bybit keys are typically tied to the
  operator's risk profile (rotate on suspicion, not on schedule).
- **Consider adopting a secrets manager:** `~/.tradelens.secrets` is a fine starting point for a
  one-operator deployment. If the team ever grows or if production moves to a multi-host setup,
  graduate to HashiCorp Vault / AWS Secrets Manager / 1Password CLI / `pass`. The env-var
  abstraction in §A makes that future migration a sourcing-script change, not a code change.
- **`accounts.yml`:** is gitignored but holds Bybit credentials per-account. Audit whether any past
  revision of `accounts.yml` was accidentally committed (`git log --all -- tradelens/etc/accounts.yml`).
  If yes, that's a separate AUD- item — same playbook, different file.
- **`SybAdminPwd` in `sourceme.sh`:** flagged in §A.4 and §B.1.2. Decide whether it gets the same
  env-var treatment, and update this runbook (or open a follow-up audit) once decided.

## 8. Questions left for the operator to answer before running

These were flagged inline above; collected here as a single checklist to make the "I'm ready"
go/no-go decision unambiguous.

- [ ] **§1 / threat-model:** is the remote public, private, or mirrored anywhere? List every place.
- [ ] **§A.2:** do all `${VAR}` consumers in tradelens raise on missing-var, or do any silently
      default to `""`? If any silently default, fix AUD-0260 FIRST.
- [ ] **§A.4:** does `sourceme.sh`'s hardcoded `SybAdminPwd=test12345` need to move to env-var? Decide.
- [ ] **§A.6:** is `etc/config.yml` actively read by any cron/systemd unit that runs OUTSIDE the
      `sourceme.sh`-sourced shell? (If yes, those units need their own env-var injection.)
- [ ] **§B.1.1:** where does the running TradeLens application read its Bybit credentials TODAY?
      Trace the loader before rotating, so the rotation doesn't orphan the live app.
- [ ] **§B.1.4:** is invalidating all existing web-push subscriptions acceptable? If yes, rotate
      VAPID. If no, accept VAPID as "not rotated" and document the residual risk.
- [ ] **§B.1.5:** is the Pushover user_key worth rotating, or is rotating just the app_token
      sufficient? Decide based on whether the user_key has been used elsewhere.
- [ ] **§B.2.2:** use `--replace-text` to scrub `test12345` from non-targeted files (e.g.
      `sourceme.sh`)? Or leave it alone and rely on rotation making it irrelevant?
- [ ] **§B.3.3:** push the `pre-aud0353-rewrite-snapshot` tag to the remote, or keep it local-only?
- [ ] **§B.3.4:** are there long-lived branches besides master that need their own force-push?
- [ ] **§6.4:** which remote-side cache purges apply (GitHub support ticket, self-hosted gc,
      mirror re-indexes)?

When every box is ticked, the operator is ready to run §3 (Phase A) and then §4 (Phase B).

## 9. Additional safety warnings (added 2026-04-26 follow-up review)

These are easy-to-overlook side channels. Each is small but each is a credential leak vector if ignored.

### 9.1 Backup tarball is itself a leak

The §2.3 tarball at `/tmp/tradesuite-pre-aud0353-<timestamp>.tgz` contains the **dirty `.git/` history including all exposed secrets in plaintext**. Treat it like the live keys.

- **Storage**: do NOT leave it in `/tmp` unattended. After the §2.3 verification, move it to an encrypted volume or a password-manager-vaulted file. If the operator uses `pass`, GnuPG, or 1Password with file attachments, attach there.
- **Disposal**: once §6 post-flight passes (rotation succeeded, history clean, app running), securely delete the tarball:
  ```bash
  shred -uvz /tmp/tradesuite-pre-aud0353-*.tgz   # GNU shred
  # or
  rm -P /tmp/tradesuite-pre-aud0353-*.tgz        # BSD/macOS
  ```
- **Do NOT** push it anywhere (cloud backup, Dropbox, GitHub release) — that just relocates the leak.

### 9.2 Don't execute on a screen-shared / recorded session

The runbook prints the OLD secrets to terminal at multiple points (§2.1 enumeration, §B.1.x rotation steps where you paste the old key into Bybit's "rotate" form, §6.3 "Old credentials are dead" verification). If your terminal output is being captured anywhere — **stop**:

- Disable screen-sharing in Slack / Zoom / Meet / Teams BEFORE starting.
- Stop any local screen recorder (OBS, QuickTime, Loom).
- Live streams (Twitch, YouTube): pause or end the stream.
- IDE remote-share: kill any "Live Share" / Tuple / Pop / VS Code Live Share session.
- Ensure you are not at a coffee-shop / shared workspace where over-the-shoulder leakage matters.

If anyone else is reviewing your terminal in real-time (pair programming), they need to be on the trust list for these secrets — same as if you handed them the key file.

### 9.3 Scrub the secrets from non-git surfaces

`git filter-repo` only cleans the git repo. The same secrets may be in:

- **Slack / Discord / Teams DMs and channels** — search for `<BYBIT_API_KEY_OLD>`, `test12345`, `<DISCORD_INGEST_API_KEY_OLD>`, `<VAPID_PRIVATE_KEY_OLD>`, `<PUSHOVER_USER_KEY_OLD>`, `<PUSHOVER_APP_TOKEN_OLD>`. Delete + edit messages where present. Slack admin can purge from history.
- **Issue / ticket systems** (Linear, Jira, GitHub Issues, GitLab) — same search. Edit out of issue bodies + comments + close-comments.
- **Paste sites** (Pastebin, GitHub Gist, Hastebin) — delete any that the operator may have used during debug.
- **Email** — `grep` mailbox for the secrets. Delete with extreme prejudice + empty trash.
- **Password manager old entries** — once rotated, old entries should be deleted, not just marked "obsolete." A leaked vault export would still expose them.
- **Cloud sync logs** — Dropbox / iCloud / Google Drive may have versioned the old `etc/config.yml`. Check version history; purge old versions.
- **Local IDE caches** — `.vscode/`, JetBrains `idea` caches, vim swap files. `find . -name '.swp' -delete` and clear IDE search caches.
- **Browser history / form-fill** — if the operator ever pasted a key into a web form, the browser may have it cached. Clear autocomplete data for the relevant forms.

This list is non-exhaustive. The operator should think about **everywhere they have ever interacted with these specific strings** and methodically clean each surface.

### 9.4 Clear terminal scrollback + shell history after execution

The runbook's `echo`, `cat`, and `cat <<EOF >> ~/.tradelens.secrets` steps put plaintext secrets into:

- **Terminal scrollback buffer** (in-memory, persists until window close). Close the terminal window after execution, don't just clear the screen.
- **Shell history file** (`~/.bash_history`, `~/.zsh_history`). Inspect:
  ```bash
  grep -E 'BYBIT_API_KEY|TRADELENS_PG_PASSWORD|test12345|<any-old-secret>' ~/.bash_history ~/.zsh_history 2>/dev/null
  ```
  Edit out matching lines OR truncate the file:
  ```bash
  history -c    # clear in-memory history
  > ~/.bash_history    # truncate the file (or `> ~/.zsh_history`)
  ```
  Better: prefix sensitive commands with a leading space (zsh `setopt HIST_IGNORE_SPACE`, bash `HISTCONTROL=ignorespace`) so they are never recorded — but that has to be configured BEFORE running the runbook.

- **tmux / screen scrollback** (if used). Detach, kill the session, restart.
- **journalctl** or systemd logs — if any service crashed and printed its env, the old secret may be in `journalctl -u <service>` output. `sudo journalctl --vacuum-time=1d` clears it.

### 9.5 Operator-only confirmation before §3 begins

Before running §3 (Phase A), the operator should explicitly write down on paper or in a personal note:

> I, &lt;name&gt;, am about to execute the AUD-0353 + AUD-0354 security runbook. I have:
> - taken and securely stored the §2.3 backup
> - disabled all screen-sharing and screen-recording
> - acknowledged that §B.3 force-push is not reversible on the remote
> - committed to running §6 post-flight checks immediately after §B.3
> - planned the §9.3 non-git scrub immediately after §6

This pre-commitment exists to slow down the irreversible-step transition. The operator who skips it is exactly the operator who later regrets a missed step.
