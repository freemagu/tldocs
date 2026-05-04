# T2 re-triage — chunks 11-12 + tail (Unclassified appendix)

**Generated:** 2026-04-25
**Scope:** ~58 still-`Confirmed` tracker items listed under "Unclassified" in [[decisions-pending]]. These came from later audit chunks (1, 6, 7, 8, 9, 10, 11, 12, 13) and were not covered by the three earlier re-triage files.
**Source files:** [[t2-retriage-chunks-1-2]], [[t2-retriage-chunks-3-5]], [[t2-retriage-chunks-6-14]]
**Tracker:** [[AUDIT_TRACKER]]
**Purpose:** Assign each item a bucket (A / B / C / D / F / G) using the same criteria as the three earlier re-triage files, so the next round of ticks in [[decisions-pending]] can include this set.

## Method

Re-triage rules (carried over from the earlier files):
- **A — Quick-yes:** narrow scope, clear canonical answer, single-commit ship-ready, no signature/schema change.
- **B — Pick-one:** 2-3 reasonable answers; one marked `*Recommended.*`.
- **C — Money-moving / schema:** canonical answer is clear but blast radius warrants explicit sign-off.
- **D — Verify first:** Suspicious — read-only investigation needed before A/B/C/F decision. (Default for uncertain calls.)
- **F — T3 architectural:** multi-day, planning-not-shipping; note rough size + dependencies.
- **G — Close-as-WAI / won't-fix.**

## Pre-check: items already Resolved

Per [[AUDIT_TRACKER]] (HEAD `93c65abb`):

| ID | Status | Note |
|---|---|---|
| **AUD-0073** | Resolved | Listed under Minor in Unclassified, but tracker row says fixed under AUD-0042's f-string SQL remediation; allowlist guard at `initial_risk_calculator.py:426-431`. Drop from re-triage. |

The Unclassified list in [[decisions-pending]] is therefore stale by 1 ID. The remaining 57 are still `Confirmed`.

## Counts

| Bucket | Items | Notes |
|---|---|---|
| **A** Quick-yes | 4 | Mostly chunk-12 frontend cleanups + chunk-11 `_t` interceptor removal |
| **B** Pick-one | 6 | Mostly retention/cache policy choices |
| **C** Money/schema | 2 | candle ingest perf + production-table writes from research scripts |
| **D** Verify first | 0 | Nothing in this batch is genuinely Suspicious — all are confirmed-real with known scope |
| **F** T3 architectural | 41 | Dominant — most chunk-9/10/11/12/13 items are multi-file refactors / split-large-file / cross-daemon redesign |
| **G** Close-as-WAI | 4 | Items already covered by other tickers OR moot once dependent F-bucket lands |
| **Total** | **57** | (after dropping AUD-0073) |

The heavy F-bucket skew reflects what these chunks contain: chunk 9 is "split god-class" (`MDSyncRunnerPG`, `vwap_*`); chunk 10 is "12-wrapper duplication + process-model rewrite"; chunks 11/12 are frontend-architecture (mega-components, persistence sprawl, no test harness, no error boundary, persistence-without-migrations). Each is design-first, not ship-first.

---

## Bucket A — Quick-yes (narrow scope, clear canonical answer)

Items where the fix is mechanical, additive, and the canonical answer is unambiguous.

- [ ] **AUD-0313** (Major/Performance) — `frontend/web/src/lib/api.ts:37-48` cache-busting `_t` param interceptor.
  - Tracker: *"Defeats browser cache, CDN, reverse proxy AND React Query URL dedup; `Cache-Control: no-cache` already set."*
  - Fix: delete the interceptor. Single-file edit; React Query already handles dedup; `Cache-Control: no-cache` already covers correctness. Net win on every dimension (perf, network, React Query semantics).

- [ ] **AUD-0322** (Minor/Cleanup) — Extract `RR_HELP_CONTENT` markdown out of `trade-journal-chart.tsx`.
  - Tracker: *"100+ line inline markdown template literal ... Belongs in .md file loaded via Vite `?raw`."*
  - Fix: move literal to `frontend/web/src/components/journal/rr-help.md` + `import RR_HELP_CONTENT from './rr-help.md?raw'`. Two-file mechanical edit. (Note in [[decisions-pending]]: marked blocked on AUD-0332 vitest setup, but actual fix doesn't require tests — only the *test for it* would. Pure code-move counts as `frontend-styling` exempt-from-tests under our policy.)

- [ ] **AUD-0338** (Minor/Cleanup) — Add `<Route path="*" element={<NotFound />} />` to `app.tsx:39-52`.
  - Tracker: *"Mis-typed URLs render blank `<main>`. UX bug."*
  - Fix: one-line route + minimal NotFound component. No state/store change; no test needed beyond a render smoke test (deferred until vitest lands).

- [ ] **AUD-0339** (Minor/Cleanup) — Replace bare `try/catch` around localStorage in `equity.tsx:87-88` and 1-2 hooks with explicit recovery.
  - Tracker: *"Preferences silently reset on corrupt JSON."*
  - Fix: log + return default with a recoverable error class. Strictly additive observability; no behavior change for valid data.

---

## Bucket B — Pick-one (two or more reasonable answers)

Tick exactly one option per item. Recommended options are flagged.

- [ ] **AUD-0256** (Major/Performance) — `data/discord_media/` no retention policy.
  - Tracker: *"Grows forever. Purge by age or on idea archival."*
  - (a) Purge-by-age cron (e.g. 90d after last referenced). *Recommended — simple, predictable.*
  - (b) Purge-on-idea-archival (lifecycle-driven; needs idea→media linkage table).
  - (c) Move to S3 / object store with expiry policy.

- [ ] **AUD-0260** (Minor/Duplication) — third `${VAR}` expansion in `discord_ingest.py:57-60`.
  - Tracker note (T1 halt): *"the `_expand_env_vars` in `account_context.py:115` is an instance method ... raises `ConfigurationError` on missing vars; the local copy here silently defaults to `""`. Two aren't drop-in replacements — deciding which semantic to keep ... is a T2 design call."*
  - (a) Lift `account_context._expand_env_vars` to module-level helper, switch all 3 sites to it, accept fail-fast on missing var. *Recommended — consistent with `account_context` semantic and matches AUD-0007 fix philosophy.*
  - (b) Keep silent-default-to-empty in `discord_ingest`, document why.
  - (c) Add `strict=True/False` flag to a unified helper.

- [ ] **AUD-0275** (Major/Cleanup) — `TIMEFRAME_CONFIG` vs `QUICK_TIMEFRAME_CONFIG` in `mdsync/runner.py:22-23`.
  - Already flagged in [[decisions-pending]] *"Move to pick-one (B)"* — explicit B-bucket entry. Lookbacks differ 30d vs 365d, so it's not a strict subset.
  - (a) Derive quick from normal via `replace(lookback_days=30)` projection. *Recommended — single source of truth.*
  - (b) Keep two configs; add a property test asserting timeframe-set equality.
  - (c) Delete `QUICK_TIMEFRAME_CONFIG`, accept that quick mode runs full lookback (slower but correct).

- [ ] **AUD-0281** (Major/Reliability) — propagate `singleton_lock` flock pattern from VWAP daemons to others.
  - Tracker: *"Good pattern; should be propagated to LevelGuard (AUD-0182) and pipeline scripts."*
  - (a) Roll out flock-singleton to all 13 daemons in one PR. *Recommended — propagation, not net new.*
  - (b) Add to LevelGuard + pipeline only (covers the hot paths).
  - (c) Park; rely on `bin/tl` PID check (status quo).

- [ ] **AUD-0294** (Major/Duplication) — 12× duplicated ~155-LOC shell wrappers, ~2,480 LOC total.
  - Tracker: *"Single `service-wrapper.sh` parameterized by service name."*
  - (a) Extract `bin/_lib/service-wrapper.sh`; 12 wrappers shrink to ~10 LOC each (`source _lib/service-wrapper.sh`). *Recommended — biggest LOC delete in the audit.*
  - (b) Park behind AUD-0301 (process-model rewrite to systemd/Docker, F-bucket).
  - (c) Keep duplicate; accept 12-edit-per-fix tax.

- [ ] **AUD-0303** (Major/Cleanup) — `bin/monitor` 641 LOC of bash → Python rewrite.
  - Tracker: *"Shell is wrong language for 641 LOC."* Already noted in [[decisions-pending]] parked-section: *"single-file cleanup (worker). Pull context before shipping."*
  - (a) Rewrite in Python using `psutil` (coordinates with AUD-0341/0350/0352). *Recommended — bundles into a system_monitor.py refactor.*
  - (b) Split bash into smaller modules.
  - (c) Park behind AUD-0301 process-model rewrite.

---

## Bucket C — Money-moving / schema / explicit sign-off

Canonical answer is clear; blast radius warrants explicit sign-off.

- [ ] **AUD-0271** (Critical/Performance) — `candle_pg/store_pg.py:104-220` per-row UPDATE/INSERT → `INSERT ... ON CONFLICT DO UPDATE` batch.
  - **Already flagged in [[decisions-pending]] bucket C.** Re-listing here for completeness — wrong candles mislead every downstream analytic (charts, alerts, level-guard, signal labelling).
  - Recommended approach: `psycopg2.extras.execute_values` with `ON CONFLICT (symbol, interval, timestamp) DO UPDATE SET ...`. Same batch semantics the audit recommends; matches existing `parser_inbox` upsert pattern.
  - Money-adjacent test gate: ride a regression test that asserts identical candle output from old vs new path on a 1000-row fixture.

- [ ] **AUD-0347** (Major/Architecture) — `bin/tools/breach_spot_backfill.py` writes to production `market_candle` table.
  - Tracker: *"A research bug can corrupt real-time chart data. Dedicated breach_* schema or separate DB."*
  - Recommended approach: introduce `breach_candle` table with the same schema, route research scripts there, add a one-shot view that UNIONs both for backfill comparison. Money-adjacent because today a research backfill bug can poison live charts. Migration + tracker rebind for breach pipeline.

---

## Bucket D — Verify first (Suspicious)

Empty for this batch. Every Unclassified item has a confirmed, observable signature in the tracker. The earlier D-bucket sweep (chunks 6-14, batch 2) closed all 13 Suspicious items already. Re-add to D when new Suspicious entries arrive from future audits.

---

## Bucket F — T3 architectural (schedule a planning session)

Multi-day refactors. Tick to schedule a planning session (design doc + phased plan), not autonomous execution.

### F.1 — Database / pool architecture

- [ ] **AUD-0030** (Minor/Dead Code) — `lib/tradelens/core/db_pool.py` shim.
  - 30 importers across `lib/tradelens/api/*.py` and `lib/tradelens/services/*.py` (verified via `grep`). Migrating away from the shim is the same scope as AUD-0008 (DB lifecycle across FastAPI lifespan, already F-bucket). **Bundle with AUD-0008.** Size: ~30-file mechanical edit + 1 lifespan-rewire commit.

- [ ] **AUD-0224** (Major/Cleanup) — `PooledDB` pattern across 30+ endpoints in `api/ideas.py`.
  - Tracker: *"AUD-0008 reinforced for this file. Migrate to `get_db_connection`."* **Subset of AUD-0008/0030 cluster.** Bundle.

- [ ] **AUD-0268** (Critical/Architecture) — second PG connection pool in `candle_reader/factory.py`.
  - Tracker: *"Up to 20 connections when combined with core pool. Pool exhaustion is independent per pool; config drift across two sections."*
  - Size: medium. Touches every `candle_reader` consumer (~5 files) + config restructure. Coordinate with AUD-0302 (DB connection sprawl, already F).

- [ ] **AUD-0302** (Major/Architecture) — DB connection sprawl across 60+ peak connections vs default `max_connections=100`.
  - Tracker: *"PgBouncer or shared pool."* Foundation question for all DB-pool work — likely the **gating decision** for AUD-0008/0030/0224/0268. Schedule first.

### F.2 — Market data architecture (chunk 9)

- [ ] **AUD-0269** (Critical/Architecture) — second Bybit HTTP client in `mdsync/fetcher.py:49-100`.
  - Tracker: *"Reimplements fetch/pagination/rate-limit outside `adapters/bybit_client.py` ... reinforces AUD-0002, AUD-0011."* Multi-day route-through-BybitClient refactor; depends on AUD-0002 (retry policy, F) for safe POST handling.

- [ ] **AUD-0270** (Critical/Architecture) — inline DDL `ensure_schema` in `candle_pg/store_pg.py:46-102`.
  - Tracker: *"Delete `ensure_schema`; rely on bin/setup."* Looks small but every consumer assumes startup-side-effect schema creation; needs migration sequencing across 5+ entry points. **Already in bucket B in [[decisions-pending]] under chunk 9.** Listed here as F because of cross-entry-point coordination (vs B's "callers must be updated" framing — that's the F bit).

- [ ] **AUD-0272** (Critical/Performance) — `mdsync/runner.py:638-697` parallel fetch + serial upsert on single PG conn.
  - Tracker: *"Batch upsert (C5 fix) or per-thread connections."* Coupled with AUD-0271 (ON CONFLICT) and AUD-0268 (pool consolidation). Plan after C-bucket lands.

- [ ] **AUD-0276** (Major/Architecture) — four VWAP implementations (worker, engine, util, frontend).
  - Tracker: *"Drift across four copies of a tuned algorithm. Server-side only; frontend reads pre-computed."* Cross-process design decision; touches FE contract.

- [ ] **AUD-0277** (Major/Test Gap) — ~7,000 LOC of market-data code, `test_vwap_series.py` is the only coverage.
  - Bundle with AUD-0358 (overall coverage lift) which is already F.

- [ ] **AUD-0278** (Major/Architecture) — `MDSyncRunnerPG` god-class 892 LOC.
  - Tracker: *"Coverage, backfill, live, first-available cache, threads, signals. Untestable as a unit. Split into phases."* Direct counterpart to the existing F-bucket file-split entries (AUD-0058, AUD-0192).

- [ ] **AUD-0279** (Major/Architecture) — `vwap_series_worker.py` (986 LOC) + `vwap_order_engine.py` (981 LOC) god classes.
  - Same SRP violation as AUD-0278. Bundle into "split engine daemons" planning session.

### F.3 — Frontend architecture (chunks 11-12)

- [ ] **AUD-0315** (Major/Performance) — `trade-journal-chart.tsx` 0 useMemo + 3 useCallback.
  - Tracker: *"Chart recomputes everything on every render."* Multi-component memoisation pass; coordinates with AUD-0308/0310 (split frontend files, already F). **Blocks on AUD-0332 vitest** for safe regression testing.

- [ ] **AUD-0316** (Major/Bug) — `smart-trade-form.tsx` 2 `eslint-disable react-hooks/exhaustive-deps`.
  - Tracker: *"Suppressions correlate with the ref-based race-guards. Bug vectors."* Risky to re-enable without tests; **blocked on AUD-0332**.

- [ ] **AUD-0317** (Major/Cleanup) — `Create` vs `Update` interface duplication in `api.ts`.
  - Tracker: *"`type Update = Partial<Create>` or generate from OpenAPI."* Bundles with AUD-0314 (OpenAPI codegen, already F).

- [ ] **AUD-0318** (Major/Bug) — `trade-journal.tsx:526-563` client-side filters on server-paginated data.
  - Tracker: *"User sees 'total=500, visible=3'. Push all filters server-side."* Backend API contract change + FE migration; multi-day. Money-adjacent (filters affect what users *see* of their own trade history).

- [ ] **AUD-0319** (Major/Cleanup) — 30+ per-field `setXLocal`/`setX` debounce-commit pattern in `smart-trade-form.tsx:256-450`.
  - Tracker: *"Adopt form library."* Multi-day react-hook-form + `useDebouncedState` migration of the trade-form god-component. Bundles with AUD-0310 (split smart-trade-form.tsx, already F).

- [ ] **AUD-0320** (Major/Test Gap) — 18,382 LOC FE reviewed, zero tests.
  - **Bundle with AUD-0332 (vitest setup) + AUD-0358 (coverage lift)**, both already F.

- [ ] **AUD-0321** (Major/Security) — `api.ts:68-75` response error interceptor flattens `[{loc, msg, type}]` to string.
  - Tracker: *"Downstream callers can't surface per-field errors. Preserve structure; typed error classes."* Cross-FE refactor — every `.catch()` and `useMutation` `onError` in the codebase must be updated to consume the new typed errors. Multi-day.

- [ ] **AUD-0323** (Minor/Duplication) — `STATUS_COLUMN_OPTIONS`/`KIND_FILTER_OPTIONS` duplicated FE/BE.
  - Tracker: *"Generate from backend enum via OpenAPI."* Bundle with AUD-0317 + AUD-0314 (OpenAPI codegen).

- [ ] **AUD-0324** (Minor/Cleanup) — ~40 `console.*` calls across 5 FE files.
  - Tracker: *"Sentry or equivalent; remove console.*."* New observability dependency + FE-wide sweep. F because of the dependency add.

- [ ] **AUD-0325** (Critical/Performance) — `main.tsx:7-22` `gcTime: Infinity` + `refetchIntervalInBackground: true`.
  - Tracker: *"Memory grows unbounded on long sessions; network stays saturated."* Single-file fix BUT every page's polling assumption depends on it. Multi-component verification needed. F-bucket because the *test plan* is multi-day, not the code change.

- [ ] **AUD-0326** (Critical/Reliability) — no `ErrorBoundary` anywhere in `main.tsx`/`app.tsx`.
  - Tracker: *"Trader mid-submission sees a white page with live Bybit state."* Mechanical add of `react-error-boundary`, but per-route boundary placement is a design decision (where do you put each boundary, what's the fallback UI per route). Plan first.

- [ ] **AUD-0327** (Critical/Security) — no CSP, no SRI in `index.html`, external Google Fonts stylesheet.
  - Tracker: *"Strict CSP meta; SRI; self-host fonts."* Self-hosting fonts + CSP design = multi-day; CSP nonces interact with React-injected styles.

- [ ] **AUD-0328** (Critical/Architecture) — persistence sprawl: 5 zustand-persist stores + 5+ raw localStorage sites; 20+ keys; `journalStore` at version 21.
  - Tracker: *"One persistence layer; versioned migrations."* Cross-store migration sweep; touches the entire FE state architecture.

- [ ] **AUD-0329** (Critical/Duplication) — 3 definitions of `DcaLevel`/`TpLevel` across `smartTradeStore`, `ideasStore`, `smart-trade-form`.
  - Tracker: *"Single source in `lib/types.ts`."* Bundles with AUD-0314 (OpenAPI codegen) — types should come from BE.

- [ ] **AUD-0330** (Major/Architecture) — mega-component pattern across 8 components/pages totalling ~12,700 LOC.
  - Tracker call-out: notes-tags-panel 2,955; trade-ideas 1,893; trade-journal-expanded-row 1,825; etc. Same SRP problem as AUD-0308/0310/0311. **Bundle as one F-bucket "FE split-large-files" workstream.**

- [ ] **AUD-0331** (Major/Performance) — `app.tsx:5-16` no `React.lazy` / no code splitting; 12 pages bundled into initial JS.
  - Tracker: *"`React.lazy` per route."* Mechanical pattern but couples to FE bundle config + chunk ordering. Plan size: ~1 day.

- [ ] **AUD-0333** (Major/Performance) — `main.tsx:17` `refetchOnMount: 'always'` + `staleTime: 5000` causes double-fetch.
  - Tracker: *"Revisit defaults per-query."* Per-query audit across every `useQuery` site (50+) — multi-day with risk of breaking polling-dependent UI.

- [ ] **AUD-0334** (Major/Reliability) — `journalStore.ts:362` `version: 21` with no migrations.
  - Tracker: *"Add `migrate:` handler."* Reverse-engineering 21 historical schema bumps from git history. Multi-day forensic work even if the resulting code is small.

- [ ] **AUD-0335** (Major/Architecture) — incomplete React Query migration across 10+ pages.
  - Tracker: *"Every remaining page mixes `usePolling`/`useQuery` with raw `setInterval`."* Same scope as AUD-0311 (already F). Bundle.

- [ ] **AUD-0336** (Major/Security) — `vite.config.ts:12-15` `host: '0.0.0.0'` + hardcoded Tailscale IP `100.94.171.76`.
  - Tracker: *"127.0.0.1 by default; remove allowedHosts IP."* Looks A-bucket but the dev workflow depends on Tailscale access — needs an explicit per-developer override mechanism. Plan that, then ship.

- [ ] **AUD-0337** (Major/Reliability) — 7 `any` props in `trade-idea-expanded-row.tsx` plus other components.
  - Tracker: *"Strict types."* Bundle with AUD-0317/0323/0329 (typing/codegen workstream).

- [ ] **AUD-0340** (Minor/Cleanup) — hand-maintained `partialize` field list in `ideasStore.ts:481-490`.
  - Tracker: *"Generate from a marker type."* Type-system trick that's the same shape as AUD-0317; bundle.

### F.4 — Workers / process model (chunk 10)

- [ ] **AUD-0301** (Major/Architecture) — 13 independent daemons + hand-rolled shell supervision.
  - Tracker: *"systemd unit files or Docker Compose."* THE foundational decision for chunk 10. Schedule before AUD-0294/0303 because they're downstream choices.

### F.5 — Test gaps

- [ ] **AUD-0199** (Major/Test Gap) — no tests for `level_guard_daemon.py` (1,582 LOC money-mover).
  - Bundle with AUD-0192 (split level_guard_daemon.py, already F) and AUD-0358 (coverage lift, already F). Tests should ride with the split.

- [ ] **AUD-0258** (Major/Test Gap) — no tests for Discord/Telegram parsers/state machine/normalizer.
  - Bundle with AUD-0358 + AUD-0250 (unify IdeaCreator, B-bucket — tests ride with that refactor).

- [ ] **AUD-0277** (Major/Test Gap) — already listed in F.2.

- [ ] **AUD-0320** (Major/Test Gap) — already listed in F.3.

- [ ] **AUD-0346** (Major/Test Gap) — `breach_analysis/` 1,542 LOC pure-numerical research code, zero tests.
  - Tracker: *"FeatureSet/FeatureExtractor pattern is ideally testable."* This one can ship unbundled — pure-function research code is the cheapest test write. ~1 day. Could be A if user de-prioritises consistency with the bigger F-bucket coverage workstream; F as default.

### F.6 — Peripheral / ops (chunk 13)

- [ ] **AUD-0202** (Major/Architecture) — breach-detection latency in `level_guard_daemon.py:89` (500ms polling + LevelMind subscription lag).
  - Tracker: *"Document latency budget; event-driven via NOTIFY/LISTEN."* New PG NOTIFY infrastructure + level-guard rework. Money-moving (bigger latency = bigger slippage). Plan first.

- [ ] **AUD-0259** (Major/Architecture) — extension self-botting as load-bearing assumption.
  - Already covered by AUD-0240 (B-bucket pick-one in [[decisions-pending]]: "Plan migration to Discord webhooks"). **G-bucket** in this re-triage — close as duplicate of AUD-0240.

- [ ] **AUD-0304** (Major/Reliability) — no log rotation across 5+ daemons.
  - Tracker: *"`RotatingFileHandler` everywhere. Reinforces AUD-0209."* Multi-daemon mechanical edit but coordinates with AUD-0301 (process-model decision — if systemd lands, journald replaces this).

- [ ] **AUD-0341** (Critical/Performance) — `system_monitor.py:95-345` 30+ subprocess spawns per request.
  - Tracker: *"Use `psutil`; cache 2-3s."* Bundles with AUD-0303 (bash→Python rewrite, B) + AUD-0350 (TOCTOU, F) + AUD-0352 (psutil migration, F).

- [ ] **AUD-0343** (Critical/Performance) — `trader_scorecard.py:87,96,110,138` hardcoded `account_id=1` + JSON-LIKE pattern match.
  - Tracker: *"Same pattern as AUD-0238/0242 ... Dedicated `source_channel_key` column; AccountContext."* Schema change (ride on top of AUD-0242 schema migration). C-adjacent but classified F because the larger redesign of `trader_scorecard.py` is multi-day.

- [ ] **AUD-0345** (Major/Duplication) — 10 `bin/tools/breach_*.py` CLIs sharing scaffolding (4,294 LOC total).
  - Tracker: *"`bin/tools/_lib/cli_base.py`."* Multi-file refactor. Bundle with AUD-0349 (orchestrator) into a "breach pipeline cleanup" planning session.

- [ ] **AUD-0349** (Major/Architecture) — implicit 6-stage breach pipeline with no orchestrator.
  - Tracker: *"`breach_pipeline.sh` or Python orchestrator."* Same workstream as AUD-0345.

- [ ] **AUD-0350** (Major/Reliability) — TOCTOU between PID read and metrics collection in `system_monitor.py:283-338`.
  - Bundle with AUD-0341/0352 into one "system_monitor.py rewrite" planning session.

- [ ] **AUD-0352** (Minor/Architecture) — `system_monitor.py` reimplements `psutil` in subprocess shell, 528 LOC.
  - Bundle with AUD-0341/0350.

---

## Bucket G — Close-as-WAI / won't-fix / duplicate

- [ ] **AUD-0259** — Close as **duplicate of AUD-0240** ([[decisions-pending]] B-bucket: extension migration to webhooks). The audit double-recorded the same finding from chunk 8 (AUD-0240) and chunk-12-ish architectural sweep. Tracker flip only.

---

## Cross-references / unblocking notes

- The **AUD-0008 / 0030 / 0224 / 0268 / 0302** cluster is one workstream: "PostgreSQL pool architecture." Schedule **AUD-0302 first** as the foundational decision (PgBouncer vs shared pool); everything else flows from it.
- The **chunk-11/12 frontend cluster** is roughly 18 F-bucket items that all gate on **AUD-0332 vitest setup**. Once that ships, the FE work parallelises nicely; without it, every commit is a regression-roulette.
- The **system_monitor.py cluster** (AUD-0303 + 0341 + 0350 + 0352) is one rewrite, not four separate fixes. Easiest to dispatch as a single B-bucket pick-one (rewrite-in-Python-with-psutil + cache + atomic-PID-read).
- **AUD-0271 + 0272 + 0270** in market data are sequential dependencies: ON-CONFLICT batch (C, ship first) → batch upsert in runner (F, after batch) → DDL move (F, last because callers depend on startup-side-effect today).

---

## Top 5 highest-leverage items in this batch

For quick user sign-off priority — ordered by "shipping this unblocks the most downstream work."

### 1. **AUD-0302** (Major/Architecture) — DB connection sprawl decision
**Bucket: F.** This is the gating decision for a 5-item cluster (AUD-0008/0030/0224/0268). Until we pick PgBouncer-vs-shared-pool, no other DB pool work can ship safely. **Plan first.**

### 2. **AUD-0271** (Critical/Performance) — candle ingest `ON CONFLICT` batch
**Bucket: C.** Single highest-impact perf win in the unclassified set. Wrong candles silently corrupt every analytic downstream. Schema-clean, well-understood pattern.

### 3. **AUD-0294** (Major/Duplication) — extract `bin/_lib/service-wrapper.sh`
**Bucket: B (a).** Biggest LOC delete (~2,300 lines) in the audit; mechanical; pays for every future wrapper change. Recommended option (a) is canonical.

### 4. **AUD-0301** (Major/Architecture) — process-model rewrite (systemd / Docker)
**Bucket: F.** Foundational chunk-10 decision. Without it, AUD-0292/0293/0294/0303/0304 are all "fix the symptom" patches. **Plan first.**

### 5. **AUD-0313** (Major/Performance) — delete `_t` cache-busting interceptor in `api.ts`
**Bucket: A.** Single-file deletion; net win on every dimension (browser cache, CDN, React Query dedup). Easiest "free perf" in the entire FE pile. Could ship today.

---

## Surprises

- **AUD-0073 already Resolved** — listed in [[decisions-pending]] Unclassified-Minor but the tracker row shows it landed under AUD-0042's f-string SQL remediation. The Unclassified list is therefore stale by one entry. Drop from re-triage.
- **AUD-0259 is a duplicate of AUD-0240** — same self-botting concern recorded twice across chunks 8 and 12. Recommend G-bucket close.
- **The F-bucket dominates 41/57** — far higher F ratio than any of the three earlier re-triage files. This is structural: chunks 9/10/11/12/13 are where the architectural-debt audits landed, vs the per-function bug-hunt in chunks 1-8. Expect any "land everything sensible" sprint to leave most of these untouched.
- **No D-bucket items** — none of these are genuinely Suspicious; they're all confirmed-real with known scope. The earlier batch-2 sweep (chunks 6-14) cleared every Suspicious item.
- **A bucket smaller than expected (4 items)** — the chunk-11/12 FE work is dominated by mega-component splits (F-bucket), not quick-yes wins. The few easy wins (AUD-0313/0322/0338/0339) are real but won't move the resolved-percentage needle far.
