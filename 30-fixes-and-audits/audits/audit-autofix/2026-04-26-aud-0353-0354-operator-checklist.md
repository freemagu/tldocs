---
status: operator-checklist
generated: 2026-04-26
audit-ids:
  - AUD-0353
  - AUD-0354
references:
  - 2026-04-26-aud-0353-0354-security-runbook.md (full runbook)
execution-mode: USER-ONLY (Claude does NOT execute destructive steps)
---

# AUD-0353 + AUD-0354 — operator checklist (one-page summary)

This is a one-page summary of the runbook at
`2026-04-26-aud-0353-0354-security-runbook.md`. **Read the full runbook before
acting.** This checklist is for at-a-glance go/no-go decisions, not a substitute
for the runbook itself.

## What I (the operator) must do manually

These are the destructive / irreversible / authentication-bound steps. Claude
cannot do any of them.

| # | Step | Why it's operator-only |
|---|---|---|
| 1 | Rotate Bybit API key + secret in the Bybit dashboard | Requires logged-in dashboard access (2FA, session cookies, possibly hardware key). Claude has no Bybit console session. |
| 2 | Rotate PostgreSQL password (`ALTER ROLE tradelens WITH PASSWORD '<new>'`) | Requires PG admin credentials Claude doesn't have; also requires coordinating with all live connections. |
| 3 | Rotate Discord-ingest API key | Discord admin console access; same auth wall as Bybit. |
| 4 | Decide whether to rotate VAPID keypair (invalidates existing push subscriptions) | Product / UX decision; not a code question. |
| 5 | Decide whether to rotate Pushover user_key (separate from rotating just app_token) | Same as VAPID — product decision. |
| 6 | Take + securely store the §2.3 backup tarball | Encryption key + storage decision is operator-bound. |
| 7 | Run `git filter-repo` to scrub history | Destructive on the local clone; must be coordinated with §1–§5 above. |
| 8 | `git push --force-with-lease` to remote | Irreversible on the remote. Requires push credentials and collaborator coordination. |
| 9 | GitHub / GitLab cache-purge support ticket (if applicable) | Out-of-band channel; only the repo owner can file. |
| 10 | Scrub non-git surfaces (§9.3): Slack / Linear / email / password manager / cloud-sync version history | Each surface has its own auth wall. |
| 11 | Clear terminal scrollback + shell history after execution (§9.4) | Local-machine state Claude cannot reach. |

## What MUST NOT be delegated to Claude (ever, on this runbook)

- ❌ Running `git filter-repo` — irreversible, destructive history rewrite. Even
  with explicit user authorization, Claude declines this category per
  user's standing rules.
- ❌ Force-pushing — same reason. Claude does not push to `master`/`main`
  without explicit per-event authorization, and never force-pushes.
- ❌ Calling Bybit / Discord / Pushover / PG admin APIs to rotate keys live.
  Even with credentials in scope, the rotation is a one-way operation that
  may break the running app; the operator owns the timing.
- ❌ Touching `etc/config.yml.bkup-20251110223555` (the audit row's named
  file) — Claude can read it for enumeration but must not edit / delete /
  rename it before the operator has taken the §2.3 backup.

## What CAN be safely automated later (post-rotation)

These are small, reversible, additive items that a future Claude session can
land as docs-only or low-risk single-AUD ships:

| # | Step | Notes |
|---|---|---|
| 1 | Add `etc/config.yml.example` template (post-Phase-A) | Single file, trivial diff. Claude can ship after operator confirms env-var names. |
| 2 | Add `.gitignore` rule for `etc/config.yml` (post-Phase-A) | One-line addition. Trivial. |
| 3 | Update CLAUDE.md to document the `~/.tradelens.secrets` convention | Docs-only. |
| 4 | Add a `pre-commit` / `git-secrets`-style hook to scan for credential patterns (related to AUD-0260 / AUD-0361) | Separate AUD; design covered in `2026-04-26-aud-0361-cicd-design.md`. |
| 5 | Periodic credential-rotation reminder cron (e.g. quarterly PG password rotation) | Schedule via `/schedule`; not part of this runbook. |

## Exact order

This order is non-negotiable. Skipping or reordering corrupts the safety
guarantees:

1. **§2 Pre-flight** (backup, dashboard access, collaborator notice, clean tree).
2. **§3 Phase A** — convert `etc/config.yml` secrets to `${VAR}` substitution. Test that the app still runs with the env vars. Commit Phase A normally (no force-push).
3. **§4 Phase B-1 — ROTATE FIRST.** All affected credentials. Verify the running app picks up the new values via §6.1 smoke test. Do NOT proceed to §B-2 if any rotation didn't take effect.
4. **§4 Phase B-2 — `git filter-repo`** to scrub history. Verify locally with `git log --all --full-history -- '<file>'` returning empty.
5. **§4 Phase B-3 — force-push** with `--force-with-lease`. Push tags. Notify collaborators they need to re-clone.
6. **§6 Post-flight** — verify all four surfaces (app running, history clean, old creds dead, remote cache purged).
7. **§9.3 Non-git scrub** — Slack / tickets / email / password manager / cloud-sync.
8. **§9.4 Local cleanup** — terminal scrollback, shell history, tmux/screen sessions.
9. **§9.1 Tarball disposal** — `shred` or `rm -P` the §2.3 backup.

## When to **STOP** mid-execution

If any of these fire during §B-1 (rotation), **STOP and re-plan** before
proceeding to §B-2:

- Any rotated credential's smoke-test fails (app reports auth error after env
  reload).
- `~/.tradelens.secrets` doesn't get sourced by `sourceme.sh` (env var still
  empty after `source ./sourceme.sh`).
- Any service refuses to restart after the env change.

If any of these fire during §B-2 (history rewrite):

- `git filter-repo` errors / refuses to run.
- Pre-rewrite snapshot tag wasn't created (`git tag pre-aud0353-rewrite-snapshot`).
- Verification grep finds the old secret still present in any pack file.

If any of these fire during §B-3 (force-push):

- `--force-with-lease` refuses (someone else pushed since the rotation started).
- Remote rejects the push (branch protection wasn't relaxed first).

In all of the above, the safe state is: pause, verify, fix the root cause,
re-run from the affected step. Do NOT skip ahead.

## "Am I ready" checklist

Tick every box before §3 starts:

- [ ] I have read the full runbook end-to-end.
- [ ] I have answered every question in §8 of the runbook.
- [ ] §2.3 backup tarball is taken and stored on an encrypted volume.
- [ ] All screen-sharing / screen-recording is disabled (§9.2).
- [ ] No collaborators will be surprised by the force-push (§2.4 notice sent + acked, OR I am the solo operator).
- [ ] I have a 90-minute uninterrupted block to run §3–§6.
- [ ] I have written the §9.5 pre-commitment note.

When every box is ticked, run §3 (Phase A) → §4 (Phase B) → §6 (post-flight) → §9.3 (non-git scrub) → §9.4 (local cleanup) → §9.1 (tarball disposal). In that order.
