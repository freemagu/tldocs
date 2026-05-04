# Breach-Decision Retraining — Suggested Scheduled Jobs

> Part of [[40-research/breach-decision/INDEX|breach-decision documentation]]

Companion to [[breach-decision-training]].
That doc captures the *pipeline plan* (what runs and how). This doc
captures the *operational cadence* (when each piece should run, who
acts on the output, and what the alerts mean).

**Status as of 2026-05-04**: J1 (trigger probe), J6 (quarterly audit), J8
(held-rate drift), and J9 (tick-archive CSV refresh) are all available today.
J2 (retrain run) and J3 (post-retrain validation) are also available — the
full training pipeline shipped 2026-04-29 and was first run 2026-05-04. J4
(manual promotion) is always manual by policy. J5 (calibration retrofit) is
available but small-fold calibration issues have not been resolved yet.
See [[pool-vs-baseline-2026-05-04]] for the first training run results.

---

## Job inventory

### J1 — Retrain-trigger probe

| Field | Value |
|---|---|
| Status | **Available today** |
| Cadence | Daily, ~05:00 UTC |
| Command | `tradelens/bin/breach-decision-retrain-trigger` |
| Prereq | None |
| Alert when | Any symbol's status flips from `wait` → `retrain` |
| Operator action | Begin a retrain run for that symbol (J2 once available) |

The trigger is cheap (one count query per symbol). Daily is plenty —
the underlying ok-row count moves slowly, and we don't want to spam
on identical-state-day-to-day output. Recommended: pipe through
`diff` against yesterday's run and only emit if status changed.

```bash
# Example (pseudo) — adjust for your scheduler.
tradelens/bin/breach-decision-retrain-trigger --json \
    > /var/tmp/retrain-trigger.today.json
diff -q /var/tmp/retrain-trigger.yesterday.json \
        /var/tmp/retrain-trigger.today.json \
    || tradelens/bin/breach-decision-retrain-trigger
mv /var/tmp/retrain-trigger.today.json /var/tmp/retrain-trigger.yesterday.json
```

### J2 — Retrain run

| Field | Value |
|---|---|
| Status | **Available today** — first run completed 2026-05-04 |
| Cadence | Triggered by J1 (or manual) |
| Command | `breach-decision-train --symbol <SYM> --version <version>` or `--pool S1,S2,...` |
| Prereq | Labelled rows in `breach_decision_log` (min 200 by default, tunable via `--min-rows`) |
| Output | New artefact at `data/models/breach_decision/<sym>/<version>/artefact.json` (per-symbol) or `data/models/breach_decision/_pool/<version>/artefact.json` (pool). Includes a persisted `metrics` block per target (since 2026-05-04). |
| Operator action | J3 review, then J4 promotion |

**CLI flags worth knowing:**

- `--symbol <SYM>` and `--pool S1,S2,...` are mutually exclusive — pick one.
- `--min-rows <N>` lowers the labelled-row floor (default 200). Useful for
  small-symbol diagnostic runs.
- `--allow-small-calibration-fold` — bypasses the calibrator-collapse guard.
  By default the trainer **warns** at `n_calib < 50` and **errors** at
  `n_calib < 20`; this flag suppresses both. Intended for diagnostic runs only.
  Models produced with this flag should not be promoted.

Don't auto-run on a calendar — only when J1 says `retrain`. A
calendar-driven retrain risks shipping a model fitted on too few
rows because "it's been 7 days".

### J3 — Post-retrain validation

| Field | Value |
|---|---|
| Status | **Pending** — needs J2 + a candidate artefact |
| Cadence | Once per candidate artefact |
| Command | `breach-decision-validate-candidate --artefact <path>` *(planned)* |
| Prereq | J2 produces a candidate; reference test set defined |
| Acceptance criteria | New artefact's calibrated log-loss ≤ current model's, on a held-out window the candidate did not see |
| Operator action | If pass: J4. If fail: investigate (label noise, regime shift, threshold drift) |

This is the gate that prevents bad models from being promoted.
Validation must run on **out-of-fold** data — the candidate's
training cutoff should sit before the validation window.

### J4 — Manual promotion

| Field | Value |
|---|---|
| Status | **Always manual** — by policy |
| Cadence | Once per validated candidate |
| Command | Edit `etc/config.yml`, set `model_version_<sym>: <new_version>`, then `tl restart level-mind` |
| Prereq | J3 passed |
| Rollback | Revert config to prior `model_version_<sym>`, restart |

Don't automate this. The cost of an automated bad-model deploy is
days of mis-scored gate decisions; the cost of one manual config
edit is seconds. Until the pipeline has a multi-month track record,
the human-in-the-loop is the cheap insurance.

### J5 — Calibration retrofit (interim)

| Field | Value |
|---|---|
| Status | **Pending** — needs ≥50 ok-status rows per symbol |
| Cadence | Monthly, while waiting for J2 to be ready |
| Command | `breach-decision-fit-calibrator --symbol <SYM>` *(planned)* |
| Prereq | Sufficient labelled `execute_gate_log` outcomes |
| Output | Isotonic calibrator JSON alongside artefact (`calibrator.json`) |
| Operator action | J4-style edit to `model_calibrator_<sym>` config key (proposed) |

J5 is the **near-term escape hatch** the training doc flags: even
without retraining LR coefficients, fitting an isotonic calibrator
on top of the existing model addresses the production-observed
overconfidence at p>0.95. Cheap to fit (one sklearn call), cheap to
roll back, and it gets value out of accumulated gate-outcome data
much sooner than full retraining.

### J6 — Quarterly model audit

| Field | Value |
|---|---|
| Status | **Available today** (parts) |
| Cadence | Quarterly, manual |
| Commands | `tradelens/bin/breach-decision-health`, `tradelens/bin/breach-decision-retrain-trigger`, `psql` queries on `execute_gate_log` |
| Prereq | None |
| Output | Markdown report committed under `docs/30-fixes-and-audits/` |

A periodic *operator* action, not a scheduled task. Walks through:

1. Trigger verdict per symbol (J1 output).
2. Gate-outcome distribution from `execute_gate_log` (counts of
   `breach_rejected` / `adverse_cap` / `time_cap`; per-symbol
   `held_rate` if a holds-mode gate is live).
3. Per-bucket calibration: for each predicted-probability decile,
   the realised breach-rejection rate. Flag overconfidence.
4. Decision: promote calibrator (J5), schedule retrain (J2), or
   accept current model.

The output is a doc, not a green/red signal. The point is to keep
the operator paying attention to the model on a fixed cadence.

---

## Dataset-shift sanity checks

The retraining cadence assumes the data distribution doesn't shift
between training and inference. These two cheap probes catch the
common shift modes:

### J7 — Daily breach-rate monitor

| Field | Value |
|---|---|
| Status | **Available today** (script-this) |
| Cadence | Daily |
| Query | `SELECT symbol, COUNT(*) FROM breach_decision_log WHERE decided_at_utc > NOW() - INTERVAL '24h' GROUP BY symbol;` |
| Alert when | Daily count drops below 50% of the trailing-7-day average per symbol |

Sudden drops in breach rate (without a corresponding drop in market
volatility) usually mean the upstream pipeline broke (missing data
source, ATR provider down). Distinct from "no breaches happened"
which is normal and informative.

### J8 — Held-rate drift on filled limits

| Field | Value |
|---|---|
| Status | **Available today** |
| Cadence | Weekly |
| Command | `tradelens/bin/holds-mode-backtest --eval-window-min 30 --tolerance-pct 1.00` |
| Alert when | Aggregate held-rate moves more than ±10pp from the 2026-04-28 baseline (DCAs 80%, TPs 64%) |

A material drop in held-rate is a regime-shift signal. If trader
behaviour didn't change but levels are failing more often, the
market structure has shifted and the (eventual) holds-mode model
needs retraining. If trader behaviour DID change (different level
placement style), document the change — the model's training
distribution no longer matches inference.

### J9 — Tick-archive CSV refresh

| Field | Value |
|---|---|
| Status | **Running** — cron at 03:00 UTC daily, data-driven from `breach_event ∪ level_guard` (91+ symbols). Shipped 2026-04-30. |
| Cadence | Daily, ~03:00 UTC |
| Command | `bin/refresh-tick-archive` |
| Prereq | Bybit daily public CSVs downloadable at ingest time |
| Output | New `<symbol>/<YYYY-MM-DD>.parquet` files appended to `/db/data01/tick_archive/`, `tick_trade_raw_ingest` rows added |
| Alert when | The most recent ingest is >48 h old (Bybit publishes T+1, so 48 h means we missed a day) |

Bybit publishes daily public-data CSV dumps with ~1-day lag. The
existing `TickIngestor` reads those CSVs and writes parquet — but
it currently runs only when invoked manually. A daily scheduled run
keeps the archive within ~24 h of real-time, which is sufficient
for retraining (J2) and label backfill
(`bin/server/breach_decision_label_backfill.py`).

The ingestor is idempotent on its (symbol, date) primary key in
`tick_trade_raw_ingest` and self-recovers from stale `'ingesting'`
status rows older than `stale_ingesting_minutes` (default 60). Safe
to re-run.

If sub-day-old ticks become a real requirement (e.g. for
within-session model adaptation), the path forward is a live
websocket → archive bridge inside `TickSidecar`. That is **not**
needed today; J9 + the existing retraining pipeline cover the
recurring use case.

---

## Recommended thresholds — rationale

The trigger defaults (`min_ok_rows=500`, `min_age_days=7`) reflect:

- **500 rows** — lower bound for a stable per-symbol LR fit with
  14 features (~36 events per coefficient). Below this the
  coefficient standard errors dominate and the new model is
  noisier than the old one.
- **7 days** — minimum dwell time to avoid retraining on a single
  market regime (e.g. one weekend's price action). Long enough
  to capture a weekday/weekend cycle.

These can be tuned in the trigger CLI:

```bash
tradelens/bin/breach-decision-retrain-trigger --min-ok-rows 1000 --min-age-days 14
```

Once the pipeline has a few quarters of operating history, revisit
both. Stricter thresholds stabilise the model; looser thresholds
adapt to regime changes faster. There is no free lunch.

---

## Cross-references

- [[breach-decision-training]] — pipeline plan (what runs and how)
- [[breach-decision-glossary]] — terminology
- [[holds-mode-backtest]] — holds-rate drift (J8)
- [[pool-vs-baseline-2026-05-04]] — first training run results (J2 output)
- [[40-research/breach-decision/INDEX|Breach-decision index]] — Map of Content
- `lib/tradelens/breach_decision/training/trigger.py` — trigger evaluator
- `bin/breach-decision-retrain-trigger` — trigger CLI
- `bin/breach-decision-health` — production data health

*Last reviewed: 2026-05-04 — J2 and J9 status updated; pool training first run noted.*
