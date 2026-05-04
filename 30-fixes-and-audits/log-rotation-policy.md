---
status: partial-shipped
tracker: "[[AUDIT_TRACKER]]"
tracker-rows:
  - "[[AUDIT_TRACKER#AUD-0371]]"
  - "[[AUDIT_TRACKER#AUD-0372]]"
created: 2026-04-25
---

# Log rotation policy

## Context

A 2026-04-25 deep health check found `tradelens/logs/api.log` at **4.65 GB** with `/dev/sda1` at **96 %** full (3.6 GB free). The same `logs/` tree had multiple 100+ MB lumps:

| File | Size | Owner of FD |
|---|---|---|
| `api.log` | 4.65 GB | shell `>>` redirect (nohup wrapper) |
| `vwap_order_engine.log` | 134 MB | Python `FileHandler` |
| `monitor.log` | 118 MB | Python `FileHandler` |
| `alert_engine.log` | 110 MB | Python `FileHandler` |
| `mdsync_pg.log` | 71 MB | Python `FileHandler` |

The proposed policy split the work into three independent tracks:

- **Track A** — in-process `RotatingFileHandler` for every Python daemon
- **Track B** — OS-level `logrotate(8)` for shell-redirected logs
- **Track C** — quieten the source by filtering uvicorn `/ws/notifications` access lines

Only **Track B** was shipped immediately (it caps the bleeding on the worst offender). Tracks A and C are deferred and tracked as **AUD-0371** and **AUD-0372** respectively.

## Track A — in-process `RotatingFileHandler` (DEFERRED → AUD-0371)

### Scope

| Daemon | RotatingFileHandler? |
|---|---|
| `pipeline_daemon` | ✅ landed in commit `bd5e415b` (AUD-0209) |
| `level_guard_daemon` | ✅ landed in commit `bd5e415b` (AUD-0209) |
| `level_mind_worker` | ✅ landed in commit `bd5e415b` (AUD-0209) |
| `alert_engine` | ❌ |
| `correlation_worker` | ❌ |
| `mdsync_pg` | ❌ |
| `vwap_order_engine` | ❌ |
| `vwap_series_worker` | ❌ |
| `telegram_signals` | ❌ |
| `discord_signals` | ❌ |
| `monitor` | ❌ |

The "❌" rows are the AUD-0371 work item.

### Recommended implementation

Add a shared helper at `lib/tradelens/core/logging.py`:

```python
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path

_LOG_DIR = Path(__file__).resolve().parents[3] / "logs"


def setup_rotating_logger(
    name: str,
    *,
    max_bytes: int = 50_000_000,  # 50 MB
    backup_count: int = 10,        # 50 × 10 = 500 MB cap per service
    debug: bool = False,
) -> logging.Logger:
    """Daemon-grade logger. Survives multi-day runs without filling disk.

    Mirrors the AUD-0209 setup that's already live in the three guard/mind/pipeline
    daemons. See docs/30-fixes-and-audits/log-rotation-policy.md.
    """
    logger = logging.getLogger(name)
    logger.handlers.clear()
    logger.setLevel(logging.DEBUG if debug else logging.INFO)

    log_path = _LOG_DIR / f"{name}.log"
    file_h = RotatingFileHandler(
        log_path,
        maxBytes=max_bytes,
        backupCount=backup_count,
        encoding="utf-8",
        delay=True,
    )
    file_h.setFormatter(logging.Formatter(
        "%(asctime)s %(levelname)-7s [%(name)s] %(message)s"
    ))
    logger.addHandler(file_h)
    return logger
```

Wire each daemon entry-point to call it instead of constructing a bare `FileHandler`.

### Choices

| Setting | Value | Rationale |
|---|---|---|
| `maxBytes` | 50 MB | Small enough to grep, large enough that backup count stays modest |
| `backupCount` | 10 | 50 × 10 = ~500 MB per service ceiling |
| `encoding` | `utf-8` | Defensive — Telegram/Discord content can be non-ASCII |
| `delay` | `True` | Don't open file until first write; cleaner restart semantics |

### Why stdlib instead of porting `gatekeeper/lib/logging_helper.py`

Gatekeeper's `GatekeeperLogger` rotates **only at script startup**. That works for gatekeeper because its scripts exit minutes/hours after starting. tradelens daemons stay up for days; `vwap_order_engine.log` reached 134 MB without ever restarting. We need on-write threshold checking, which `RotatingFileHandler` gives for free.

Gatekeeper's **inode-preserving truncate trick** (`shutil.copy2` + truncate so `tail -f` keeps following) is genuinely useful for one-shot scripts and could be lifted as a separate helper later. Not load-bearing for the daemon use case.

### Verification

For each daemon after wiring up:

```bash
# Drive enough activity to cross the 50 MB boundary, then check:
ls -la /app/syb/tradesuite/tradelens/logs/<svc>.log*
# Expected: <svc>.log (active), <svc>.log.1 (rotated), no growth past N×50 MB total.
```

## Track B — OS-level `logrotate` for shell-captured logs (SHIPPED 2026-04-25)

### Why a separate track

`api.log` and `web.log` are captured via shell redirection in `bin/server/start_api.sh` and `bin/server/start_trade_dashboard.sh`:

```bash
nohup "$TLHOME/bin/lib/autorestart.sh" --name api -- \
    "$TLHOME/bin/server/run_api.sh" "$API_HOST" "$API_PORT" \
    >> "$API_LOG" 2>&1 &
```

The writer is the shell, not Python. Stdlib `RotatingFileHandler` is unreachable here. A `mv`-style rotation would leave the shell's FD pointing at the renamed file. **`copytruncate` is mandatory.**

### Config — `tradelens/etc/logrotate.conf`

```
/app/syb/tradesuite/tradelens/logs/api.log
/app/syb/tradesuite/tradelens/logs/web.log
{
    size 100M
    rotate 7
    compress
    delaycompress
    copytruncate
    missingok
    notifempty
    su sybase sybase
}
```

| Setting | Value | Rationale |
|---|---|---|
| `size 100M` | 100 MB | WS access-log noise can fill 100 MB in hours; daily-only too coarse |
| `rotate 7` | 7 backups | 100 × 7 = 700 MB cap; ~1 week of headroom (drops once Track C ships) |
| `compress + delaycompress` | gzip from `.2` | `.1` stays uncompressed for greppability |
| `copytruncate` | yes | mandatory for shell `>>` writers |
| `missingok + notifempty` | both | safe defaults so logrotate doesn't bark when api is down |
| `su sybase sybase` | yes | run as the user that owns the files |

### Cron entry

Appended to `sybase` user's crontab:

```
0 * * * * /usr/sbin/logrotate -s /app/syb/tradesuite/tradelens/logs/.logrotate.state /app/syb/tradesuite/tradelens/etc/logrotate.conf >/dev/null 2>&1
```

State file lives inside the project (`logs/.logrotate.state`) so logrotate doesn't need write access to `/var/lib/`.

### Trade-off

`copytruncate` has a tiny race window where in-flight writes between `cp` and `:>` can be lost. For uvicorn access-log noise this is acceptable. If we ever need lossless rotation here, the path forward is to retire the shell `>>` redirect in `start_api.sh` and configure uvicorn with its own `RotatingFileHandler` via `--log-config`.

## Track C — uvicorn access-log filter (DEFERRED → AUD-0372)

### Why this matters

A `tail -5000 logs/api.log | uniq -c | sort -rn` taken on 2026-04-25 showed the WebSocket keepalive triplet dominating:

| Lines per 100 KB sample | Pattern |
|---:|---|
| 83 | `connection open` |
| 83 | `100.x.x.x:N - "WebSocket /ws/notifications" [accepted]` |
| 82 | `connection closed` |
| 49 | `Waiting for application startup.` |
| 49 | `Waiting for application shutdown.` |

≈80 % of `api.log` content is `/ws/notifications` keepalive churn. The WS endpoint is a long-poll-style notification stream that frontend clients reconnect every few seconds.

### Recommended fix

Two equally valid approaches:

**Option 1 — drop `--access-log` entirely** in `bin/server/run_api.sh`. Loses *all* HTTP request lines (not just WS keepalives). Acceptable if no one is reading them.

**Option 2 — pass `--log-config <json>`** that filters `/ws/notifications` from the access logger only. Preserves real HTTP request lines.

Sample log_config (Option 2):

```json
{
  "version": 1,
  "disable_existing_loggers": false,
  "filters": {
    "exclude_ws_notifications": {
      "()": "tradelens.core.logging.ExcludePathFilter",
      "exclude": ["/ws/notifications"]
    }
  },
  "handlers": {
    "default": {
      "class": "logging.StreamHandler",
      "stream": "ext://sys.stdout",
      "formatter": "default"
    },
    "access": {
      "class": "logging.StreamHandler",
      "stream": "ext://sys.stdout",
      "formatter": "access",
      "filters": ["exclude_ws_notifications"]
    }
  },
  "formatters": {
    "default":  {"format": "%(asctime)s %(levelprefix)s %(message)s"},
    "access":   {"format": "%(asctime)s %(levelprefix)s %(client_addr)s - \"%(request_line)s\" %(status_code)s"}
  },
  "loggers": {
    "uvicorn":         {"handlers": ["default"], "level": "INFO", "propagate": false},
    "uvicorn.error":   {"level": "INFO"},
    "uvicorn.access":  {"handlers": ["access"], "level": "INFO", "propagate": false}
  }
}
```

The `ExcludePathFilter` would be a tiny `logging.Filter` subclass that drops records whose `request_line` matches an entry in the exclude list.

### Expected impact

Order-of-magnitude reduction in `api.log` write volume. Once Track C ships, Track B's `rotate 7` can drop to `rotate 4`.

## Migration ordering

A and C are independent. Recommended order:

1. **Track A** — single PR adding `lib/tradelens/core/logging.py` helper plus per-daemon entry-point edits. Restart each daemon to pick up the new rotation.
2. **Track C** — independent PR; restart `api` only.

Track B is already live; nothing to migrate.

## Cross-references

- AUD-0209 — already-resolved Track-A subset (level_guard / level_mind / pipeline) — commit `bd5e415b`
- AUD-0304 — broader RotatingFileHandler ask; partly subsumed by AUD-0371
- AUD-0371 — Track A (this doc)
- AUD-0372 — Track C (this doc)
- `gatekeeper/lib/logging_helper.py` — the inspirational rotation impl; intentionally not ported (see "Why stdlib" above)
