# 70-task-log/

Placeholder for a vault-visible surface over task-tracking state.

The actual state lives outside the vault:
- `.claude/checkpoints/*.md` — `/t-checkpoint` snapshots (harness-pinned)
- `claude-task` CLI state — session + task database (not markdown)
- Global cross-project memory — `/app/syb/.claude/projects/.../memory/`

**Planned content:**
- Symlinks (or a cron-refreshed index) pointing to the latest checkpoints
  so they're browseable/searchable via Obsidian
- A rendered history of completed tasks (from `claude-task list`)
- Cross-project memory pointer doc

For now this dir is a stub — run `/t-checkpoint-load` or `claude-task list`
directly from the shell.
