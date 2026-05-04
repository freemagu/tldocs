# Phase 2 Manual Review — 15 sampled labelled events

Seed: 42. Source: `breach_labels.csv`. Stratified: up to 5 per label class.

For each event: chart BTCUSDT 30m from `breached_at − 2h` through `breached_at + 8h`.
Mark the level price, the breach tick, and the 2h / 6h windows. Then judge:

1. **Label sanity**: does the chart agree with the assigned label?
2. **Recovery-close flag**: if True, is the first recovery-close bar visible within R?
3. **Excursion magnitudes**: do the recorded ATR-unit retreat / advance look roughly right?

Verdict column: `pass` / `fail` / `anomaly:<note>`.

| # | Event | Label | Type | Level | Breached (UTC) | Rcov | Rev (ATR) | Fwd (ATR) | Win? | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 32 | Ambiguous | low | 107842.2000000000 | 2025-10-30T13:37:46.405300 | True | 0.874 | 1.693 | True |  |
| 2 | 85 | Ambiguous | low | 85259.2000000000 | 2025-12-18T19:16:37.392100 | True | 0.926 | 1.102 | True |  |
| 3 | 174 | Ambiguous | high | 69500.0000000000 | 2026-03-10T02:30:17.716800 | True | 0.331 | 2.852 | True |  |
| 4 | 176 | Ambiguous | high | 71300.0000000000 | 2026-03-10T14:56:07.675600 | False | 3.371 | 0.946 | True |  |
| 5 | 184 | Ambiguous | high | 74499.8000000000 | 2026-03-16T21:04:52.264500 | True | 0.928 | 3.716 | True |  |
| 6 | 18 | Confirmed | high | 109434.5000000000 | 2025-10-20T03:50:14.412900 | False | 1.757 | 4.673 | True |  |
| 7 | 59 | Confirmed | high | 89172.2000000000 | 2025-11-26T17:42:00.531800 | False | 1.091 | 2.455 | True |  |
| 8 | 147 | Confirmed | low | 65065.0000000000 | 2026-02-23T01:19:57.825500 | False | 2.591 | 1.341 | True |  |
| 9 | 171 | Confirmed | low | 67400.7000000000 | 2026-03-07T19:19:03.046200 | False | 0.474 | 1.753 | True |  |
| 10 | 175 | Confirmed | high | 70600.0000000000 | 2026-03-10T08:05:31.040800 | False | 1.870 | 1.419 | True |  |
| 11 | 66 | SFP | low | 85560.2000000000 | 2025-12-01T12:40:50.847000 | True | 2.126 | 3.555 | True |  |
| 12 | 79 | SFP | low | 89336.5000000000 | 2025-12-11T14:56:21.080400 | True | 3.419 | 0.216 | True |  |
| 13 | 127 | SFP | low | 90610.1000000000 | 2026-01-20T14:47:27.903300 | True | 1.891 | 3.584 | True |  |
| 14 | 105 | SFP | low | 87177.8000000000 | 2026-01-25T18:44:36.496000 | True | 1.253 | 3.886 | True |  |
| 15 | 186 | SFP | low | 69432.9000000000 | 2026-03-19T12:50:38.494600 | True | 1.825 | 1.773 | True |  |

## Reviewer notes (free form)
(populate after inspection — anything surprising, ambiguous, or wrong)

## Anomalies & proposed actions
- If any event has `window_exhausted=False`, flag — data truncation, not genuine ambiguity.
- If reversal_excursion_atr and followthrough_excursion_atr are BOTH large on an SFP or
  Confirmed event, note it; the precedence rule handled it but the event is volatile.

