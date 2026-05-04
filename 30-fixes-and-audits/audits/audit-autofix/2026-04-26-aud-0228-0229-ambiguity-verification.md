---
status: verification-confirmed
generated: 2026-04-26
verifies:
  - 2026-04-26-aud-0228-backfill-ambiguity.md
  - 2026-04-26-aud-0229-status-ambiguity.md
audit-ids:
  - AUD-0228 (migration 080)
  - AUD-0229 (migration 081)
---

# AUD-0228 + AUD-0229 — ambiguity verification (T4 follow-up)

Cross-check of the two ambiguity reports against the live `tradelens` PG
database, executed read-only as part of the post-campaign operational
follow-up. **No data modification.**

## AUD-0228 — `trade_idea_id` backfill (migration 080)

### Live counts vs report

```sql
SELECT 'trade_intent' AS t, COUNT(*) AS total,
       COUNT(*) FILTER (WHERE trade_idea_id IS NOT NULL) AS set,
       COUNT(*) FILTER (WHERE trade_idea_id IS NULL) AS null_count
FROM trade_intent
UNION ALL
SELECT 'trade_journal', COUNT(*), COUNT(*) FILTER (WHERE trade_idea_id IS NOT NULL), COUNT(*) FILTER (WHERE trade_idea_id IS NULL)
FROM trade_journal;
```

| Table | Total | `trade_idea_id` set | `trade_idea_id` NULL |
|---|---:|---:|---:|
| trade_intent | 304 | 261 | 43 |
| trade_journal | 486 | 281 | 205 |

✅ **Matches the AUD-0228 ambiguity report byte-for-byte.** No drift since the
migration applied on 2026-04-26.

### NULL rows are intentional — confirmed

The 248 NULL rows (43 intent + 205 journal) break down as:
- **213 zero-match rows** (41 intent + 172 journal): no candidate `trade_idea`
  in the ±24h `(symbol, side, timestamp)` window. These are legacy rows from
  before `trade_idea` existed in its current form, or trades placed without
  going through the idea-driven flow (manual trades, automated reactive
  entries). Not bugs — these legitimately have no parent idea.
- **34 multi-match rows** (2 intent + 32 journal): two or more candidate
  ideas in the window — the deterministic single-match join couldn't pick.
  Per the standing "do not guess" decision, these stayed NULL pending a
  manual reconciliation pool.
- **1 anchor-missing row**: `trade_journal` row with `opened_at IS NULL` —
  no timestamp anchor to drive the join.

### Manual review pool

The AUD-0228 ambiguity report's §"Recovery queries" section provides the
SQL to enumerate each ambiguous row + its candidate idea matches. That
section is preserved unchanged. Operator can run those queries when a
manual reconciliation window opens; nothing is forcing the issue.

✅ **Verification: the manual review pool is clearly documented and
re-derivable** from the existing report.

## AUD-0229 — `status_enum` backfill (migration 081)

### Live distribution vs report

```sql
SELECT status, status_enum::text AS status_enum, COUNT(*)
FROM trade_journal
GROUP BY status, status_enum
ORDER BY status, status_enum NULLS LAST;
```

| `status` | `status_enum` | Rows |
|---|---|---:|
| cancelled | (NULL) | 59 |
| closed | closed | 411 |
| open | open | 13 |
| suspended | suspended | 3 |

✅ **Matches the AUD-0229 ambiguity report byte-for-byte.** Backfilled
427 / 486 rows (87.9%). 59 NULL rows all have `status='cancelled'` — a
non-suspend lifecycle state intentionally outside the enum.

### Post-migration drift check — STILL ZERO

The migration's dual-write contract requires that any row with `status` in
the enum domain ALSO has the matching `status_enum` populated. The drift
check:

```sql
SELECT COUNT(*) FROM trade_journal
WHERE status IN ('open','suspending','suspended','resuming','closing','closed')
  AND status_enum IS NULL;
```

**Result: 0 rows.** ✅

This means:
1. The migration's initial backfill correctly covered every enum-eligible
   row at apply time.
2. Every code path that has WRITTEN to `trade_journal.status` since the
   migration applied has correctly also written `status_enum` (the
   dual-write contract is being honoured at `services/suspend_service.py:405,
   568` and `api/suspend.py:1116, 2014`).

If this query EVER returns non-zero, it means a code path is bypassing
the dual-write — investigate by `grep -nE "UPDATE trade_journal SET status\\s*=" lib/ bin/`
to find the rogue writer.

### Non-enum statuses are intentional — confirmed

The 59 `cancelled` rows + the documented-but-zero-rows-today statuses
(`seeded`, `pending_entry`, `force_open_failed`) are NOT in the enum by
design. The audit row's narrative explicitly scoped the enum to the
suspend FSM. Per the standing "do not guess" decision, these stay NULL.

A future commit (separate AUD) will either:
- Extend the enum to cover all `trade_journal.status` values (one
  comprehensive enum) and require new entries via CHECK constraint, OR
- Document that `status_enum` is suspend-lifecycle-only and stays
  NULL outside that domain.

Either approach is valid. Decision deferred per standing rule
"do not extend scope on the cleanup commit."

## Summary

| Check | Result |
|---|---|
| AUD-0228 NULL rows intentional? | ✅ Yes (zero-match + multi-match + 1 anchor-missing) |
| AUD-0228 manual review pool documented? | ✅ Yes (in the ambiguity report) |
| AUD-0228 numbers stable since migration apply? | ✅ Yes (live counts match the report exactly) |
| AUD-0229 non-suspend NULLs intentional? | ✅ Yes (all 59 are `cancelled`, outside enum scope) |
| AUD-0229 dual-write drift-check zero? | ✅ Yes (0 enum-eligible rows with NULL `status_enum`) |
| AUD-0229 string column `status` still source of truth? | ✅ Yes (cleanup deferred) |

**No data corrupted. No backfill needs reconsideration. No drift detected.**

The ambiguity reports stand as-is. No updates required to either report.
This verification doc is the audit trail for the post-campaign T4 review.
