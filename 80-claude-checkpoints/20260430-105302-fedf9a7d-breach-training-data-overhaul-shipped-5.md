# Checkpoint: Breach-training data overhaul shipped — 5 commits, 2 retrained models, 2 follow-up items still open

**Saved:** 2026-04-30 10:53:02 UTC
**Working dir:** /app/syb/tradesuite/tradelens
**Git:** master @ 17cbc97b
**Session:** fedf9a7d-c5e3-4180-a600-1bfc35f043fd
**Active task:** none (just closed `20260429-breach-training-data-overhaul` at commit 0992a6f0)

## Handover Statement

You are resuming a productive session in a clean state. The user invoked /t-checkpoint right after closing a multi-hour task that overhauled the breach-decision training dataset end to end. **Nothing is in flight that requires immediate action.** All five commits passed tests, both retrained models exist on disk, the schema is consistent, and the production worker is untouched. Do NOT take any action that touches the breach-decision subsystem until the user gives a fresh instruction — there is no half-finished edit to repair.

The single most load-bearing piece of state is this: **the retrained B7 models (`btc-research-v1-2026-04-30` and `eth-research-v1-2026-04-30`) are research-quality, NOT production-ready.** Their test-fold log-loss is *worse than the base rate* on the 15-second target for both symbols, and calibration makes things *worse* than uncalibrated on most targets. The user's commit message and my last reply explicitly forbid flipping `etc/config.yml` `model_version_btcusdt` / `model_version_ethusdt` to point at these artefacts. Treat them as a starting point for iteration, not a deployable result. The pipeline works end-to-end; model quality is the next research question.

To resume cold, read in this order: (1) the **Handover Statement** you're reading; (2) the **Decisions** section below — it captures the design choices for the schema migrations 093/094/095, the source_type taxonomy, the synthetic level_id encoding, and the multi-breach state machine; (3) the **Rejected approaches** section, especially the schema-loosening alternatives we considered for swing-pivot ingestion, and the per-source training ablations we deferred; (4) the **Files touched** section to know exactly what landed where; (5) `git log --oneline 5c417955..HEAD` to see the commit chain. Skip the Narrative section unless you need the chronological reasoning — it's long.

The exact next-action posture: **wait for user direction.** I gave them three "what's next" options at the end and they checkpointed instead of picking one. The three options were (a) diagnose the bad model metrics via pooled-symbol training, comparison against the production model, and per-source ablation; (b) B9 LevelMindCore wiring (deferred from the session before this one); (c) backfill the existing research-side feature/label tables (`breach_event_features.py`, `breach_event_label.py`) for the 2,316 events we just added. My recommendation is (a). If the user resumes with "let's do option 1" or "diagnose" or anything similar, start with pooled-symbol training — the trainer at `bin/server/breach_decision_train.py` accepts `--symbol BTCUSDT` today, so adding a `--pool BTCUSDT,ETHUSDT,SOLUSDT,...` flag is the first edit. Phase 5 cross-symbol evidence at `docs/40-research/swing-levels/cross_symbol/comparison.md` shows BTC↔ETH features transfer at F1≈0.83 (in-sample), which justifies pooling. Do NOT propose feature engineering or new schema work — those are downstream of pooling.

## Session context

### User's stated goal (verbatim where possible)

The session opened with a /t-checkpoint-load on a prior session, then a status request: *"can we first discuss these issues:- ... 1. 377 status='skipped' rows have atr_anchor=0 ... 2. status='ok' rows accumulate slowly — 12 rows over 3 days = ~4/day"*. Discussion of those issues led the user to conclude the funnel was the problem, then they delivered the substantive ask: *"I thought the breach training was done on agreed levels (not just prior guarded level), for example all the swing highs and swing lows that we wrote a script to generate. And all TPs, DCAs, TTLs, TTPs TBE, Stops as test data?"* — this surfaced that I had been conflating two datasets (breach_event vs breach_decision_log).

The user then refined the spec across multiple turns: *"For breached levels in fact it's not just breach levels but I think we had umm a rule where we were not just checking the breach level once so if it was breached and then price retraced and then it was breached again..."* — this introduced the multi-breach requirement. *"And I'm not sure why you've got by your singling out tbe like tbe rescue why is tbe different to TTP or TTL they are all the same leg types the only difference is the price relative to the waep"* — this corrected my "TBE rescue" framing. *"Please read and understand /app/syb/tradesuite/tradelens/docs/10-architecture/order-leg-classification.md"* — this gave me the family structure (non-trailing tp/be/tl can be limit/conditional-limit/market; trailing_tp/trailing_be/trailing_tl are conditional-market; stop is conditional-market). *"And I spent exit remove out of made that out of scope that is a market order we do not train on market orders make that very clear"* — explicit instruction to filter market orders.

After I produced a 5-task plan covering filter+execute_mode+DCAs, multi-breach, expanded swing-pivot symbols, the user said: *"I want you to do all of this work now"*. After I finished those 5 tasks the user said: *"lets finish the job by working on these: 1. Bridge swing pivots → breach_event ... 4. Actually retrain B7"*. After Item 4 completed and the model metrics were poor, the user closed with `/t-done` then asked "whats next" then `/t-checkpoint`.

### User preferences and corrections established this session

1. **Market orders are out of scope for breach-decision training.** *"that is a market order we do not train on market orders make that very clear"*. Implication: any leg with `order_kind='market'` must be excluded from the training corpus, including suspend_exit (always market) and the market-variants of tp/stop/trailing_*. The dataset filter must enforce this.

2. **TBE is not different from TTP/TTL.** *"why is tbe different to TTP or TTL they are all the same leg types the only difference is the price relative to the waep"*. Implication: the family `{trailing_tp, trailing_tl, trailing_be, auto_trailing_be}` is one structural unit (conditional-market, fail-mode), and the suffix is purely about price-vs-WAEP. Don't write code that special-cases TBE.

3. **Multi-breach per level matters.** *"I think we had umm a rule where we were not just checking the breach level once so if it was breached and then price retraced and then it was breached again and breached again we were checking all of those breaches"*. Implication: breach_event was per-leg-fill (one row per terminated order), but the user wants per-armed-cross (multiple rows per level over its active window). The re-arm state machine in `swing_research/breach_enumerate.py` was the right model to extend.

4. **DCAs are in scope.** Same family as TPs (limit / conditional-limit) but with `execute_mode='hold'`. The original `breach_event_backfill.py` had explicitly excluded DCAs ("DCAs are entries, not protective levels"); the user reversed that.

5. **Order kind is the in/out filter, not leg_type.** *"BE They can both be market orders or they can be limit or even conditional limit orders in some cases ... so let's make it clear let's add the the order type column and make it clear that for the for execute mode fail the order type must be conditional market and for leg type DCA TP betl the order type must be limit which includes conditional limit basically a conditional limit means it's you know it's triggered on a condition conditional price but the it's executed as a limit order so limit is the key here"*. Implication: the filter is `order_kind != 'market'`, NOT a leg_type allowlist. A non-trailing tp can be limit (in scope) or market (out of scope).

6. **suspend_exit is always out, BE-market is always out, resume_* is always out.** *"And be should also be out of scope because a be order is a market order"* (with the later clarification that this means market-variant be only — limit be is in). *"all the resumes should be our [out]"*. *"suspend exit ... that is a market order we do not train on"*.

7. **Hold-mode vs fail-mode polarity is structural, not informational.** *"DCAs and TPs ... will be executed on hold whereas that all of the trailing order types and the stop order type will be executed on fail"*. Implication: the trainer's positive label flips polarity by execute_mode (hold-mode positive = level held; fail-mode positive = level failed). One model with leg-type-derived target sign is the cleaner approach than two separate models.

8. **The user wants ambitious scope completed in one go.** *"I want you to do all of this work now"* and later *"lets finish the job"*. Implication: don't ask for incremental confirmation between subtasks once a multi-step plan is approved. Ship coherent commits per subtask, with tests, with migrations, with bootstrap kept in sync.

### Working environment

- **Production services:** the `level-mind` worker is running with the previous session's deploy (PID 1446183 from 2026-04-29 21:47:16Z). Plan 3 sidecar watchdog active. Active guards are 59 (ONDOUSDT), 60 (AKTUSDT), 75 (BTCUSDT). The retrained models are NOT loaded — `etc/config.yml` still points at `lr-btcusdt-2026-04-25-v1` / `lr-ethusdt-2026-04-25-v1`. We have NOT restarted the worker in this session.
- **Cron:** J9 daily refresh-tick-archive at 03:00 UTC still installed (from prior session). Other crontab entries unchanged.
- **Test DB:** `tradelens_test` is on migration 095 (in lock-step with prod `tradelens`). Both DBs received migrations 093 + 094 + 095 in this session.
- **Background processes from this session:** none. All bg jobs completed.
- **Parallel session activity is heavy.** HEAD is at `17cbc97b` (an AUD-0008 B-4 commit by a parallel session) which landed AFTER my last commit at `0992a6f0`. My commit `0992a6f0` accidentally bundled 8 parallel-session API/test files because they were dirty in the working tree at commit time — same precedent as commit `7562166` from the session-before-last where the user said "leave it". I did NOT cause those edits; I just swept them along.
- **Uncommitted in working tree at checkpoint time:** 9 parallel-session AUD-0008 files (api/* and tests/*) plus an audits AUDIT_TRACKER.md plus 5 phase1_summary_stats.md files I generated. The 5 .md files are blocked by a markdown-location pre-commit gate; same precedent as ETH's existing run, which never committed them either. None of these are mine to deal with.
- **The new model artefacts are at:** `tradelens/data/models/breach_decision/btcusdt/btc-research-v1-2026-04-30/artefact.json` and `tradelens/data/models/breach_decision/ethusdt/eth-research-v1-2026-04-30/artefact.json`. Both are gitignored (per existing convention for `data/models/`).

## Objective

The user's surface goal was a structured re-do of the breach-decision training dataset to give the B7 model a realistic shot at training on real data. The motivation is that B7's production trainer (`bin/breach-decision-train`) reads from `breach_decision_log` filtered to `status='ok' AND realised_label_at IS NOT NULL`, and that table accumulates slowly (~6 ok-rows/day on BTC, 0/day on ETH). At ~50 days from a usable training threshold, organic accumulation isn't viable; we needed to populate the table from existing data.

The deeper goal is to use the historical research datasets — the swing-pivot CSVs the user remembered (`research/swing_levels/phase1/<symbol>/breach_events.csv`) and the order-derived events in `breach_event` — as the training corpus, after structuring them per the user's spec (multi-breach per level, market orders excluded, hold-mode / fail-mode polarity tagged, DCAs included).

Scope explicitly IN: schema migrations to add execute_mode, breach_seq, and loosen NOT NULL on order-specific columns; updating the leg-fill backfill script to filter market orders, include DCAs, and populate execute_mode; a new multi-breach state-machine module + backfill CLI for order-derived levels; running the swing-pivot research pipeline on 5 additional symbols (BTC + ETH already done); a CSV ingest CLI for the swing-pivot data; a feature-pipeline ingest from breach_event into breach_decision_log; running the existing trainer on the resulting dataset.

Scope explicitly OUT (or deferred): re-running `breach_event_features.py` and `breach_event_label.py` for the new rows in their research-side schemas (the trainer uses B7's feature schema, computed fresh during ingest, so research-side analytics stay on their old datasets); B9 LevelMindCore wiring (untouched, foundation still from the session-before-last); investigating the 378 lingering `atr_anchor=0` rows from the Apr 26 production ATR-unavailable window; flipping production model versions in `etc/config.yml`; pooled-symbol training (offered as the recommended next step but not done in this session).

## Narrative: how we got here

The session began with a /t-checkpoint-load resuming the previous day's session. That prior session had ended with the hard-stop refactor shipped (parallel session) and the diagnosis that the orchestrator's "hard-stop precondition not met" filter was rejecting 70% of breaches, which the parallel session had since moved to the guard-creation API. I confirmed the new state empirically and noted ETH still contributed zero rows.

I traced the ETH dispatch gap. Findings: the only-ever ETH guard (id=56) created on 2026-04-16 and executed on 2026-04-17 — both BEFORE the orchestrator went live on 2026-04-26 with bundle B4. ASTER guard 67 created Apr 27 made it through dispatch correctly (1 row, "no model loaded" rejection). Verdict: ETH zero-coverage was operational, not a bug. No code fix needed.

The user pivoted to the bigger question: *"I thought the breach training was done on agreed levels (not just prior guarded level)"*. This caught a real gap in my mental model. I had been treating `breach_decision_log` as the only training corpus when in fact `breach_event` (with 507 rows at that point) was the larger pool, populated from order_leg_hist via `breach_event_backfill.py` and from level_guard_attempt. The swing_research package additionally produced CSV-based event lists in `research/swing_levels/phase1/` from BTC + ETH pivots. I owned the conflation and re-laid out three distinct datasets.

The user then audited what we had, finding leg_type / order_kind gaps. Specifically: 154 of 507 rows in `breach_event` were market orders (mostly tp/market manual-close events), TBE was missing entirely (because `trailing_be` rarely reaches `status='filled'`), and DCAs were excluded by the `EXIT_LEG_TYPES` constant. The user clarified the in-scope rule (`order_kind != 'market'`), corrected my "TBE rescue" framing (TBE is the same family as TTP/TTL — sparse data is the only issue), pointed at `docs/10-architecture/order-leg-classification.md` as the authoritative reference, and surfaced multi-breach per level as a missing requirement. *"I want you to do all of this work now"*.

I shipped the 5-task plan in this order:

**Task 1+2+3 (commit fa2e2fbb):** Migration 093 added `execute_mode VARCHAR(8) NULL CHECK ('hold','fail')`, populated existing rows by leg_type, and deleted 154 market-order rows along with their 630 child labels and 462 child features (no FK cascade existed). I updated `breach_event_backfill.py` to add DCAs to `EXIT_LEG_TYPES`, drop suspend_exit, gate on `order_kind != 'market'`, and populate `execute_mode` via a new `derive_execute_mode()` helper. 18 unit tests in `tests/unit/test_breach_event_backfill_filters.py`. Re-ran the backfill which added 189 new events (108 DCAs + 51 guarded + miscellaneous), bringing the dataset to 542 events.

**Task 4 (commit a726eb24):** Migration 094 added `breach_seq INT NOT NULL DEFAULT 0` and replaced the unique constraint `(source_type, source_ref_id)` with `(source_type, source_ref_id, breach_seq)` so multiple breaches per source order get distinct rows. New module `lib/tradelens/breach_decision/order_level_enumerate.py` with a pure-logic `enumerate_order_breaches(level, candles)` function — same re-arm state machine as `swing_research/breach_enumerate.py` but operating on an `OrderLevel` (level price + active window + swing_type + provenance). New CLI `bin/tools/breach_event_order_level_backfill.py` walks each historical order's active window with 5m candles. 15 unit tests in `tests/unit/test_order_level_enumerate.py` covering active-window honouring, swing_type='high'/'low' polarity, re-arm semantics, chatter suppression, same-bar recovery, rearm=False mode, and provenance round-trip. The backfill processed 1663 orders → 896 with breaches → 1810 total breach events → 1361 new rows after dedup. Distribution validated: 521 orders had 1 breach, 37 had 2, 18 had 3, several had 16-20 (re-armed many times). Bug caught and fixed: parameter order in the SQL placeholders had been `leg_types + status` but the SQL used `status IN (...) AND leg_type IN (...)`, so the first dry run returned 0 rows.

**Task 5 (commit 76eed796):** Configured 4 new symbols (HYPEUSDT, ZECUSDT, XRPUSDT, ASTERUSDT) plus the previously-configured-but-never-run SOLUSDT in `swing_levels_phase1.py` `TICK_SIZES` + `DEFAULT_WINDOWS` dicts. Each window matched the symbol's actual tick-archive coverage queried from `tick_trade_raw_ingest`. Per-symbol results: SOL 198/194/182, HYPE 130/126/117, ZEC 155/153/137, XRP 73/72/64, ASTER 65/64/54 (pivots/kept/breaches). 554 NEW pivot-derived breach events, bringing the swing-pivot dataset across the 7 symbols to 955 events. Outputs landed at `research/swing_levels/phase1/<symbol>/breach_events.csv`. Pre-commit gate blocked the `phase1_summary_stats.md` files; same precedent as ETH's existing run which never committed them either, so I excluded them from the commit and noted this in the message.

After Task 5 the user said "lets finish the job by working on these: 1. Bridge swing pivots → breach_event ... 4. Actually retrain B7".

**Item 1 (commit f68ebdb4):** Migration 095 loosened NOT NULL on `trade_side`, `qty`, `close_type` so non-order events have a place to land. `leg_type` and `exit_direction` stayed NOT NULL because they're meaningful for pivots ('swing_pivot' leg_type; 'above'/'below' by swing_type). `account_id` stayed NOT NULL with the existing -1 sentinel. New CLI `bin/tools/breach_event_swing_pivot_ingest.py` reads each phase1 CSV and inserts with `source_type='swing_pivot'`. `source_ref_id` encoded as `hash12(symbol) * 1_000_000 + event_id` for cross-symbol uniqueness; the script sanity-checks symbol-bucket collisions before inserting. 16 unit tests in `tests/unit/test_breach_event_swing_pivot_ingest.py` covering encoding stability, symbol/event_id separation, bigint fit, no-collisions for the current 7 symbols, CSV row parsing (high/low polarity, tz-aware timestamps, breach_price fallback to level_price for tick-gap rows, blank ATR, malformed input rejection), and module-level constants. 955 events ingested, dataset now at 2858.

**Item 4 (commit 0992a6f0):** New CLI `bin/tools/breach_decision_log_ingest_from_breach_event.py` runs B7's existing `_assemble_features` function over each breach_event row that has tick coverage. For each event: compute `atr_anchor` (use `atr_value` if set, else `wilder_atr(14)` on prior 30m candles), pull pre-breach ticks (60s window) from the tick archive via `TickLoader`, pull prior 5 30m bars, build a `BreachContext`, call `_assemble_features`, insert into `breach_decision_log` with `status='ok'`, `model_version='ingest-research-2026-04-30'`, synthetic `level_id = LEVEL_ID_BASE + breach_event.id` (`LEVEL_ID_BASE = 1_000_000_000`), predictions / decisions NULL. Also fixed `bin/server/breach_decision_train.py` line ~89 to expand `${VAR}` substitutions in the config dict (the trainer was using `get_config()` which doesn't expand env vars; `load_config()` does but returns a typed object the trainer can't use directly — cleanest fix was calling `expand_env_vars_recursive` on the raw dict). Run results: 2364 events inserted (out of 2394 with tick coverage; 30 skipped — no ticks in the precise 60s window; 0 ATR-compute failures). Label backfill found 2369 candidates and labelled all of them; 378 pre-existing `atr_anchor=0` rows from the Apr 26 production window remained unlabelled (known data-quality issue, not from this ingest).

Trained B7 on BTC: 597 labelled rows, splits 417/89/91. Trained B7 on ETH: 327 labelled rows, splits 228/49/50. Both artefacts written to `data/models/breach_decision/<sym>/<version>/`. Test-fold metrics revealed bad calibration: calibrated log-loss > uncalibrated on most targets, BTC 15s log-loss = 1.24 (vs base-rate ~0.69), suggesting the small calibration fold (49–89 rows) is overfitting. Pipeline works end-to-end; quality is the next research question. The commit message and my user-facing summary explicitly forbid flipping `etc/config.yml` `model_version_*` to these artefacts.

The user closed the active task with /t-done. I closed `20260429-breach-training-data-overhaul` at commit `0992a6f0`. The user asked "whats next" — I gave three options (a: diagnose model metrics via pooled training, b: B9 LevelMindCore wiring, c: research-side feature/label backfill) with (a) recommended. The user then invoked /t-checkpoint without picking an option. We are now at the checkpoint moment.

## Work done so far

1. **Migration 093** at `tradelens/migrations/093_breach_event_execute_mode_and_market_filter.sql`. Added `execute_mode VARCHAR(8) NULL` with CHECK constraint, populated by leg_type, deleted 154 market-order rows + 630 labels + 462 features. Status: applied to both DBs, committed in fa2e2fbb.

2. **Migration 094** at `tradelens/migrations/094_breach_event_breach_seq.sql`. Added `breach_seq INT NOT NULL DEFAULT 0`, replaced unique constraint with `(source_type, source_ref_id, breach_seq)`. Status: applied to both DBs, committed in a726eb24.

3. **Migration 095** at `tradelens/migrations/095_breach_event_loosen_for_pivots.sql`. Dropped NOT NULL on `trade_side`, `qty`, `close_type`. Status: applied to both DBs, committed in f68ebdb4.

4. **Updated `breach_event_backfill.py`** at `tradelens/bin/tools/breach_event_backfill.py`. Lines ~46–80 changed: `EXIT_LEG_TYPES` dropped 'suspend_exit' and added 'dca' + 'tl' + 'auto_trailing_be'. Added `DCA_LIKE = {'dca'}`, `EXECUTE_MODE_BY_LEG_TYPE` mapping (lines ~64–74). New `derive_execute_mode()` helper at line ~99. Updated SQL `WHERE` to add `AND (olh.order_kind IS NULL OR olh.order_kind != 'market')` at line ~141. Updated INSERT statements at line ~215 and ~367 to include the `execute_mode` column. Status: committed in fa2e2fbb.

5. **New module `order_level_enumerate.py`** at `tradelens/lib/tradelens/breach_decision/order_level_enumerate.py`. ~190 LOC. Exports `Candle`, `OrderLevel`, `OrderLevelBreach`, `derive_swing_type()`, `enumerate_order_breaches()`. Pure logic — no DB I/O, no clock reads. The state machine matches `swing_research/breach_enumerate.py` but is independent because the swing-research package is intentionally isolated. Status: committed in a726eb24.

6. **New CLI `breach_event_order_level_backfill.py`** at `tradelens/bin/tools/breach_event_order_level_backfill.py`. ~290 LOC. Reads `order_leg_hist` joined to `trade_leg_map` + `trade_journal` + `instrument_meta_cache`, walks each order's active window with 5m candles, calls `enumerate_order_breaches`, inserts via `INSERT ... ON CONFLICT (source_type, source_ref_id, breach_seq) DO NOTHING`. Idempotent. Status: ran successfully (1361 rows inserted), committed in a726eb24.

7. **New CLI `breach_event_swing_pivot_ingest.py`** at `tradelens/bin/tools/breach_event_swing_pivot_ingest.py`. ~290 LOC. Reads each phase1 CSV, encodes `source_ref_id = hash12(symbol) * 1_000_000 + event_id`, inserts with `source_type='swing_pivot'`. Sanity-checks symbol-bucket collisions before inserting. Status: ran successfully (955 rows inserted), committed in f68ebdb4.

8. **New CLI `breach_decision_log_ingest_from_breach_event.py`** at `tradelens/bin/tools/breach_decision_log_ingest_from_breach_event.py`. ~430 LOC. Computes ATR if missing, pulls ticks via TickLoader, pulls 30m bars, builds BreachContext, calls `orchestrator._assemble_features`, inserts into breach_decision_log with `model_version='ingest-research-2026-04-30'`. Synthetic `level_id = LEVEL_ID_BASE + breach_event.id` where `LEVEL_ID_BASE = 1_000_000_000`. Status: ran successfully (2364 rows inserted), committed in 0992a6f0.

9. **Trainer fix** at `tradelens/bin/server/breach_decision_train.py:88-91`. Added `from tradelens.utils.env_expand import expand_env_vars_recursive` and `cfg = expand_env_vars_recursive(cfg, raise_on_missing=True)` so `password: "${TRADELENS_PG_PASSWORD}"` resolves. Status: committed in 0992a6f0.

10. **Phase1 expansion** at `tradelens/bin/tools/swing_levels_phase1.py:101-130`. Added 4 entries to `TICK_SIZES` (HYPEUSDT, ZECUSDT, XRPUSDT, ASTERUSDT) and 4 entries to `DEFAULT_WINDOWS` plus SOLUSDT (already had TICK_SIZES, was missing from runs). Status: committed in 76eed796.

11. **Bootstrap kept in sync** at `tradelens/bin/setup/setup_database_pg.py`. Lines around 1041–1072 reflect all three migrations: `execute_mode` column with CHECK, `breach_seq` column, NOT NULL relaxations on trade_side/qty/close_type, expanded UNIQUE constraint, `idx_breach_event_execute_mode` index. Status: committed across fa2e2fbb / a726eb24 / f68ebdb4.

12. **Schema doc kept in sync** at `tradelens/etc/schema.md` lines ~143–186. Both new columns documented, NOT NULL changes reflected, new index listed, expanded UNIQUE constraint shown. Status: committed across the same three commits.

13. **Three test files added.** `tests/unit/test_breach_event_backfill_filters.py` (18 tests). `tests/unit/test_order_level_enumerate.py` (15 tests). `tests/unit/test_breach_event_swing_pivot_ingest.py` (16 tests). All pass. Status: committed in fa2e2fbb / a726eb24 / f68ebdb4 respectively.

14. **Phase1 ran on 5 new symbols.** Generated CSVs at `tradelens/research/swing_levels/phase1/<sym>/{breach_events,levels_filtered,levels_raw}.csv` for SOL/HYPE/ZEC/XRP/ASTER. Total 554 new events. Status: CSVs committed in 76eed796 (the .md summary stats files are NOT committed — pre-commit gate, same as ETH's pattern).

15. **Two B7 model artefacts trained.** `data/models/breach_decision/btcusdt/btc-research-v1-2026-04-30/artefact.json` (597 rows; 14 features × 4 targets; calibrator + scaler per target). `data/models/breach_decision/ethusdt/eth-research-v1-2026-04-30/artefact.json` (327 rows). Both gitignored. Status: not committed (data/models/ is gitignored), exist on disk only.

16. **Label backfill re-ran.** `bin/server/breach_decision_label_backfill.py --once --limit 5000` processed 2747 candidates, labelled 2369, 378 unlabelled (`atr_anchor=0` from Apr 26 incident). Status: rows updated in `breach_decision_log` only — no code change.

17. **Active task closed.** `claude-task done 0992a6f0` for `20260429-breach-training-data-overhaul`. Context written to `~/.claude/tasks/context/20260429-breach-training-data-overhaul.md`. Status: closed cleanly.

## Decisions made (and why)

1. **Decision:** Use `order_kind != 'market'` as the filter at SQL level, NOT a leg_type allowlist.
   **Proposed by:** user (with the order-leg-classification.md doc citation).
   **Rationale:** A non-trailing tp can be limit, conditional-limit, or market — all classified as `tp`. Filtering by leg_type would either include market closes (wrong) or exclude legitimate limit closes (also wrong). The order_kind filter cleanly captures "has a level" which is the actual training-relevance criterion.
   **Alternatives considered:** Filter by leg_type allowlist (too coarse — see above). Filter by both (redundant).
   **Revisit if:** A new leg_type emerges that is always non-market by definition; the dual filter could simplify.
   **Affects:** `breach_event_backfill.py` SQL line ~141, the migration 093 DELETE clause, the swing-pivot ingest's INSERT (which pre-strips market-only sources).

2. **Decision:** Add `execute_mode VARCHAR(8) NULL` rather than computing it on-demand from leg_type at query time.
   **Proposed by:** user (implicitly — they specified the categories).
   **Rationale:** Trainers and analytics queries will filter by execute_mode constantly. Materialising the value with an index gives stable performance and acts as a contract that this row knows its mode. NULL allowed because non-order events (swing pivots) don't have an execute_mode.
   **Alternatives considered:** Compute via CASE in queries (slow, error-prone). Make NOT NULL with a sentinel (loses ability to mean "N/A").
   **Revisit if:** A leg_type emerges that can fire either mode depending on context — would need an additional column or JSONB.
   **Affects:** Migration 093, schema.md line ~159, bootstrap line ~1054, all INSERT statements that touch breach_event.

3. **Decision:** Loosen NOT NULL on `trade_side`, `qty`, `close_type` for breach_event; keep NOT NULL on `leg_type`, `exit_direction`, `account_id`.
   **Proposed by:** Claude.
   **Rationale:** Swing pivots have no trade behind them, so `trade_side` and `qty` and `close_type` are genuinely undefined. But `leg_type` is informative ('swing_pivot' tells you "this is not order-derived"), `exit_direction` is informative (high pivot → upward breach, low → downward), and `account_id` has an established -1 sentinel for unattributable events. Loosening means schemas tell the truth; sentinels would have lied.
   **Alternatives considered:** All-sentinels approach (trade_side='none', qty=0, close_type='none') — would silently corrupt analytics that filter on trade_side. Mixed (loosen only some) — what we did.
   **Revisit if:** A consumer downstream actually needs trade_side on every row — would force a pivot to all-sentinels.
   **Affects:** Migration 095, bootstrap line ~1051, schema.md line ~157.

4. **Decision:** Add `breach_seq INT NOT NULL DEFAULT 0` and expand the unique constraint to `(source_type, source_ref_id, breach_seq)`.
   **Proposed by:** Claude.
   **Rationale:** The user's multi-breach requirement means one source order produces N rows, but the original UNIQUE was `(source_type, source_ref_id)` which would collide. The default=0 means existing single-breach rows stay valid without a backfill. Multi-breach rows from `order_level_walk` start at 0 and increment.
   **Alternatives considered:** Encode breach_idx into source_ref_id (e.g., `olh_id * 1000 + idx`) — hacky, breaks the FK-ish meaning of source_ref_id. Move uniqueness to a hash of (source_ref_id, breach_idx) — same problem. Add a secondary key column without a unique constraint — would allow duplicates.
   **Revisit if:** breach_seq exceeds 999 in production (currently max observed is 20); the constraint widens fine but indices may need attention.
   **Affects:** Migration 094, bootstrap line ~1069, schema.md line ~177–180, the order-level backfill's INSERT.

5. **Decision:** Use `source_type='order_level_walk'` for multi-breach rows, distinct from `historical_replay`.
   **Proposed by:** Claude.
   **Rationale:** The two have different semantics: `historical_replay` is "the leg fill that terminated the order" (1 per order, the breach that closed it); `order_level_walk` is "every armed cross of the level during the order's active window" (0..N per order). Mixing them under one source_type would make queries that want "leg fill outcomes" indistinguishable from queries that want "all level crosses". The taxonomy is now cleaner.
   **Alternatives considered:** Replace historical_replay rows with order_level_walk's first-cross row — would lose the "this is the breach that filled" signal carried by historical_replay rows that have a real `trade_id`. Keep both under one source_type with a discriminator column — needs a new column anyway.
   **Revisit if:** Analytics queries find the distinction unhelpful.
   **Affects:** Backfill CLI, future labelling/feature pipelines that need to know which source they're looking at.

6. **Decision:** Use 5m candles for the order-level multi-breach walk, not 30m or 1m.
   **Proposed by:** Claude.
   **Rationale:** 30m mirrors the swing-research approach but loses too much resolution for shorter-active orders (e.g., an order active for 1h gets 2 bars, can't really show multi-breach). 1m gives 60 bars/hour but produces excessive same-bar chatter that the re-arm rule has to suppress, and the volume of data is large. 5m is the sweet spot: 12 bars/hour, enough resolution for typical order activity, manageable data volume.
   **Alternatives considered:** 30m (per swing-research) — too coarse for short-active orders. 1m — too noisy, candle volume large. Adaptive (1m for short windows, 30m for long) — added complexity without clear benefit.
   **Revisit if:** The re-arm rule misses meaningful crosses on long-active orders, or the multi-breach distribution shows excessive 1-breach orders that shorter timeframes would have caught.
   **Affects:** `breach_event_order_level_backfill.py` `--timeframe 5m` default.

7. **Decision:** Encode source_ref_id for swing pivots as `hash12(symbol) * 1_000_000 + event_id`.
   **Proposed by:** Claude.
   **Rationale:** Each phase1 CSV has `event_id` starting at 1 per symbol, so naive use would collide. Encoding gives a deterministic globally-unique bigint with the event_id recoverable. 12-bit hash = 4096 possible buckets; with ~100 symbols actively in scope, birthday collision odds are negligible. The script sanity-checks for collisions before inserting.
   **Alternatives considered:** Add `symbol` to the unique key (breaks the existing semantic where source_ref_id is the unambiguous referent within a source_type). Use a globally-counter `swing_pivot.id` table (extra schema). Use full SHA256 truncated (overkill, harder to debug).
   **Revisit if:** Symbol count grows enough to make collisions likely (>~50 symbols in active use), or if a collision actually fires the script's sanity check.
   **Affects:** `breach_event_swing_pivot_ingest.py:encode_source_ref_id`.

8. **Decision:** Synthetic `level_id = LEVEL_ID_BASE + breach_event.id` where `LEVEL_ID_BASE = 1_000_000_000` for breach_decision_log ingest rows.
   **Proposed by:** Claude.
   **Rationale:** breach_decision_log requires `level_id NOT NULL`. For ingested rows we have no real level_id (these aren't tied to a guard). The base-1G ensures no collision with real guard_ids (currently in the 50-100 range, plus order_leg_live_ids in the thousands — both << 1G). The encoding lets us recover breach_event.id by subtraction, useful for joins.
   **Alternatives considered:** Migrate level_id to nullable (out of scope, breaks production code). Use breach_event.id directly (could collide with future guard_ids if production ever creates 100M+ guards — implausible but cheap to defend against).
   **Revisit if:** breach_event grows past 1G rows (extremely unlikely).
   **Affects:** `breach_decision_log_ingest_from_breach_event.py:LEVEL_ID_BASE`.

9. **Decision:** Use `model_version='ingest-research-2026-04-30'` as a sentinel for ingested rows; predictions/decisions stay NULL.
   **Proposed by:** Claude.
   **Rationale:** The ingested rows are not historical inferences — no model ran on them at the time of breach. Setting a real `model_version` would falsely claim they were predictions. The dated tag makes them queryable as a coherent batch. Predictions NULL means downstream consumers (the trainer) treat them as labelled-only training data.
   **Alternatives considered:** Use the production model version (would lie about provenance). Use an empty string (loses queryability).
   **Revisit if:** Downstream code requires non-null predictions.
   **Affects:** `breach_decision_log_ingest_from_breach_event.py:MODEL_VERSION_TAG`.

10. **Decision:** Trainer fix uses `expand_env_vars_recursive(get_config())` rather than switching to `load_config()`.
    **Proposed by:** Claude.
    **Rationale:** `load_config()` returns a typed dataclass-like object the trainer would have to refactor to use; `get_config()` returns a dict that works with the existing `psycopg2.connect(**kwargs)` pattern. The 2-line fix preserves the trainer's structure.
    **Alternatives considered:** Refactor trainer to use `load_config()` + extract dict (more invasive). Hardcode password (security regression).
    **Revisit if:** The trainer adopts the typed config object for other reasons.
    **Affects:** `bin/server/breach_decision_train.py:89-91`.

## Rejected approaches (and why)

1. **Approach:** Filter market orders by adding suspend_exit, market-only-tp, etc. to a leg_type denylist.
   **Who proposed it:** Claude (initial sketch).
   **Why rejected:** The user pointed at `order-leg-classification.md` and clarified that the same leg_type can be limit OR market depending on `order_kind`. A leg_type denylist would either over-include (treat market-tp as in-scope) or over-exclude (drop legitimate limit-tp). The order_kind filter at SQL level is the right cut.
   **Would we reconsider if:** The leg_type taxonomy ever evolves so that order_kind is fully determined by leg_type — but the doc shows that's not the case today.

2. **Approach:** "TBE rescue" — special-case TBE because it has zero coverage.
   **Who proposed it:** Claude (in the user-facing summary about the data shape).
   **Why rejected:** User correction: *"why is tbe different to TTP or TTL they are all the same leg types the only difference is the price relative to the waep"*. The zero-coverage issue is a count problem (only 2 trailing_be created in production, none filled), not a category one. Special-casing TBE would have been wrong code.
   **Would we reconsider if:** Never. The classification doc cements the family structure.

3. **Approach:** Schema-only solution: keep breach_event order-derived, add a new `swing_pivot_breach` table for pivots.
   **Who proposed it:** Claude (briefly considered before settling on loosening NOT NULL).
   **Why rejected:** Two tables with the same semantic (a breach event) but different schemas would force every downstream consumer (label backfill, feature backfill, trainer ingest) to handle both. The cost of loosening 3 NOT NULL constraints is much lower.
   **Would we reconsider if:** A schema divergence emerges that NULL columns can't paper over (e.g., pivots need a column orders don't have).

4. **Approach:** Strip realised_label_at and use the rows as raw "training data" without label backfill.
   **Who proposed it:** Claude (briefly, when worrying about label backfill cost).
   **Why rejected:** The trainer requires `realised_label_at IS NOT NULL` as part of its filter. Stripping the requirement means trainer ingest path needs forking. Re-running label backfill is cheap and uses existing code.
   **Would we reconsider if:** Label backfill becomes prohibitively slow at scale (currently fine — 2369 rows in <1 minute).

5. **Approach:** Train per-symbol models for all 7 swing-pivot symbols.
   **Who proposed it:** Claude (would have been thorough).
   **Why rejected:** Time budget — only BTC and ETH have enough rows (>=200) to train at the default `--min-rows`. The smaller-symbol models would have failed the threshold. Documented in the commit as deferred.
   **Would we reconsider if:** The user wants per-symbol training and accepts lowering `--min-rows`.

6. **Approach:** Pooled-symbol training in this session.
   **Who proposed it:** Claude (recommended as the next step).
   **Why rejected:** Out of scope for the "Item 4: Actually retrain B7" item — the user asked to retrain, which produced the per-symbol artefacts. Pooled training requires adding a `--pool` flag to the trainer, which is a separate piece of work. Recommended as the immediate next step.
   **Would we reconsider if:** Always — it's the highest-value next experiment.

7. **Approach:** Auto-flip `etc/config.yml` `model_version_*` after training succeeds.
   **Who proposed it:** Claude (briefly).
   **Why rejected:** The metrics are bad. Auto-flipping a research-quality model into production would cause real harm. The commit message explicitly forbids this.
   **Would we reconsider if:** Metrics are validated against the production model and shown to be at-parity-or-better.

8. **Approach:** Add the production model's training-time metrics to its artefact JSON for comparison.
   **Who proposed it:** Claude (thought about it for the diagnosis option).
   **Why rejected:** Out of scope for Item 4. Worth doing as part of option (a) in the "what's next" recommendation.
   **Would we reconsider if:** The user picks option (a).

9. **Approach:** Trim the 8 unrelated parallel-session files out of the Item 4 commit by separately committing them first.
   **Who proposed it:** Implicitly considered when the commit bundled them.
   **Why rejected:** Established precedent — earlier commit `7562166` bundled parallel-session deletions and the user said *"leave it"*. The bundling is annoying but harmless; separating would require deeper coordination with the parallel session.
   **Would we reconsider if:** The user explicitly asks for separation in future commits.

## Files touched or about to touch

1. `tradelens/migrations/093_breach_event_execute_mode_and_market_filter.sql`
   - **Status:** edited-saved, committed in fa2e2fbb. Applied to both DBs.
   - **What's there:** Adds `execute_mode VARCHAR(8) NULL CHECK ('hold','fail')`, populates by leg_type, deletes 154 market-order rows + 630 labels + 462 features.
   - **Why it matters:** Foundation for all subsequent execute_mode-aware code.
   - **Cross-refs:** Decision #2 (add column). Affects backfill scripts.

2. `tradelens/migrations/094_breach_event_breach_seq.sql`
   - **Status:** edited-saved, committed in a726eb24. Applied to both DBs.
   - **What's there:** Adds `breach_seq INT NOT NULL DEFAULT 0`. Replaces UNIQUE (source_type, source_ref_id) with UNIQUE (source_type, source_ref_id, breach_seq).
   - **Why it matters:** Lets multi-breach rows coexist with single-breach rows under the same source_ref_id.
   - **Cross-refs:** Decision #4. Required by `breach_event_order_level_backfill.py`.

3. `tradelens/migrations/095_breach_event_loosen_for_pivots.sql`
   - **Status:** edited-saved, committed in f68ebdb4. Applied to both DBs.
   - **What's there:** Drops NOT NULL on trade_side, qty, close_type.
   - **Why it matters:** Lets `swing_pivot` rows insert without sentinel values.
   - **Cross-refs:** Decision #3. Required by `breach_event_swing_pivot_ingest.py`.

4. `tradelens/lib/tradelens/breach_decision/order_level_enumerate.py` (~190 LOC, NEW)
   - **Status:** edited-saved, committed in a726eb24.
   - **What's there:** `OrderLevel`, `OrderLevelBreach`, `Candle`, `derive_swing_type()`, `enumerate_order_breaches()`. Pure-logic re-arm state machine.
   - **Why it matters:** Core algorithm for multi-breach enumeration. Mirror of `swing_research/breach_enumerate.py` — kept independent for module isolation.
   - **Cross-refs:** Decision #5 (separate source_type), used by `breach_event_order_level_backfill.py`.

5. `tradelens/bin/tools/breach_event_order_level_backfill.py` (~290 LOC, NEW)
   - **Status:** edited-saved, ran successfully (1361 rows inserted), committed in a726eb24.
   - **What's there:** Reads order_leg_hist + trade_leg_map + trade_journal + instrument_meta_cache. For each order: derives active window (created_at → terminal_time), pulls 5m candles, calls `enumerate_order_breaches`, inserts via ON CONFLICT.
   - **Why it matters:** Populates the largest single source of training events.
   - **Cross-refs:** Decision #6 (5m candles), Decision #5 (source_type).

6. `tradelens/bin/tools/breach_event_swing_pivot_ingest.py` (~290 LOC, NEW)
   - **Status:** edited-saved, ran successfully (955 rows inserted), committed in f68ebdb4.
   - **What's there:** Reads phase1 CSVs, encodes source_ref_id, inserts with source_type='swing_pivot'.
   - **Why it matters:** Bridges the swing-research dataset into the database for the first time.
   - **Cross-refs:** Decision #7 (source_ref_id encoding), Decision #3 (NULL columns).

7. `tradelens/bin/tools/breach_decision_log_ingest_from_breach_event.py` (~430 LOC, NEW)
   - **Status:** edited-saved, ran successfully (2364 rows inserted), committed in 0992a6f0.
   - **What's there:** For each breach_event row: compute ATR, pull ticks, pull bars, build BreachContext, call `_assemble_features`, insert into breach_decision_log with status='ok'.
   - **Why it matters:** Closes the loop from breach_event → breach_decision_log → trainer.
   - **Cross-refs:** Decisions #8 (level_id), #9 (model_version sentinel).

8. `tradelens/bin/tools/breach_event_backfill.py`
   - **Status:** edited-saved, committed in fa2e2fbb. Multiple changes around lines 46–80 (constants), ~99 (derive_execute_mode), ~141 (SQL filter), ~215 + ~367 (INSERTs).
   - **What's there before:** Excluded DCAs, no execute_mode, no order_kind filter.
   - **What's there now:** Includes DCAs + tl + auto_trailing_be, populates execute_mode, filters market orders.
   - **Cross-refs:** Decision #1 (order_kind filter), Decision #2 (execute_mode column).

9. `tradelens/bin/tools/swing_levels_phase1.py`
   - **Status:** edited-saved, committed in 76eed796. Lines ~101–130 (TICK_SIZES + DEFAULT_WINDOWS).
   - **What's there now:** 7-symbol coverage (was BTC + ETH + SOL configured-but-not-run; now all 7 plus 5 new windows for HYPE/ZEC/XRP/ASTER).
   - **Why it matters:** Generated the 5 new CSV directories at `research/swing_levels/phase1/`.

10. `tradelens/bin/server/breach_decision_train.py:88-91`
    - **Status:** edited-saved, committed in 0992a6f0.
    - **What's there before:** `cfg = get_config()` then `psycopg2.connect(... password=db_cfg["password"] ...)` which used the literal "${TRADELENS_PG_PASSWORD}" string.
    - **What's there now:** Added `from tradelens.utils.env_expand import expand_env_vars_recursive` and `cfg = expand_env_vars_recursive(cfg, raise_on_missing=True)`.
    - **Why it matters:** Without this the trainer fails with `FATAL: password authentication failed for user "tradelens"`.

11. `tradelens/bin/setup/setup_database_pg.py`
    - **Status:** edited-saved across fa2e2fbb / a726eb24 / f68ebdb4. Lines ~1041–1072 (breach_event DDL) and ~1287–1291 (indices).
    - **What's there now:** Bootstrap matches all three migrations.

12. `tradelens/etc/schema.md` lines ~143–186
    - **Status:** edited-saved across same three commits.
    - **What's there now:** All column changes + index additions reflected.

13. `tradelens/tests/unit/test_breach_event_backfill_filters.py` (NEW, 18 tests)
14. `tradelens/tests/unit/test_order_level_enumerate.py` (NEW, 15 tests)
15. `tradelens/tests/unit/test_breach_event_swing_pivot_ingest.py` (NEW, 16 tests)
    - **Status:** all committed, all green.
    - **Why they matter:** Pin the EXIT_LEG_TYPES membership, derive_execute_mode mapping, exit_direction polarity, encoding stability, state-machine correctness, CSV parsing edge cases. Compaction-resistant via test names.

16. `tradelens/research/swing_levels/phase1/{solusdt,hypeusdt,zecusdt,xrpusdt,asterusdt}/{breach_events,levels_filtered,levels_raw}.csv` (NEW, 15 files)
    - **Status:** committed in 76eed796.
    - **Why they matter:** Source data for the swing_pivot ingest.

17. `tradelens/research/swing_levels/phase1/<sym>/phase1_summary_stats.md` for the 5 new symbols
    - **Status:** generated on disk but NOT committed (pre-commit gate, same precedent as ETH).
    - **Why it matters:** Regenerable by re-running phase1; stays out of the way.

18. `tradelens/data/models/breach_decision/btcusdt/btc-research-v1-2026-04-30/artefact.json` (NEW)
19. `tradelens/data/models/breach_decision/ethusdt/eth-research-v1-2026-04-30/artefact.json` (NEW)
    - **Status:** on disk only. data/models/ is gitignored by repo convention.
    - **Why they matter:** First B7 retrain output. Research-quality, not for production.

## Open threads

1. **Thread:** Pooled-symbol training experiment.
   **State:** Not started. Recommended in my closing reply but the user has not picked an option yet.
   **Context needed to resume:** `bin/server/breach_decision_train.py` — the trainer currently takes a single `--symbol`. Adding a `--pool` flag (comma-separated symbols, fetch_labelled_dataset accepts list) is the first edit. Then run with `--pool BTCUSDT,ETHUSDT,SOLUSDT,HYPEUSDT,ZECUSDT,XRPUSDT,ASTERUSDT --version pool-research-v1-2026-04-30 --min-rows 500`. Phase 5 evidence at `docs/40-research/swing-levels/cross_symbol/comparison.md` justifies pooling.
   **Expected resolution:** A pooled-model artefact with calibrated log-loss <= base-rate on at least 3 of 4 horizons.

2. **Thread:** Comparison of new models against production `lr-btcusdt-2026-04-25-v1`.
   **State:** Not done. The production model's training-time metrics aren't logged in its artefact JSON (verified by reading the schema in our run output — only training metadata is included).
   **Context needed to resume:** Read `data/models/breach_decision/btcusdt/lr-btcusdt-2026-04-25-v1/artefact.json` to see what's there. May need a separate eval script that runs the production model on our 597 BTC labelled rows in evaluation mode.
   **Expected resolution:** A printed comparison table showing test-fold metrics for both models on the same dataset.

3. **Thread:** Per-source ablation training.
   **State:** Not done. Three trainings: only swing_pivot rows, only order_level_walk rows, only historical_replay+guarded rows.
   **Context needed to resume:** Trainer needs filtering by source_type. Currently filters by symbol only. Adding source_type filter requires a small `fetch_labelled_dataset` change. The level_id encoding (LEVEL_ID_BASE + breach_event.id) lets us join back to `breach_event` to get source_type.
   **Expected resolution:** Three artefacts with comparable metrics, identifying which source produces the best signal.

4. **Thread:** B9 LevelMindCore wiring.
   **State:** Carried over from session-before-last. Foundation (table `level_reclaim_state` + state engine + persistence + 14 tests) shipped in commit `7444e638`. Wiring into `level_mind_core._handle_breached_*` is deferred.
   **Context needed to resume:** The parallel session's level-guard refactor (commits `45995f9`, `d21e149`, `f007363`, `a015ce6`, `aceda4c`, `6713119`) moved related code; need `git show --stat` on each to know where the hook points are now. Also `docs/10-architecture/b9-reclaim-mode-plan.md` step 3 documents the surgery.
   **Expected resolution:** A new commit `feat(breach-decision): B9 — wire reclaim_state into LevelMindCore`.

5. **Thread:** 378 lingering atr_anchor=0 rows from the Apr 26 production window.
   **State:** Untouched. Open since session-before-last. Pre-existing data-quality issue, not caused by anything in this session.
   **Context needed to resume:** `tail -50 logs/breach_decision_label_backfill.log` shows the WARNING messages. Trace orchestrator code path that writes status='skipped' rows with atr_anchor=0 instead of refusing the row.
   **Expected resolution:** Either a code fix that prevents future zero-ATR rows, or a doc that explains why they're acceptable.

6. **Thread:** Research-side feature/label backfill for the 2316 new events.
   **State:** Not done. `breach_event_features.py` and `breach_event_label.py` haven't been re-run since the multi-breach + swing-pivot ingests added 2316 rows. They currently know about only 352 of the 2858 events.
   **Context needed to resume:** `bin/tools/breach_event_features.py` runs in versions v1/v2/v3 (all 352 events have all 3 versions). Re-run for the new events — same script, no code change. Then `bin/tools/breach_event_label.py` for the labelling run.
   **Expected resolution:** All 2858 events have v1/v2/v3 features and a research-style label.

7. **Thread:** Operational ETH guard creation.
   **State:** ETH has zero ok-rows in production breach_decision_log because no ETH guards have been created since the orchestrator went live. This isn't a code issue — it's the user's strategy. May or may not get addressed.
   **Context needed to resume:** N/A — the user creates guards by trading.

8. **Thread:** Phase1 summary md files unused.
   **State:** Pre-commit gate blocks them. Same as ETH precedent.
   **Context needed to resume:** None unless we want to change the gate. The summaries are regenerable.

## Surprises / gotchas

1. **Finding:** breach_event_label and breach_event_feature have NO foreign key cascade to breach_event. Migration 093's DELETE had to clean them up explicitly.
   **How we discovered it:** Ran `\d breach_event_label` and grepped for foreign keys; got zero. Then queried `pg_constraint` to confirm.
   **Time cost:** ~5 minutes to rewrite the migration with the explicit cleanup.
   **Implication:** Any future DELETE on breach_event must clean up child tables explicitly.
   **Where it's documented:** Migration 093 SQL comment.

2. **Finding:** trailing_be never reaches `status='filled'` in production order_leg_hist — they all transition through `lg_replaced` or `deactivated`.
   **How we discovered it:** Query `SELECT leg_type, status, COUNT(*) FROM order_leg_hist WHERE leg_type='trailing_be' GROUP BY 1,2;` returned only `lg_replaced=2, deactivated=1`. Auto_trailing_be similar (all `lg_replaced`).
   **Time cost:** Initially confused me into thinking TBE backfill was broken; user corrected.
   **Implication:** TBE coverage in the leg-fill backfill is and will remain near-zero. Multi-breach picks them up if they're active long enough, but they're sparse. Not a code issue — production data shape.
   **Where it's documented:** Earlier session findings + this checkpoint.

3. **Finding:** SQL parameter order matters even with placeholders if the same statement uses two different IN-lists.
   **How we discovered it:** First dry-run of `breach_event_order_level_backfill.py` returned 0 rows. The SQL had `WHERE status IN (...) AND leg_type IN (...)` but the params list was `IN_SCOPE_LEG_TYPES + ACTIVE_STATUSES` — order mismatch. The IN-clauses got swapped, status got compared against leg_type values, no matches.
   **How we discovered it:** Compared the SQL clause order to the params list, spotted the mismatch.
   **Time cost:** ~5 minutes.
   **Implication:** When using multiple IN-lists in one query, order params explicitly to match clause order.
   **Where it's documented:** Code comment at the params= line in `breach_event_order_level_backfill.py`.

4. **Finding:** TickLoader expects naive-UTC timestamps, but breach_event stores tz-aware.
   **How we discovered it:** First call to `loader.load(symbol, breach_ts, window_start, window_end)` with tz-aware timestamps returned None (silent failure). Read `breach_analysis/tick_loader.py:73` docstring: "All timestamps should be naive UTC".
   **Time cost:** ~10 minutes.
   **Implication:** Strip `.tzinfo` before calling TickLoader, re-attach UTC after fetching.
   **Where it's documented:** `breach_decision_log_ingest_from_breach_event.py:fetch_pre_breach_ticks` has a comment + the conversion logic.

5. **Finding:** `get_config()` does NOT expand `${VAR}` substitutions in the YAML; `load_config()` does (via `expand_env_vars_recursive`), but returns a typed object.
   **How we discovered it:** Trainer failed with `psycopg2.OperationalError: FATAL: password authentication failed for user "tradelens"` because `db_cfg["password"]` was the literal string `"${TRADELENS_PG_PASSWORD}"`.
   **Time cost:** ~5 minutes.
   **Implication:** Any new code that uses `get_config()` directly with credentials must call `expand_env_vars_recursive` itself.
   **Where it's documented:** Fix at `breach_decision_train.py:88-91` with a comment.

6. **Finding:** breach_event_backfill's existing INSERT had INSERT-from-historical_replay and INSERT-from-guarded as separate code paths with different placeholder counts.
   **How we discovered it:** Reading the file before editing.
   **Time cost:** Zero — surfaced before causing a bug.
   **Implication:** Both INSERTs needed the new `execute_mode` placeholder added; missing one would silently NULL out the column for that source.
   **Where it's documented:** Both INSERTs share the same column-list shape now.

7. **Finding:** breach_event CSV has empty `breach_price` for some swing-research events past tick-gap days.
   **How we discovered it:** First parser run threw `decimal.InvalidOperation: [<class 'decimal.ConversionSyntax'>]` on row 8 of BTC's CSV.
   **Time cost:** ~5 minutes.
   **Implication:** Fall back to `level_price` when breach_price is empty (the level was crossed by definition; tick refinement just couldn't pin the exact crossing price).
   **Where it's documented:** Comment in `breach_event_swing_pivot_ingest.py:parse_csv_row`.

8. **Finding:** The pre-commit hook auto-bundles dirty files in the working tree even when `git add` was selective.
   **How we discovered it:** Item 4 commit (`0992a6f0`) bundled 8 unrelated parallel-session API/test files even though I only `git add`-ed two specific files. Same pattern as commit `7562166` from the session-before-last.
   **Time cost:** Zero — user said "leave it" in the prior session.
   **Implication:** When working alongside a parallel session, expect commits to include their dirty files. Don't try to separate.
   **Where it's documented:** Memory note from prior session + this checkpoint.

9. **Finding:** Calibration regresses test-fold log-loss for both models (logloss_cal > logloss_uncal on most targets).
   **How we discovered it:** Looking at the trainer's printed metrics table.
   **Time cost:** Not chased — flagged as the open quality question.
   **Implication:** Either the calibration fold is too small (89 BTC, 49 ETH; isotonic regression overfits), or the data is genuinely heterogeneous in a way calibration can't fix. Pooling symbols would expand the calibration fold to ~200+; that's the recommended next experiment.
   **Where it's documented:** Commit message of `0992a6f0` and this checkpoint.

## Commands that mattered

1. **Command:** `PGPASSWORD=tradelens_poc psql ... -c "SELECT source_type, leg_type, order_kind, execute_mode, COUNT(*) FROM breach_event GROUP BY 1,2,3,4 ORDER BY 1,5 DESC;"`
   **Output (relevant portion):** Confirmed final state — 542 events, all with execute_mode populated, no market orders, 276 hold + 266 fail. 14 distinct (source_type, leg_type, order_kind, execute_mode) combinations.
   **What we inferred:** Migration 093 + backfill update worked correctly.

2. **Command:** `python3 bin/tools/breach_event_order_level_backfill.py` (full run)
   **Output:** "Orders processed: 1663 / Orders with breaches: 896 / Total breaches seen: 1810 / New rows inserted: 1361"
   **What we inferred:** Multi-breach enumeration produced 1361 new training events. Average 2.0 breaches per "with breaches" order, with a long tail (some had 16-20).

3. **Command:** `python3 bin/tools/breach_event_swing_pivot_ingest.py`
   **Output:** "TOTAL inserted: 955" across 7 CSVs.
   **What we inferred:** All 7 swing-pivot CSV symbols ingested cleanly. No collisions detected. No invalid rows.

4. **Command:** `python3 bin/tools/breach_decision_log_ingest_from_breach_event.py`
   **Output:** "Inserted (status='ok'): 2364 / Skipped — no ticks: 30 / Skipped — assembly error: 0"
   **What we inferred:** 99% of tick-covered events ingestable. The 30 skips were edge cases where the precise 60s pre-breach window had no ticks (likely sparse-volume periods).

5. **Command:** `python3 bin/server/breach_decision_label_backfill.py --once --limit 5000`
   **Output:** "{'candidates': 2747, 'labelled': 2369, 'no_data': 378}"
   **What we inferred:** All 2369 newly-ingested rows got labels. The 378 no_data rows are pre-existing atr_anchor=0 from the Apr 26 production window.

6. **Command:** `python3 bin/server/breach_decision_train.py --symbol BTCUSDT --version btc-research-v1-2026-04-30 --min-rows 200`
   **Output:** First failed with auth error (env-var expansion bug), then after the fix: "Training BTCUSDT with 597 labelled rows ... splits: train=417 calibration=89 test=91". Test metrics table showed safe_delay_15s logloss_uncal=1.2351 logloss_cal=3.8720 — calibration regression.
   **What we inferred:** Pipeline works end-to-end. Model quality requires investigation. Recommended pooled-symbol training as the diagnostic next step.

7. **Command:** `git log --oneline 5c417955..HEAD --grep="breach"` (informally during summarization)
   **Output:** 5 of my commits visible: fa2e2fbb / a726eb24 / 76eed796 / f68ebdb4 / 0992a6f0.
   **What we inferred:** Commit chain intact, parallel-session interspersing didn't lose anything.

## Schema / API / data facts worth preserving

- **Fact:** breach_event UNIQUE constraint is now `(source_type, source_ref_id, breach_seq)` — was `(source_type, source_ref_id)` before migration 094. — **Evidence:** `\d breach_event` after migration. — **Why it matters:** Multi-breach inserts must populate breach_seq distinctly per source_ref_id; ON CONFLICT must include all three columns.

- **Fact:** breach_event source_types after this session: `'guarded'` (89), `'historical_replay'` (453), `'order_level_walk'` (1361 — NEW), `'swing_pivot'` (955 — NEW). Total 2858 events. — **Evidence:** `SELECT source_type, COUNT(*) FROM breach_event GROUP BY 1;` after final ingests. — **Why it matters:** Filter by source_type for any source-specific analytics. Be aware that source_type='order_level_walk' rows can have non-zero breach_seq.

- **Fact:** swing_pivot rows have NULL trade_side, qty, close_type — and these columns are nullable as of migration 095. — **Evidence:** `\d breach_event` shows trade_side, qty, close_type as nullable post-095. — **Why it matters:** Any aggregate query that filters/groups on these columns must handle NULL.

- **Fact:** The synthetic level_id encoding for ingested breach_decision_log rows is `LEVEL_ID_BASE + breach_event.id` where `LEVEL_ID_BASE = 1_000_000_000`. — **Evidence:** `breach_decision_log_ingest_from_breach_event.py:LEVEL_ID_BASE`. — **Why it matters:** To recover breach_event.id from a breach_decision_log row, subtract 1_000_000_000.

- **Fact:** Trained model artefacts live at `tradelens/data/models/breach_decision/<symbol>/<version>/artefact.json`. The directory is gitignored. — **Evidence:** Successful artefact_writer logs + `git check-ignore` confirms. — **Why it matters:** Don't try to commit artefacts. Don't expect them in fresh clones — the trainer must run.

- **Fact:** TickLoader expects naive-UTC timestamps. — **Evidence:** `breach_analysis/tick_loader.py:73` docstring. — **Why it matters:** Strip tzinfo before calling, re-attach after fetching.

- **Fact:** `get_config()` doesn't expand `${VAR}`; `load_config()` does. — **Evidence:** Auth failure of trainer until fix at `breach_decision_train.py:88-91`. — **Why it matters:** Any code using credentials from `get_config()` must call `expand_env_vars_recursive`.

- **Fact:** `breach_event_label` and `breach_event_feature` have no FK cascade from breach_event. — **Evidence:** `pg_constraint` query returned 0 rows. — **Why it matters:** Future DELETEs must clean up children explicitly.

- **Fact:** Phase1 swing-pivot CSVs have an empty breach_price for some events past tick-gap days. — **Evidence:** First parse failure on row 8 of BTC CSV. — **Why it matters:** Use level_price as fallback in the parser.

- **Fact:** breach_decision_log requires level_id NOT NULL but breach_decision_log.level_confirmed_at_utc is nullable. — **Evidence:** `\d breach_decision_log`. — **Why it matters:** Synthetic level_id is required for ingest; level_confirmed_at_utc can stay NULL (orchestrator's _assemble_features handles None with a neutral default).

- **Fact:** breach_decision_log model_version is VARCHAR(64) — fits any reasonable version tag. — **Evidence:** `\d breach_decision_log`. — **Why it matters:** Use distinctive sentinels like 'ingest-research-2026-04-30' to identify ingestion batches.

## Next steps

1. **Wait for user direction.** The session ended with three "what's next" options offered (pooled-symbol training, B9 wiring, research-side feature/label backfill) and the user has not picked one.

2. **If user says "option 1" / "diagnose" / "pooled":**
   - Read `bin/server/breach_decision_train.py` and `lib/tradelens/breach_decision/training/label_builder.py` to find where `--symbol` is filtered into the SQL query.
   - Add a `--pool` flag (comma-separated symbols) that takes the place of `--symbol` when set.
   - The trainer's chronological 70/15/15 split should still work — pooled time-ordered events should split identically.
   - Run with `--pool BTCUSDT,ETHUSDT,SOLUSDT,HYPEUSDT,ZECUSDT,XRPUSDT,ASTERUSDT --version pool-research-v1-2026-04-30 --min-rows 500`.
   - Compare metrics to per-symbol artefacts (BTC: 597 rows; pooled: ~1500 rows; expect calibration fold to triple).
   - Decision criterion: if pooled calibrated log-loss < base-rate on at least 3 of 4 horizons, pooling is the right path forward.

3. **If user says "option 2" / "B9":**
   - First read the 6 parallel-session level-guard refactor commits via `git show --stat 45995f9 d21e149 f007363 a015ce6 aceda4c 6713119`.
   - Re-read `lib/tradelens/services/level_mind_core.py` `_handle_breached_fails` and `_handle_breached_holds` (locations may have moved).
   - Plan the wiring per `docs/10-architecture/b9-reclaim-mode-plan.md` step 3.
   - Add hook calls to `read_state` + `decide_reclaim_state` + `insert_or_refresh_state` / `delete_state` from `lib/tradelens/breach_decision/reclaim_persistence.py`.
   - New integration test class.

4. **If user says "option 3" / "feature/label backfill":**
   - Run `bin/tools/breach_event_features.py` for the new 2316 events.
   - Run `bin/tools/breach_event_label.py` for the new events.
   - Verify with `SELECT COUNT(*) FROM breach_event_feature WHERE feature_set_version='v3';` and `SELECT outcome, COUNT(*) FROM breach_event_label GROUP BY 1;`.
   - These populate research-side analytics; they don't help B7 retraining (B7 uses its own feature schema computed at ingest time).

5. **If user picks something else:** Don't argue — start the new direction. Note the three options remain valid and we can revisit.

## Verification checklist for the next session

1. `git log --oneline -5` includes commits `fa2e2fbb`, `a726eb24`, `76eed796`, `f68ebdb4`, `0992a6f0` (in that chronological order, possibly with parallel-session commits interspersed).
2. `PGPASSWORD=tradelens_poc psql ... -c "SELECT COUNT(*) FROM breach_event;"` returns 2858.
3. `PGPASSWORD=tradelens_poc psql ... -c "SELECT source_type, COUNT(*) FROM breach_event GROUP BY 1;"` returns 4 rows: guarded=89, historical_replay=453, order_level_walk=1361, swing_pivot=955.
4. `PGPASSWORD=tradelens_poc psql ... -c "SELECT model_version, COUNT(*) FILTER (WHERE realised_label_at IS NOT NULL) FROM breach_decision_log WHERE model_version='ingest-research-2026-04-30' GROUP BY 1;"` returns 2369.
5. `ls tradelens/migrations/093_*.sql tradelens/migrations/094_*.sql tradelens/migrations/095_*.sql` shows all three migrations exist.
6. `ls tradelens/data/models/breach_decision/btcusdt/btc-research-v1-2026-04-30/artefact.json` exists.
7. `ls tradelens/data/models/breach_decision/ethusdt/eth-research-v1-2026-04-30/artefact.json` exists.
8. `PYTHONPATH=. python3 -m pytest tests/unit/test_breach_event_backfill_filters.py tests/unit/test_order_level_enumerate.py tests/unit/test_breach_event_swing_pivot_ingest.py 2>&1 | tail -3` shows 49 passed.
9. `tradelens/bin/tl status level-mind` shows the worker still running with the previous PID (no restart this session).
10. `cat tradelens/etc/config.yml | grep model_version` shows model_version_btcusdt and model_version_ethusdt still pointing at the `lr-*-2026-04-25-v1` production models, NOT the research artefacts.

If any item fails, the checkpoint is stale on that point and re-validation is needed before acting on the related sections.
