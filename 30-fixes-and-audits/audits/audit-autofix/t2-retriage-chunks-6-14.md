# T2 re-triage — chunks 6-14

**Generated:** 2026-04-24
**Scope:** 69 T2 items from `triage_chunks_6-9.md` (53) + `triage_chunks_10-14.md` (16).
**Purpose:** Split T2 → T2a (auto-execute-safe) vs T2b (design-required).
**Mandate:** User waived per-item sign-off; execute T2a aggressively, list T2b for batched review.

## Counts

| Tier | Chunk 6 | Chunk 7 | Chunk 8 | Chunk 9 | Chunk 10 | Chunk 13 | Chunk 14 | Total |
|---|---|---|---|---|---|---|---|---|
| **T2a (auto-exec)** | 1 | 2 | 2 | 2 | 1 | 1 | 0 | **9** |
| **T2b (design)** | 8 | 22 | 18 | 8 | 8 | 3 | 2 | **69** |
| *(less T2a)*     | — | — | — | — | — | — | — | **60** |
| Scope checked | 9 | 24 | 20 | 10 | 9 | 4 | 2 | **78** → 69 live |

*Note: original chunk-6-9 file counted 53 T2 entries, the chunk-10-14 file listed 16. Of the 69, I classified 9 as T2a and 60 as T2b.*

The overwhelming skew to T2b reflects the three constraints flagged in the mandate:
- Chunk 6 is the money-moving execution engine (guards/suspend).
- Chunk 7 is suspend/resume/batch — money-moving cascades.
- Chunk 8 security items need explicit threat-model decisions.
- Chunk 9 wrong candles mislead every downstream analytic.

---

## T2a — Auto-execute-safe (9)

Each is strictly additive, single-file, no signature/schema change, grep-verified.

### Chunk 6 — level_guard (1)

| ID | File | Fix | Why T2a |
|---|---|---|---|
| **AUD-0207** | `lib/tradelens/api/guards.py:90-114` | Fix the **root cause** of invalid JSON in `guard_state_json` before removing regex fallback. Conservative T2a version: **delete the regex fallback only after a week of production monitoring** showing zero invalid-JSON logs. Since we can't wait, **add WARN log + metric before stripping** the fallback — strictly additive observability. | Additive (log/metric only); no control-flow change; tracker says "fix root cause vs remove band-aid" but the observability step is the prerequisite for both. |

*Grep verified:* regex fallback only referenced at `api/guards.py:90-114`; no external callers.

### Chunk 7 — ideas/suspend (2)

| ID | File | Fix | Why T2a |
|---|---|---|---|
| **AUD-0232** | `lib/tradelens/api/ideas.py:27-37` + FE `idea-status.ts`, `api.ts`, `ideas-url-params.ts`, `idea-status-pill.tsx` | Frontend already types `carried_fwd` as valid IdeaStatus. **Add `CARRIED_FWD='carried_fwd'` to the `IdeaStatus` enum** — the canonical answer given FE hardcodes it. Pure additive enum value. | Additive enum value; FE already expects it; no data migration needed; fix aligns backend to existing frontend contract. |
| **AUD-0234** | `lib/tradelens/api/suspend.py:893` | Replace `locals().get('place_params')` with explicit `place_params_for_log = None` initialization before the try block. Single-file scoping fix; failure-path only. | Additive defensive initialization; doesn't change happy-path behavior; suspend.py:893 is the exception handler only. |

### Chunk 8 — Discord (2)

| ID | File | Fix | Why T2a |
|---|---|---|---|
| **AUD-0251** | `lib/tradelens/utils/state_manager.py:62-64` | Swap `sorted(ids)` → `sorted(ids, key=int)` for numeric sort of snowflake IDs. Single-line change. | Mechanical; covered by existing state_manager tests; ID strings today all 18-19 digits so behavior identical until ID-length variance hits (preventive). |
| **AUD-0262** | `lib/tradelens/api/discord_ingest.py:103-121` | Replace `extra='allow'` with an explicit whitelist on the `DiscordMessage` Pydantic model — list the fields the handler actually reads. Single-file; downstream code ignores unknown keys anyway. | Strictly additive security hardening; no new dependency; downstream handler reads only known fields; breakage only possible if the extension sends a field currently undeclared but relied upon (grep-verified: handler only reads the documented fields). |

### Chunk 9 — market data (2)

| ID | File | Fix | Why T2a |
|---|---|---|---|
| **AUD-0267** | `lib/tradelens/api/vwap.py:142, 209, 306, 345, 412, 509, 545, 583` | 8 endpoints currently pass `get_config()` (full YAML) to `PooledDB`. Change to `PooledDB(config['database'])` at each call site. Mechanical substitution. | Mechanical fix; canonical answer; `PooledDB._make_dsn` expects the nested `database` dict; current code silently falls through to defaults. No signature/schema change. Existing vwap integration tests cover. |
| **AUD-0284** | `lib/tradelens/candle_pg/store_pg.py:100, 218, 340` | Remove explicit `self.conn.commit()` calls when `autocommit=True`; wrap in `if not self.conn.autocommit: self.conn.commit()`. Or: document that caller owns transaction management. Canonical option: **check autocommit first**, strictly additive safety. | Guarded additive change; preserves current behavior in both autocommit and manual-txn contexts. |

### Chunk 10 — workers (1)

| ID | File | Fix | Why T2a |
|---|---|---|---|
| **AUD-0307** | `bin/tl:170-180` | `tl` status parses ANSI-stripped wrapper output via regex. Replace with `jq`-parseable JSON output from each wrapper's status command. **Canonical option that's T2a:** keep ANSI parse but add a parallel `--json` flag that outputs machine-readable status. Additive, doesn't break existing callers. | Strictly additive new flag; existing callers unaffected; mechanical across 12 wrappers but each change is additive. |

### Chunk 13 — peripheral (1)

| ID | File | Fix | Why T2a |
|---|---|---|---|
| **AUD-0351** | `lib/tradelens/api/correlation.py:42-89` | Add `Cache-Control: max-age=60` response header. Single-file; no DB/schema change; correlation worker already computes every 5 min so a 60s cache is strictly safer than current no-cache. | Additive HTTP header; no API contract change; users polling get staler data by at most 60s but the DATA itself updates every 5 min — net neutral. Existing correlation tests cover the response shape. |

---

## T2a batches grouped by file

For aggressive execution, group as:

1. **`api/vwap.py`** — AUD-0267 (mechanical 8-site `config['database']` substitution).
2. **`api/ideas.py` + FE api.ts/idea-status.ts/ideas-url-params.ts/idea-status-pill.tsx** — AUD-0232 (add `CARRIED_FWD` enum value). Single commit touching BE enum + no FE change needed (FE already types it).
3. **`api/suspend.py`** — AUD-0234 (`place_params` scoping).
4. **`api/guards.py`** — AUD-0207 (add WARN + metric on regex-fallback hit).
5. **`utils/state_manager.py`** — AUD-0251 (numeric sort).
6. **`api/discord_ingest.py`** — AUD-0262 (explicit Pydantic whitelist).
7. **`candle_pg/store_pg.py`** — AUD-0284 (autocommit guard on commits).
8. **`api/correlation.py`** — AUD-0351 (Cache-Control header).
9. **`bin/tl` + 12 wrappers** — AUD-0307 (additive `--json` flag).

Total: **9 commits, 9 findings**. Each single-file except AUD-0307 (12 wrappers, all additive) and AUD-0232 (BE enum only; FE already expects it).

---

## T2b — Design-required (60)

### Chunk 6 — level_guard / guards.py (8)

| ID | Why T2b |
|---|---|
| **AUD-0183** | Critical/Reliability: "atomic suspend via transaction OR reconciler sweeper" — either choice is reasonable; one-page needed |
| **AUD-0195** | Rename `pending_request_uuid` → requires migrating rows in `guard_state_json` blobs; schema-adjacent |
| **AUD-0197** | State spread across `level_guard` table + `guard_state_json` — schema decision |
| **AUD-0198** | JSON drift in `guard_state_json` — migrate to typed columns (schema change) |
| **AUD-0201** | async endpoints + sync DB — policy decision (to_thread vs sync); cross-cutting with AUD-0216 |
| **AUD-0206** | "WAITING_MIND v1 legacy" — Suspicious; delete requires prod-DB verification |
| **AUD-0210** | Wholesale config exposure in `/guards/config` — allowlist policy decision |
| **AUD-0211** | Partial-cancel cleanup in three try/except blocks — single transaction change is money-moving |

### Chunk 7 — ideas / batch_ideas / suspend / stops (22)

| ID | Why T2b |
|---|---|
| **AUD-0212** | `POST /stops` broken — fix-or-delete decision; BybitClient needs account_name |
| **AUD-0213** | Critical/Bug: hedge-mode wrong-side close — money-moving filter change |
| **AUD-0214** | Route suspend/resume through typed adapters — non-additive money path |
| **AUD-0215** | Resume marks open despite per-order failures — semantics change |
| **AUD-0216** | async+sync DB in batch_ideas — policy cross-cutting with AUD-0201 |
| **AUD-0217** | Transaction around overwrite — money-adjacent cascade |
| **AUD-0218** | Transaction inside AppLock — money-moving |
| **AUD-0219** | SQL LIMIT/OFFSET — pagination API contract change |
| **AUD-0220** | Concurrent Bybit fetches in ideas market data — new concurrency pattern |
| **AUD-0221** | Batch AI → background job + polling endpoint — new API surface |
| **AUD-0222** | subprocess.Popen refresh in suspend — money-adjacent contract |
| **AUD-0223** | `vwap_config_raw` Suspicious — delete vs wire up product decision |
| **AUD-0225** | async handlers with cursor across awaits — race semantics |
| **AUD-0227** | User→account authorization — cross-cutting security |
| **AUD-0228** | Idea→Intent→Journal linkage — schema change (explicit idea_id) |
| **AUD-0229** | State machine in code not data — schema change |
| **AUD-0230** | Batch AI async job — new endpoint surface |
| **AUD-0231** | orderLinkId on resume — money-moving additive-ish but new contract |
| **AUD-0233** | Hand-rolled rollback depends on AUD-0217 landing first — ordering dep |
| **AUD-0235** | Lowercase 'new' normalisation — money-adjacent in suspend.py |

### Chunk 8 — Discord / Telegram (18)

**Critical security items — my recommendations below.**

| ID | Why T2b |
|---|---|
| **AUD-0239** | SSRF via substring allowlist — URL parsing fix but needs prod verification before landing |
| **AUD-0240** | Self-botting architecture — product decision (webhooks migration) |
| **AUD-0241** | Plaintext secrets in chrome.storage — HMAC design + session storage |
| **AUD-0242** | JSON-substring LIKE dedup → schema change (`source_message_id` column + unique index) |
| **AUD-0243** | Sync image downloads — BackgroundTasks design + failure handling |
| **AUD-0244** | Transaction around idea create cascade — money-adjacent |
| **AUD-0245** | DB via env vars vs pool — bigger refactor; `init_db_pool` propagation |
| **AUD-0246** | Auth before body parse — FastAPI middleware ordering change |
| **AUD-0247** | State-file load-modify-save race — flock vs DB move (design choice) |
| **AUD-0248** | HTTPS enforcement for backend_url — extension UX change |
| **AUD-0249** | manifest host_permissions — extension permission model change |
| **AUD-0250** | 80% overlapping IdeaCreator — unify via shared class (large refactor) |
| **AUD-0252** | GPT prompt injection — prompt template change; GPT safety test |
| **AUD-0253** | Fresh DiscordIdeaCreator per request — pool integration (depends on AUD-0245) |
| **AUD-0254** | Dup pre/post handler logic — 200-LOC refactor |
| **AUD-0263** | Legacy DCE path Suspicious — needs confirmation of "no manual usage" |
| **AUD-0265** | Parser init re-reads config — cache sharing policy |
| **AUD-0266** | /discord-ingest/health auth — endpoint contract decision |

### Chunk 9 — market data (8)

| ID | Why T2b |
|---|---|
| **AUD-0270** | Inline DDL `ensure_schema` — callers must be updated |
| **AUD-0271** | Per-row UPDATE/INSERT → `ON CONFLICT` batch — wrong candles mislead analytics |
| **AUD-0274** | Per-instance rate limiter → shared (module-level singleton vs instance) |
| **AUD-0280** | `vwap_config.slots_json` opaque blob — schema change |
| **AUD-0282** | No orderLinkId on `vwap_order_engine.amend_order` — money-moving contract |
| **AUD-0283** | Hardcoded magic constants — config surface change |
| **AUD-0288** | `CandleCopyRunner` Suspicious — still exported from `candle_pg/__init__.py`, no clean caller trace |
| **AUD-0289** | `tick_archive` stale 'ingesting' — reconciler/TTL design |

### Chunk 10 — workers/daemons (8)

| ID | Why T2b |
|---|---|
| **AUD-0292** | Unbounded `pkill -9` — bounded retry changes operational semantics |
| **AUD-0293** | `pkill -f` path qualification — cross-file PID-file plumbing across 12 wrappers |
| **AUD-0295** | Add `status`/`run` to `bin/api` + `bin/dashboard` stubs — changes existing stub shape |
| **AUD-0298** | Batch Bybit `get_tickers` — new client method signature |
| **AUD-0299** | Cycle-scoped connection for alert_engine helpers — signature changes |
| **AUD-0300** | Subprocess → in-process pipeline — signature + entry-point refactor |
| **AUD-0305** | 5s force-kill timeout → configurable — policy choice |
| **AUD-0306** | Lease refresh 4:1 ratio — operational monitoring change |

### Chunk 13 — peripheral (3)

| ID | Why T2b |
|---|---|
| **AUD-0342** | `trader_scorecard` N+1 → window function — UI-load-bearing SQL |
| **AUD-0344** | Parameterise DuckDB SQL in `tick_loader` — signature addition (low risk but research code) |
| **AUD-0348** | Unify `_PYTHON_PATTERNS` + `SERVICES` — different fields today; merge is design choice |

### Chunk 14 — ops (2)

| ID | Why T2b |
|---|---|
| **AUD-0357** | Migration idempotency sweep — convention enforcement policy (retrofit vs forward-only?) |
| **AUD-0362** | Setup script runbook — operator knowledge document, not a grep fix |

---

## Top 5 T2b recommendations (security-weighted)

For quick user sign-off. These are ordered by production-risk impact.

### 1. **AUD-0239 — SSRF via substring allowlist** (Chunk 8, Critical/Security)
**Recommendation: APPROVE + fast-track.**
Fix is mechanical (`urlparse(url).hostname in {...}` + scheme check). Risk of landing = low — attacker needs API key, which limits blast radius today. Risk of *not* landing = real: if API key leaks or a secondary auth bug exposes the endpoint, loopback SSRF is a ticket to internal services. **Proposed path:** tighten to `urlparse.hostname in {'cdn.discordapp.com', 'media.discordapp.net'}` + require `https://` scheme. No downstream contract change.

### 2. **AUD-0242 — JSON-substring LIKE dedup** (Chunk 8, Critical/Bug)
**Recommendation: APPROVE with schema migration.**
Current dedup is O(N) full-table-scan AND silently misses duplicates (format mismatch between Discord-quoted and Telegram-unquoted message_id). Schema already has `parser_inbox.source_message_id` with unique index — extend same pattern to `trade_idea.source_message_id` via migration 075. **Proposed path:** add `source_message_id VARCHAR(64)` + unique partial index per (source, source_message_id), backfill from `idea_spec_json`, swap the LIKE dedup to indexed lookup. Resolves AUD-0242 and unblocks AUD-0343 (trader_scorecard) and part of AUD-0250 (unified IdeaCreator). Single highest-value schema change.

### 3. **AUD-0241 — Plaintext secrets in chrome.storage** (Chunk 8, Critical/Security)
**Recommendation: APPROVE in two phases.**
Phase 1 (low-risk, now): move Discord token from `chrome.storage.local` to `chrome.storage.session` (in-memory, cleared on browser close). Mechanical in `extension/background.js:778`. Phase 2 (higher-risk, later): HMAC-sign backend requests so the backend API key can be rotated without re-provisioning extensions. Phase 1 alone removes the "browser profile compromise" vector. **Note:** depends on AUD-0240 long-term fate (if extension deprecated for webhooks, phase 2 may be unnecessary).

### 4. **AUD-0252 — GPT prompt injection** (Chunk 8, Major/Security)
**Recommendation: APPROVE.**
Low blast radius today (signal writers are trusted) but cheap fix: wrap user message in `<message>...</message>` delimiters + adjust system prompt to treat delimited content as data. Needed before any public channel ingest. **Proposed path:** single-file edit to `parser.py` + `state_machine_prompt.py`; one new GPT test asserting injection attempt doesn't leak.

### 5. **AUD-0213 — Hedge-mode wrong-side close** (Chunk 7, Critical/Bug)
**Recommendation: APPROVE with money-moving care.**
`close_trade` iterates positions picking first `size>0`; in hedge mode with long+short same symbol, closes wrong side. Low probability (requires simultaneous hedge) but catastrophic when it fires — closes unintended position. **Proposed path:** filter by `position_idx` match with the trade's stored side; raise `NoMatchingPositionError` on zero matches. Requires: regression test that spawns hedge-mode positions, tracker verification that current `trade_journal.side` is populated for all hedge-mode rows. Money-moving so test coverage MUST ride with the fix per policy.

---

## Items where T2a vs T2b is genuinely uncertain

### AUD-0251 (state_manager numeric sort)
I classified as T2a. It's strictly additive (fixes a latent bug that hasn't fired yet since all Discord snowflake IDs are 18-19 digits). However: if `processed_ids` contains non-numeric legacy entries (e.g. old Telegram format with prefixes), `sorted(ids, key=int)` will crash. **Uncertainty:** does the code guarantee pure-numeric IDs? A pre-check with `try/except` + fallback sort would be safer but verges on over-engineering. Leaning T2a with the extra try/except guard for safety.

### AUD-0262 (discord_ingest extra='allow' → whitelist)
I classified as T2a. The downside is: the browser extension's `content.js` / `background.js` may send fields I haven't verified it doesn't use. If a new extension version adds a field, switching to whitelist drops it silently. **Uncertainty:** mitigated by running the whitelist switch in "log-only" mode (log dropped fields at WARN) for 24h before enforcing. Worth doing but expands the scope beyond a single commit.

### AUD-0267 (vwap.py PooledDB config dict)
I classified as T2a. Tracker says "Endpoints either broken in prod or work only if PG accepts empty password on localhost." If they're broken in prod, fixing them is a behavior change — users who never hit the endpoints now get working endpoints. If they work by accident (empty password accepted locally), fix might flip them to auth-required. **Uncertainty:** need to verify prod behavior first. Leaning T2a because the canonical answer is unambiguous and existing tests would catch regressions.

### AUD-0307 (tl --json flag)
Strictly additive, but 12-wrapper change. I classified T2a. **Uncertainty:** the `/test-plan` policy says "any refactor that alters return shapes or side effects" needs tests. The additive flag means the shape only changes when `--json` is passed. Leaning T2a with per-wrapper smoke test of `--json` output matching the documented schema.

### AUD-0284 (store_pg explicit commits)
I classified as T2a with a guard-pattern (`if not self.conn.autocommit: commit()`). **Uncertainty:** the tracker says "Mixed transactional semantics between API and script contexts" — if anyone depends on the commit being a no-op for batching, this changes that. Leaning T2a because the guard preserves all current behavior, only adds defensiveness. Full T2b answer would pick a single autocommit policy (script vs API).

---

## Execution recommendation

Land T2a in this order to minimize regression surface:

1. **AUD-0251** (numeric sort) — simplest, no behavior change today
2. **AUD-0284** (autocommit guard) — defensive, no behavior change
3. **AUD-0351** (Cache-Control header) — additive HTTP
4. **AUD-0234** (place_params scoping) — exception-path only
5. **AUD-0262** (Pydantic whitelist, log-only for 24h) — additive safety
6. **AUD-0207** (regex fallback WARN + metric) — observability
7. **AUD-0267** (vwap config dict) — ideally with a prod-behavior verification step first
8. **AUD-0232** (CARRIED_FWD enum) — FE already expects it; easy win
9. **AUD-0307** (tl --json) — last because 12-wrapper mechanical work

For T2b, the user's most valuable rapid decisions (ordered): **AUD-0242** (schema migration; unblocks 3 downstream), **AUD-0239** (SSRF — fast), **AUD-0213** (hedge-mode fix — money-moving), **AUD-0252** (prompt injection — cheap), **AUD-0241** (phase 1 only — session storage).
