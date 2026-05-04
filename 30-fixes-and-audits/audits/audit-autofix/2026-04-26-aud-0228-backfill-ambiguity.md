# AUD-0228 — Migration 080 Backfill Ambiguity Report

**Date:** 2026-04-26
**Migration:** `migrations/080_add_idea_id_fk_to_intent_and_journal.sql`
**Generated against:** production `tradelens` database, immediately post-apply.

## Summary

Migration 080 added FK constraints (`ON DELETE SET NULL`) on
`trade_intent.trade_idea_id` and `trade_journal.trade_idea_id` referencing
`trade_idea(id)`. As part of the migration:

1. Orphan `trade_idea_id` values (pointing at deleted ideas) were set to
   NULL, since they would otherwise have blocked FK creation. Logically
   equivalent to `ON DELETE SET NULL` having fired retroactively.
2. NULL `trade_idea_id` rows were backfilled via a deterministic
   single-match join on `(symbol, side, created_at|opened_at ± 24h)`.
   Per the standing user decision, **rows with zero or multiple
   candidate matches stayed NULL (no guessing).**

## Final state — `trade_idea_id` row counts

| Table          | Total | `trade_idea_id` set | `trade_idea_id` NULL |
|----------------|------:|--------------------:|---------------------:|
| trade_intent   |   304 |                 261 |                   43 |
| trade_journal  |   486 |                 281 |                  205 |

## Pre-migration baseline (for comparison)

| Table          | Total | NULL before | Orphan rows nullified | Backfilled (single match) | NULL after |
|----------------|------:|------------:|----------------------:|--------------------------:|-----------:|
| trade_intent   |   304 |          28 |                    24 |                         9 |         43 |
| trade_journal  |   486 |         234 |                    19 |                        48 |        205 |

## Why the remaining rows stayed NULL

### `trade_intent` (43 NULL rows)

| Bucket                                  | Rows |
|-----------------------------------------|-----:|
| Zero candidate ideas in ±24h window     |   41 |
| Two candidate ideas (ambiguous)         |    1 |
| Three candidate ideas (ambiguous)       |    1 |

### `trade_journal` (205 NULL rows)

| Bucket                                  | Rows |
|-----------------------------------------|-----:|
| `opened_at` IS NULL (no anchor)         |    1 |
| Zero candidate ideas in ±24h window     |  172 |
| Two candidate ideas (ambiguous)         |   30 |
| Three candidate ideas (ambiguous)       |    1 |
| Four candidate ideas (ambiguous)        |    1 |

## Interpretation

- **Zero-match rows** (41 intents + 172 journals) are almost certainly
  legacy data from before `trade_idea` existed in its current form, or
  trades placed without going through the idea-driven flow (manual
  trades, automated reactive entries, etc.). These are not bugs — they
  are correctly modelled as NULL.
- **Multi-match rows** (2 intents + 32 journals) are genuine ambiguity
  cases: more than one idea on the same `(symbol, side)` was created
  within ±24h of the intent/trade. Disambiguating them deterministically
  would require source-message correlation or human review. The standing
  user decision says we do not guess; these stay NULL.

## Follow-up (manual review pool)

If a future audit wants to recover the 32 multi-match journals:

```sql
-- Multi-match candidates for trade_journal (still NULL, opened_at present)
SELECT tj.trade_id, tj.symbol, tj.side, tj.opened_at,
       array_agg(i.id ORDER BY i.created_at) AS candidate_idea_ids
FROM trade_journal tj
JOIN trade_idea i
  ON UPPER(i.symbol) = UPPER(tj.symbol)
 AND LOWER(i.side)   = LOWER(tj.side)
 AND tj.opened_at IS NOT NULL
 AND i.created_at BETWEEN tj.opened_at - INTERVAL '24 hours'
                      AND tj.opened_at + INTERVAL '24 hours'
WHERE tj.trade_idea_id IS NULL
GROUP BY tj.trade_id, tj.symbol, tj.side, tj.opened_at
HAVING COUNT(*) > 1
ORDER BY tj.opened_at DESC;
```

The same query against `trade_intent` (anchored on `created_at` instead
of `opened_at`) returns the 2 intent multi-matches.

## Going forward

The pipeline already propagates `trade_idea_id` explicitly when an
intent is created from an idea (`api/ideas.py` execute path) and from
the intent into the journal (`bin/pipeline/refresh_trade_journal.py`
sessionizer, via `trade_intent.trade_idea_id`). New rows from this
point onward will not contribute to the legacy NULL pool.
