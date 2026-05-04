# AppLock - Application-Level Distributed Locking

AppLock is a generic application-level locking system for TradeLens that coordinates work across multiple processes and hosts using PostgreSQL as a shared coordination store.

## Table of Contents

- [Overview](#overview)
- [Design Goals](#design-goals)
- [Lock Identity Model](#lock-identity-model)
- [How It Works](#how-it-works)
- [Python API](#python-api)
- [CLI Tool](#cli-tool)
- [Database Schema](#database-schema)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)

---

## Overview

AppLock provides distributed mutual exclusion for TradeLens subsystems. It is **not** a database transaction lock or engine-level lock - it's an application-level coordination mechanism that uses PostgreSQL as a shared state store.

**Key characteristics:**
- Crash-safe via TTL-based expiration
- Automatic heartbeat to extend lock lifetime
- Stale lock detection and takeover
- Observable via SQL queries or CLI tool
- No long-lived database transactions

---

## Design Goals

| Goal | Description |
|------|-------------|
| **Cross-process coordination** | Multiple processes on same or different hosts can coordinate |
| **Crash safety** | If a process crashes, its lock expires after TTL and can be taken over |
| **Fine-grained** | Lock individual resources (e.g., per-symbol, per-pipeline-step) |
| **Observable** | All locks visible in database table, queryable via SQL or CLI |
| **No long transactions** | Uses INSERT/DELETE, never holds DB transactions open |
| **Reusable** | Generic design works for any TradeLens subsystem |

**Non-goals:**
- Fair scheduling (no queue, no ordering guarantees)
- Distributed consensus (not Paxos/Raft)
- Replacing job queues (use for coordination, not task distribution)

---

## Lock Identity Model

A lock is uniquely identified by **three dimensions**:

```
(namespace, lock_key, lock_type)
```

| Dimension | Purpose | Examples |
|-----------|---------|----------|
| `namespace` | Subsystem ownership domain | `mdsync`, `pipeline`, `alerts` |
| `lock_key` | Resource identifier | `BTCUSDT:linear`, `refresh_order_leg_hist`, `global` |
| `lock_type` | Access mode / behavior | `exclusive` (v1 only) |

### Naming Conventions

**Namespace:** Use your subsystem name. Keep it short (max 32 chars).
```
mdsync      - Market data sync operations
pipeline    - Data pipeline steps
alerts      - Alert processing
```

**Lock type:** Currently only `exclusive` is supported (one holder at a time).

### Lock Key Naming Conventions

AppLock does **NOT** enforce any specific format for `lock_key`. However, following
consistent conventions helps avoid ambiguity and collisions across subsystems.

**Recommended Patterns:**

| Pattern | Use Case | Examples |
|---------|----------|----------|
| `symbol:category` | Per-symbol operations | `BTCUSDT:linear`, `ETHUSDT:spot` |
| `step-name` | Pipeline/job steps | `refresh-order-leg-hist`, `daily-report` |
| `resource:id` | Specific resource by ID | `account:12345`, `idea:67890` |
| `global` | Coarse/singleton locks | `global` (one lock for entire namespace) |

**Guidelines:**

1. **Use lowercase with hyphens** - Prefer `refresh-order-leg-hist` over `refresh_order_leg_hist`
2. **Be specific** - `BTCUSDT:linear` is better than `BTCUSDT` if you have multiple markets
3. **Keep it short** - Max 128 characters, but aim for under 64
4. **Avoid special characters** - Stick to alphanumeric, hyphens, colons, underscores
5. **Document your conventions** - Each subsystem should document its lock key patterns

**Examples by Subsystem:**

```
# mdsync - per-symbol locks
mdsync / BTCUSDT:linear / exclusive
mdsync / ETHUSDT:spot / exclusive

# pipeline - per-step locks
pipeline / refresh-order-leg-hist / exclusive
pipeline / refresh-trade-journal / exclusive

# alerts - singleton lock
alerts / process-batch / exclusive
```

**Important:** These are conventions, not enforced rules. AppLock will accept any
string up to 128 characters as a lock key.

### Owner ID Format

Each lock holder is identified by a standardized `owner_id` with the format:

```
<role>@<hostname>:<pid>:<short_uuid>
```

| Component | Description | Example |
|-----------|-------------|---------|
| `role` | Identity of the lock holder | `mdsync-backfill`, `pipeline`, `api-idea-create` |
| `hostname` | Machine hostname | `rocky-8gb` |
| `pid` | Process ID | `12345` |
| `short_uuid` | Process-stable UUID (8 chars) | `5674756d` |

**Examples:**
```
mdsync-backfill@rocky-8gb:12345:5674756d
pipeline@rocky-8gb:12346:a91e33bc
api-idea-create@rocky-8gb:12347:cc81fa12
lockctl:admin@rocky-8gb:12348:deadbeef
```

**Role Assignment:**
- Pass `role='my-role'` explicitly to the constructor (recommended)
- If not provided, role is inferred from the calling script name
- Falls back to `'unknown'` if detection fails

**Benefits:**
- Easy to identify which script/process holds a lock
- Process-stable UUID groups all locks from same process
- Useful for debugging and audit trails

---

## How It Works

### Lock Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                        LOCK STATES                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   [NOT EXISTS]  ──acquire()──►  [HELD]  ──release()──►  [NOT EXISTS]
│        │                          │                         │
│        │                          │ heartbeat thread        │
│        │                          │ extends expires_at      │
│        │                          ▼                         │
│        │                     [HELD + FRESH TTL]             │
│        │                          │                         │
│        │                          │ process crashes         │
│        │                          │ (no more heartbeats)    │
│        │                          ▼                         │
│        │                     [EXPIRED/STALE]                │
│        │                          │                         │
│        └──────takeover()──────────┘                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Acquire Algorithm

1. **Attempt INSERT** with `expires_at = now + ttl_seconds`
2. **If INSERT succeeds:** Lock acquired
3. **If INSERT fails** (PK conflict):
   - Read existing row
   - If `now >= expires_at`: Attempt stale takeover (DELETE + re-INSERT)
   - If lock is fresh: Wait and retry (if `wait_seconds > 0`) or fail

**Important:** Acquisition uses INSERT, not UPDATE. This ensures clean semantics and avoids race conditions.

### Heartbeat Mechanism

While holding a lock, a background thread periodically:
1. Updates `heartbeat_at` to current time
2. Extends `expires_at` by `ttl_seconds`

**Heartbeat interval:** `ttl_seconds / 3`, clamped to `[10, 120]` seconds.

If the heartbeat UPDATE affects 0 rows, the lock has been lost (taken over by another process). A `LockLostError` is raised.

### Stale Lock Takeover

When a process crashes without releasing its lock:
1. The lock row remains in the database
2. After `expires_at` passes, the lock is considered **stale**
3. Another process attempting to acquire will:
   - Detect the stale lock
   - DELETE the stale row (conditional on `expires_at`)
   - INSERT a new row with itself as owner

This is crash-safe: if two processes race to take over, only one DELETE will succeed.

### Process Liveness Check

In addition to TTL-based stale detection, AppLock performs **process liveness checks** for locks held on the **same host**:

1. When acquisition fails due to an existing lock, check the holder's host
2. If holder is on **same host**: Use `os.kill(pid, 0)` to check if the process is still alive
3. If the process is **dead**: Treat lock as stale immediately (no TTL wait)
4. If holder is on **different host**: Fall back to TTL-based detection (can't check remote processes)

**Benefits:**
- **Immediate recovery**: No waiting for TTL when a process crashes on the same host
- **Zero latency**: Lock takeover happens in milliseconds instead of waiting up to 300s
- **Safe**: Falls back to TTL for remote hosts or if liveness check fails

**Edge cases handled:**
| Case | Behavior |
|------|----------|
| Different host | Falls back to TTL-based detection |
| PID reused | Safe - `_attempt_stale_takeover()` uses conditional DELETE |
| Permission denied | Treats process as alive (can't signal, but exists) |
| Zombie process | `os.kill(pid, 0)` returns True - protected by TTL |

### Release

Release is a conditional DELETE:
```sql
DELETE FROM tradelens_app_lock
WHERE namespace = ? AND lock_key = ? AND lock_type = ?
  AND owner_id = ? AND owner_pid = ?
```

The `owner_id` and `owner_pid` conditions ensure you only release your own lock.

---

## Python API

### Installation

The module is part of TradeLens:
```python
from tradelens.locking import AppLock, LockAcquireError, LockTimeoutError, LockLostError
```

### Context Manager (Recommended)

```python
from tradelens.locking import AppLock

# Basic usage - lock held for duration of with block
with AppLock(namespace='mdsync', lock_key='BTCUSDT:linear', lock_type='exclusive'):
    do_exclusive_work()
# Lock automatically released, heartbeat stopped
```

```python
# With options
with AppLock(
    namespace='pipeline',
    lock_key='refresh_order_leg_hist',
    lock_type='exclusive',
    ttl_seconds=600,      # 10 minute TTL
    wait_seconds=30,      # Wait up to 30s for lock
    meta='cron job'       # Debug info stored in DB
):
    run_refresh()
```

### Manual Usage

```python
from tradelens.locking import AppLock

lock = AppLock(namespace='mdsync', lock_key='BTCUSDT:linear')

if lock.acquire():
    try:
        lock.start_heartbeat()  # Start background refresh
        do_work()
    finally:
        lock.stop_heartbeat()
        lock.release()
else:
    print("Could not acquire lock")
```

### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `namespace` | str | required | Subsystem domain (max 32 chars) |
| `lock_key` | str | required | Resource identifier (max 128 chars) |
| `lock_type` | str | `'exclusive'` | Access mode |
| `ttl_seconds` | int | `300` | Lock time-to-live (min 10) |
| `wait_seconds` | float | `0` | Max time to wait for lock (0 = no wait) |
| `role` | str | auto | Role identifier for owner_id (e.g., `'mdsync-backfill'`) |
| `owner_id` | str | auto | Full owner identifier (overrides auto-generation) |
| `meta` | str | `None` | Debug info (max 255 chars) |
| `enable_audit` | bool | `False` | Write audit trail events |

### Methods

| Method | Description |
|--------|-------------|
| `acquire()` | Attempt to acquire lock. Returns `True`/`False`. May raise `LockTimeoutError`. |
| `release()` | Release the lock. Returns `True` if released, `False` if not held. |
| `refresh()` | Manually extend TTL. Raises `LockLostError` if lock was lost. |
| `start_heartbeat()` | Start background thread to auto-refresh TTL. |
| `stop_heartbeat()` | Stop the background heartbeat thread. |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `is_held` | bool | True if lock is currently held by this instance |
| `is_lost` | bool | True if lock was lost (heartbeat failed) |
| `acquired_at` | datetime | When lock was acquired, or None |
| `owner_id` | str | This instance's owner identifier |

### Exceptions

```python
from tradelens.locking import LockAcquireError, LockTimeoutError, LockLostError

try:
    with AppLock(namespace='x', lock_key='y', wait_seconds=10):
        do_work()
except LockTimeoutError:
    # Could not acquire within wait_seconds
    print("Lock busy, try again later")
except LockLostError:
    # Lock was taken over while we held it (should be rare)
    print("CRITICAL: Lock lost mid-operation, aborting")
except LockAcquireError:
    # General acquisition failure
    print("Could not acquire lock")
```

### Utility Functions

```python
from tradelens.locking import list_locks, force_release_lock

# List all active locks
locks = list_locks()
for lock in locks:
    print(f"{lock['namespace']}/{lock['lock_key']} held by {lock['owner_id']}")

# List locks in a specific namespace
locks = list_locks(namespace='mdsync')

# Include expired locks
locks = list_locks(include_expired=True)

# Force release a stuck lock (admin only!)
force_release_lock(namespace='mdsync', lock_key='BTCUSDT:linear')
```

---

## CLI Tool

The `lockctl.py` tool provides administration and debugging commands.

### Location

```bash
/app/syb/tradesuite/tradelens/bin/tools/lockctl.py
```

### Commands

#### List Locks

```bash
# List all active locks
python3 bin/tools/lockctl.py list

# Filter by namespace
python3 bin/tools/lockctl.py list --namespace mdsync

# Include expired locks
python3 bin/tools/lockctl.py list --include-expired
```

**Output:**
```
NAMESPACE       LOCK_KEY                       TYPE         OWNER              EXPIRES_AT         STATUS
------------------------------------------------------------------------------------------------------------
mdsync          BTCUSDT:linear                 exclusive    rocky-8gb:12345    2025-12-15 11:45   ACTIVE
pipeline        refresh_order_leg_hist         exclusive    rocky-8gb:12346    2025-12-15 11:48   ACTIVE
```

#### Lock Info

```bash
python3 bin/tools/lockctl.py info <namespace> <lock_key>
```

**Example:**
```bash
python3 bin/tools/lockctl.py info mdsync BTCUSDT:linear
```

**Output:**
```
Lock Info: mdsync/BTCUSDT:linear/exclusive
------------------------------------------------------------
  Status:       ACTIVE
  Owner ID:     rocky-8gb:12345:5674756d
  Owner Host:   rocky-8gb
  Owner PID:    12345
  Acquired:     2025-12-15 11:43:34.737836
  Heartbeat:    2025-12-15 11:44:34.123456
  Expires:      2025-12-15 11:45:34.737836
  Meta:         backfill process
  TTL:          58.2 seconds remaining
```

#### Force Release

```bash
python3 bin/tools/lockctl.py release <namespace> <lock_key>
```

**Warning:** Only use this for stuck locks from crashed processes. Never force-release a lock held by a running process.

#### Test

```bash
python3 bin/tools/lockctl.py test
```

Runs a quick self-test of the locking system.

---

## Database Schema

### Table: tradelens_app_lock

```sql
CREATE TABLE tradelens_app_lock (
    -- Lock identity (composite primary key)
    lock_namespace      VARCHAR(32) NOT NULL,
    lock_key            VARCHAR(128) NOT NULL,
    lock_type           VARCHAR(32) NOT NULL,

    -- Owner information
    owner_id            VARCHAR(128) NOT NULL,
    owner_host          VARCHAR(64) NOT NULL,
    owner_pid           INT NOT NULL,

    -- Timestamps
    acquired_at         BIGDATETIME NOT NULL,
    heartbeat_at        BIGDATETIME NOT NULL,
    expires_at          BIGDATETIME NOT NULL,

    -- Optional metadata
    meta                VARCHAR(255) NULL,

    PRIMARY KEY (lock_namespace, lock_key, lock_type)
)
```

### Indexes

| Index | Columns | Purpose |
|-------|---------|---------|
| `idx_app_lock_namespace_expires` | `(namespace, expires_at)` | Efficient stale lock queries |
| `idx_app_lock_owner` | `(owner_host, owner_pid)` | Find locks by process |

### Direct SQL Queries

```sql
-- View all active locks
SELECT * FROM tradelens_app_lock
WHERE expires_at > CURRENT_TIMESTAMP
ORDER BY lock_namespace, lock_key

-- View locks for a namespace
SELECT * FROM tradelens_app_lock
WHERE lock_namespace = 'mdsync'

-- Find stale locks
SELECT * FROM tradelens_app_lock
WHERE expires_at <= CURRENT_TIMESTAMP

-- Find locks held by a specific host
SELECT * FROM tradelens_app_lock
WHERE owner_host = 'rocky-8gb'
```

### Audit Table (Optional)

If `enable_audit=True`, events are written to `tradelens_app_lock_audit`:

```sql
SELECT event_type, event_time, owner_id, lock_key
FROM tradelens_app_lock_audit
WHERE lock_namespace = 'mdsync'
ORDER BY event_time DESC
```

Event types: `acquire`, `release`, `heartbeat`, `takeover`

---

## Troubleshooting

### Lock Not Releasing

**Symptom:** Lock stuck in database, process is dead.

**Solution:**
```bash
# Verify process is dead
ps -p <owner_pid>

# Force release
python3 bin/tools/lockctl.py release <namespace> <lock_key>
```

### LockLostError Raised

**Symptom:** `LockLostError` exception during operation.

**Cause:** Another process took over the lock (likely because TTL expired before heartbeat ran).

**Solutions:**
1. Increase `ttl_seconds` if operations take longer than expected
2. Ensure heartbeat thread is running (`start_heartbeat()` or use context manager)
3. Check for long-blocking operations that prevent heartbeat

### Lock Contention

**Symptom:** `acquire()` returns `False` or raises `LockTimeoutError`.

**Solutions:**
1. Increase `wait_seconds` to wait longer
2. Reduce lock scope (more granular `lock_key`)
3. Review if operations can be parallelized

### Database Connection Errors

**Symptom:** Connection errors during lock operations.

**Cause:** Database configuration incorrect or PostgreSQL unavailable.

**Solution:**
```bash
# Verify PostgreSQL connection in $TLHOME/etc/config.yml

# Test connection
psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens
```

---

## Examples

### Example 1: Pipeline Step Lock

```python
from tradelens.locking import AppLock, LockTimeoutError

def refresh_order_leg_hist():
    """Run the order leg history refresh with exclusive lock."""
    try:
        with AppLock(
            namespace='pipeline',
            lock_key='refresh_order_leg_hist',
            lock_type='exclusive',
            ttl_seconds=600,
            wait_seconds=60,
            meta='refresh_order_leg_hist.py'
        ):
            print("Lock acquired, running refresh...")
            # ... do the actual work ...
            print("Refresh complete")
    except LockTimeoutError:
        print("Another refresh is running, skipping this run")
```

### Example 2: Per-Symbol Lock

```python
from tradelens.locking import AppLock

def backfill_symbol(symbol: str, market: str):
    """Backfill a single symbol with exclusive lock."""
    lock_key = f"{symbol}:{market}"

    with AppLock(
        namespace='mdsync',
        lock_key=lock_key,
        lock_type='exclusive',
        ttl_seconds=1800,  # 30 minutes for long backfills
        meta=f'backfill {symbol}'
    ):
        print(f"Backfilling {symbol}...")
        # ... backfill logic ...
```

### Example 3: Try-Lock Pattern (No Wait)

```python
from tradelens.locking import AppLock

def maybe_process_alerts():
    """Process alerts if no one else is, otherwise skip."""
    lock = AppLock(
        namespace='alerts',
        lock_key='process_batch',
        lock_type='exclusive',
        wait_seconds=0  # Don't wait
    )

    if lock.acquire():
        try:
            lock.start_heartbeat()
            process_pending_alerts()
        finally:
            lock.stop_heartbeat()
            lock.release()
    else:
        print("Alert processing already in progress, skipping")
```

### Example 4: Global Singleton Lock

```python
from tradelens.locking import AppLock

def run_daily_report():
    """Ensure only one daily report runs across all hosts."""
    with AppLock(
        namespace='reports',
        lock_key='daily_summary',
        lock_type='exclusive',
        ttl_seconds=3600,
        wait_seconds=0
    ):
        generate_daily_summary()
        send_email_report()
```

---

## Migration

The schema was created by migration `037_app_lock.sql`. To apply:

```bash
source /app/syb/tradesuite/sourceme.sh
cd /app/syb/tradesuite/tradelens
python3 bin/setup/run_migration.py 037_app_lock.sql
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.1 | 2025-12-15 | Added process liveness check for faster stale lock detection on same host |
| 1.0 | 2025-12-15 | Initial release with exclusive lock support |
