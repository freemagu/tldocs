# TradeLens Docs — Index

Landing page for the Obsidian vault at `tradelens/docs/`.

Everything under `docs/` is the **canonical home for markdown documentation**.
A handful of files live outside `docs/` for tool/convention reasons — they are
listed at the bottom of this page.

## Tree

```
docs/
├── 00-inbox/                # new notes land here, then get moved
├── 10-architecture/         # system design, data models, module maps
├── 20-runbooks/             # operational step-by-step procedures
├── 30-fixes-and-audits/     # bug fixes, corrections, issue investigations
├── 40-research/             # phased research + incident analysis
│   ├── audit-autofix/       # spring 2026 audit-tracker workstream artefacts
│   ├── frontend-viewport/   # trade-journal viewport research
│   ├── levelguard-analysis/ # per-trade level-guard incident writeups
│   └── swing-levels/        # swing-level research phases 1-5 (MDs only; CSV data at research/swing_levels/)
├── 50-reference/            # conventions, API refs, rules of the road
│   └── examples/            # Bybit API request JSON examples + explainers
├── 60-playbooks/            # decision-making playbooks (when/whether)
├── 70-task-log/             # checkpoint mirrors, task history (stub)
├── 90-archive/              # retired plans, implementation history, one-offs
├── _templates/              # Obsidian note templates (stub)
├── assets/                  # images / attachments (stub)
├── MOC.md                   # Maps of Content — hand-curated top-level nav
└── INDEX.md                 # this file
```

## Tree vs categories

- **Architecture** — how something is designed. If you need to understand the shape of a subsystem, start here.
- **Runbook** — you have a specific operational task to do (restart a service, run a migration). Step-by-step.
- **Playbook** — you have a decision to make (should I suspend this trade?). The playbook walks the decision tree.
- **Reference** — conventions and lookup material. You dip in, grab the fact, leave. Examples: rounding rules, timezone rules, API payload shapes.
- **Fixes & audits** — post-hoc writeups of a specific bug / correction / investigation. Frozen snapshot.
- **Research** — phased research tracks with data co-located in `research/`.

## MDs outside docs/ (tool-pinned)

These stay at their conventional paths because tools reference them there:

| File | Why it stays |
|---|---|
| `CLAUDE.md` (repo root & `tradelens/`) | Claude Code auto-loads these |
| `tradelens/README.md` | GitHub convention |
| `tradelens/AUDIT_TRACKER.md` | Hard-referenced throughout the audit workstream |
| `tradelens/etc/schema.md` | `tradelens/CLAUDE.md` mandates this exact path |
| `tradelens/bin/README.md` | Referenced by CLAUDE.md |
| `tradelens/examples/README.md` | Describes the example JSON scripts next to it |
| `tradelens/frontend/web/README.md` | npm package README |
| `tradelens/frontend/web/CHANGELOG.md` | Convention |
| `tradelens/frontend/web/src/components/journal/rr-help.md` | Bundled via Vite `?raw`; content of in-app RR help modal |
| `.claude/commands/test-plan.md` | Slash-command skill |
| `.claude/agents/*.md` | Subagent definitions |
| `.claude/checkpoints/*.md` | Harness state; `/t-checkpoint-load` reads here |

**New markdown goes under `docs/` by default.** The pre-commit hook at
`scripts/check-md-location.sh` rejects any new `.md` outside `docs/` unless
its path is in the pinned allowlist above.

## Filename conventions

- Regular notes: `kebab-case.md` (lowercase, dashes)
- Conventional files: `README.md`, `CHANGELOG.md`, `INDEX.md`, `MOC.md` — preserved uppercase

## Lineage

This tree replaced a flatter layout on 2026-04-24. Pre-consolidation:
- 20+ MDs at `docs/` root
- `research/` as a sibling of `docs/`
- `docs/archive/`, `docs/levelguard-analysis/` at docs/ root
- `examples/*.md` alongside example scripts
- `frontend/web/*.md` (selected) alongside frontend code
- Root-level `ACHIEVEMENT.md`

All of the above moved under `docs/` with `kebab-case` normalization.
CSV/data research artefacts stayed at `research/swing_levels/` (their MDs moved
to `docs/40-research/swing-levels/`).
