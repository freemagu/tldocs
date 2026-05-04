# AUD-0229 — Migration 081 Status Backfill Ambiguity Report

**Date:** 2026-04-26
**Migration:** `migrations/081_add_suspend_state_enum.sql`
**Generated against:** production `tradelens` database, immediately pre-apply
(numbers reproduced from queries run on the live DB at audit time; the
migration itself does not write a report file).

## Summary

Migration 081 introduces a Postgres ENUM type `suspend_state_enum` with
6 values matching the post-AUD-0218 collapsed suspend FSM:

```
open → suspending → suspended
            ↓           ↓
         (rollback)  resuming → open
                        ↓
                     closing → closed
```

It then ADDs a NULLable `status_enum suspend_state_enum` column to
`trade_journal` and backfills it from the existing free-form `status`
VARCHAR(20) column where the value is in the enum. Per the standing
user decision, **rows whose `status` is outside the enum stayed NULL
(no guessing)** — those values represent non-suspend lifecycle states
that the audit row did not target.

The string column `trade_journal.status` is **not** dropped. It remains
the source of truth for downstream readers; a future commit will cut
readers over to `status_enum` and only then drop the string column.

## Pre-migration distribution of `trade_journal.status`

| `status` value     | Rows | In enum? | `status_enum` after backfill |
|--------------------|-----:|----------|------------------------------|
| `closed`           |  411 | YES      | `'closed'`                   |
| `cancelled`        |   59 | NO       | NULL                         |
| `open`             |   13 | YES      | `'open'`                     |
| `suspended`        |    3 | YES      | `'suspended'`                |
| **Total**          |  486 |          |                              |

Backfilled cleanly: **427 rows (87.9%)**.
Left NULL (status outside enum): **59 rows (12.1%)**.

The PARK threshold in the AUD-0229 task brief was ">50% of rows would
fail the cast". 12.1% is well under that, so the migration ships.

## Why the 59 NULL rows stayed NULL

All 59 NULL-after-backfill rows have `status = 'cancelled'`. This is
the canonical pre-trade-cancellation state set by
`bin/pipeline/refresh_trade_journal.py` and
`lib/tradelens/api/journal.py` when a `pending_entry` trade is
cancelled before its entry order fills. It is not a suspend-lifecycle
state, so it is intentionally outside the `suspend_state_enum`.

Other non-suspend `status` values that exist in the codebase but
happened to have zero rows in production at backfill time:

| `status` value       | Source                                   |
|----------------------|------------------------------------------|
| `seeded`             | `lib/tradelens/api/trades.py:2377` — created on submit before entry fill |
| `pending_entry`      | `lib/tradelens/api/journal.py:735` — pending-limit-entry status |
| `force_open_failed`  | `lib/tradelens/api/journal.py:4820` / `:4888` — force-open failure mode |

If any of these appear in future, they will also stay NULL after this
migration's backfill (which only runs once on apply; later inserts go
through the dual-write code paths and only write `status_enum` when
the value is in the enum).

## Dual-write contract (post-migration code)

The four codepaths that write the suspend-lifecycle states to
`trade_journal.status` were updated to also write `status_enum`:

| File                                              | Line(s) | State written |
|---------------------------------------------------|---------|---------------|
| `lib/tradelens/services/suspend_service.py`       |   ~405  | `'suspending'` |
| `lib/tradelens/services/suspend_service.py`       |   ~570  | `'suspended'` |
| `lib/tradelens/api/suspend.py` (resume path)      |  ~1116  | `'open'` |
| `lib/tradelens/api/suspend.py` (close path)       |  ~2013  | `'closed'` |

Codepaths that write non-suspend values (`'cancelled'`, `'seeded'`,
`'force_open_failed'`, etc.) were intentionally NOT modified — those
rows have `status_enum = NULL` and that is the correct state.

## Operational note

After apply, an analytics check that surfaces any drift between the
two columns is:

```sql
SELECT trade_id, status, status_enum
FROM trade_journal
WHERE status IN ('open', 'suspending', 'suspended', 'resuming', 'closing', 'closed')
  AND (status_enum IS NULL OR status_enum::text <> status);
```

This should return zero rows in steady state. If it returns rows, a
codepath has written one of the 6 enum values to `status` without
also writing `status_enum`.
