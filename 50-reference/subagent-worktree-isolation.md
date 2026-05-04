# Sub-agent Worktree Isolation — When To Use It

**Created:** 2026-04-25
**Status:** Reference / decision rationale
**Topic:** Claude Code Agent tool's `isolation: "worktree"` parameter

> **Note:** This doc is about *sub-agent* isolation within a single Claude Code session (`Agent({ ..., isolation: "worktree" })`). For *parallel Claude sessions* sharing a codebase, see [[worktree-parallel-sessions]] — different problem, different solution.

## TL;DR

For the audit-autofix workflow as it ran on 2026-04-25 (25+ serial write-heavy sub-agent dispatches with strict file-scope discipline), **`isolation: "worktree"` is not worth setting up.** The collisions it would prevent are cheap to recover from; the ones that actually bit us — incomplete scope (AUD-0148 missed `detect_seeded_trade_promotions`), pre-existing unmerged paths from a prior session — wouldn't have been prevented by isolation. Disk pressure (we hit 96% mid-batch) makes the per-worktree ~300 MB cost untenable anyway.

Reach for it only in three narrow cases (see [§ When to actually use it](#when-to-actually-use-it)).

## How worktree mode works

Calling `Agent({ ..., isolation: "worktree" })` invokes `git worktree add` under the hood and gives the sub-agent a separate checkout that shares the parent's `.git`. The sub-agent commits to its own branch. When it returns, the parent gets a `path` + `branch` ref and decides how to merge — usually `cherry-pick` or `git merge --ff-only` if the parent wants the commits inline. If the sub-agent makes no changes, the worktree is auto-cleaned.

Per dispatch:
- ~5–10 seconds setup (`git worktree add`)
- ~300 MB disk for the tradelens checkout (test fixtures, frontend assets, etc. all duplicated)
- Merge work at the back end (parent has to fold each sub-agent's commits into the main branch)

## What it solves

| Problem | Mitigated by worktree? |
|---|---|
| `AUDIT_TRACKER.md` Edit collisions | ✅ each worktree edits its own copy |
| Mid-write reads (verifier reads while writer rewrites) | ✅ sub-agent works on a snapshot |
| Git index lock contention on simultaneous `git add` / `git commit` | ✅ separate `.git/index.lock` per worktree |
| Read-only verification running parallel to write work | ✅ already safe even without isolation, but cleaner with it |

## What it does NOT solve

| Problem | Why isolation doesn't help |
|---|---|
| Shared `tradelens_test` DB | One DB on the host. Two pytest runs trample each other regardless of filesystem isolation. **This is the actual bottleneck for parallel writes**, not the filesystem. |
| Logical conflicts (incomplete scope) | AUD-0148 missed `detect_seeded_trade_promotions` — both worktrees would have committed valid-looking code; the latent bug surfaces only at AUD-0161 dead-helper deletion time. Worktrees don't catch human-style scoping errors. |
| Migration sequencing | If two sub-agents each generate "migration 077", a worktree lets both succeed locally; collision surfaces at merge. Same problem, deferred. |
| Disk pressure | Adds ~300 MB per worktree. We hit 96% disk during this session — 25 worktrees × 300 MB = 7.5 GB I didn't have. |
| Process-level shared state | Running services, file locks, stale daemons — the filesystem isn't the layer that gets contention. |

## When today's session would have benefited (it wouldn't have)

I rebuilt this from the actual 2026-04-25 batch:

- **Every write-heavy sub-agent was dispatched serially** (per the standing rule from the parent's prompt). Worktree mode adds zero parallelism for serial dispatch — it just adds overhead.
- **The two real frictions today** were (a) one `Edit` "file modified since read" rejection on `AUDIT_TRACKER.md`, recovered with a re-read in ~1 second, and (b) pre-existing unmerged paths from a prior session that one sub-agent had to resolve. Worktrees wouldn't have helped (b) — they'd actually have made it worse, since a sub-agent in a fresh worktree wouldn't see the unmerged state and would commit clean code on top of broken HEAD.
- **Read-only verification sub-agents** were already safe to run in parallel without isolation.

## When to actually use it

Three narrow cases where the cost is worth paying:

1. **Multi-day exploratory refactor.** A sub-agent doing extended work (e.g. T3-sized AUD-0058 splitting `lib/tradelens/utils/initial_risk_calculator.py`) where you want full isolation until the design is clear. Branch survives the dispatch; parent merges only when satisfied.
2. **Experimental approach you might throw away.** Try-it-and-see code that you don't want polluting `master` even temporarily. Worktree branch can be discarded with no cleanup cost.
3. **Genuine parallel writes to non-overlapping files that don't touch shared state.** Rare in this codebase because almost everything either touches the `tradelens` DB or imports from `lib/tradelens/core/`. If you ever do find a clean-cut workload (e.g. independent doc generation across non-overlapping source dirs), isolation lets you parallelise without scope-discipline gymnastics.

## Higher-leverage alternatives

If parallelism is the goal, the real bottlenecks are elsewhere:

1. **Per-sub-agent `tradelens_test` databases** (e.g. a `tradelens_test_<agent_id>` pattern). This is the actual blocker on parallel test execution, not file isolation. Without it, two sub-agents running pytest at once still trample each other regardless of how isolated their filesystems are.
2. **Pre-flight `git status` check in the parent** before each dispatch. Catches the "pre-existing unmerged paths" footgun that bit one sub-agent today. Cheap, catches a real failure mode worktrees don't.
3. **Lock around `AUDIT_TRACKER.md` edits.** The simplest possible serialization: parent only lets one sub-agent at a time touch the tracker, regardless of what else they're doing. Trivial to implement, eliminates the only Edit collision actually seen this session.

Each of those buys more safety than worktree mode for a fraction of the cost.

## Decision matrix

| Workflow shape | Recommendation |
|---|---|
| Serial write-heavy sub-agents (this session's pattern) | **Don't use isolation.** Discipline + serial dispatch is sufficient. |
| Parallel read-only verification | **Don't use isolation.** Already safe. |
| Parallel write sub-agents on shared DB | **Isolation alone is not enough.** Solve DB sharing first. |
| Multi-day refactor / experimental branch | **Use isolation.** Worth the disk + merge cost. |
| Disk-constrained host (>90% full) | **Don't use isolation.** Will exhaust disk. |

## Final word

The discipline-based approach (strict file-scope rules in the prompt, serial dispatch for writes, parallel only for read-only) has held up across hundreds of dispatches in this project. It's the right point on the simplicity-vs-safety curve for the workflow we actually run. Worktree isolation is a real tool, just for a different shape of work than what we're doing day-to-day.
