# Parallel Claude Sessions with Git Worktrees

**Created:** 2026-04-01
**Status:** Proposal — not yet implemented

## Problem

Multiple Claude Code sessions edit tradelens code simultaneously. All 12+ services run from the same codebase on master. Without isolation, concurrent edits cause conflicts and there's no safe way to test one session's changes without disrupting others.

## Solution: Worktree-based parallel editing with serial testing

- **Edit in parallel** — each Claude session works in its own git worktree on its own branch
- **Test serially** — when ready, merge the branch to master and restart only the affected service(s)
- **Revert if broken** — undo the merge on master and go back to editing in the worktree

```
/app/syb/tradesuite/              <- master (production, services run here)
/app/syb/tradesuite-wt/task-a/    <- branch wt/task-a (session 1 editing)
/app/syb/tradesuite-wt/task-b/    <- branch wt/task-b (session 2 editing)
```

## Workflow Diagram

```
Session 1                          Session 2                     master
---------                          ---------                     ------
/wt-new "fix alert debounce"       /wt-new "add corr UI"        (production, running)
  |                                  |
/t-new (task tracking)             /t-new
  |                                  |
edit, edit, edit...                edit, edit, edit...
  |                                  |
/t-done (commit to branch)        /t-done (commit to branch)
  |                                  |
/wt-test                           |  (still editing)
  -> merge to master                |
  -> tl restart alert-engine        |
  -> test passes                    |
  |                                  |
/wt-done (cleanup)                /wt-test
                                    -> merge to master
                                    -> tl restart dashboard
                                    -> test fails
                                    |
                                  /wt-revert
                                    -> revert on master
                                    -> tl restart dashboard
                                    -> back to editing...
```

## Proposed Skills

Six new slash commands that layer on top of the existing `/t-*` task tracking system. The worktree is the *environment*; tasks still track the *work* within it.

```
Worktree lifecycle:  /wt-new -> edit (using /t-*) -> /wt-test -> /wt-done
                                                        |
                                                   /wt-revert (if broken)

Abandon:             /wt-drop (throw away without merging)
Status:              /wt-list (show all worktrees)
```

---

### 1. `/wt-new` — Create a worktree for parallel editing

**Purpose:** Set up an isolated working directory on a new branch so a Claude session can edit without affecting master or other sessions.

**What it does:**
1. Asks user: "What are you working on?"
2. Generates branch name: `wt/<slug>` (e.g., `wt/fix-alert-debounce`)
3. Creates git worktree at `/app/syb/tradesuite-wt/<slug>/`
4. Branches from current master HEAD
5. Symlinks shared resources that shouldn't be duplicated:
   - `venv/` (shared Python environment)
   - `node_modules/` (if dashboard frontend exists)
   - `cache/` (data cache)
   - `logs/` (keep centralized)
6. Generates a per-worktree `sourceme-wt.sh` that overrides `TSHOME`, `TLHOME` to point at the worktree
7. Registers the worktree in `~/.claude/tasks/worktrees.tsv`

**Example interaction:**
```
> /wt-new
What are you working on? "Fix alert engine debounce logic"

Created worktree:
  Path:   /app/syb/tradesuite-wt/fix-alert-debounce/
  Branch: wt/fix-alert-debounce
  Based on: master @ e8f39887

To activate: source /app/syb/tradesuite-wt/fix-alert-debounce/sourceme-wt.sh
```

**Key detail:** The Claude session's working directory moves to the worktree. All subsequent file edits happen there. The existing `/t-*` skills work unchanged — they just commit to the worktree's branch instead of master.

---

### 2. `/wt-list` — Show all worktrees and their status

**Purpose:** See what's in flight across all sessions.

**What it does:**
- Lists all active worktrees with: branch name, path, created date, file change count, merge status
- Shows which worktrees have been merged to master (tested) vs. still pending

**Example output:**
```
Worktrees:
  wt/fix-alert-debounce    3 files changed   NOT MERGED
  wt/add-correlation-ui    7 files changed   MERGED (testing)
  master                   (production)
```

**Implementation:** Combines `git worktree list` with `git diff --stat master..<branch>` for each.

---

### 3. `/wt-test` — Merge to master and restart affected services

**Purpose:** Take the worktree's changes live for testing against the real running system.

This is the most complex skill. Three stages:

**Stage 1 — Identify changes:**
- Ensures all changes in the worktree are committed (warns if uncommitted)
- Diffs the worktree branch against master
- Maps changed files to affected services using the service map (see below)

**Stage 2 — Show plan and confirm:**
```
Changes on wt/fix-alert-debounce vs master:
  M  lib/tradelens/engine/alert_engine.py
  M  lib/tradelens/core/config.py          <- shared module

Affected services:
  alert-engine     (direct change)
  ALL services     (shared core/config.py changed)

Plan:
  1. cd /app/syb/tradesuite (main tree)
  2. git merge wt/fix-alert-debounce
  3. tl restart alert-engine    (or 'tl restart all' if shared code)

Proceed? [wait for user confirmation]
```

**Stage 3 — Execute:**
- Switches to the main tradesuite directory
- Merges the worktree branch into master
- Runs `tl restart <affected-services>`
- Reports success/failure

**Special cases:**
- If shared code (`core/`, `utils/`) is changed: warns that ALL services need restart, asks for confirmation
- If schema/migration files are changed: warns loudly and suggests running migrations manually before restart
- If merge has conflicts: stops and reports the conflicts (user must resolve)

---

### 4. `/wt-revert` — Revert a failed test merge

**Purpose:** Undo a merge on master and get back to known-good state.

**What it does:**
1. Verifies the last commit on master is a merge from a `wt/*` branch (refuses otherwise)
2. Reverts the merge commit: `git revert HEAD --no-edit`
3. Restarts the same services that were restarted during `/wt-test`
4. Reports that master is back to known-good state
5. Session continues editing in the worktree

**Safeguard:** Only works if the HEAD commit on master is a merge from a `wt/*` branch. This prevents accidentally reverting unrelated work.

---

### 5. `/wt-done` — Clean up after successful test

**Purpose:** Remove the worktree after changes are merged and tested.

**What it does:**
1. Verifies the worktree branch is already merged to master (refuses if not)
2. Removes the worktree: `git worktree remove <path>`
3. Deletes the branch: `git branch -d <branch>`
4. Removes entry from `worktrees.tsv`
5. Prints summary of what was merged

**Safeguard:** Refuses if the branch is NOT merged to master. Suggests `/wt-test` first, or `/wt-drop` to abandon.

---

### 6. `/wt-drop` — Abandon a worktree without merging

**Purpose:** Throw away a worktree's changes entirely.

**What it does:**
1. Confirms with user (destructive action)
2. Removes the worktree: `git worktree remove --force <path>`
3. Force-deletes the branch: `git branch -D <branch>`
4. Removes entry from `worktrees.tsv`

---

## Service-to-Path Mapping

The `/wt-test` skill needs to know which services are affected by file changes. This mapping should live in a config file so it stays maintainable as services evolve.

**Proposed file:** `$TLHOME/etc/service_map.yml`

```yaml
# Maps file path patterns to the services they affect.
# Used by /wt-test to determine which services to restart.

services:
  api:
    paths:
      - "lib/tradelens/api/*"
      - "lib/tradelens/main.py"
      - "lib/tradelens/services/portfolio*"
      - "lib/tradelens/services/sizing*"
      - "lib/tradelens/models/*"

  dashboard:
    paths:
      - "dashboard/*"
      - "lib/tradelens/api/*"
      - "lib/tradelens/main.py"

  pipeline:
    paths:
      - "bin/server/pipeline*"
      - "bin/pipeline/*"
      - "lib/tradelens/services/portfolio*"

  mdsync_pg:
    paths:
      - "bin/mdsync_pg*"
      - "lib/tradelens/candle_pg/*"
      - "lib/tradelens/candle_reader/*"

  alert-engine:
    paths:
      - "bin/engine/alert_engine*"
      - "lib/tradelens/engine/alert*"

  vwap-engine:
    paths:
      - "bin/engine/vwap_order*"

  vwap-series:
    paths:
      - "bin/engine/vwap_series*"

  level-guard:
    paths:
      - "bin/server/level_guard*"
      - "lib/tradelens/services/level_guard*"

  level-mind:
    paths:
      - "bin/server/level_mind*"
      - "lib/tradelens/services/level_mind*"

  correlation-engine:
    paths:
      - "bin/engine/correlation*"

  telegram-signals:
    paths:
      - "bin/telegram_signals*"

  monitor:
    paths:
      - "bin/monitor"

# Changes to these paths affect ALL services — triggers 'tl restart all'
shared_paths:
  - "lib/tradelens/core/*"
  - "lib/tradelens/utils/*"
  - "etc/config.yml"
  - "etc/accounts.yml"

# Changes to these paths are schema/migration changes.
# /wt-test should WARN and suggest running migrations manually
# before restarting services. Never auto-restart for these.
schema_paths:
  - "bin/setup/*"
  - "migrations/*"
  - "etc/schema.md"
```

---

## Supporting Infrastructure

### `claude-task` CLI additions

Three new subcommands for tracking worktrees:

```bash
# Register a new worktree
claude-task worktree-register <branch> <path>

# List tracked worktrees (with status)
claude-task worktree-list

# Remove a worktree from tracking
claude-task worktree-remove <branch>
```

### Tracking file: `~/.claude/tasks/worktrees.tsv`

```
branch              path                                          created_at           status
wt/fix-alert        /app/syb/tradesuite-wt/fix-alert/             2026-04-01T10:00:00  ACTIVE
wt/add-corr-ui      /app/syb/tradesuite-wt/add-corr-ui/           2026-04-01T11:30:00  MERGED
```

Statuses: `ACTIVE`, `MERGED`, `REVERTED`, `DONE`, `DROPPED`

---

## Design Decisions to Make

These are open questions to resolve before implementation:

### 1. Service map format
**Option A:** YAML config file (`etc/service_map.yml`) — maintainable, survives skill updates.
**Option B:** Hardcoded in the skill markdown — simpler, one less file.
**Recommendation:** YAML file. Services will evolve.

### 2. Schema changes during /wt-test
**Option A:** Refuse to merge if migrations are present — forces manual handling.
**Option B:** Warn loudly but allow merge — user runs migrations themselves.
**Recommendation:** Option B (warn). Sometimes a migration is trivial (add nullable column) and refusing would be annoying.

### 3. Shared code changes
**Option A:** Auto-run `tl restart all` when shared paths are changed.
**Option B:** List affected services, ask user which to restart.
**Recommendation:** Option A with confirmation. Shared code could break anything — better to restart all.

### 4. Worktree base directory
**Option A:** `/app/syb/tradesuite-wt/<slug>/` (sibling of main repo).
**Option B:** `/app/syb/tradesuite/.worktrees/<slug>/` (inside repo, gitignored).
**Recommendation:** Option A. Keeps worktrees clearly separate from production.

### 5. What to symlink vs. copy
Symlink (shared, don't duplicate):
- `venv/` — large, never modified per-session
- `cache/` — data cache, no reason to duplicate
- `logs/` — centralized logging is easier to monitor

Do NOT symlink (must be independent per worktree):
- `etc/config.yml` — may need port overrides for parallel testing
- `etc/accounts.yml` — could differ
- All source code (that's the whole point)

---

## Edge Cases

### Two worktrees modify the same file
The second `/wt-test` merge will have a conflict. Git handles this naturally — the skill reports the conflict and the user resolves it manually in the main tree.

### Worktree modifies a running service's code
No impact until `/wt-test` merges to master. The running service still uses the old code from master until `tl restart` is called.

### Multiple merges before reverting
If you merge worktree A, then merge worktree B, and B breaks things, `/wt-revert` only reverts B (the last merge). A's changes remain on master. This is the correct behavior — A was tested and worked.

### Stale worktrees
If a worktree is abandoned without cleanup, `git worktree list` will still show it. `/wt-list` should flag worktrees older than N days as stale. Cleanup with `/wt-drop`.

---

## Relationship to Existing Skills

| Existing skill | Behavior in worktree |
|---|---|
| `/t-new` | Works unchanged — creates task on worktree branch |
| `/t-done` | Works unchanged — commits to worktree branch |
| `/t-commit` | Works unchanged — commits to worktree branch |
| `/t-drop` | Works unchanged — abandons task (worktree stays) |
| `/t-save` | Works unchanged — saves context |
| `/t-resume` | Works unchanged — can resume task in same worktree |
| `/t-status` | Should show worktree info (branch, path) alongside task info |
| `/t-plan` | Works unchanged — investigation only |
| `/t-fork-child` | Redundant in worktree model — worktrees replace forking |

The key insight: worktrees are a *higher-level* concept than tasks. A worktree is the environment. Tasks track individual pieces of work within that environment. The `/wt-*` skills manage the environment; the `/t-*` skills manage the work.
