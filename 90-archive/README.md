# docs/90-archive/

Historical docs that are no longer actively maintained. Kept for archaeology —
reading them should answer "what did we try / build / decide at time X" but
they are **not** a current reference.

## Contents

```
docs/90-archive/
├── implementation-history/   # "we built X" retrospectives and phase summaries
├── plans/                    # plan-*.md design docs (some shipped, some stale)
├── ui/                       # frontend / chart / preview notes
└── achievement.md            # "Building TradeLens in 4 months" reflection
```

## What to consult instead

For anything still load-bearing today:

- **How the code actually works** → read the code + `tradelens/CLAUDE.md`
- **Schema reference** → `tradelens/etc/schema.md` (auto-generated)
- **Architecture / data model docs** → `docs/10-architecture/`
- **Operational runbooks** → `docs/20-runbooks/`
- **Decision playbooks** → `docs/60-playbooks/`
- **Conventions & API/feature reference** → `docs/50-reference/`

## Lineage note

Before the April 2026 docs consolidation this content lived under
`docs/archive/` (and `ACHIEVEMENT.md` at the tradelens/ repo root).
The migration:
- Renamed `docs/archive/` → `docs/90-archive/`
- Moved `ACHIEVEMENT.md` here as `achievement.md`
- Normalized `ALL_CAPS` / `snake_case` filenames to `kebab-case`
- Pulled a few one-off plans out into `plans/`
