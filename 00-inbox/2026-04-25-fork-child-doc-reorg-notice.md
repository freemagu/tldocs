---
status: notice-to-parent-session
from: fork-child (post-audit-autofix-batch session)
to: parent session that ran the 24-commit audit-autofix batch on 2026-04-25
created: 2026-04-25
---

# Heads-up: doc paths you were working with have moved

Hi parent,

A child session forked off after your 24-commit audit-autofix batch landed (HEAD `be338f7d` at fork time) and was asked to reorganise `docs/30-fixes-and-audits/` and relocate the `audit-autofix/` folder. **You will hit ENOENT if you try to read files under `docs/40-research/audit-autofix/` — that path no longer exists.**

The reorg landed in commit `d9130b5a` on master.

## What moved

| Was                                                               | Now                                                                              |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `docs/40-research/audit-autofix/` (whole folder)                  | `docs/30-fixes-and-audits/audits/audit-autofix/`                                 |
| `docs/30-fixes-and-audits/alerts-performance.md`                  | `docs/30-fixes-and-audits/bug-postmortems/alerts-performance.md`                  |
| `docs/30-fixes-and-audits/incremental-exec-aggregation-bug.md`    | `docs/30-fixes-and-audits/bug-postmortems/incremental-exec-aggregation-bug.md`    |
| `docs/30-fixes-and-audits/stop-loss-auto-cancel-investigation.md` | `docs/30-fixes-and-audits/bug-postmortems/stop-loss-auto-cancel-investigation.md` |
| `docs/30-fixes-and-audits/plan-hist-classifier-corrections.md`    | `docs/30-fixes-and-audits/spot-balance-corrections/plan-hist-classifier-corrections.md`       |
| `docs/30-fixes-and-audits/spot-balance-corrections.md`            | `docs/30-fixes-and-audits/spot-balance-corrections/spot-balance-corrections.md`               |

## Specifically about your `decisions-pending.md`

It was untracked (parent-owned) at fork time. I moved it via plain `mv` (NOT `git mv`) so it's still untracked at the new location:

  **`docs/30-fixes-and-audits/audits/audit-autofix/decisions-pending.md`**

Your in-place edits to that file (the "Shipped 2026-04-25 batch" section, removed-shipped-lines, etc.) are intact — same file contents, new path. If you want it tracked, `git add` it from the new location.

## Other parent-owned items I left alone

Per fork-child mode:
- `bin/tools/find_latest` deletion — still unstaged
- `research/swing_levels/phase2/ethusdt/breach_labels.csv` modification — still unstaged
- All `research/swing_levels/phase3/...` and `docs/40-research/swing-levels/phase3/...` swing-research files — still untracked
- `.claude/agents/`, `.claude/checkpoints/`, `.claude/scheduled_tasks.lock` — still untracked

I touched none of these.

## Other refs updated

- `docs/MOC.md` line 31 — wikilink to audit-autofix tracker repointed to the new path.
- `docs/00-inbox/2026-04-24-docs-consolidation.md` — left alone; it's a historical changelog of *prior* moves, so updating it would falsify history.
- `docs/.obsidian/workspace.json` — Obsidian's editor-state file has stale references; it'll self-heal on next open. Not touched.

## Why the move

`audit-autofix` is fundamentally a *fixes-and-audits* project (358 audit findings, autofix workstream), not a research project. It was originally placed under `40-research/` during the 2026-04-24 docs consolidation but the categorisation didn't fit. Moving to `30-fixes-and-audits/audits/audit-autofix/` plus introducing `bug-postmortems/` and `spot-balance-corrections/` subfolders for the previously-flat files at the same level.

— fork-child session
