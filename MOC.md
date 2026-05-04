# TradeLens Vault — Map of Content

Hand-curated top-level navigation. For the folder-level tree and conventions,
see [[INDEX]].

## By category

### Architecture — how things are designed
- [[api-reference]] — FastAPI REST reference
- [[order-leg-classification]] — how orders become trade legs
- [[trade-journal]] — Trade Journal subsystem
- [[trade-journal-notes-denormalization]] — denormalized notes columns
- [[app-lock]] — distributed locking
- [[level-guard]] — wick-protection state machine (generates breach events)
- [[breach-decision-glossary]] — breach/level terminology (single source of truth)
- [[breach-decision-training]] — training pipeline (label-build → LR → calibrate → artefact)
- [[breach-decision-retraining-jobs]] — job cadence (J1–J9 operational schedule)
- [[holds-mode-backtest]] — B8 holds-mode gate backtest (Phase 1 results)
- [[b9-reclaim-mode-plan]] — B9 reclaim mode design (not yet implemented)
- [[initial-risk-cutoff-design]] — initial-R lock-in design
- [[risk-column-design]] — trade journal risk columns
- [[frontend-implementation-summary]] — frontend sizing modes implementation
- [[frontend-sizing-modes-update]] — follow-up changes

### Runbooks — step-by-step procedures
- [[breach-decision-stage-1-shadow-mode]] — run breach-decision predictor in observation-only mode
- [[playwright-mcp-setup]] — browser automation setup for Claude Code

### Fixes & audits — frozen investigations
- [[alerts-performance]]
- [[spot-balance-corrections]]
- [[stop-loss-auto-cancel-investigation]]
- [[plan-hist-classifier-corrections]]
- [[incremental-exec-aggregation-bug]]

### Research
- **[[30-fixes-and-audits/audits/audit-autofix/run-2026-04-24-status|Audit autofix — 2026-04 run]]** — tracker (moved from 40-research)
- **[[40-research/breach-decision/INDEX|Breach-decision — Map of Content]]** — breach predictor, level-guard analysis, swing-levels; start here for the whole corpus
- **[[40-research/swing-levels/tracker|Swing levels — tracker]]** — phased research; Phase 5 complete (F1 ≈ 0.84 ceiling confirmed)
- **[[40-research/levelguard-analysis/README|Level-guard analysis]]** — per-trade incident writeups (19 cases)
- **[[40-research/frontend-viewport/trade-journal-viewport-analysis|Frontend viewport]]**

### Reference — rules of the road
- [[rounding]] — canonical rounding rules (Family A / Family B)
- [[timezone-conventions]] — UTC everywhere, client display rules
- [[risk-reward-rr]] — R, RR, worst-case layered risk
- [[claude-api-migration-notes]] — OpenAI → Claude evaluation
- [[worktree-parallel-sessions]] — parallel Claude session workflow
- **Bybit examples:** [[conditional-tp-guide]], [[conditional-tp-update]], [[tp-guide]], [[usage]], [[solution]]

### Playbooks — decisions
- [[plan-auto-review]] — when/whether to trigger auto-review

### Archive
- [[90-archive/README|Archive README]] — what lives here and why

## External-to-vault pointers

Pinned files that live outside `docs/` but are still vault-linkable via explicit relative links:
- `../CLAUDE.md` — Claude Code project context (auto-loaded; don't link from notes, just read)
- `../AUDIT_TRACKER.md` — live audit tracker (dynamic; don't wiki-link)
- `../etc/schema.md` — authoritative schema reference

## Tasks & sessions
- `70-task-log/` — checkpoint mirrors + session artefacts (stub, to be wired up)
