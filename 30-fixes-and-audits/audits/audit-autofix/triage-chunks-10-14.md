# Audit autofix triage — chunks 10, 11, 12, 13, 14

**Generated:** 2026-04-23
**Scope:** AUD-0290 through AUD-0366 (77 findings across 5 chunks)
**Purpose:** Classify into T1 (autofix) / T2 (human-review) / T3 (architectural) / T4 (closed / stale claim).
**Process:** User reviews this file. On approval, Step 2 executes T1 items autonomously.

## Counts

| Tier | Count | Meaning |
|---|---|---|
| **T1** | 7 | Ready for autonomous fix |
| **T2** | 16 | Needs a one-page proposal, then user decides |
| **T3** | 48 | Architectural / deferred / vitest-blocked frontend |
| **T4** | 6 | Already Resolved / stale claim / fixed but tracker not updated |
| **Total** | 77 | |

The frontend-heavy chunks (11, 12) and ops/arch (14) dominate T3. The hard
constraint is that **no vitest is wired up** — per CLAUDE.md, this means any
non-CSS frontend fix that adds files or changes signatures is T3 until a test
harness exists. That pushes nearly all of chunks 11-12 into T3.

T1 in these chunks is narrow and mostly lives in chunks 10, 14, and the
single-file breach backend work.

---

## T1 — Autonomous fix queue (7)

### bin/tl (service-manager shell wrapper)
- **AUD-0296** Major/Cleanup — 4 hardcoded service lists (`SERVICES`,
  `SERVICES_REVERSE`, `SERVICES_ALL`, `SERVICES_ALL_REVERSE`) must stay in
  sync. Derive the reverse/all variants from the forward list in bash.
  Verified at `bin/tl:43-48`. Purely mechanical transformation; output of
  `tl status` should be unchanged. Exempt as `config-only` /
  `docs-only`-adjacent shell refactor, but defensively include a shell-level
  smoke test of `tl` status parsing.

### bin/engine/correlation_worker.py
- **AUD-0297** Major/Performance — `_fetch_candle_data` issues one query
  per symbol. Swap the `for symbol in symbols: cursor.execute(...)` loop for
  a single `WHERE symbol = ANY(%s)` + Python-side group. Verified at
  correlation_worker.py:153-187. Return shape (`dict[symbol] → [(ts, close)]`)
  preserved. Mechanical; needs a unit test asserting the new SQL binds a
  list and groups on `symbol`. No public-API change.

### pyproject.toml (dead runtime deps)
- **AUD-0363** Major/Cleanup — Remove `streamlit>=1.28.0` and
  `pandas>=2.1.0` from runtime dependencies. Grep-verified: zero
  `import pandas` / `import streamlit` / `from pandas` / `from streamlit`
  references anywhere in `bin/`, `lib/`, `tests/`, or `frontend/`. Commit
  exempt as `config-only` (dep manifest, no logic paths).

### .gitignore (AUD-0356 — runtime-state footguns)
- **AUD-0356** Critical/Reliability — Add `logs/`, `cache/`, `.next/`,
  `frontend/web/.next/` to `.gitignore`. Verified not currently present.
  None are tracked, so this is purely preventive. Commit exempt as
  `config-only`. Note: AUD-0353 (secrets-in-git-history) is a separate T3
  item — rotating keys + `git filter-repo` stays out of scope here.

### bin/TRASH/ + bin/pipeline/TRASH/ + etc/*.bkup (verified dead)
- **AUD-0359** Major/Dead Code — Delete the TRASH directories and the
  .bkup files that are either untracked or zero-reference. Grep verified:
  `bin/TRASH/` only referenced internally by its own files +
  `docs/INDEX.md` (one-liner pointing at a POC README that'll be deleted
  with it); `bin/pipeline/TRASH/` has no in-repo callers;
  `accounts.yml.bkup` is untracked; `devdoc.bkup` is untracked;
  `frontend/web/.next/` is untracked. **NOT included in this T1:**
  `etc/config.yml.bkup-20251110223555` is the secrets-in-history file —
  that needs AUD-0353's full rotation + filter-repo workflow. Leave it
  alone; this commit only removes the verified-dead artefacts and updates
  docs/INDEX.md to drop the POC reference. Commit exempt as
  `dead-code-removal`.

### Root housekeeping (AUD-0365 partial)
- **AUD-0365** Minor/Cleanup — Delete `playwrite_notes` (untracked typo'd
  file), and `.plan` (tracked, but a stale completed bug-fix checklist —
  grep-verified zero references). **NOT included:** `ACHIEVEMENT.md` is
  untracked but arguably a project milestone doc; leave that call to the
  user. Commit exempt as `dead-code-removal`.

### tests/integration/ claim is incorrect (T4 reclassification)
- **AUD-0366** — the finding claims the directory is empty. Verified false:
  13 integration tests exist (test_accounts_api, test_level_guard_*,
  test_journal_sessionization_db, etc.). Demote to **T4 (stale claim)** —
  the audit read of "only `__init__.py`" was wrong. No fix needed; the
  tracker row should be flipped to Resolved / Stale-claim when human
  updates the tracker.

---

## T2 — One-page proposal queue (16)

Each needs a design decision or touches money-moving / signature-stable code.

| ID | Severity | Why T2 (not T1) |
|---|---|---|
| **AUD-0292** | Critical/Reliability | Unbounded `pkill -9` loops — bounded retry is behavior-visible; ops runbooks may rely on current "kill until gone" semantics |
| **AUD-0293** | Critical/Security | `pkill -f` path qualification — staging/prod collision is real but fix requires PID-file plumbing across ~12 wrappers; cross-file behavior change |
| **AUD-0295** | Major/Cleanup | Add `status`/`run` to `bin/api` and `bin/dashboard` stubs — matches other wrappers, but introduces new behavior; users may have scripts expecting the 18-line stub shape |
| **AUD-0298** | Major/Performance | Batch Bybit `get_tickers` replacing per-alert `get_ticker` — introduces new Bybit client method (signature) and changes the per-symbol failure fallback |
| **AUD-0299** | Major/Performance | Cycle-scoped connection for alert_engine helpers — requires passing `conn`/`cursor` through `_get_trade_waep_waxp`, `_get_price_by_lineage` etc.; changes function signatures |
| **AUD-0300** | Major/Performance | Subprocess → in-process pipeline — signature change + CLI entry-point refactor; touches pipeline_daemon:240-298 but risks async/error-propagation semantics |
| **AUD-0305** | Minor/Reliability | 5-second force-kill timeout → configurable — policy decision; needs default choice |
| **AUD-0306** | Minor/Reliability | Lease refresh ratio change — monitors may rely on 120s window for recovery |
| **AUD-0307** | Minor/Cleanup | Machine-readable status via JSON — requires updating all ~12 wrapper scripts in one commit |
| **AUD-0342** | Critical/Performance | Single window-function query replacing the N+1 `trader_scorecard` helpers — correct refactor, but SQL is load-bearing for the UI card |
| **AUD-0348** | Major/Duplication | Unify `_PYTHON_PATTERNS` and `SERVICES` — different fields today (`display_name`, `script`, `self_service`); merge is design choice |
| **AUD-0351** | Major/Performance | Add `Cache-Control: max-age=60` to correlation endpoint — caching policy, may surprise users expecting live data |
| **AUD-0344** | Major/Security | Parameterise DuckDB SQL in tick_loader — low-risk today but signature addition (swap path-string API for param list); research code |
| **AUD-0355** | Critical/Reliability | Marked Resolved — already done |
| **AUD-0357** | Critical/Bug | Migration idempotency sweep — requires convention enforcement; pure T1 on already-applied migrations is harmless but the policy choice (enforce on new ones? retrofit?) is a decision |
| **AUD-0362** | Major/Cleanup | Setup script runbook — needs operator-knowledge document, not a grep fix |

Note: AUD-0355 is already Resolved in the tracker — listed here only
because it's adjacent to the idempotency policy decision in AUD-0357.

---

## T3 — Architectural / deferred (48)

No attempt in this workstream. Chunks 11/12 are almost entirely T3 because
**vitest is not wired up** — per CLAUDE.md, non-styling frontend changes
cannot ship without tests, and test-harness setup itself is T3.

### Chunk 10 — workers/daemons (5)
| ID | Why T3 |
|---|---|
| **AUD-0291** | Per-thread PG connection → shared pool — **actually already implemented** (see level_mind_worker.py:77-82 comment citing AUD-0291). T3 label is formal; flag for T4 reclassification in tracker update |
| **AUD-0290** | No singleton enforcement — **actually already implemented** (grep shows `acquire_singleton_lock("pipeline_daemon")` and `("level_mind_worker")`). Flag for T4 reclassification |
| **AUD-0294** | 12× duplicated wrappers → single `service-wrapper.sh` — cross-cutting refactor |
| **AUD-0301** | 13 daemons + hand-rolled shell supervision → systemd/Docker — full deploy-model change |
| **AUD-0302** | DB connection sprawl → PgBouncer — infra work |
| **AUD-0303** | bin/monitor 641-LOC bash → Python rewrite — full rewrite |
| **AUD-0304** | RotatingFileHandler across daemons — touches every daemon's logging setup; cross-cutting |

### Chunk 11 — frontend top-5 files (13)
Every item except CSS is blocked on vitest.
| ID | Why T3 |
|---|---|
| **AUD-0308** | Split 6,731-LOC trade-journal-chart.tsx — multi-week |
| **AUD-0309** | react-hook-form migration for smart-trade-form.tsx — multi-day |
| **AUD-0310** | Split 3,647-LOC trade-journal.tsx — multi-week |
| **AUD-0311** | Complete React Query migration — touches every polling site |
| **AUD-0312** | Frontend auth headers — cross-cutting, needs backend coordination |
| **AUD-0313** | Remove cache-busting `_t` param — no tests to prove it doesn't break SW cache |
| **AUD-0314** | Split 3,192-LOC api.ts + OpenAPI codegen — tooling + multi-PR work |
| **AUD-0315** | Memoisation sweep in chart — no render tests |
| **AUD-0316** | Fix `eslint-disable exhaustive-deps` — requires understanding each stale-closure site; no tests to catch regressions |
| **AUD-0317** | `type Update = Partial<Create>` sweep — drifts through most of api.ts; no tests |
| **AUD-0318** | Push all filters server-side — API contract change |
| **AUD-0319** | `setXLocal`/`setX` wrapper pattern — same as AUD-0309 (react-hook-form) |
| **AUD-0320** | Test coverage gap — setup vitest first |
| **AUD-0321** | Structured error types — cross-module |
| **AUD-0322** | Extract 100+ line markdown to .md file — tiny, but creates a new file + Vite `?raw` loader setup; without tests it's risky |
| **AUD-0323** | FE/BE enum drift — needs OpenAPI gen |
| **AUD-0324** | Sentry / remove console.* — dependency add + behavior change |

### Chunk 12 — frontend rest (14)
| ID | Why T3 |
|---|---|
| **AUD-0325** | `gcTime: Infinity` → 5m default — memory-saving but changes cache semantics globally; no tests |
| **AUD-0326** | ErrorBoundary — new dependency + crash-handling policy |
| **AUD-0327** | CSP + SRI + self-host fonts — multi-file infra |
| **AUD-0328** | Persistence consolidation — multi-day store refactor |
| **AUD-0329** | 3-definition `DcaLevel`/`TpLevel` — cleanup but sweeps 3 files; no tests |
| **AUD-0330** | Mega-component split across 8 files — multi-week |
| **AUD-0331** | React.lazy / code splitting — bundle-config change, Vite |
| **AUD-0332** | Wire up vitest — blocker for all other frontend work |
| **AUD-0333** | `refetchOnMount` + `staleTime` defaults — cache-policy change |
| **AUD-0334** | Journal store migrations for version:21 — needs migration authoring per bump |
| **AUD-0335** | Finish React Query migration — same as AUD-0311, chunk-12 scope |
| **AUD-0336** | Dev vite config host — IP is intentional for Tailscale (see MEMORY.md); "fix" changes developer workflow |
| **AUD-0337** | Strict-type sweep — multi-file; `any` usages require understanding actual contract |
| **AUD-0338** | NotFound route — adds a new route + component file; without vitest, risky |
| **AUD-0339** | Raw localStorage recovery paths — cross-file |
| **AUD-0340** | Generate `partialize` from marker type — codegen tooling |

### Chunk 13 — peripheral (8)
| ID | Why T3 |
|---|---|
| **AUD-0341** | 30+ subprocess/request in system_monitor → psutil rewrite — new dependency + 528-LOC refactor |
| **AUD-0343** | Hardcoded `account_id=1` + JSON-LIKE — needs dedicated `source_channel_key` column (schema change) |
| **AUD-0345** | CLI base extraction for 10 breach_*.py — useful but cross-10-file refactor |
| **AUD-0346** | breach_analysis test coverage — setup tests first |
| **AUD-0347** | Separate schema for research tables — schema migration |
| **AUD-0349** | breach_pipeline orchestrator — new tooling |
| **AUD-0350** | system_monitor TOCTOU — needs /proc atomic read refactor |
| **AUD-0352** | Adopt psutil — duplicates AUD-0341; T3 |

### Chunk 14 — ops (8)
| ID | Why T3 |
|---|---|
| **AUD-0353** | Rotate Bybit keys + filter-repo etc/config.yml.bkup from history — production secret rotation + destructive git history rewrite; user-only task |
| **AUD-0354** | Convert all plaintext secrets in config.yml to `${VAR}` — cross-cutting; also needs config.yml.example + deploy updates |
| **AUD-0358** | 4.4% → higher test coverage — multi-month |
| **AUD-0360** | 4 schema sources of truth — migrations-as-SOT policy shift, ties in with AUD-0355/0357 |
| **AUD-0361** | CI/CD + pre-commit — setup work |
| **AUD-0364** | migrations/pg/ half-finished — **actually already deleted** (directory missing). T4 reclassification |

---

## T4 — Closed already / stale claim (6)

| ID | Why T4 |
|---|---|
| **AUD-0290** | singleton_lock call already present (pipeline_daemon.py:519; level_mind_worker.py:1030). Tracker not yet updated. |
| **AUD-0291** | Shared pool already implemented; comment block cites AUD-0291 (level_mind_worker.py:77-82). Tracker not yet updated. |
| **AUD-0355** | Already marked Resolved in tracker. |
| **AUD-0364** | `migrations/pg/` directory already deleted. No `/pg/` references anywhere. Tracker not yet updated. |
| **AUD-0366** | Claim is stale: `tests/integration/` has 13 tests. Tracker misread the listing. |
| — | (no other explicit T4 in this range) |

---

## Execution plan for Step 2

Order of T1 work (grouped by file to share worktrees):

1. **.gitignore** (AUD-0356) — smallest, purely additive
2. **pyproject.toml** (AUD-0363) — trivial, commit-exempt `config-only`
3. **bin/tl** (AUD-0296) — single shell file, local change
4. **bin/engine/correlation_worker.py** (AUD-0297) — needs unit test for batched SQL
5. **TRASH directories + bkup files** (AUD-0359) — `git rm` + docs/INDEX.md update
6. **Root housekeeping** (AUD-0365 partial) — `git rm .plan` + `rm playwrite_notes`

Six commits, 6 findings. AUD-0366 demoted to T4 needs no commit, just a
tracker flip when human touches the row.

---

## Review checklist

Before kicking off Step 2, please confirm:

- [ ] **T1→T2 rethink:** AUD-0363 depends on `streamlit` and `pandas`
      being genuinely unused. Grep showed zero imports in `bin/`, `lib/`,
      `tests/`. Is there any out-of-repo tool (notebook, script) that
      `pip install`s the venv and expects them?
- [ ] **AUD-0359 scope:** confirm user is OK deleting `docs/INDEX.md`
      reference to `bin/TRASH/poc/README.md` (since we're deleting the
      target). If no — AUD-0359 becomes T2.
- [ ] **AUD-0365 scope:** OK to delete `.plan`? Untracked
      `playwrite_notes` + `ACHIEVEMENT.md` are a gray area; I'm leaving
      the latter.
- [ ] **AUD-0290/0291/0355/0364/0366 tracker flips:** these five should be
      marked Resolved when the tracker is next touched. Confirm you want
      Step 2 to do that in the same commit stream as the T1 fixes, or in
      a separate cleanup commit.
- [ ] **Frontend boundary:** any T3 frontend item you want pulled up to
      T2 because you're willing to land it without tests (at your risk)?
- [ ] **Chunk 14 vs chunk 10 priority:** T1 batches fit in ~6 commits;
      should I interleave or run ops first (AUD-0356/0363 — lowest risk)?

Reply "go" to kick off Step 2 on the T1 batch, or name IDs to move.
