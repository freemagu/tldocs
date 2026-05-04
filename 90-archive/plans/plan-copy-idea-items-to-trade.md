# Plan: Copy Notes/Tags/Snapshots from Idea to Trade

## Overview

When a trade is created from an idea, copy all notes, tags, and snapshots from the idea to the trade. After copying, they are completely independent - changes to the idea don't affect the trade and vice versa.

## Current Behavior (Problems)

1. Trade journal API uses UNION queries to show idea items alongside trade items
2. Items appear on trade but are owned by idea (`trade_idea_id` set, `trade_id` NULL)
3. Deleting from trade view fails because item belongs to idea
4. On idea deletion, items get migrated to trade (but this is too late)

## Target Behavior

1. When trade is created with `trade_idea_id`, immediately copy all idea items to trade
2. Copied items have `trade_id = {new_trade_id}`, `trade_idea_id = NULL`
3. Trade only shows its own items (no UNION with idea)
4. Idea deletion simply deletes idea items (no migration needed)
5. Trade and idea are completely independent after trade creation

---

## Implementation Steps

### Step 1: Create Copy Helper Function

**File:** `lib/tradelens/utils/idea_item_copier.py` (NEW)

```python
"""
Copy notes, tags, and snapshots from an idea to a trade.

Called when a trade is first created from an idea.
"""

import logging
from typing import Optional
from tradelens.core.config import config
from tradelens.utils.snapshot_storage import get_snapshot_storage

logger = logging.getLogger(__name__)


def copy_idea_items_to_trade(
    conn,
    idea_id: int,
    trade_id: int,
    account_id: int,
    dry_run: bool = False
) -> dict:
    """
    Copy all notes, tags, and snapshots from an idea to a trade.

    Args:
        conn: Database connection
        idea_id: Source idea ID
        trade_id: Target trade ID
        account_id: Account ID for the trade
        dry_run: If True, don't actually copy, just report what would be copied

    Returns:
        Dict with counts: {notes_copied, tags_copied, snapshots_copied}
    """
    cursor = conn.cursor()

    # Find all items on the idea that haven't been copied to trade yet
    # (trade_idea_id = idea_id AND trade_id IS NULL)
    cursor.execute(f"""
        SELECT id, event_type, content, tag_id,
               snapshot_source, snapshot_provider, snapshot_filename, snapshot_description,
               created_at
        FROM trade_journal_notes
        WHERE trade_idea_id = {idea_id} AND trade_id IS NULL
    """)
    rows = cursor.fetchall()
    cursor.close()

    if not rows:
        logger.info(f"No items to copy from idea {idea_id} to trade {trade_id}")
        return {"notes_copied": 0, "tags_copied": 0, "snapshots_copied": 0}

    notes_copied = 0
    tags_copied = 0
    snapshots_copied = 0

    for row in rows:
        item_id = row[0]
        event_type = row[1]
        content = row[2]
        tag_id = row[3]
        snapshot_source = row[4]
        snapshot_provider = row[5]
        snapshot_filename = row[6]
        snapshot_description = row[7]
        created_at = row[8]

        # Check for duplicates before copying
        if event_type == 'tag' and tag_id:
            # Skip if trade already has this tag
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT COUNT(*) FROM trade_journal_notes
                WHERE trade_id = {trade_id} AND tag_id = {tag_id}
            """)
            if cursor.fetchone()[0] > 0:
                cursor.close()
                logger.debug(f"Skipping duplicate tag {tag_id} for trade {trade_id}")
                continue
            cursor.close()

        elif event_type == 'note':
            # Skip if trade already has note with same content
            cursor = conn.cursor()
            cursor.execute("""
                SELECT COUNT(*) FROM trade_journal_notes
                WHERE trade_id = %s AND event_type = 'note'
                  AND content = %s
            """, (trade_id, content))
            if cursor.fetchone()[0] > 0:
                cursor.close()
                logger.debug(f"Skipping duplicate note for trade {trade_id}")
                continue
            cursor.close()

        elif event_type == 'snapshot':
            # Skip if trade already has snapshot with same content URL
            cursor = conn.cursor()
            cursor.execute("""
                SELECT COUNT(*) FROM trade_journal_notes
                WHERE trade_id = %s AND event_type = 'snapshot'
                  AND content = %s
            """, (trade_id, content))
            if cursor.fetchone()[0] > 0:
                cursor.close()
                logger.debug(f"Skipping duplicate snapshot for trade {trade_id}")
                continue
            cursor.close()

        if dry_run:
            logger.info(f"[DRY RUN] Would copy {event_type} (id={item_id}) from idea {idea_id} to trade {trade_id}")
        else:
            # For uploaded snapshots, physically copy the file
            new_content = content
            new_filename = snapshot_filename

            if event_type == 'snapshot' and snapshot_source == 'UPLOAD':
                storage = get_snapshot_storage()
                if storage.is_upload_url(content):
                    # Copy the file and get new URL
                    new_url, new_fname = storage.copy_file(content)
                    if new_url:
                        new_content = new_url
                        new_filename = new_fname
                        logger.debug(f"Copied snapshot file: {content} -> {new_content}")
                    else:
                        logger.warning(f"Failed to copy snapshot file: {content}, using original")

            # Insert copy with trade_id, no trade_idea_id
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO trade_journal_notes
                    (trade_id, trade_idea_id, event_type, content, tag_id,
                     snapshot_source, snapshot_provider, snapshot_filename, snapshot_description,
                     created_at, updated_at)
                VALUES
                    (%s, NULL, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
            """, (trade_id, event_type, new_content, tag_id,
                  snapshot_source, snapshot_provider, new_filename,
                  snapshot_description, created_at))
            cursor.close()

            logger.debug(f"Copied {event_type} (id={item_id}) from idea {idea_id} to trade {trade_id}")

        if event_type == 'note':
            notes_copied += 1
        elif event_type == 'tag':
            tags_copied += 1
        elif event_type == 'snapshot':
            snapshots_copied += 1

    result = {
        "notes_copied": notes_copied,
        "tags_copied": tags_copied,
        "snapshots_copied": snapshots_copied
    }

    logger.info(f"Copied items from idea {idea_id} to trade {trade_id}: {result}")
    return result


```

---

### Step 2: Add File Copy Method to Snapshot Storage

**File:** `lib/tradelens/utils/snapshot_storage.py`

Add new method to copy a snapshot file:

```python
def copy_file(self, source_url: str) -> tuple[Optional[str], Optional[str]]:
    """
    Copy a snapshot file to a new location.

    Args:
        source_url: URL of the source file (e.g., /api/v1/snapshots/file/xxx.png)

    Returns:
        Tuple of (new_url, new_filename) or (None, None) on failure
    """
    if not self.is_upload_url(source_url):
        return None, None

    # Extract filename from URL
    # URL format: /api/v1/snapshots/file/{filename}
    parts = source_url.split('/')
    if len(parts) < 2:
        return None, None

    old_filename = parts[-1]
    old_path = self.upload_dir / old_filename

    if not old_path.exists():
        logger.warning(f"Source file not found: {old_path}")
        return None, None

    # Generate new unique filename
    import uuid
    ext = old_path.suffix
    new_filename = f"{uuid.uuid4().hex}{ext}"
    new_path = self.upload_dir / new_filename

    # Copy file
    import shutil
    shutil.copy2(old_path, new_path)

    new_url = f"/api/v1/snapshots/file/{new_filename}"
    logger.info(f"Copied snapshot file: {old_filename} -> {new_filename}")

    return new_url, new_filename
```

---

### Step 3: Call Copy Function on Trade Creation

**File:** `bin/pipeline/refresh_trade_journal.py`

After inserting a new trade with `trade_idea_id`, call the copy function.

Find the section after line ~1573 where new trades are inserted:

```python
# After: cursor.execute(insert_sql) for new trade
# Add:

if trade_idea_id and is_new_trade:
    # Copy notes/tags/snapshots from idea to trade
    from tradelens.utils.idea_item_copier import copy_idea_items_to_trade
    copy_result = copy_idea_items_to_trade(
        conn=conn,
        idea_id=trade_idea_id,
        trade_id=trade_id,
        account_id=session.account_id,
        dry_run=dry_run
    )
    logger.info(f"Copied idea items to new trade {trade_id}: {copy_result}")
```

**Important:** Need to track whether this is a new trade vs update. The current code returns `(trade_id, False)` for updates and we need to track new inserts.

---

### Step 4: Remove UNION Queries from Journal API

**File:** `lib/tradelens/api/journal.py`

#### 4a. Notes Query (lines ~803-820)

**Before:**
```python
if trade_idea_id:
    notes_sql = f"""
    SELECT id, content, created_at, updated_at, 'journal' as source
    FROM trade_journal_notes
    WHERE trade_id = {trade_id} AND event_type = 'note'
    UNION ALL
    SELECT id, content, created_at, updated_at, 'idea' as source
    FROM trade_journal_notes
    WHERE trade_idea_id = {trade_idea_id} AND trade_id IS NULL AND event_type = 'note'
    ORDER BY created_at
    """
else:
    notes_sql = f"""..."""
```

**After:**
```python
# No more UNION - trade only shows its own notes
notes_sql = f"""
SELECT id, content, created_at, updated_at
FROM trade_journal_notes
WHERE trade_id = {trade_id} AND event_type = 'note'
ORDER BY created_at
"""
```

#### 4b. Tags Query (lines ~837-886)

**Before:** Complex UNION query

**After:**
```python
# No more UNION - trade only shows its own tags
tags_sql = f"""
SELECT tjn.id, tjn.content, tjn.created_at, tjn.updated_at,
       tjn.tag_id, td.name as tag_name, td.tag_group
FROM trade_journal_notes tjn
LEFT JOIN tag_definition td ON tjn.tag_id = td.id
WHERE tjn.trade_id = {trade_id} AND tjn.event_type = 'tag'
ORDER BY
    CASE td.tag_group
        WHEN 'IDEA_BY' THEN 0
        WHEN 'ENTRY' THEN 1
        WHEN 'EXECUTION' THEN 2
        WHEN 'EXIT' THEN 3
        WHEN 'RISK' THEN 4
        WHEN 'CONTEXT' THEN 5
        WHEN 'PSYCH' THEN 6
        WHEN 'LEARNING' THEN 7
        ELSE 8
    END,
    tjn.created_at
"""
```

#### 4c. Snapshots Query (lines ~909-929)

**Before:** UNION query

**After:**
```python
# No more UNION - trade only shows its own snapshots
snapshots_sql = f"""
SELECT id, content, created_at, updated_at,
       snapshot_source, snapshot_provider, snapshot_filename, snapshot_description
FROM trade_journal_notes
WHERE trade_id = {trade_id} AND event_type = 'snapshot'
ORDER BY created_at
"""
```

#### 4d. Remove `source` field from NoteTag model

Since we no longer need to distinguish 'journal' vs 'idea' source, remove the `source` field added earlier:

**File:** `lib/tradelens/api/journal.py` (line ~128)

Remove: `source: Optional[str] = None`

And remove `source=row[7]...` from the tag building code.

---

### Step 5: Simplify Idea Deletion (No Migration)

**File:** `lib/tradelens/api/ideas.py`

**Before (lines 1876-1901):**
```python
# If idea was executed, migrate notes/tags/snapshots to the journal entry
if linked_trade_intent_id:
    # Find the journal entry linked to this idea
    cursor.execute(f"""
        SELECT trade_id FROM trade_journal
        WHERE trade_idea_id = {idea_id}
    """)
    journal_row = cursor.fetchone()

    if journal_row:
        journal_trade_id = journal_row[0]
        # Migrate: change trade_idea_id to trade_id
        cursor.execute(f"""
            UPDATE trade_journal_notes
            SET trade_id = {journal_trade_id},
                trade_idea_id = NULL
            WHERE trade_idea_id = {idea_id}
        """)
        logger.info(f"Migrated notes/tags/snapshots from idea {idea_id} to journal {journal_trade_id}")
    else:
        cursor.execute(f"DELETE FROM trade_journal_notes WHERE trade_idea_id = {idea_id}")
else:
    cursor.execute(f"DELETE FROM trade_journal_notes WHERE trade_idea_id = {idea_id}")
```

**After:**
```python
# Delete idea's notes/tags/snapshots
# (Trade already has its own copies from when it was created)
#
# For uploaded snapshots, we need to delete the files too
cursor.execute(f"""
    SELECT id, content, snapshot_source
    FROM trade_journal_notes
    WHERE trade_idea_id = {idea_id}
""")
items_to_delete = cursor.fetchall()

# Delete snapshot files for uploaded snapshots
from tradelens.utils.snapshot_storage import get_snapshot_storage
storage = get_snapshot_storage()
for item in items_to_delete:
    item_id, content, snapshot_source = item
    if snapshot_source == 'UPLOAD' and storage.is_upload_url(content):
        # Check if any other record references this file
        cursor.execute("""
            SELECT COUNT(*) FROM trade_journal_notes
            WHERE content = %s
              AND id != %s
        """, (content, item_id))
        other_refs = cursor.fetchone()[0]
        if other_refs == 0:
            storage.delete_file_by_url(content)
            logger.debug(f"Deleted snapshot file for idea {idea_id}: {content}")

# Delete all items
cursor.execute(f"DELETE FROM trade_journal_notes WHERE trade_idea_id = {idea_id}")
logger.info(f"Deleted notes/tags/snapshots for idea {idea_id}")
```

---

### Step 6: Migration Script for Existing Data

**File:** `bin/setup/migrate_idea_items_to_trades.py` (NEW)

```python
#!/usr/bin/env python3
"""
One-time migration: Copy notes/tags/snapshots from ideas to their linked trades.

For existing trades that were created from ideas before the copy-on-creation
feature was implemented.

Usage:
    ./migrate_idea_items_to_trades.py [--dry-run]

Options:
    --dry-run    Show what would be copied without making changes
"""

import sys
import os
import argparse
import logging

# Add lib to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'lib'))

from tradelens.core.pg_db import PostgresDB
from tradelens.core.config import config
from tradelens.utils.idea_item_copier import copy_idea_items_to_trade

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    parser = argparse.ArgumentParser(description='Migrate idea items to trades')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be copied')
    args = parser.parse_args()

    db = PostgresDB(config.database, logger)
    conn = db.connect()
    cursor = conn.cursor()

    # Find all trades linked to ideas
    cursor.execute("""
        SELECT tj.trade_id, tj.trade_idea_id, tj.account_id, tj.symbol
        FROM trade_journal tj
        WHERE tj.trade_idea_id IS NOT NULL
        ORDER BY tj.trade_id
    """)
    trades = cursor.fetchall()
    cursor.close()

    logger.info(f"Found {len(trades)} trades linked to ideas")

    total_notes = 0
    total_tags = 0
    total_snapshots = 0

    for trade in trades:
        trade_id, idea_id, account_id, symbol = trade

        logger.info(f"Processing trade {trade_id} (idea {idea_id}, {symbol})...")

        result = copy_idea_items_to_trade(
            conn=conn,
            idea_id=idea_id,
            trade_id=trade_id,
            account_id=account_id,
            dry_run=args.dry_run
        )

        total_notes += result['notes_copied']
        total_tags += result['tags_copied']
        total_snapshots += result['snapshots_copied']

    logger.info("=" * 50)
    logger.info(f"Migration {'(DRY RUN) ' if args.dry_run else ''}complete:")
    logger.info(f"  Trades processed: {len(trades)}")
    logger.info(f"  Notes copied: {total_notes}")
    logger.info(f"  Tags copied: {total_tags}")
    logger.info(f"  Snapshots copied: {total_snapshots}")

    db.close()


if __name__ == '__main__':
    main()
```

---

### Step 7: Remove `source` Field from Frontend

**File:** `frontend/web/src/components/journal/notes-tags-panel.tsx`

Remove the `source` field from the `NoteTag` interface (line ~164):

```typescript
interface NoteTag {
  id: number
  content: string
  created_at: string
  updated_at: string
  tag?: TagInfo | null
  // Remove: source?: 'journal' | 'idea'
  tag_id?: number
  tag_name?: string
  tag_group?: string
}
```

---

## Execution Order

1. **Create** `lib/tradelens/utils/idea_item_copier.py`
2. **Add** `copy_file()` method to `snapshot_storage.py`
3. **Run migration** `bin/setup/migrate_idea_items_to_trades.py --dry-run` (verify)
4. **Run migration** `bin/setup/migrate_idea_items_to_trades.py` (for real)
5. **Modify** `bin/pipeline/refresh_trade_journal.py` to call copy on new trades
6. **Modify** `lib/tradelens/api/journal.py` to remove UNION queries
7. **Modify** `lib/tradelens/api/ideas.py` to simplify deletion (no migration)
8. **Remove** `source` field from backend NoteTag model
9. **Remove** `source` field from frontend NoteTag interface
10. **Restart** API server
11. **Test** end-to-end

---

## Testing Checklist

- [ ] Create new idea with notes, tags, snapshots
- [ ] Execute idea to create trade
- [ ] Verify trade has copies of all items (not inherited)
- [ ] Verify idea still has original items
- [ ] Modify note on trade - verify idea note unchanged
- [ ] Modify note on idea - verify trade note unchanged
- [ ] Delete tag from trade - verify it works
- [ ] Delete idea - verify trade items remain
- [ ] Verify snapshot files were physically copied (different filenames)

---

## Rollback Plan

If issues arise:

1. Revert `journal.py` to restore UNION queries
2. Revert `ideas.py` to restore migration-on-delete
3. Revert `refresh_trade_journal.py` to remove copy-on-create
4. Copied items remain in database (harmless duplicates)
