# Audit autofix triage — chunks 6, 7, 8, 9

**Generated:** 2026-04-24
**Scope:** AUD-0181 through AUD-0289 (109 findings across chunks 6, 7, 8, 9)
**Purpose:** Classify into T1 (autofix) / T2 (human-review) / T3 (architectural) / T4 (closed).
**Process:** User reviews this file. On approval, Step 2 executes T1 items autonomously.

## Counts

| Tier | Count | Meaning |
|---|---|---|
| **T1** | 15 | Ready for autonomous fix |
| **T2** | 53 | Needs a one-page proposal, then user decides |
| **T3** | 19 | Architectural — parked for dedicated tasks |
| **T4** | 22 | Already Resolved / Works-as-intended / duplicated |
| **Total** | 109 | |

Of the 87 "live" items (T1+T2+T3), T1 covers about 17%. Lower than chunks 1-2
(31%) because:
- Chunk 6 (level_guard) is the money-moving execution engine — almost every
  non-additive change is T2.
- Chunk 7 has suspend.py + trades-flow writers — same money-moving restriction.
- Chunk 8 writes to production `trade_idea` and touches GPT prompts — a lot
  of findings are judgment calls.
- Chunk 9 has 7,000 LOC untested; most refactors carry regression risk.

Many chunk-6 items are **already fixed by recent commits** but the tracker was
never updated — I've put them in T4 with the commit SHA, so Step 2 just needs
to flip the tracker status.

---

## T1 — Autonomous fix queue (15)

Executed in this order. Each gets pre-test, fix, regression test, post-test,
commit. Grouped by file so same-file work shares a worktree.

### bin/server/level_guard_daemon.py

- **AUD-0194** was landed in 1f5aa24f already — **MOVED TO T4**.
- **AUD-0209** was landed in bd5e415b already — **MOVED TO T4**.
- No remaining T1 work in this file — everything mechanical was already
  committed in the recent sprint, and everything else in chunk 6 either
  touches transactional money-flow paths (T2) or is architectural (T3).

### lib/tradelens/services/level_guard.py (MINOR cleanup only)
- **AUD-0203** DecisionReason enum — VERIFIED NOT dead; used in
  `services/level_mind_core.py:610,632,671,699`. Claim is wrong. **MOVED TO T4
  (WAI / false positive)**.
- **AUD-0204** LevelClassification enum — VERIFIED NOT dead; used in
  `services/level_mind_core.py` (12+ sites) and `bin/server/level_mind_worker.py:712`.
  Claim is wrong. **MOVED TO T4**.
- **AUD-0205** EvaluationResult dataclass — VERIFIED NOT dead; heavily used in
  `services/level_mind_core.py` (20+ sites). Claim is wrong. **MOVED TO T4**.

### lib/tradelens/api/guards.py
- **AUD-0208** Minor/Cleanup — Co-locate `_CONFIG_DESCRIPTIONS` (hardcoded at
  `api/guards.py:766-852`) with config defaults. Straight refactor — move
  the dict + export from `lib/tradelens/core/config.py` or introduce a
  `level_guard_config_meta.py` sibling. Keeps same output shape. No
  behavior change. **T1 (single file touch; purely additive metadata
  relocation)**.
  - *Grep verified:* `_CONFIG_DESCRIPTIONS` only referenced inside
    `api/guards.py` (line 766 declaration, line 862-863 lookup).

### lib/tradelens/api/ideas.py
- **AUD-0236** Minor/Duplication — Replace inline day-filter logic at
  `ideas.py:772-791` with a call to the existing `_build_day_where_clause`
  helper at `ideas.py:446-463`. Pure DRY refactor, helper already tested by
  existing `list_trade_ideas` path (line 501).
  - *Grep verified:* Helper defined once (line 446) and already called once
    (line 501). Inline block at 772 reimplements the same logic.

### lib/tradelens/discord/state.py + lib/tradelens/discord/__init__.py
- **AUD-0264** Minor/Dead Code — 6-LOC shim that re-exports `StateManager`
  from `utils.state_manager`. Delete the shim, update `discord/__init__.py`
  to import from the canonical location. Mechanical two-file edit, no
  callers import `discord.state` directly (grep-verified — only `__init__.py`
  touches it).
  - *Grep verified:* Zero direct `from tradelens.discord.state import` or
    `from tradelens.discord import state` occurrences outside the shim
    itself.

### bin/telegram_signals.py
- **AUD-0257** Major/Cleanup — Rename `MessageHandler` at
  `telegram_signals.py:1214` to `TelegramMessageHandler` (or similar) to
  avoid collision with `lib/tradelens/discord/handler.py:15` class of the
  same name. Internal-only rename; no cross-file import exists today.
  - *Grep verified:* No file imports `MessageHandler` from the telegram
    file; the class is only referenced locally (lines 1686, 1840). Discord
    `MessageHandler` is imported independently by `api/discord_ingest.py`
    and they never collide in a single namespace today.
- **AUD-0261** Minor/Cleanup — Replace hand-rolled `utc_to_cet` at
  `telegram_signals.py:82-107` with `zoneinfo.ZoneInfo('Europe/Berlin')`
  (or similar). Python 3.9+; `zoneinfo` already in stdlib. Single file,
  purely functional replacement; one caller at line 821.
  - *Grep verified:* One caller only (:821).

### lib/tradelens/api/discord_ingest.py
- **AUD-0255** Major/Bug — Replace `parts[-1]` filename extraction at
  `discord_ingest.py:174-180` with a hash-based filename (e.g.
  `sha256(url).hexdigest()[:16] + ext`). Single file; purely defensive;
  no upstream format assumption broken because downstream callers already
  handle arbitrary names. **T1** because it's strictly additive
  (attack-surface reduction in a non-money path).
- **AUD-0260** Minor/Duplication — Third-copy `${VAR}` expansion in
  `discord_ingest.py:57-60`. Route through the central `_expand_env_vars`
  helper (memory note: Pydantic-resolved fixes in AUD-0007 already
  landed). Zero-cost deduplication.
  - *Verified:* Prefix/suffix-match expansion identical in semantics to
    centralised helper.

### lib/tradelens/candle_pg/store_pg.py
- **AUD-0286** Minor/Duplication — `execute_values` imported at line 12
  AND re-imported inside `bulk_insert_candles` at line 275. Delete the
  inner import. Pure style fix.

### lib/tradelens/mdsync/fetcher.py
- **AUD-0285** Minor/Cleanup — `_invalid_symbols` set at `fetcher.py:84` is
  unbounded. Cap it (e.g. `collections.OrderedDict` LRU at 1000 entries)
  or add a TTL. Defensive; long-running fetcher process is the usage.
  **T1** — purely additive; single file; no behavior change under normal
  load.

### lib/tradelens/mdsync/config.py + runner.py
- **AUD-0275** Major/Cleanup — `QUICK_TIMEFRAME_CONFIG` in runner.py
  duplicates `TIMEFRAME_CONFIG`. Derive quick from normal (pick a subset).
  Two-file change but trivial; zero downstream API impact.
  - *Note:* need to confirm which subset "quick" really is — if quick is
    a strict subset of normal, this is T1. Will grep first in Step 2; if
    not strict-subset, demote to T2.

### lib/tradelens/utils/vwap_calculator.py + core/config.py
- **AUD-0287** Minor/Duplication — `TIMEFRAME_FALLBACK_ORDER` at
  `vwap_calculator.py:93` vs `bybit_interval_to_timeframe` at
  `config.py:226`. Export one canonical list from `config.py`; import it
  in vwap_calculator. Pure refactor.

### lib/tradelens/candle_reader/pg_reader.py
- **AUD-0273** Major/Bug — `fetch_candle_range` returns Decimals; other
  methods convert to float. Align to float conversion (that's the
  established pattern in the file's other methods). Single-file; covered
  by downstream `Decimal(str(...))` calls which continue to work. Low risk
  because the return type is currently silently already going through
  that wrapper.
  - *Note:* want to grep callers first to make sure none actually relies
    on Decimal precision, which would flip this to T2.

---

## T2 — One-page proposal queue (53)

Each needs a human call. Many cluster into themes (transactions, async/sync
mismatch, security hardening) so the proposals can be batched per theme.

### Chunk 6 — level_guard / guards.py

| ID | Severity | Why T2 (not T1) |
|---|---|---|
| **AUD-0183** | Critical/Reliability | "Atomic suspend via transaction OR reconciler sweeper" — design choice |
| **AUD-0195** | Major/Cleanup | Rename repurposed `pending_request_uuid` field — requires DB row migration (guard_state_json blobs) |
| **AUD-0197** | Major/Architecture | State spread across level_guard + guard_state_json — schema decision |
| **AUD-0198** | Major/Architecture | JSON drift in guard_state_json — migrate to typed columns (schema change) |
| **AUD-0201** | Major/Architecture | async endpoints with sync DB — policy decision (make sync OR threadpool) |
| **AUD-0206** | Minor/Dead Code | Suspicious — requires prod-DB verification before deleting a safety fallback |
| **AUD-0207** | Minor/Cleanup | Regex fallback in guard_state_json parse — fix root cause vs remove band-aid |
| **AUD-0210** | Minor/Cleanup | Wholesale config exposure — decide the allowlist policy |
| **AUD-0211** | Minor/Cleanup | Partial-cancellation cleanup — single transaction touches money-moving daemon state |

### Chunk 7 — ideas / batch_ideas / suspend / stops

| ID | Severity | Why T2 (not T1) |
|---|---|---|
| **AUD-0212** | Critical/Bug | `POST /stops` broken — fix requires passing default account OR deleting endpoint |
| **AUD-0213** | Critical/Bug | Hedge-mode wrong-side close — money-moving filter change in suspend.py |
| **AUD-0214** | Critical/Architecture | Route suspend/resume through typed adapters — non-additive money path |
| **AUD-0215** | Critical/Reliability | Resume marks open despite per-order failures — semantics change |
| **AUD-0216** | Critical/Performance | async+sync DB in batch_ideas — threadpool vs sync |
| **AUD-0217** | Critical/Reliability | Transaction around overwrite in batch_ideas — money-adjacent |
| **AUD-0218** | Critical/Reliability | Suspend/resume/close transaction inside lock — money-moving |
| **AUD-0219** | Major/Performance | SQL LIMIT/OFFSET in list_trade_ideas — pagination API contract change |
| **AUD-0220** | Major/Performance | Concurrent Bybit fetches in ideas market data — new concurrency pattern |
| **AUD-0221** | Major/Performance | Batch AI → background job + polling endpoint — new endpoint surface |
| **AUD-0222** | Major/Performance | subprocess.Popen refresh in suspend — money-adjacent; contract with pipeline |
| **AUD-0223** | Major/Dead Code | `vwap_config_raw` Suspicious — delete vs wire up (requires product decision) |
| **AUD-0225** | Major/Reliability | async handlers with cursor across awaits in batch_ideas |
| **AUD-0227** | Major/Security | User→account binding — cross-cutting authorization |
| **AUD-0228** | Major/Architecture | Idea→Intent→Journal fuzzy matching — schema change (explicit idea_id propagation) |
| **AUD-0229** | Major/Architecture | State machine in code, not data — schema change |
| **AUD-0230** | Major/Architecture | Batch AI async job — new endpoint surface |
| **AUD-0231** | Major/Reliability | orderLinkId on resume re-places — money-moving additive-ish but new contract |
| **AUD-0232** | Minor/Bug | `carried_fwd` field vs enum mismatch — add enum value vs remove field |
| **AUD-0233** | Minor/Cleanup | Hand-rolled rollback — depends on AUD-0217 landing first |
| **AUD-0234** | Minor/Suspicious | `locals().get('place_params')` — scoping change in money-moving path |
| **AUD-0235** | Minor/Cleanup | Lowercase 'new' normalisation — money-adjacent; reinforces AUD-0185 already fixed |

### Chunk 8 — Discord / Telegram

| ID | Severity | Why T2 (not T1) |
|---|---|---|
| **AUD-0239** | Critical/Security | SSRF via substring allowlist — URL-parsing fix, but production-critical verification needed before landing |
| **AUD-0240** | Critical/Security | Self-botting architecture — product decision (webhooks migration) |
| **AUD-0241** | Critical/Security | Plaintext secrets in chrome.storage — HMAC design + session storage |
| **AUD-0242** | Critical/Bug | JSON-substring LIKE dedup — requires schema change (`source_message_id` column + unique index) |
| **AUD-0243** | Critical/Performance | Sync image downloads — BackgroundTasks design + failure handling |
| **AUD-0244** | Critical/Reliability | Transaction around idea create cascade — money-adjacent |
| **AUD-0245** | Critical/Architecture | DB via env vars vs pool — bigger refactor; fix requires `init_db_pool` propagation |
| **AUD-0246** | Major/Security | Auth before body parse — FastAPI middleware ordering change |
| **AUD-0247** | Major/Security | State-file load-modify-save race — flock vs DB move (design choice) |
| **AUD-0248** | Major/Security | HTTPS enforcement for backend_url — extension UX change |
| **AUD-0249** | Major/Security | manifest host_permissions — extension permission model change |
| **AUD-0250** | Major/Architecture | 80% overlapping IdeaCreator — unify via shared class (large refactor) |
| **AUD-0251** | Major/Reliability | Numeric sort of snowflakes — works today, fix needed before ID-length variance |
| **AUD-0252** | Major/Security | GPT prompt injection via message content — prompt template change; GPT safety test |
| **AUD-0253** | Major/Performance | Fresh DiscordIdeaCreator per request — pool integration |
| **AUD-0254** | Major/Cleanup | Dup pre/post handler logic in two paths — 200-LOC refactor; error handling consolidation |
| **AUD-0262** | Minor/Cleanup | `extra='allow'` on DiscordMessage — whitelist design |
| **AUD-0263** | Minor/Dead Code | Legacy DCE path Suspicious — requires confirming "no manual usage" before deleting |
| **AUD-0265** | Minor/Cleanup | Parser init re-reads config — cache sharing policy |
| **AUD-0266** | Minor/Security | /discord-ingest/health auth — endpoint contract decision |

### Chunk 9 — market data

| ID | Severity | Why T2 (not T1) |
|---|---|---|
| **AUD-0267** | Critical/Bug | 8 vwap endpoints pass full YAML to PooledDB — migrate to `get_db_connection` (cross-endpoint contract) |
| **AUD-0270** | Critical/Architecture | Inline DDL `ensure_schema` — callers must be updated (runner.py + runner_pg.py) |
| **AUD-0271** | Critical/Performance | Per-row UPDATE/INSERT → `INSERT ... ON CONFLICT` batch — money-adjacent (wrong candles mislead analytics) |
| **AUD-0274** | Major/Reliability | Per-instance rate limiter → shared — architecture change (singleton in module vs fetcher instance) |
| **AUD-0280** | Major/Cleanup | vwap_config.slots_json opaque blob — schema change to normalised columns |
| **AUD-0282** | Major/Cleanup | No orderLinkId on `vwap_order_engine.amend_order` — money-moving contract |
| **AUD-0283** | Major/Config | Hardcoded magic constants in mdsync/runner/fetcher — config surface change |
| **AUD-0284** | Minor/Reliability | Explicit commits on potentially-autocommit conn — semantics decision |
| **AUD-0288** | Minor/Dead Code | `CandleCopyRunner` Suspicious — exported from __init__.py; only caller is in bin/TRASH but tracker says verify; can't cheap-verify as T1 |
| **AUD-0289** | Minor/Reliability | tick_archive 'ingesting' stale state — reconciler/TTL design |

---

## T3 — Architectural / deferred (19)

No attempt in this workstream. Each becomes a dedicated task.

### Chunk 6
| ID | Severity | Why T3 |
|---|---|---|
| **AUD-0192** | Major/Architecture | 1,582-LOC SRP split of level_guard_daemon |
| **AUD-0199** | Major/Test Gap | Test coverage requires extraction first (depends on AUD-0192) |
| **AUD-0202** | Major/Architecture | Breach-detection latency — NOTIFY/LISTEN event-driven rearchitecture |

### Chunk 7 (no pure T3 — most arch items are scoped refactors → T2)
(none additional — the chunk-7 arch items are sized for one-page proposals)

### Chunk 8
| ID | Severity | Why T3 |
|---|---|---|
| **AUD-0250** (also listed T2) can escalate to T3 if unified IdeaCreator turns into a week-long rewrite — flagged as "T2 or T3" |
| **AUD-0258** | Major/Test Gap | Discord/Telegram test suite build-out — depends on AUD-0250 |
| **AUD-0259** | Major/Architecture | Self-botting as load-bearing — depends on 0240 product call; multi-week |

### Chunk 9
| ID | Severity | Why T3 |
|---|---|---|
| **AUD-0268** | Critical/Architecture | Unify two PG connection pools — depends on broader pool rearchitecture (see AUD-0008 chunk 1) |
| **AUD-0269** | Critical/Architecture | Second Bybit HTTP client — depends on AUD-0002 retry/backoff (chunk 1) |
| **AUD-0272** | Critical/Performance | Parallel fetch + serial upsert — depends on AUD-0271 batch upsert |
| **AUD-0276** | Major/Architecture | 4 VWAP implementations — cross-cutting (frontend + 3 Python) |
| **AUD-0277** | Major/Test Gap | Market data test suite — depends on splitting `MDSyncRunnerPG` |
| **AUD-0278** | Major/Architecture | 892-LOC `MDSyncRunnerPG` god-class split |
| **AUD-0279** | Major/Architecture | 986 + 981 LOC daemon god-classes (vwap_series_worker + vwap_order_engine) |
| **AUD-0281** | Major/Reliability | Propagate singleton_lock pattern to other daemons — already fixed for level_guard (AUD-0182) via same helper; rolling out broadly is multi-daemon task |

---

## T4 — Already closed / fixed / WAI (22)

Either tracker-Resolved, or landed by a recent commit but tracker not yet updated, or tracker claim is a false positive.

### Tracker already marked Resolved (3)
- **AUD-0186** — Resolved (duplicate binary deleted alongside AUD-0041)
- **AUD-0226** — Resolved (Stop Lab subsystem deleted)
- **AUD-0237** — Resolved (moot; stoplab deleted alongside AUD-0226)

### Landed by recent commit; tracker pending update (14)
- **AUD-0181** — 9f3d1a47 `fix(level_guard): include exchange_updated_at in _get_guarded_legs` (2026-04-23)
- **AUD-0182** — 03c0b4e1 `fix(daemons): enforce singleton via flock on guard/mind/pipeline daemons`
- **AUD-0184** — 71ba5dc6 `fix(level_guard): wrap post-Bybit DB cascade in explicit transaction`
- **AUD-0185** — 42209370 `fix(level_guard): match guard statuses case-insensitively in daemon filter`
- **AUD-0187** — e4cc4b05 `fix(level_guard): classify execute-path exceptions and fail-fast, no retry`
- **AUD-0188** — 14b6e0be `fix(level_guard): abort cascade on exchange-cancel failure`
- **AUD-0189** — 295892cf `fix(level_guard): CRITICAL log for unmatched EXECUTION_MATRIX…`
- **AUD-0190** — Verified single source now at `level_guard_daemon.py:1402` — other site was removed; effectively Resolved
- **AUD-0191** — 101ff71c `fix(level_guard): raise instead of returning 0 from _record_attempt`
- **AUD-0193** — d00bbd2d `fix(level_guard): drop redundant per-event guard_state_json re-read`
- **AUD-0194** — 1f5aa24f `fix(level_guard): try/finally around cursor use in poll/status/info`
- **AUD-0196** — 295892cf `… pin suspend lock-scope` (same commit as AUD-0189)
- **AUD-0200** — ecb1ff05 `fix(api/guards): atomic acknowledge_guards via UPDATE…RETURNING`
- **AUD-0209** — bd5e415b `fix(daemons): RotatingFileHandler for 3 server daemons`
- **AUD-0238** — 848b1dca `fix(signals): replace hardcoded account_id=1 with signal_account resolution`

### False positives / WAI (3)
- **AUD-0203** — `DecisionReason` IS used (12+ sites in level_mind_core.py). Claim "dead enum" is wrong — it's only unused from `level_guard_daemon.py`, but that's fine: the enum is canonical and the daemon uses string comparisons through `GuardStateData.to_json()` which round-trips enum values.
- **AUD-0204** — `LevelClassification` IS used in `level_mind_worker.py:712` and 20+ sites in `level_mind_core.py`. Claim is wrong.
- **AUD-0205** — `EvaluationResult` IS heavily used throughout `level_mind_core.py`. Claim is wrong.

### Duplicates / subsumed (2)
- **AUD-0224** — Reinforces AUD-0008 (PooledDB migration). Handled by the
  chunk-1 T3 entry; no separate action.
- **AUD-0256** — Minor performance retention; arguably T2, but explicitly
  listed by the tracker as "covered by AUD-0240 product redesign", so
  subsumed into the self-botting migration (T3).

---

## Execution plan for Step 2

Order of T1 work (groups findings by file to share worktrees):

1. **level_guard cleanup batch** (AUD-0208)
   Single file touch on api/guards.py metadata relocation. Covered by existing
   `tests/integration/test_guards.py` (if present) or a new unit test for
   `_CONFIG_DESCRIPTIONS` export.

2. **api/ideas.py day-helper DRY** (AUD-0236)
   Single file. Existing ideas-endpoints integration tests cover path.

3. **discord shim deletion** (AUD-0264)
   Two-file change (state.py delete + __init__.py import update). Grep-
   verified no external callers.

4. **telegram rename + zoneinfo** (AUD-0257, AUD-0261)
   Single file, batched together because both touch only telegram_signals.py.
   New unit test for the zoneinfo path.

5. **discord_ingest hardening** (AUD-0255, AUD-0260)
   Single file (api/discord_ingest.py). Both strictly additive. Unit tests
   cover filename generation (hash-based) and env-var expansion.

6. **store_pg dedup import** (AUD-0286)
   Single line edit. No test change required (style).

7. **mdsync/fetcher invalid-symbol cap** (AUD-0285)
   Single file. New unit test that seeds 1001 invalid-symbol entries and
   asserts set is bounded at 1000.

8. **mdsync TIMEFRAME_CONFIG dedup** (AUD-0275)
   Two-file but trivial. Verify "quick is subset of normal" with grep first.
   Unit test asserts the derivation still produces the expected subset.

9. **vwap_calculator timeframe list dedup** (AUD-0287)
   Two-file (utils/vwap_calculator.py + core/config.py). Export one list;
   import in the other. Existing `test_vwap_series.py` covers.

10. **pg_reader float consistency** (AUD-0273)
    Single file. Before landing: grep callers for Decimal dependence; if
    any exist, demote to T2.

Ten batches, 15 findings. Estimated 10 commits.

## Review checklist for you

Before I start Step 2, please eyeball:

- [ ] The T4 tracker-pending-update batch (14 items) — these are the
      highest-value cleanup. **Should Step 2 flip their tracker status?**
      (They're already Resolved by commit; the tracker just hasn't caught
      up.)
- [ ] AUD-0203/0204/0205 — do you agree these are false positives given
      the level_mind_core.py references, or do you want me to still delete
      them from level_guard.py? (They may be "canonical here, used
      elsewhere" and that's fine.)
- [ ] AUD-0275 (quick/normal timeframe dedup) — I'll grep the quick set
      first to confirm it's a strict subset; if not, I'll demote to T2
      rather than invent a derivation.
- [ ] AUD-0273 (Decimal→float in pg_reader) — same escape hatch: grep
      callers; any Decimal dependence → T2.
- [ ] AUD-0232 (`carried_fwd`) — I left this as T2 because the fix path
      requires a product decision (add enum value vs remove field, and
      the frontend `api.ts:557,580` currently types it as a valid value).
      Agreed?
- [ ] Any T2 item that should be T1 because the risk I flagged is
      imaginary? (Most likely candidates: AUD-0207 regex fallback
      deletion, AUD-0208 config exposure allowlist.)
- [ ] Any T3 item you'd rather tackle now as T2?
- [ ] Ordering — is there a file you'd rather I start on or avoid?

Reply "go" to kick off Step 2 on the T1 batch, or name the IDs you want
moved between tiers.

## Cross-chunk dependencies noted

- **AUD-0224** (ideas.py PooledDB) → reinforces **AUD-0008** (chunk 1 T3 —
  migration to `get_db_connection`). Must wait for that to land.
- **AUD-0216 / AUD-0201** (async + sync DB) → same policy question; should
  be resolved together.
- **AUD-0269** (mdsync BybitClient) → depends on **AUD-0002** (chunk 1 T3
  retry/backoff) — routing through BybitClient only helps if that client
  has the retry/etc. work done first.
- **AUD-0268** (second PG pool) → depends on **AUD-0008** (same pool
  migration story).
- **AUD-0242** (LIKE-dedup → schema change) → if this lands, it obsoletes
  much of AUD-0250's justification (less duplication to hide).
- **AUD-0235** (lowercase 'new' in suspend.py) → reinforces **AUD-0185**
  (already fixed in 42209370). Still worth flagging because it's a
  preventative normalization on the write side.
- **AUD-0281** (singleton_lock pattern) → confirms the approach taken by
  **AUD-0182** (already fixed). Propagation to remaining daemons is a
  chunk-10 story.
