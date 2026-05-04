# Autonomous audit-autofix run — 2026-04-23/24 extended session

**Session span:** 2026-04-23 (pilot + chunks 1-2) through 2026-04-24 (all chunks + T2 re-triage + T2a execution + security fixes).
**Final state:** 53 commits since master @ `434710d0`, all green.

## Numbers

| Metric | Start (2026-04-23) | End of run | Delta |
|---|---|---|---|
| Tracker `Resolved` | 36 | **123** | **+87** (10% → 34%) |
| Tracker `Confirmed` | 312 | 228 | −84 |
| Tracker `Suspicious` | 17 | 15 | −2 |
| pytest passing | ~503 | **722** | **+219 tests** |
| pytest regressions | — | 0 | clean |
| Commits landed | — | 53 | all green |

## Phase breakdown

### Phase 1 — Pilot + T1 (2026-04-23)

8 commits, 15 findings resolved. Chunks 1-2 T1 queue executed to completion (pg_pool, bybit_client, config.py dead aliases, levelguard dup, LIMIT 1, sizing symbol arg, waep validator loop).

### Phase 2 — T1 autofix chunks 3-14 (2026-04-24 overnight)

Delegated to 3 parallel triage sub-agents + 6 serial execution sub-agents.

**Tracker-only flips** — 1 commit, 22 findings (level_guard fixes landed in prior sprints but tracker never updated, plus 3 false-positive enum claims, plus already-done chunk 10/14 items).

**Group 1 — ops hygiene (chunk 14)** — 5 commits, 4 findings: .gitignore, pyproject dep removal, TRASH/.bkup cleanup, root housekeeping.
**Group 2 — workers (chunk 10)** — 2 commits, 2 findings: `tl` service list derivation, correlation_worker N+1 → ANY.
**Group 3 — API / Discord (chunks 6-8)** — 5 commits, 6 findings: guards CONFIG_DESCRIPTIONS relocation, ideas day-filter DRY, discord.state shim deletion, telegram rename + zoneinfo, Discord filename hashing.
**Group 4 — market data (chunk 9)** — 4 commits, 4 findings: store_pg dup import, mdsync invalid-symbols LRU cap, canonical TIMEFRAME_FALLBACK_ORDER, pg_reader float consistency.
**Group 5 — API chunks 3-4** — 3 commits, 5 findings: open_orders lru_cache + docstring, journal dead aliases + fees log, trades LIMIT 1.
**Group 6 — pipeline (chunk 5)** — 3 commits, 5 findings: hist f-string SELECT parameterization, live Decimal.quantize + is-not-None, pipeline_lock.py delete + lock_step.sh LOCK_DIR env var.

### Phase 3 — T2 re-triage (2026-04-24)

3 parallel sub-agents split the 135+ T2 items into **T2a (auto-executable, 22 items)** vs **T2b (design-required, ~113 items)**. Output:
- `research/audit_autofix/t2_retriage_chunks_1-2.md`
- `research/audit_autofix/t2_retriage_chunks_3-5.md`
- `research/audit_autofix/t2_retriage_chunks_6-14.md`

### Phase 4 — T2a autonomous execution (2026-04-24)

**Group 7 — chunks 1-2 T2a** — 6 commits, 6 findings: config factory, bybit unknown-account guard + balance raise, AccountContext singleton migration, waep tolerance kwarg, risk reader injection, sizing _build_legs extraction. Batch D (AUD-0031 pg_pool raise-on-fallback) correctly halted to T2b — sub-agent discovered legitimate standalone callers.
**Group 8 — chunks 3-5 T2a** — 4 commits, 4 findings: open_orders dead missing_trade branch, pg_reader public .conn, trades markdown formatter relocation, R-metric WARN (test-only — found fix already landed earlier).
**Group 9 — chunks 6-14 T2a** — 9 commits, 9 findings: vwap PooledDB sub-dict, IdeaStatus.carried_fwd enum, suspend place_params scoping, guards regex-fallback WARN, state_manager numeric sort, discord_ingest unexpected-fields log, store_pg autocommit guard, correlation Cache-Control, `tl status --json`.

### Phase 5 — Security + final push (2026-04-24)

**Group 10** — 3 commits, 4 findings (AUD-0174 partial):
- **AUD-0239 SSRF**: `urlparse.hostname` allowlist replacing substring match. 25 regression tests across subdomain suffix, userinfo, scheme downgrade, loopback bypass patterns.
- **AUD-0252 prompt injection**: delimiter-wrap user content in GPT prompts; system-prompt contract updated to treat wrapper contents as untrusted data.
- **AUD-0160 + AUD-0174 (2/3 sites)**: parameterize IN-clause joins in spot-sessions and order-id queries.

## Items correctly held at T2/T3 (stop conditions honoured)

Sub-agents halted on these rather than force-fitting:

**Phase 2 halts (3):**
- **AUD-0260** (discord_ingest env-var helper) — `_expand_env_vars` semantic mismatch (instance method + raises, local copy was silent-default).
- **AUD-0275** (mdsync QUICK_TIMEFRAME_CONFIG) — shares keys with TIMEFRAME_CONFIG but values differ (30d vs 365d lookbacks). Not a strict subset; needs product decision on QUICK_RATIOS / QUICK_OVERRIDES shape.
- **AUD-0177** skipped (no-op) — diagnose_orphan_legs already has sufficient INFO/WARN/DEBUG logging.

**Phase 4 halts (1):**
- **AUD-0031** (pg_pool raise-on-fallback) — discovered legitimate standalone callers (push_sender, ai_snapshot, pushover_sender via pipeline/engine scripts). Raising would break them.

**Phase 5 halts (1):**
- **AUD-0174 site 2** (refresh_order_leg_live.py:2399 cleanup SELECT dynamic WHERE) — part of AUD-0147 primary-writer cluster. Sites 1 and 3 landed.

## Tracker-correction commits

- `232400a2` — AUD-0186 false-positive narrative corrected (`bin/levelguard_cli.py` was a symlink; `.resolve()` follows symlinks on Linux → claimed path-resolution bug was imaginary).
- `2f4ea4f0` — AUD-0363 follow-up tracker flip (concurrent-edit conflict on first attempt).
- `9140a0ef` — 22 tracker-only flips for already-fixed findings not previously reflected.

## Explicitly skipped (T2b / T3 — require user input)

**High-value T2b items flagged by re-triage with "APPROVE" recommendations** but held back for user judgment:

- **AUD-0242** — `trade_idea.source_message_id` indexed dedup. Requires migration 075 + schema.md update; not suitable for overnight autonomous. *Re-triage recommendation:* APPROVE with schema migration; unblocks AUD-0343 + part of AUD-0250.
- **AUD-0213** — hedge-mode wrong-side close in `close_trade`. Money-moving. *Re-triage recommendation:* APPROVE with mandatory test coverage; canonical fix is `filter by position_idx; raise on zero match`.
- **AUD-0241 Phase 1** — move Discord token from chrome.storage.local (plaintext) to chrome.storage.session. Single-file extension edit, low-risk. *Re-triage recommendation:* APPROVE Phase 1 now; HMAC design (Phase 2) deferred.
- **AUD-0111** — preview cache atomic preview+submit. *Re-triage recommendation:* APPROVE atomic approach over Redis (avoids new dep).
- **AUD-0152/0153** — zero → NULL semantics for realized_pnl etc. *Re-triage recommendation:* APPROVE `is not None` check.
- **AUD-0165** — pipeline `"1=1" when empty` archive-all hazard. *Re-triage recommendation:* APPROVE sentinel-based fix to distinguish empty-vs-failed Bybit response.
- **AUD-0136/0144** — NoteEventType enum replacement for string literals. Mechanical but touches 10+ files. *Re-triage recommendation:* could green-light as one sweeping commit.

**~80 other T2b items** — genuinely need design decisions. See the three re-triage files for full listings and per-item recommendations.

**~80 T3 architectural items** — multi-day refactors out of scope for autonomous execution. Key ones:
- `AUD-0058` split 1,781-LOC initial_risk_calculator.py
- `AUD-0192` split 1,582-LOC level_guard_daemon.py
- `AUD-0308/0310` split 6,731-LOC + 3,647-LOC frontend files
- `AUD-0314` split 3,192-LOC api.ts + OpenAPI codegen
- `AUD-0332` wire up vitest (unlocks ~30 frontend T2/T3 items)
- `AUD-0353` rotate Bybit keys + filter-repo secret history (user-only destructive task)
- `AUD-0358` lift test coverage from 4.4% to target
- `AUD-0361` CI/CD + pre-commit infrastructure

## Policy adherence

- **`/test-plan` policy upheld.** Every non-trivial code change shipped with regression tests written BEFORE the fix. Dead-code-removal / config-only exemptions documented in commit messages.
- **Pre-test / post-test gates** on every batch. 722 passing at end, 2 testnet-gated skips, 0 regressions across 53 commits.
- **Stop conditions respected.** 5 items correctly halted rather than force-fitted. None were overridden by improvisation.
- **Money-moving-path discipline.** `level_guard_daemon.py`, `api/trades.py` order-placement, `api/open_orders.py` order-placement, `api/suspend.py` close-flows — only strictly additive changes landed (logging, caches, LIMIT 1, dead-code deletion, helper extraction with parity tests).
- **No unrelated files staged.** `research/swing_levels/*` and other pre-existing working-tree modifications remain untouched.

## Tracker snapshot

```
grep -c "| Resolved |"   AUDIT_TRACKER.md   → 123
grep -c "| Confirmed |"  AUDIT_TRACKER.md   → 228
grep -c "| Suspicious |" AUDIT_TRACKER.md   → 15
```

Total still sums to 366 — no findings lost or duplicated.

## Artefacts for the user

- `tradelens/research/audit_autofix/triage.md` (chunks 1-2 pilot triage)
- `tradelens/research/audit_autofix/triage_chunks_3-5.md`
- `tradelens/research/audit_autofix/triage_chunks_6-9.md`
- `tradelens/research/audit_autofix/triage_chunks_10-14.md`
- `tradelens/research/audit_autofix/t2_retriage_chunks_1-2.md`
- `tradelens/research/audit_autofix/t2_retriage_chunks_3-5.md`
- `tradelens/research/audit_autofix/t2_retriage_chunks_6-14.md`
- `tradelens/research/audit_autofix/run_2026-04-24_status.md` (this file)

## Natural stopping point

Further autonomous execution on T2b items is possible but carries real risk — the remaining findings are either:
1. **Design decisions** with ≥2 reasonable answers (e.g., "threadpool vs async-all vs keep-sync DB lifecycle");
2. **Money-moving non-additive** (e.g., hedge-mode close fixes, retry policy for POSTs without orderLinkId);
3. **Schema-touching** (new indexed columns, migration 075+);
4. **Multi-file signature changes** with external-caller coordination required.

Each would benefit from a quick user read + go/no-go rather than autonomous execution. The re-triage files flag the 5-7 highest-value items where the recommendation is clear.
