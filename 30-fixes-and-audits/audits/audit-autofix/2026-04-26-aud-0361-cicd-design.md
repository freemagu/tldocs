---
status: design-ready-for-implementation
generated: 2026-04-26
authors: claude-orchestrator-via-subagent
audit-id: AUD-0361
tier: T3
related:
  - AUD-0357 (forward-only migration policy — pre-commit hook should enforce)
  - AUD-0332 (vitest bootstrap — frontend test infra; CI must run it once it exists)
  - AUD-0357 already-shipped check-md-location.sh hook (reuse pattern)
---

# AUD-0361 — CI/CD + Pre-commit: Design + Phased Plan

> **Documentation only.** This document describes WHAT will ship in each phase
> and WHY. The actual `.pre-commit-config.yaml`, `.github/workflows/ci.yml`,
> `check-migration-sequence.sh`, and branch-protection settings are deliberately
> NOT in this commit. Each phase below is a separate future commit, pinned for
> the operator's go-ahead before it lands.

## 0. The audit row

```
| AUD-0361 | 14 | Major | Reliability | Confirmed | project root | no CI/CD,
no pre-commit, no enforced lint/test | pyproject.toml lists black/ruff/pytest
as deps but no `.pre-commit-config.yaml`, no `.github/workflows/`, no `test`
script in pyproject. | Formatting/linting/testing depends on developer
discipline. | Add pre-commit + GitHub Actions; required status checks. |
project root contents. |
```

Bucket F (Reliability), Tier T3 (process / hygiene). Severity Major because
the absence of enforcement means every cleanup audit (lint drift, format
drift, test rot) is a re-occurring tax: AUD-0359 (no CI test runs) is the
sister row, and the April 2026 audit sweep itself uncovered 366 distinct
issues largely because nothing in the commit pipeline rejects regressions.

## 1. Status quo (verified 2026-04-26 against worktree at `9b8cb7bf`)

| Component | Present? | Location | Notes |
|---|---|---|---|
| `pyproject.toml` lists `black`, `ruff`, `pytest` under `[project.optional-dependencies].dev` | yes | `tradelens/pyproject.toml:20-28` | also `pytest-asyncio`, `pytest-cov`, `respx` |
| `pyproject.toml` `[tool.black]` / `[tool.ruff]` / `[tool.pytest.ini_options]` blocks | yes | `tradelens/pyproject.toml:30-49` | line-length 100, py39 target, `integration`/`testnet` markers declared |
| `.pre-commit-config.yaml` (the `pre-commit` framework) | **NO** | — | confirmed: `ls /app/syb/tradesuite/.pre-commit-config.yaml` → not found |
| `.git/hooks/pre-commit` (hand-rolled) | **YES (partial)** | `.git/hooks/pre-commit` → calls only `tradelens/scripts/check-md-location.sh` | installed by `tradelens/scripts/install-git-hooks.sh`; runs only the markdown-location check, no lint/test |
| `tradelens/scripts/check-md-location.sh` | yes | `tradelens/scripts/check-md-location.sh` | AUD-0357-shipped enforcement of `tradelens/docs/` discipline; 75 lines; reuse as the model |
| `tradelens/scripts/install-git-hooks.sh` | yes | `tradelens/scripts/install-git-hooks.sh` | writes the hardcoded hook above; will need rework in Phase 1 |
| `scripts/check-tests.sh` (repo root) | yes | `/app/syb/tradesuite/scripts/check-tests.sh` | invoked by `/t-done` skill, NOT by the git pre-commit hook; supports `--quick` (= `pytest -m "not integration"`); exit codes 0/1/2; honours `SKIP_TEST_GATE=1` |
| `.github/workflows/` | **NO** | — | confirmed: `ls /app/syb/tradesuite/.github` → not found |
| `Makefile` (top-level or `tradelens/`) | **NO** | — | confirmed |
| `tradelens/bin/tools/dump_schema.py` | yes | `tradelens/bin/tools/dump_schema.py` | dumps to `etc/schema.md` (1675 lines today); CLAUDE.md mandates manual updates after schema changes — no enforcement today |
| `tradelens/bin/setup/setup_test_db.py` | yes | `tradelens/bin/setup/setup_test_db.py` | bootstraps `tradelens_test` PG database for integration tests |
| `tradelens/bin/setup/migrate.py` | yes | `tradelens/bin/setup/migrate.py` | the migration runner (AUD-0357 forward-only policy) |
| `tradelens/migrations/` | yes | `tradelens/migrations/001..082_*.sql` | 79 sql files, contiguous numbering (gaps would be a regression to detect) |
| `tradelens/bin/tl` | yes | `tradelens/bin/tl` | service manager, NOT a test runner |

### Net effect today

- A commit with un-formatted Python or a ruff violation will land cleanly.
- A commit that breaks `pytest` will land cleanly unless the developer
  remembered to type `/t-done` (which runs `check-tests.sh`).
- A commit that adds a column to PG without updating `etc/schema.md` will
  land cleanly.
- A commit that introduces a duplicate or out-of-sequence migration number
  (a direct AUD-0357 violation) will land cleanly.
- There is no remote-side enforcement at all — `git push` is unconditional.

## 2. Goals

### Local (pre-commit, fast)
1. Reject commits with formatting drift (`black --check`).
2. Reject commits with lint violations (`ruff check`).
3. Keep the existing `check-md-location.sh` enforcement.
4. **New:** reject commits with migration-numbering violations (gap, duplicate,
   or non-monotone) per AUD-0357.
5. Run a fast unit-test slice (`pytest -m "not integration"`) capped at
   ~30 s wall-time. The full suite is too slow to gate every commit; the CI
   side runs it.

### Remote (GitHub Actions, comprehensive)
6. Run the full pytest suite including integration tests against a
   PostgreSQL service container, on every push and every pull request.
7. Re-run the lint pass via `pre-commit run --all-files` so the local hook
   is mirrored centrally (catches the `--no-verify` escape hatch).
8. Run a **schema-sync** job: regenerate `etc/schema.md` via
   `bin/tools/dump_schema.py` and assert the output matches the committed
   file byte-for-byte. Drift means CLAUDE.md's "After Making ANY Schema
   Change" rule was skipped — fail the build.

### Enforcement
9. GitHub branch-protection rules on `master` that require all four CI
   jobs (`lint`, `test-unit`, `test-integration`, `schema-sync`) to pass
   before merge.
10. Document an explicit, auditable override path for emergency hotfixes
    (admin force-merge on critical security/CVE fixes only).

## 3. Phased plan

Each phase is a separate, independently-shippable commit. Each phase MUST
follow `/test-plan`'s rules (most are docs/config-only and exempt; the
`check-migration-sequence.sh` script is NOT exempt and ships with a
`tests/unit/test_migration_sequence_check.py`).

### Phase 1 — Local pre-commit framework (low blast radius)

**What ships:**

1. `.pre-commit-config.yaml` at repo root, declaring hooks:
   - `black` (mode `--check`, scoped to `tradelens/lib/`, `tradelens/bin/`,
     `tradelens/tests/`).
   - `ruff` (lint, same scope).
   - `local: check-md-location` — wraps the existing
     `tradelens/scripts/check-md-location.sh` (no behaviour change).
   - `local: check-migration-sequence` — wraps the new
     `tradelens/scripts/check-migration-sequence.sh` (see #2).
   - `local: pytest-quick` — runs
     `python3 -m pytest -m "not integration" --tb=short -q -x`
     from `tradelens/`. Flag: `pass_filenames: false`. Stage: `pre-commit`
     only (NOT `pre-push`, to avoid double-runs on the CI side).
2. `tradelens/scripts/check-migration-sequence.sh` — new file:
   - Lists `tradelens/migrations/*.sql`.
   - Extracts the leading 3-digit number from each.
   - Asserts: monotone, no duplicates, no gaps, starts at 001.
   - Exit 0 / 1 with descriptive error.
   - Idempotent and side-effect-free.
3. `tests/unit/test_migration_sequence_check.py` — pure unit test that
   uses `tmp_path` to fabricate fake `migrations/` directories (good,
   gap, duplicate, out-of-order) and asserts the script's exit code.
4. `tradelens/scripts/install-git-hooks.sh` rewritten to:
   - Detect whether `pre-commit` is installed; if so, run
     `pre-commit install` and exit. If not, fall back to today's
     hardcoded `check-md-location.sh`-only hook AND emit a clear
     "install pre-commit (`pip install pre-commit`) for the full
     enforcement suite" warning.
5. `tradelens/CLAUDE.md` — append a "Pre-commit hooks" subsection under
   "Test infrastructure" pointing developers at `pre-commit install`.
6. Add `pre-commit>=3.6` to `[project.optional-dependencies].dev` in
   `tradelens/pyproject.toml` so a fresh `pip install -e .[dev]` brings
   it in.

**Tests:**
- `tests/unit/test_migration_sequence_check.py` — REQUIRED, not exempt.
- The hook-config files themselves are config-only; commit message states
  exemption.

**Effort:** 4-6 h. **Risk:** low. **Reversible:** yes — removing
`.pre-commit-config.yaml` and reverting `install-git-hooks.sh` undoes it.

**Acceptance:**
- `git commit` with un-formatted Python fails locally.
- `git commit` with a duplicate migration number fails locally.
- `pytest -m "not integration"` runs in under 30 s on the dev box.
- `pre-commit run --all-files` exits 0 on a clean checkout.

### Phase 2 — GitHub Actions CI (medium risk, debug-on-runner cost)

**What ships:**

1. `.github/workflows/ci.yml` with **four jobs**, all triggered by
   `push` and `pull_request`:

   **`lint` job:**
   - Runner: `ubuntu-latest`.
   - Steps: checkout → setup-python 3.11 → pip install
     `pre-commit pre-commit-hooks` → `pre-commit run --all-files
     --show-diff-on-failure`.
   - Cache: pip cache + `~/.cache/pre-commit`.
   - Wall-time target: < 2 min.

   **`test-unit` job:**
   - Runner: `ubuntu-latest`.
   - Needs: `lint`.
   - Steps: checkout → setup-python 3.11 → `pip install -e
     tradelens/[dev]` → `cd tradelens && python3 -m pytest -m
     "not integration" --tb=short -q`.
   - Wall-time target: < 5 min.

   **`test-integration` job:**
   - Runner: `ubuntu-latest`.
   - Needs: `lint`.
   - **Service container:** `postgres:16` (pin a specific minor — see
     §4 risk), env: `POSTGRES_USER=tradelens`, `POSTGRES_PASSWORD=tradelens_poc`,
     `POSTGRES_DB=tradelens_test`. Health-check: `pg_isready`.
   - Steps: checkout → setup-python 3.11 → `pip install -e tradelens/[dev]`
     → wait for PG → `python3 tradelens/bin/setup/setup_test_db.py
     --recreate` → `python3 tradelens/bin/setup/migrate.py up --database
     tradelens_test` → `cd tradelens && python3 -m pytest -m integration
     --tb=short -q`.
   - Wall-time target: < 15 min.

   **`schema-sync` job:**
   - Runner: `ubuntu-latest`.
   - Needs: `test-integration` (so we have a populated `tradelens_test` DB).
   - Steps: regenerate schema dump against `tradelens_test` →
     `diff -u tradelens/etc/schema.md /tmp/schema-fresh.md` → fail if
     non-zero.
   - Wall-time target: < 1 min.

2. `.github/workflows/README.md` — short doc explaining each job, the
   service-container Postgres version pin, and the override path.

**Tests:** workflow YAML is config-only; commit message states exemption.

**Effort:** 8-12 h (mostly debugging service-container quirks: Postgres
listening port, volume permissions, health-check timing). **Risk:**
medium — CI environment surprises are routine. **Reversible:** yes —
delete `.github/workflows/`.

**Acceptance:**
- A PR that breaks `pytest` shows red `test-unit` or `test-integration`
  on GitHub.
- A PR that introduces schema drift shows red `schema-sync`.
- A PR with a black/ruff violation shows red `lint`.
- All four jobs run in under 25 minutes total wall-time.

### Phase 3 — Branch-protection rules on `master` (operator-only)

**What ships:**

This phase is a **GitHub repo-settings change**, not a code commit.
Claude does NOT have repo-admin access; the operator clicks through the
following:

1. GitHub repo → Settings → Branches → Add branch protection rule for
   pattern `master`.
2. Enable: **Require a pull request before merging** (1 reviewer minimum
   recommended).
3. Enable: **Require status checks to pass before merging** → check the
   four jobs from Phase 2: `lint`, `test-unit`, `test-integration`,
   `schema-sync`.
4. Enable: **Require branches to be up to date before merging**.
5. **Do NOT** enable "Restrict who can push to matching branches" until
   the team confirms — that's a separate decision.
6. Configure who can override: **Administrators only** (the override path
   for critical hotfixes).

**Effort:** 30 min (operator). **Risk:** low. **Reversible:** yes — delete
the rule.

**Acceptance:**
- Direct push to `master` is rejected.
- A PR with red status checks shows a "Merge" button that's disabled
  except for admins.
- Admin override is auditable in the GitHub merge log.

### Phase 4 — Frontend test gate (BLOCKED on AUD-0332)

**What ships (when AUD-0332 lands):**

1. Add a `test-frontend` job to `ci.yml`:
   - Runner: `ubuntu-latest`.
   - Setup-node 20 → `cd tradelens/frontend/web && npm ci && npm run test`.
2. Add `test-frontend` to the branch-protection required-checks list.

**Blocker:** AUD-0332 must bootstrap vitest + at least one passing test
before this phase makes sense.

**Effort:** 2-3 h once AUD-0332 ships. **Risk:** low.

## 4. Risks and mitigations

| Risk | Mitigation |
|---|---|
| **Postgres version drift between local and CI.** Local dev uses whatever PG the operator installed; CI service container will pin to (proposed) `postgres:16.6-alpine`. | Pin the same minor in `bin/setup/setup_database_pg.py` documentation; flag any divergence in the PR description. |
| **Pre-commit hook runs slow → developers `--no-verify` (the very pattern we're enforcing against).** | The pytest-quick hook runs `pytest -m "not integration"` with `-x` (stop on first failure) and `-q` (quiet) — measured budget < 30 s. If a developer's workstation slips past 60 s, that's a signal to optimize the unit suite, NOT to disable the hook. CI mirrors the pre-commit run via `pre-commit run --all-files`, catching `--no-verify` bypasses. |
| **Schema-sync check fails because `dump_schema.py` is non-deterministic.** Alphabetical / dict-order quirks across PG versions can silently shift output. | Audit `dump_schema.py` for determinism FIRST (Phase 2 prerequisite): every `SELECT` must `ORDER BY` explicitly; every dict iteration must `sorted()`. If non-deterministic, fix it as a Phase 2.0 prerequisite commit. |
| **Branch-protection blocks legitimate emergency merges.** | Documented admin-override path. Recommend: any override force-merge requires a paired follow-up PR within 48 h that brings the codebase green. |
| **`pre-commit` framework adds a new dev dependency that breaks fresh-install flow.** | Phase 1 adds `pre-commit>=3.6` to `[project.optional-dependencies].dev`; `install-git-hooks.sh` falls back to today's hardcoded hook if `pre-commit` is missing AND warns loudly. So the worst case is "no Phase 1 enforcement", not "broken dev environment". |
| **`pytest-quick` hook re-runs the suite that was already green via `/t-done`.** | Acceptable cost. The pre-commit hook is the new floor; `/t-done`'s `check-tests.sh` keeps running the FULL suite as a stricter gate. They are complementary. |
| **GitHub-hosted runners can't reach a self-hosted DB / private services.** | The CI design uses a SERVICE CONTAINER (ephemeral PG inside the runner), not a connection to a real DB. No external network needed. |
| **Cost: GitHub Actions minute consumption.** | Job concurrency (`concurrency: ${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: true`) cancels superseded PR runs. Unit tests run on every push; integration tests only on PR + merge to master. Estimated < 1000 minutes/month for current commit cadence. |

## 5. Open questions for the operator (escalate before Phase 2)

1. **Production target branch.** CLAUDE.md says `master` is the main branch
   "you will usually use this for PRs". CONFIRM — or change to `main`?
2. **Self-hosted vs GitHub-hosted runner.** Self-hosted lets us hit local
   PG directly (no service container) and may be faster, but adds
   operator burden (runner upkeep, security). GitHub-hosted (current
   design assumption) is plug-and-play but consumes Actions minutes.
3. **Branch-protection override authority.** Recommend: admin-only override.
   Operator must confirm the list of "admins" matches reality.
4. **Build-failure notifications.** Slack channel? Email distribution
   list? Pushover? (TradeLens already uses Pushover for trade alerts —
   reuse is plausible.)
5. **Postgres version pin.** Recommend `postgres:16.6-alpine`. Operator
   to confirm this matches their local install / production target.
6. **Required Python version.** `pyproject.toml` says `requires-python =
   ">=3.9"`. CI uses 3.11 in the design above. Pin one or test a matrix
   `[3.9, 3.11]`?
7. **Frontend test gate timing.** Phase 4 is blocked on AUD-0332. Should
   we bundle Phase 4 into AUD-0332's commit or keep it as a separate
   follow-up?

## 6. Acceptance criteria — what "done" means for AUD-0361

This audit row is **not** marked Resolved until ALL of the following are
true:

1. `git commit` from a fresh clone with un-formatted Python fails locally
   with a `pre-commit` error message.
2. `git commit` with a duplicate or gap migration number fails locally.
3. A PR with a failing `pytest -m "not integration"` shows red
   `test-unit` on GitHub and the merge button is disabled.
4. A PR with a failing `pytest -m integration` shows red
   `test-integration` on GitHub and the merge button is disabled.
5. A PR that adds a column to the schema without updating `etc/schema.md`
   shows red `schema-sync` on GitHub and the merge button is disabled.
6. Direct `git push` to `master` is rejected by GitHub.
7. The override path (admin force-merge) is documented in
   `tradelens/CLAUDE.md` AND has been exercised at least once in dry-run.
8. (Phase 4) Frontend tests run on every PR and block merge on red.

Phases 1-3 cover criteria 1-7. Phase 4 covers criterion 8 once AUD-0332
ships.

## 7. Out of scope (deliberate)

- **Code coverage gating.** `pytest-cov` is already in the dev deps but
  this design does NOT introduce a coverage threshold. Coverage is a
  separate audit row (the April 2026 finding "test coverage at 4.4%"
  needs a baseline + ratchet plan, not a hard gate).
- **Renovate / Dependabot.** Dependency updates are a different bucket.
- **Security scanning (GitHub Advanced Security, CodeQL).** Worth doing,
  but a separate row.
- **Performance regression gating.** No baseline benchmarks today.
- **Release automation.** Not a release-managed project today.

## 8. References

- `tradelens/AUDIT_TRACKER.md` row AUD-0361 (this audit)
- `tradelens/AUDIT_TRACKER.md` row AUD-0357 (forward-only migrations,
  whose policy this design enforces in Phase 1)
- `tradelens/AUDIT_TRACKER.md` row AUD-0332 (vitest bootstrap, blocker
  for Phase 4)
- `tradelens/AUDIT_TRACKER.md` row AUD-0359 (sister row "no CI test runs"
  — resolved by Phase 2 of this plan)
- `tradelens/CLAUDE.md` § "Testing Policy (MANDATORY)" — the
  shipping-without-tests pattern this design fences against
- `tradelens/CLAUDE.md` § "After Making ANY Schema Change" — the
  schema-sync rule this design enforces
- `tradelens/scripts/check-md-location.sh` — the AUD-0357-shipped
  reference implementation we're patterning Phase 1 hooks on
- `scripts/check-tests.sh` — the existing `/t-done`-invoked test gate
  that complements (does NOT replace) the new pre-commit `pytest-quick`
  hook
