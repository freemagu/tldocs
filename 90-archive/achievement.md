# TradeLens: Building a Production Trading Platform in 4 Months with AI

## The Achievement

Between October 2025 and February 2026, a single developer built **TradeLens** — a full-stack, production-grade cryptocurrency trading platform — from scratch to live deployment in 124 days.

The project was built entirely through pair-programming with Claude (Anthropic's AI assistant) across **343 sessions**, producing **708 commits** over **72 active development days**.

### By the Numbers

| Metric | Value |
|--------|-------|
| Total source code | **132,000 lines** |
| Python backend | 72,000 lines across 136 files |
| React/TypeScript frontend | 50,000 lines across 122 files |
| SQL migrations | 4,800 lines across 55 migrations |
| Shell scripts & tooling | 4,600 lines |
| Claude sessions | 343 |
| Git commits | 708 |
| Calendar time | 4 months |
| Active development days | 72 |
| Estimated hours | 400-500 |

This is the output of what would typically require a team of 3-5 engineers working for 6-12 months. One person did it in four, with AI as a co-pilot.

---

## What TradeLens Does

TradeLens is a **self-hosted trading operations platform** for cryptocurrency traders on Bybit. It manages the entire lifecycle of a trade — from initial idea, through execution, active management, and post-mortem analysis — with a level of precision and automation that doesn't exist in any commercial product.

### The Problem It Solves

Professional traders juggle fragmented tools: exchange UIs for order placement, spreadsheets for journaling, TradingView for charting, calculators for position sizing, and mental notes for risk tracking. None of these tools talk to each other, and none of them understand the *structure* of a trade.

TradeLens replaces all of them with a single integrated system that understands trades as living, evolving entities — not just isolated buy and sell orders.

### Core Capabilities

**Trade Ideas & Planning** — Before entering any trade, users create structured ideas with entry levels, stop losses, and take-profit targets. Ideas can be watched with price alerts, and when the market reaches the right conditions, converted into live trades with a single click. Over time, idea accuracy becomes a measurable metric.

**Risk-Defined Execution** — Every trade starts with a risk amount, not a position size. The system calculates how many contracts to buy based on the distance between entry and stop loss. This enforces disciplined risk management at the point of execution, not as an afterthought.

**Smart Order Placement** — A single trade submission can generate a complex web of orders: a limit entry, up to four DCA (dollar-cost averaging) levels, a stop loss, and up to four take-profit targets. Take-profit orders can be defined as risk-reward ratios rather than absolute prices. Conditional orders sit dormant until their prerequisite legs fill.

**VWAP-Anchored Trading** — Three independent VWAP (Volume-Weighted Average Price) slots per trade allow traders to anchor analysis to different starting points. VWAP values update in real-time as positions grow through DCA fills. Orders and alerts can be linked to VWAP levels, meaning they move dynamically as the average price evolves — a capability no exchange or charting platform offers natively.

**Level Guard (Wick Protection)** — When price breaches a stop-loss level, the system doesn't immediately execute. Instead, it opens a configurable reclaim window. If price quickly recovers (a "wick" or liquidity sweep), the exit is cancelled. If the breach is sustained, the exit executes. This single feature can save traders from the most common source of unnecessary losses in crypto markets.

**Live Order Amendment** — Modify quantity, price, or order type on any leg of a live trade without cancelling and recreating. The system automatically recalculates weighted average entry price and all dependent R-metrics.

**R-Metric Analytics** — Every trade is measured in units of initial risk ("R"). A trade risking $500 that earns $1,500 is a +3R trade. The system tracks Initial R (projected), Exit R (realized), Maximum Favorable Excursion (best unrealized profit), Maximum Adverse Excursion (worst drawdown), and Time-to-1R (how quickly the trade became profitable). These are the metrics professional traders care about — not just dollar P&L.

**Trade Journal with Integrated Charts** — Closed trades are presented with TradingView charts overlaid with entry points, DCA levels, WAEP evolution, VWAP bands, and alert firing history. Each trade can be tagged (entry quality, execution quality, psychology, lessons learned) and annotated with free-form notes. An AI feedback feature provides conversational analysis of completed trades.

**Multi-Account Support** — Operate multiple Bybit accounts from one dashboard with account-scoped views, separate risk limits, and unified reporting.

**Always-On Background Services** — Six daemon processes run continuously:
- **Pipeline**: Syncs order data from Bybit, calculates WAEP, updates the trade journal
- **Alert Engine**: Monitors armed alerts and fires notifications when levels are hit
- **VWAP Engine**: Manages VWAP-linked orders, updating prices as VWAP moves
- **Level Guard**: Runs the wick-protection state machine for guarded exits
- **Market Data Sync**: Fetches and caches OHLCV candle data for charting
- **VWAP Series Worker**: Pre-computes VWAP time series for performance

All daemons are restart-safe with state persisted to the database, include graceful shutdown handling, and can be monitored and controlled from the dashboard's Services panel.

---

## Why Nothing Like This Exists

### Exchange platforms don't do this

Bybit, Binance, and other exchanges provide basic order types: market, limit, stop, take-profit. They have no concept of a "trade" as a structured entity with entries, DCAs, stops, and targets that relate to each other. They don't track WAEP evolution, they don't calculate R-metrics, and they certainly don't protect against wick hunts. Their APIs are order-level, not trade-level.

### TradingView doesn't do this

TradingView is a charting platform with alerting. It can draw lines and send notifications when price crosses them. It cannot place orders, manage positions, track risk in R-units, calculate VWAP from your actual fills, or protect your stop loss from wicks. It's a viewer, not an operator.

### Third-party tools don't do this

Products like 3Commas, Cornix, and similar "trading bots" focus on automated strategy execution — grid bots, DCA bots, copy trading. They optimize for hands-off automation. TradeLens is built for the opposite: a trader who is actively engaged, making decisions, and needs sophisticated tooling to execute and analyze those decisions precisely. The emphasis is on *augmenting human judgment*, not replacing it.

### Journaling tools don't do this

TraderSync, Edgewonk, and Tradervue are post-trade analysis tools. You export your trades and upload them. They have no connection to live markets, no order placement, no real-time position management. TradeLens journals trades as they happen, with data flowing directly from the exchange — no manual entry, no CSV uploads, no reconciliation gaps.

### The gap TradeLens fills

No existing product combines **idea planning, risk-defined execution, VWAP-anchored order management, wick protection, real-time position tracking, R-metric analytics, and structured journaling** in a single integrated system. Each of these capabilities exists in isolation somewhere, but the value is in their integration — where an idea flows seamlessly into execution, execution data feeds into the journal, and journal insights inform the next idea.

---

## Technical Architecture

TradeLens is a three-tier application:

- **Frontend**: React with TypeScript, TailwindCSS, Vite — a responsive single-page dashboard with TradingView chart integration
- **Backend**: Python with FastAPI — 30+ REST API endpoints, six background daemon services, Bybit exchange adapter
- **Database**: PostgreSQL — 55+ migration scripts tracking schema evolution, with both relational and time-series data patterns

The system is self-hosted, giving the trader full control over their data and execution infrastructure. There is no cloud dependency, no subscription, and no third party between the trader and their exchange.

---

## What This Represents

This project is a case study in what AI-assisted development makes possible. A 132,000-line production platform — with a React frontend, Python API backend, six background services, 55 database migrations, exchange integration, real-time alerting, and professional analytics — built by one person in four months.

The traditional estimate for this scope of work would be 3-5 engineers over 6-12 months. The code is not prototype quality; it runs in production, executing real trades with real money. The architecture includes restart-safe daemons, audit logging, graceful degradation, and the kind of defensive design that comes from actually using the software daily.

TradeLens exists because AI made it feasible for a single person with a clear vision to build exactly the tool they needed — without compromises, without waiting for a vendor roadmap, and without a team.
