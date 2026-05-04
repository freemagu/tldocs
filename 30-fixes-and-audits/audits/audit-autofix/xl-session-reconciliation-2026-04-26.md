---
status: reconciliation-complete
batch: xl-session-2026-04-26
tracker: "[[AUDIT_TRACKER]]"
generated: 2026-04-26
head-sha: 16538a38
---

# XL session reconciliation — 2026-04-26

## Top-line

| | |
|---|---|
| **HEAD SHA** | `16538a38` (`fix(tl): AUD-0292 — bounded graceful→force kill escalation`) |
| **Pytest** | 1205 passed, 4 skipped, 0 failures |
| **Resolved** | 202 (was 178 at XL start → +24) |
| **Confirmed** | 170 (was 190 → -20) |
| **Suspicious / Needs verification** | 8 (was 9 → -1) |
| **Working tree** | clean apart from system files + symlink + your `docs/chat.txt.gz` (302KB, untracked) |

## Working tree

```
?? .claude/agents/                                                         (system — Claude config)
?? .claude/checkpoints/                                                    (system)
?? ../.claude/                                                             (system)
?? docs/30-fixes-and-audits/audits/audit-autofix/AUDIT_TRACKER.md          (symlink to tracked file)
?? docs/chat.txt.gz                                                        (302KB, modified 10:05 today — assumed your chat export)
```

No staged or unstaged modifications. `bin/tools/find_latest` was earlier showing as deleted; it's now restored on disk via a sub-agent stash cycle — not a regression. Swing-research files remain untracked (your parallel work).

## Pytest classification

All previously-reported intermittent failures during the XL batch (`test_level_guard_*`, `test_aud0214_suspend_typed_adapters.py`, `test_level_b_orchestrator.py::test_hard_stop_check_fails_when_only_sibling_is_terminal`, `test_refresh_order_leg_live_archive_guard.py`) **pass on the full sequential run**. They were flaky / order-dependent / DB-contamination from concurrent test runs during heavy parallel sub-agent dispatch — not real regressions. Classification: **(c) likely from parallel test-pollution under concurrent sub-agents**, not (a) caused by XL session.

## AUD-to-commit mapping (the 7 critical IDs the user flagged)

| AUD ID | Intended fix | Code commit (real) | Tracker / docs commit | Files changed | Tests added | Tracker status | Title correct? | Notes |
|---|---|---|---|---|---|---|---|---|
| **AUD-0086** | TTL cache for `BybitClient.get_instrument_info` | `e9d15d3b` ❌ titled `docs(audit): AUD-0117/0221/0230 → Resolved` | (same) | `lib/tradelens/adapters/bybit_client.py`, `tests/unit/test_aud0086_instrument_info_ttl_cache.py` | 7 (TTL behaviour, force kwarg, per-instance cache) | Resolved | **No** — body says docs but diff is AUD-0086 code. Tracker row references `e9d15d3b` for code (correct) and explains the staging race. |
| **AUD-0117** | Reframed: AI batch async-with-polling (orig was trades.py:1648 `time.sleep`) | `8f7abdfa` ❌ titled `feat(config): AUD-0283` | `e9d15d3b` (docs) + `8016dbfc` (mismatch flag) | `lib/tradelens/api/_batch_jobs.py` (NEW), `lib/tradelens/api/batch_ideas.py` (+178 LOC), `tests/integration/test_aud0117_batch_async_api.py` (NEW), `tests/unit/test_aud0117_batch_jobs_tracker.py` (NEW) | 11 (job tracker primitive + 4 endpoints) | Resolved | **No** — code in commit titled AUD-0283. Reconciliation: opened **AUD-0375** for surviving `time.sleep(0.5)` at trades.py:1648 (the original AUD-0117 concern, not addressed by the async-batch work). |
| **AUD-0125** | Single LATERAL JOIN for `market_summary` | `41255fe3` ❌ titled `feat(config): AUD-0283` | `a23c11af` (provenance note) | `lib/tradelens/api/journal.py` (149 lines), `tests/unit/test_journal_aud0125_market_summary_single_query.py` (NEW) | 6 (single-execute, LATERAL keyword, response shape) | Resolved | **No** — code in commit titled AUD-0283. Tracker has provenance note. |
| **AUD-0214** | Resume routes through typed adapters | `eb60d4d7` ✅ correctly titled | (same) | `lib/tradelens/api/suspend.py`, `tests/unit/test_aud0214_suspend_typed_adapters.py` (NEW), updated `tests/unit/test_aud0006_place_conditional_order_required.py` to add suspend.py call site | 5 (typed adapter routing for trigger / non-trigger paths) | Resolved | **Yes** | No issues. |
| **AUD-0246** | Auth before body parse in Discord ingest | `8f7abdfa` ❌ titled `feat(config): AUD-0283` (also contains AUD-0117, AUD-0283) | (same) | `lib/tradelens/api/discord_ingest.py` (29 lines), `tests/integration/test_discord_ingest_auth_order.py` (NEW) | 4 (malformed body + wrong key → 403; valid body + wrong key → 403; missing key → 422; large payload → 403 fast) | Resolved | **No** — code in mega-commit titled AUD-0283. Tracker explains. |
| **AUD-0281** | Lease-refresh watchdog daemon thread for level_mind_worker | `eef5de75` ✅ correctly titled | (same) | `bin/server/level_mind_worker.py`, `tests/unit/test_aud0281_lease_watchdog.py` (NEW) | 4 (timer fires, stops cleanly, signals ownership loss, refreshes during blocked job) | Resolved | **Yes** for the title; **NO** for the meaning. ID was re-purposed: original tracker concern was the *positive* observation that vwap engines use `singleton_lock` correctly (flagged as good-pattern source for AUD-0182). Reconciliation: opened **AUD-0376** to capture the original concern (Resolved-as-WAI since AUD-0182 already shipped propagation 2026-04-23). |
| **AUD-0283** | Move market-data magic constants to config | `8f7abdfa` ✅ correctly titled — but commit body warns it ALSO carries AUD-0117 / AUD-0246 / AUD-0086 work | `41255fe3` (mis-attributed AUD-0125 lives here under AUD-0283 title), `43ca9753` (clean docs commit) | `etc/config.yml` (+21 lines), `lib/tradelens/mdsync/runner.py`, `lib/tradelens/mdsync/fetcher.py`, `bin/engine/vwap_series_worker.py`, `tests/unit/test_aud0283_market_data_tuning_config.py` (NEW) | 10 (config plumbing for 7 knobs) | Resolved | **Yes** for the title in `8f7abdfa`; but the commit's payload is contaminated with AUD-0117/0246/0086 work. `41255fe3` (also titled AUD-0283) is actually AUD-0125. |

### Augmentation-loss check

Sub-agent reports flagged risk that AUDIT_TRACKER augmentations for AUD-0086 / AUD-0117 / AUD-0281 may have been lost during stash pop/drop cycles. **Verified 2026-04-26: all three rows have full Resolved notes with implementation summaries, regression test paths, and commit references.** Either the loss never materialized, or sub-agents re-applied. No remediation needed.

## Other XL-session AUD-IDs (full inventory)

Cleanly committed and titled correctly:

| AUD | Commit | One-line |
|---|---|---|
| AUD-0259 | `d5ef4953` | tracker-only G close (duplicate of AUD-0240) |
| AUD-0313 | `65d31706` (+`587a150d` SHA backfill) | delete `_t` cache-busting URL interceptor |
| AUD-0322 | `be30e93b` (+`1cf96ec2`) | extract RR help to `.md` via Vite `?raw` |
| AUD-0338 | `6e01926d` | NotFound catch-all route |
| AUD-0339 | `36905b47` | localStorage corrupt-recovery in equity.tsx |
| AUD-0270 | `879f55bb` (+`cb12bbd9`) | inline DDL → migration 078 |
| AUD-0011 | `3b0c13fa` | explicit `httpx.Timeout` for BybitClient |
| AUD-0299 | `5ec0f0fc` (+`7db2d302`) | cycle-scoped DB conn for alert_engine (17 helpers) |
| AUD-0124 | `3dbbd020` (+`9889652e`) | upgrade to `= ANY(%s)` |
| AUD-0220 | `a23c11af` | asyncio.gather + Semaphore(8) for ideas |
| AUD-0080 (+0105) | `1d550ef7` | refuse amend on ticker validation failure |
| AUD-0292 | `16538a38` | bounded graceful→force pkill via shared helper |

## Tracker corrections made (this reconciliation)

1. **AUD-0227** — appended reclassification note → bucket F (T3 architectural). No user identity model exists in TradeLens (no `users` table, no FE auth headers, no JWT/session). Closure requires 5-step epic. Bundled with AUD-0312.
2. **AUD-0303** — appended reclassification note → bucket B (3 picks needed: target location, `psutil` dep, YAML loader fold-in). Self-contained 641-LOC bash, ~300-400 LOC Python target.
3. **AUD-0341** — appended reclassification note → bucket C (schema change + parser updates required when bundled with AUD-0343). Test plan from sub-agent inlined.
4. **AUD-0343** — appended reclassification note → bucket C (bundled with AUD-0341).
5. **AUD-0281** — added clarifying preamble explaining the ID was re-purposed mid-XL-batch (original was vwap singleton_lock WAI confirmation; new is lease-refresh watchdog).
6. **NEW: AUD-0375** opened — surviving `time.sleep(0.5)` at trades.py:1648-1649 (the *original* AUD-0117 concern). Critical/Performance, Confirmed.
7. **NEW: AUD-0376** opened — captures the *original* AUD-0281 row content (vwap engines use `singleton_lock` correctly). Resolved-as-WAI since AUD-0182 shipped propagation 2026-04-23.

No product code changed in this reconciliation pass.

## Remaining blockers / open items

1. **AUD-0227 (security):** moved to F. Real epic. No user model means cross-account access is currently guessable in single-user mode.
2. **AUD-0341 + AUD-0343 (perf, money-adjacent):** bundled in C. Awaiting explicit C-bucket sign-off. Ship requires migration 079 + parser updates in both Telegram and Discord paths. Sub-agent's test plan ready.
3. **AUD-0303 (cleanup):** moved to B. 3 picks needed before dispatch.
4. **AUD-0375 (the surviving original AUD-0117):** Critical/Performance. Worth fixing in a future batch — possibly bundled with AUD-0119 (BackgroundTasks for trade-event writes).
5. **Cross-session staging contamination methodology** — documented in `decisions-pending.md` "Methodology notes". Future-XL must cap parallel sub-agent dispatch at ~3 OR use git worktrees per sub-agent OR have ONE final tracker-update commit per batch by parent.

## Recommended next batch

**A — Cheap clean-up (≤1 hr):**
- Ship **AUD-0375** (surviving `time.sleep(0.5)` in trades.py) — small, well-scoped, single-file. Bundled with AUD-0119 if you want both.
- Bucket-A items still untouched from chunks-11-12 tail re-triage (already classified, ready to tick).

**B — Money-path with explicit sign-off (~3 hrs):**
- **AUD-0271** (candle ingest `ON CONFLICT` batch) — biggest perf win, schema-clean.
- **AUD-0341 + AUD-0343** bundle (trader_scorecard window functions + `source_channel_key` column + migration 079). Sub-agent test plan ready.
- Confirm test stability against concurrent test runs first.

**C — T3 planning (no code ships):**
- **AUD-0227 + AUD-0312** bundle — design a users / auth / FE-headers epic. ~5 phases.
- **AUD-0374** (94 prod orphan filled legs) — sessionization investigation.
- **AUD-0303** (bin/monitor rewrite) — pick one of 3 design options first.

**D — Methodology hardening (one-shot):**
- Document the parallel-dispatch contention rules in `tradelens/CLAUDE.md` so future-Claude-instances cap sub-agent fan-out.
- Optional: build a `tools/audit-batch-dispatch.sh` that runs sub-agents serially against a single index, reducing race surface to zero.

## Provenance

This report is the source-of-truth for the XL session's actual state. The git log titles for `41255fe3`, `8f7abdfa`, and `e9d15d3b` are misleading; trust the AUDIT_TRACKER row notes and this report's mapping table. No history was rewritten.
