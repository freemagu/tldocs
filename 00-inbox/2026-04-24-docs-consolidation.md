# Docs Consolidation — 2026-04-24

**Purpose:** brief notice for other active Claude sessions in this repo. Read
before continuing work that involves any markdown file — there was a sizeable
reorganisation and many paths changed.

**Commits:**
- `e57e8ea7` — docs: consolidate all non-pinned MDs under docs/ with category tree
- `3586647d` — docs: update stale path refs after consolidation (follow-up)

**Verified:** `pytest` 762 passed / 2 skipped — same as pre-migration, zero
regressions.

## TL;DR (read at minimum)

1. **Every non-pinned markdown file now lives under `tradelens/docs/`** in a
   numbered category tree (`10-architecture/`, `20-runbooks/`, …).
2. **Filenames were normalised** — UPPER_CASE and snake_case renamed to
   kebab-case lowercase. Conventional names (`README.md`, `CHANGELOG.md`,
   `INDEX.md`, `MOC.md`) kept.
3. **12 pinned files stayed put** — `CLAUDE.md` ×2, `README.md`,
   `AUDIT_TRACKER.md`, `etc/schema.md`, `bin/README.md`, `examples/README.md`,
   `frontend/web/{README,CHANGELOG}.md`, `.claude/{commands,agents,checkpoints}/*.md`.
4. **Non-MD research data did NOT move** — CSVs and `.pine` files in
   `research/swing_levels/` stayed. Only the 32 MDs moved to
   `docs/40-research/swing-levels/`. The user's swing-research Python code
   keeps working untouched.
5. **New pre-commit hook rejects new `.md` files outside `docs/`** (unless in
   the pinned allowlist). See the `scripts/check-md-location.sh` section below.

If your session has an active checkpoint or plan that references paths like
`docs/ROUNDING.md`, `research/swing_levels/phase3/phase3_design.md`, or
`docs/archive/plans/PLAN.md`, translate them via the mapping table below
before continuing.

## New tree

```
tradelens/docs/
├── 00-inbox/                # new notes land here, then get moved
├── 10-architecture/         # system design, data models, module maps
├── 20-runbooks/             # operational step-by-step procedures
├── 30-fixes-and-audits/     # bug fixes, corrections, issue investigations
├── 40-research/             # phased research + incident analysis
│   ├── audit-autofix/       # spring 2026 audit-tracker workstream
│   ├── frontend-viewport/   # trade-journal viewport research
│   ├── levelguard-analysis/ # per-trade level-guard incident writeups
│   └── swing-levels/        # swing-level research MDs (data in research/)
├── 50-reference/            # conventions, API refs, rules of the road
│   └── examples/            # Bybit API request JSON examples + explainers
├── 60-playbooks/            # decision-making playbooks
├── 70-task-log/             # checkpoint surface (stub, not wired up yet)
├── 90-archive/              # retired plans, implementation history, one-offs
├── _templates/              # Obsidian templates (stub)
├── assets/                  # images (stub)
├── MOC.md                   # hand-curated top-level nav
└── INDEX.md                 # vault landing page
```

## Path mapping — by source

### From `docs/*.md` root → category subdirs (+ normalised names)

| Old | New |
|---|---|
| `docs/API_REFERENCE.md` | `docs/10-architecture/api-reference.md` |
| `docs/ORDER_LEG_CLASSIFICATION.md` | `docs/10-architecture/order-leg-classification.md` |
| `docs/TRADE_JOURNAL.md` | `docs/10-architecture/trade-journal.md` |
| `docs/TRADE_JOURNAL_NOTES_DENORMALIZATION.md` | `docs/10-architecture/trade-journal-notes-denormalization.md` |
| `docs/app-lock.md` | `docs/10-architecture/app-lock.md` |
| `docs/level-guard.md` | `docs/10-architecture/level-guard.md` |
| `docs/initial-risk-cutoff-design.md` | `docs/10-architecture/initial-risk-cutoff-design.md` |
| `docs/risk-column-design.md` | `docs/10-architecture/risk-column-design.md` |
| `docs/PLAYWRIGHT_MCP_SETUP.md` | `docs/20-runbooks/playwright-mcp-setup.md` |
| `docs/alerts-performance.md` | `docs/30-fixes-and-audits/alerts-performance.md` |
| `docs/spot_balance_corrections.md` | `docs/30-fixes-and-audits/spot-balance-corrections.md` |
| `docs/stop-loss-auto-cancel-investigation.md` | `docs/30-fixes-and-audits/stop-loss-auto-cancel-investigation.md` |
| `docs/ROUNDING.md` | `docs/50-reference/rounding.md` |
| `docs/TIMEZONE_CONVENTIONS.md` | `docs/50-reference/timezone-conventions.md` |
| `docs/claude-api-migration-notes.md` | `docs/50-reference/claude-api-migration-notes.md` |
| `docs/risk-reward-rr.md` | `docs/50-reference/risk-reward-rr.md` |
| `docs/worktree-parallel-sessions.md` | `docs/50-reference/worktree-parallel-sessions.md` |
| `docs/plan-auto-review.md` | `docs/60-playbooks/plan-auto-review.md` |
| `docs/INDEX.md` | `docs/INDEX.md` (unchanged, but **contents fully rewritten**) |

### From `docs/archive/` → `docs/90-archive/`

- Entire directory renamed. All files inside got filename normalisation.
- **Note:** `PLAN-*.md` files under `docs/90-archive/plans/` are now TRACKED
  in git as `plan-*.md` (were untracked before because the gitignore rule
  `PLAN-*.md` matched them; the rule is now anchored to `/PLAN-*.md` at repo
  root only).

Examples:
| Old | New |
|---|---|
| `docs/archive/implementation-history/BACKEND_SIZING_MODES_IMPLEMENTATION.md` | `docs/90-archive/implementation-history/backend-sizing-modes-implementation.md` |
| `docs/archive/plans/PLAN.md` | `docs/90-archive/plans/plan.md` |
| `docs/archive/plans/POSITION_TIMESTAMP_OPTIONS.md` | `docs/90-archive/plans/position-timestamp-options.md` |
| `docs/archive/ui/CHART_VISUAL_IMPROVEMENTS.md` | `docs/90-archive/ui/chart-visual-improvements.md` |

(11 implementation-history files, 7 plans, 2 ui files — all follow the same
pattern: uppercase/underscore → lowercase/kebab.)

### From `docs/levelguard-analysis/` → `docs/40-research/levelguard-analysis/`

Whole directory moved (32 files — the numbered incident writeups plus
`README.md` and `ideas.md` (was `IDEAS.md`)). Numbered files `001-*.md`
through `019-*.md` already conformed to kebab-lowercase so their names
didn't change; only the path.

### From `research/` → `docs/40-research/` (MDs only)

| Old | New | Notes |
|---|---|---|
| `research/audit_autofix/` | `docs/40-research/audit-autofix/` | Whole dir moved; 8 files normalised (`run_2026-04-24_status.md` → `run-2026-04-24-status.md`, `triage_chunks_3-5.md` → `triage-chunks-3-5.md`, etc.) |
| `research/swing_levels/**/*.md` | `docs/40-research/swing-levels/**/*.md` | **Only MDs moved.** CSVs (`breach_labels.csv`, `features.csv`, ...) and `swing_pivots.pine` stayed at `research/swing_levels/`. 32 MDs normalised. |

**Swing-levels filename examples:**
| Old | New |
|---|---|
| `research/swing_levels/phase3/phase3_design.md` | `docs/40-research/swing-levels/phase3/phase3-design.md` |
| `research/swing_levels/phase3/phase3_results.md` | `docs/40-research/swing-levels/phase3/phase3-results.md` |
| `research/swing_levels/TRACKER.md` | `docs/40-research/swing-levels/tracker.md` |
| `research/swing_levels/phase1_handoff_for_next_session.md` | `docs/40-research/swing-levels/phase1-handoff-for-next-session.md` |

**Subdirectory naming preserved with underscores (to match the CSVs still
sitting in `research/`):** `cross_symbol/`, `phase1/run_v0_15m_5L5R/` — did
NOT become `cross-symbol/` / `run-v0-15m-5l5r/`. Subdir rename was reverted
precisely because research data still uses the underscore paths.

### From `frontend/web/*.md` → `docs/`

| Old | New |
|---|---|
| `frontend/web/IMPLEMENTATION_SUMMARY.md` | `docs/10-architecture/frontend-implementation-summary.md` |
| `frontend/web/SIZING_MODES_UPDATE.md` | `docs/10-architecture/frontend-sizing-modes-update.md` |
| `frontend/web/docs/trade-journal-viewport-*.md` | `docs/40-research/frontend-viewport/trade-journal-viewport-*.md` |
| `frontend/web/README.md` | **STAYS** (npm convention) |
| `frontend/web/CHANGELOG.md` | **STAYS** (convention) |

### From `examples/*.md` → `docs/50-reference/examples/`

| Old | New |
|---|---|
| `examples/CONDITIONAL_TP_GUIDE.md` | `docs/50-reference/examples/conditional-tp-guide.md` |
| `examples/CONDITIONAL_TP_UPDATE.md` | `docs/50-reference/examples/conditional-tp-update.md` |
| `examples/SOLUTION.md` | `docs/50-reference/examples/solution.md` |
| `examples/TP_GUIDE.md` | `docs/50-reference/examples/tp-guide.md` |
| `examples/USAGE.md` | `docs/50-reference/examples/usage.md` |
| `examples/README.md` | **STAYS** (describes scripts co-located there) |
| `examples/*.json` | **UNCHANGED** (Bybit request example payloads) |

### From `dev/` → `docs/30-fixes-and-audits/` (+ one renamed)

| Old | New |
|---|---|
| `dev/plan-hist-classifier-corrections.md` | `docs/30-fixes-and-audits/plan-hist-classifier-corrections.md` |
| `dev/active/incremental-exec-aggregation-bug/ANALYSIS.md` | `docs/30-fixes-and-audits/incremental-exec-aggregation-bug.md` |

`dev/` was `.gitignored` — `ANALYSIS.md` was untracked; it is now TRACKED at
the new path. The entire `dev/` directory was removed (empty after the move).

### From `tradelens/` root

| Old | New |
|---|---|
| `ACHIEVEMENT.md` | `docs/90-archive/achievement.md` |

Was previously untracked (never `git add`ed). Now tracked.

## Filename normalisation rule

- Uppercase → lowercase
- Underscores → dashes
- Preserved as-is: `README.md`, `CHANGELOG.md`, `INDEX.md`, `MOC.md`

Examples:
- `API_REFERENCE.md` → `api-reference.md`
- `PLAN.md` → `plan.md`
- `phase3_design.md` → `phase3-design.md`
- `TRACKER.md` → `tracker.md`
- `run_2026-04-24_status.md` → `run-2026-04-24-status.md`

Directories: were NOT systematically renamed (we reverted an over-eager rename
of `cross_symbol/` and `run_v0_15m_5L5R/` because research scripts still
reference those paths).

## Pinned files — stayed at conventional paths

These did not move because tools/conventions reference them by exact path:

| File | Reason pinned |
|---|---|
| `CLAUDE.md` (repo root) | Claude Code auto-loads |
| `tradelens/CLAUDE.md` | Claude Code auto-loads |
| `tradelens/README.md` | GitHub convention |
| `tradelens/AUDIT_TRACKER.md` | Hard-referenced across audit workstream |
| `tradelens/etc/schema.md` | `tradelens/CLAUDE.md` mandates this path |
| `tradelens/bin/README.md` | Referenced by CLAUDE.md |
| `tradelens/examples/README.md` | Documents the JSON example payloads next to it |
| `tradelens/frontend/web/README.md` | npm package README |
| `tradelens/frontend/web/CHANGELOG.md` | Convention |
| `.claude/commands/test-plan.md` | Slash-command skill (harness reads exact path) |
| `.claude/agents/*.md` | Subagent definitions |
| `.claude/checkpoints/*.md` | `/t-checkpoint-load` reads this path |

## Reference updates made

Files that had stale path references were updated in the follow-up commit:

- `AUDIT_TRACKER.md` — 4 rows naming `docs/ROUNDING.md` now say `docs/50-reference/rounding.md`
- `docs/40-research/audit-autofix/triage-chunks-3-5.md` — same replacement
- `docs/INDEX.md` — rewritten as vault landing page (was the old catalogue format)
- `docs/90-archive/README.md` — rewritten for new tree + kebab-case file list
- `lib/tradelens/swing_research/phase3_features.py`, `phase3_pipeline.py`,
  `phase3_evaluation.py` — docstring refs to the design MD updated
- `bin/tools/swing_levels_phase3.py`, `swing_levels_phase3_train.py` —
  docstring refs updated (6 lines total)

**NOT updated** — deliberately left alone:
- `bin/tools/swing_levels_phase3_train.py:68` — runtime write path
  `base / "phase3" / sub / "phase3_results.md"` that WRITES the trainer's
  output MD. Current behaviour: regenerates `research/swing_levels/phase3/
  phase3_results.md` (old path, underscore, at research/ — not in the vault).
  The vault copy at `docs/40-research/swing-levels/phase3/phase3-results.md`
  is frozen until someone decides whether the trainer should write there.
  Flagged for user decision.

## New pre-commit hook

`tradelens/scripts/check-md-location.sh` — blocks new or modified `.md` files
outside the allowlist. Install once on each dev machine:

```bash
tradelens/scripts/install-git-hooks.sh
```

Allowlist, keep this in sync with `docs/INDEX.md`:
- Anything under `tradelens/docs/`
- `CLAUDE.md` (repo root)
- `tradelens/{README,CLAUDE,AUDIT_TRACKER}.md`
- `tradelens/etc/schema.md`
- `tradelens/{bin,examples,frontend/web}/README.md`
- `tradelens/frontend/web/CHANGELOG.md`
- `.claude/{commands,agents,checkpoints}/*.md`

If you need to commit a new pinned location, edit the allowlist regex in the
hook script and update this file + `docs/INDEX.md`.

## `.gitignore` adjustments

- `.obsidian/` now ignored (user-specific vault config; workspace.json,
  appearance.json etc. shouldn't leak between users)
- `PLAN-*.md` rule anchored to `/PLAN-*.md` so only the repo root is blocked;
  `docs/90-archive/plans/plan-*.md` can be tracked

## Briefing snippet for other sessions (copy-paste)

> The docs tree was reorganised on 2026-04-24. If any of your context
> references the following, update to the new path:
>
> - `research/swing_levels/**/*.md` → `docs/40-research/swing-levels/**/*.md`
>   (filenames normalised kebab-case; CSVs and `.pine` stayed at the old path)
> - `research/audit_autofix/**/*.md` → `docs/40-research/audit-autofix/**/*.md`
> - `docs/ROUNDING.md` → `docs/50-reference/rounding.md`
> - `docs/TIMEZONE_CONVENTIONS.md` → `docs/50-reference/timezone-conventions.md`
> - `docs/API_REFERENCE.md` → `docs/10-architecture/api-reference.md`
> - `docs/level-guard.md` → `docs/10-architecture/level-guard.md`
> - `docs/levelguard-analysis/` → `docs/40-research/levelguard-analysis/`
> - `docs/archive/` → `docs/90-archive/` (file names inside also normalised)
> - `frontend/web/IMPLEMENTATION_SUMMARY.md` / `SIZING_MODES_UPDATE.md` →
>   `docs/10-architecture/frontend-*.md`
> - `examples/*.md` (non-README) → `docs/50-reference/examples/*.md`
> - `dev/plan-hist-classifier-corrections.md` →
>   `docs/30-fixes-and-audits/plan-hist-classifier-corrections.md`
>
> **Pinned files stayed put:** `CLAUDE.md` ×2, `README.md`, `AUDIT_TRACKER.md`,
> `etc/schema.md`, `bin/README.md`, `examples/README.md`,
> `frontend/web/{README,CHANGELOG}.md`, `.claude/commands/*.md`,
> `.claude/agents/*.md`, `.claude/checkpoints/*.md`.
>
> **Pre-commit hook** rejects new `.md` outside `docs/` unless in the pinned
> allowlist. Put new MDs under `docs/<category>/` (see
> `docs/00-inbox/2026-04-24-docs-consolidation.md` for the full mapping).
>
> Commits: `e57e8ea7` + `3586647d`. See
> `docs/00-inbox/2026-04-24-docs-consolidation.md` for the full move list.

## When to delete this file

Once all your active Claude sessions have been briefed and you're confident
none of them still hold stale paths — usually within a week or two. Move to
`docs/90-archive/` instead of deleting if you want to keep the historical
record.
