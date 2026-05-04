# TradeLens API Reference

**Version**: 0.1.0
**Base URL**: `http://localhost:8088`
**Documentation**: `http://localhost:8088/docs` (Swagger UI)
**Framework**: FastAPI
**Protocol**: HTTP/REST with JSON payloads

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Components](#architecture-components)
3. [API Endpoints](#api-endpoints)
   - [Health & Status](#health--status)
   - [Account Management](#account-management)
   - [Portfolio & Positions](#portfolio--positions)
   - [Stop Loss Configuration](#stop-loss-configuration)
   - [Trade Execution](#trade-execution)
   - [Audit Trail](#audit-trail)
   - [SmartTrade Templates](#smarttrade-templates)
4. [Database Tables](#database-tables)
5. [Bybit API Calls](#bybit-api-calls)
6. [Data Flow](#data-flow)
7. [Configuration](#configuration)
8. [Authentication](#authentication)
9. [Error Handling](#error-handling)
10. [Caching & Optimization](#caching--optimization)
11. [Multi-Account Support](#multi-account-support)
12. [Design Patterns](#design-patterns)
13. [Important Notes](#important-notes)

---

## Overview

**TradeLens API** is a FastAPI-based REST service providing portfolio management, trade execution, and analytics for Bybit cryptocurrency trading. It features multi-account support, risk-defined trade sizing, and real-time position tracking.

### Key Features

- **Portfolio Management**: Combined view of futures and spot positions
- **Risk-Based Position Sizing**: Calculate position sizes from desired risk amount
- **Multi-Account Support**: Manage multiple Bybit accounts (real, demo, testnet)
- **Trade Execution**: Place complex trades with entry, DCA, take profit, and stop loss
- **ATR Metrics**: Real-time ATR (Average True Range) calculations for risk assessment
- **Audit Trail**: Complete trade intent and order leg tracking
- **Template System**: Save and reuse trade configurations

### Data Sources

The API uses a **hybrid data model**:
1. **Real-time data** from Bybit API (current prices, positions, balances)
2. **Cached enrichment data** from PostgreSQL database (WAEP, stop losses, timestamps)

### Architecture Pattern

```
Bybit Exchange API
    ↓
Pipeline Scripts (batch ETL) → PostgreSQL Database (cache)
    ↓                               ↓
    └────────→ API Server ←─────────┘
               (combines both sources)
                    ↓
             Web UI / API Client
```

---

## Architecture Components

### Application Entry Point

**File**: `/app/syb/tradesuite/tradelens/lib/tradelens/main.py`

The FastAPI application is created by the `create_app()` factory function which:
- Registers all API routers with `/api/v1` prefix
- Configures CORS middleware for cross-origin requests
- Sets up database connections
- Loads account configurations

**Root Endpoint**:
```http
GET /
```
Returns:
```json
{
  "message": "TradeLens API",
  "version": "0.1.0"
}
```

### CORS Configuration

```python
allow_origins: ["*"]           # Configure for production
allow_credentials: True
allow_methods: ["*"]
allow_headers: ["*"]
```

### Startup Scripts

**Start API Server**:
```bash
source /app/syb/tradesuite/sourceme.sh
./tradelens/bin/api start
```

**Stop API Server**:
```bash
./tradelens/bin/api stop
```

**Restart API Server**:
```bash
./tradelens/bin/api restart
```

**Server Details**:
- Host: `0.0.0.0:8088`
- Logs: `logs/api.log`
- PID file: `logs/api.pid`
- Process: uvicorn with auto-reload disabled

---

## API Endpoints

### Health & Status

#### `GET /api/v1/health`

**Description**: System health check for database and exchange connectivity.

**Authentication**: None

**Query Parameters**: None

**Bybit API Calls**:
- `GET /v5/market/tickers?category=linear&symbol=BTCUSDT` (unauthenticated)

**Database Tables**:
- None (performs `SELECT 1` test query)

**Response**: `200 OK`
```json
{
  "status": "ok",
  "database": "ok",
  "exchange": "ok",
  "timestamp": "2025-11-14T12:34:56.789Z"
}
```

**Status Values**:
- `"ok"`: All systems operational
- `"degraded"`: Partial failures
- `"error"`: Critical failures

**Example**:
```bash
curl http://localhost:8088/api/v1/health
```

---

#### `GET /api/v1/status/data`

**Description**: Get Bybit data freshness status and cache age.

**Authentication**: None

**Query Parameters**: None

**Bybit API Calls**: None

**Database Tables**: None (in-memory cache)

**Response**: `200 OK`
```json
{
  "bybit_time_cet": "2025-10-12T23:45:21+02:00",
  "local_fetch_age_seconds": 125,
  "staleness_level": "stale",
  "formatted_age": "2m 5s"
}
```

**Staleness Levels**:
- `"fresh"`: Data fetched within last 60 seconds
- `"stale"`: Data 60-300 seconds old
- `"very_stale"`: Data older than 5 minutes

**Example**:
```bash
curl http://localhost:8088/api/v1/status/data
```

---

### Account Management

#### `GET /api/v1/accounts`

**Description**: List all configured accounts (without sensitive credentials).

**Authentication**: None

**Query Parameters**:
- `include_inactive` (boolean, default: `false`): Include inactive accounts from database

**Bybit API Calls**: None

**Database Tables**:
- READ: `accounts` (if `include_inactive=true`)

**Response**: `200 OK`
```json
{
  "default_account": "main",
  "accounts": [
    {
      "name": "main",
      "exchange": "bybit",
      "account_type": "real",
      "subaccount_ref": null,
      "base_url": "https://api.bybit.com",
      "is_production": true,
      "is_demo": false,
      "is_testnet": false,
      "is_active": true,
      "display_name": "main"
    },
    {
      "name": "demo",
      "exchange": "bybit",
      "account_type": "demo",
      "subaccount_ref": null,
      "base_url": "https://api-demo.bybit.com",
      "is_production": false,
      "is_demo": true,
      "is_testnet": false,
      "is_active": true,
      "display_name": "demo"
    }
  ]
}
```

**Example**:
```bash
curl http://localhost:8088/api/v1/accounts
curl http://localhost:8088/api/v1/accounts?include_inactive=true
```

---

#### `GET /api/v1/accounts/default`

**Description**: Get the default account name.

**Authentication**: None

**Query Parameters**: None

**Bybit API Calls**: None

**Database Tables**: None (config file only)

**Response**: `200 OK`
```json
{
  "default_account": "main"
}
```

**Example**:
```bash
curl http://localhost:8088/api/v1/accounts/default
```

---

#### `GET /api/v1/accounts/{account_name}`

**Description**: Get specific account information (without credentials).

**Authentication**: None

**Path Parameters**:
- `account_name` (string): Account identifier

**Bybit API Calls**: None

**Database Tables**: None (config file only)

**Response**: `200 OK`
```json
{
  "name": "main",
  "exchange": "bybit",
  "account_type": "real",
  "subaccount_ref": null,
  "base_url": "https://api.bybit.com",
  "is_production": true,
  "is_demo": false,
  "is_testnet": false,
  "display_name": "main"
}
```

**Errors**:
- `404 Not Found`: Account does not exist

**Example**:
```bash
curl http://localhost:8088/api/v1/accounts/main
```

---

#### `GET /api/v1/account`

**Description**: Get account balance and equity summary from Bybit.

**Authentication**: Bybit API Key (from account config)

**Query Parameters**:
- `account` (string, optional): Account name (uses default if not specified)

**Bybit API Calls**:
- `GET /v5/account/wallet-balance?accountType=UNIFIED`

**Database Tables**: None

**Response**: `200 OK`
```json
{
  "account_name": "main",
  "account_id": 1,
  "account_type": "UNIFIED",
  "balance_data": {
    "list": [
      {
        "totalEquity": "10000.50",
        "totalWalletBalance": "9500.00",
        "totalMarginBalance": "9500.00",
        "totalAvailableBalance": "5000.00",
        "totalPerpUPL": "500.50",
        "totalInitialMargin": "4500.00",
        "totalMaintenanceMargin": "2250.00",
        "accountType": "UNIFIED",
        "accountIMRate": "0.45",
        "accountMMRate": "0.225",
        "coin": [
          {
            "coin": "USDT",
            "walletBalance": "9500.00",
            "availableToWithdraw": "5000.00"
          }
        ]
      }
    ]
  }
}
```

**Example**:
```bash
curl http://localhost:8088/api/v1/account?account=main
```

---

### Portfolio & Positions

#### `GET /api/v1/portfolio`

**Description**: Get combined portfolio with futures and spot positions, enriched with ATR metrics, stop losses, and risk calculations.

**Authentication**: Bybit API Key

**Query Parameters**:
- `account` (string, optional): Account name (uses default if not specified)

**Bybit API Calls**:
1. `GET /v5/position/list?category=linear&settleCoin=USDT` - Linear USDT perpetuals
2. `GET /v5/position/list?category=inverse` - Inverse perpetuals
3. `GET /v5/account/wallet-balance?accountType=UNIFIED` - Spot balances
4. `GET /v5/market/tickers?category=spot&symbol={SYMBOL}` - Spot prices (per coin)
5. `GET /v5/execution/list?category=spot&symbol={SYMBOL}&limit=100` - WAEP calculation (fallback)
6. `GET /v5/market/kline?category={category}&symbol={SYMBOL}&interval={interval}&limit=200` - ATR calculation (per position, per timeframe)
7. `GET /v5/market/instruments-info?category=linear` - Market metadata (tick size, cached 6h)

**Database Tables**:
- READ: `order_leg_live` - Stop loss prices (per position)
- READ: `spot_position_live` - WAEP and opened_at timestamps (spot only)
- READ: `position_lifecycle_hist` - Position open timestamps (futures, fallback)

**Caching**:
- ATR values cached in-memory per `(symbol, timeframe)`
- Market metadata cached in file for 6 hours

**Response**: `200 OK`
```json
{
  "positions": [
    {
      "symbol": "BTCUSDT",
      "kind": "futures_linear_usdt",
      "side": "long",
      "qty": 0.5,
      "entry_price": 42000.0,
      "mark_price": 43000.0,
      "value_usd": 21500.0,
      "unrealized_pnl": 500.0,
      "stop_loss": 41000.0,
      "stop_source": "order_leg_live",
      "risk_to_stop_usd": 500.0,
      "stop_risk_entry": 500.0,
      "stop_risk_live": 1000.0,
      "atr_15m": 250.0,
      "atr_4h": 800.0,
      "stop_distance_xatr_15m": 4.0,
      "stop_distance_xatr_4h": 1.25,
      "tick_size": 0.1,
      "created_at": "2025-10-12T10:30:00Z"
    },
    {
      "symbol": "ATOMUSDT",
      "kind": "spot",
      "side": "long",
      "qty": 100.0,
      "entry_price": 10.50,
      "mark_price": 11.00,
      "value_usd": 1100.0,
      "unrealized_pnl": 50.0,
      "stop_loss": 9.80,
      "stop_source": "order_leg_live",
      "risk_to_stop_usd": 70.0,
      "atr_15m": 0.15,
      "atr_4h": 0.45,
      "stop_distance_xatr_15m": 4.67,
      "stop_distance_xatr_4h": 1.56,
      "tick_size": 0.001,
      "created_at": "2025-10-11T14:20:00Z"
    }
  ],
  "totals": {
    "num_positions": 2,
    "total_asset_balance": 10000.50,
    "total_unrealized_pnl": 550.0,
    "total_risk_to_stop_usd": 570.0,
    "total_stop_risk_live": 1070.0,
    "balance_after_stops": 8930.50
  }
}
```

**Position Fields**:
- `symbol`: Trading pair (e.g., "BTCUSDT")
- `kind`: Position type (`"futures_linear_usdt"`, `"futures_inverse"`, `"spot"`)
- `side`: Direction (`"long"` or `"short"`)
- `qty`: Position quantity
- `entry_price`: Average entry price (WAEP for spot)
- `mark_price`: Current market price
- `value_usd`: Position value in USD
- `unrealized_pnl`: Unrealized profit/loss
- `stop_loss`: Stop loss price (if set)
- `stop_source`: Where stop loss came from (`"order_leg_live"`, `"position_api"`, `"none"`)
- `risk_to_stop_usd`: Dollar risk if stop hits (from entry)
- `stop_risk_entry`: Same as `risk_to_stop_usd`
- `stop_risk_live`: Dollar risk if stop hits (from current price)
- `atr_15m`: 15-minute ATR value
- `atr_4h`: 4-hour ATR value
- `stop_distance_xatr_15m`: Stop distance in multiples of 15m ATR
- `stop_distance_xatr_4h`: Stop distance in multiples of 4h ATR
- `tick_size`: Minimum price increment
- `created_at`: Position open timestamp (ISO 8601)

**Example**:
```bash
curl http://localhost:8088/api/v1/portfolio?account=main
```

---

#### `GET /api/v1/positions`

**Description**: Get futures positions only (linear USDT, linear USDC, inverse).

**Authentication**: Bybit API Key

**Query Parameters**:
- `account` (string, optional): Account name

**Bybit API Calls**:
1. `GET /v5/position/list?category=linear&settleCoin=USDT`
2. `GET /v5/position/list?category=inverse`

**Database Tables**:
- READ: `order_leg_live` - Stop loss prices
- READ: `position_lifecycle_hist` - Position timestamps

**Response**: `200 OK`
```json
{
  "positions": [
    {
      "symbol": "BTCUSDT",
      "kind": "futures_linear_usdt",
      "side": "long",
      "qty": 0.5,
      "entry_price": 42000.0,
      "mark_price": 43000.0,
      "value_usd": 21500.0,
      "unrealized_pnl": 500.0,
      "stop_loss": 41000.0,
      "stop_source": "order_leg_live",
      "risk_to_stop_usd": 500.0,
      "created_at": "2025-10-12T10:30:00Z"
    }
  ]
}
```

**Example**:
```bash
curl http://localhost:8088/api/v1/positions?account=demo
```

---

#### `GET /api/v1/spot`

**Description**: Get spot holdings only with WAEP and unrealized PnL.

**Authentication**: Bybit API Key

**Query Parameters**:
- `account` (string, optional): Account name

**Bybit API Calls**:
1. `GET /v5/account/wallet-balance?accountType=UNIFIED` - Spot balances
2. `GET /v5/market/tickers?category=spot&symbol={SYMBOL}` - Mark prices (per coin)
3. `GET /v5/execution/list?category=spot&symbol={SYMBOL}&limit=100` - WAEP calculation (fallback)

**Database Tables**:
- READ: `spot_position_live` - WAEP and opened_at (primary source)
- READ: `order_leg_live` - Stop loss prices

**Response**: `200 OK`
```json
{
  "positions": [
    {
      "symbol": "ATOMUSDT",
      "kind": "spot",
      "side": "long",
      "qty": 100.0,
      "entry_price": 10.50,
      "mark_price": 11.00,
      "value_usd": 1100.0,
      "unrealized_pnl": 50.0,
      "stop_loss": 9.80,
      "stop_source": "order_leg_live",
      "risk_to_stop_usd": 70.0
    }
  ]
}
```

**WAEP Calculation Priority**:
1. **Primary**: `spot_position_live.waep` (database cache, populated by pipeline)
2. **Fallback**: Calculate from execution history (last 100 fills)

**Example**:
```bash
curl http://localhost:8088/api/v1/spot
```

---

### Stop Loss Configuration

**Note**: This API is deprecated. Use conditional stop orders in trade execution instead.

#### `GET /api/v1/stops`

**Description**: List stop loss configurations.

**Authentication**: None

**Query Parameters**:
- `symbol` (string, optional): Filter by symbol

**Bybit API Calls**: None

**Database Tables**:
- READ: `stop_config`

**Response**: `200 OK`
```json
[
  {
    "symbol": "btcusdt",
    "stop_loss": 41000.0,
    "created_at": "2025-10-12T10:00:00Z",
    "updated_at": "2025-10-12T12:00:00Z"
  }
]
```

**Example**:
```bash
curl http://localhost:8088/api/v1/stops
curl http://localhost:8088/api/v1/stops?symbol=BTCUSDT
```

---

#### `POST /api/v1/stops`

**Description**: Create or update stop loss configuration (deprecated - use conditional orders).

**Authentication**: Bybit API Key

**Request Body**: `StopConfigRequest`
```json
{
  "symbol": "BTCUSDT",
  "stop_loss": 41000.0
}
```

**Bybit API Calls**:
- `POST /v5/position/trading-stop` - Set stop loss on Bybit (futures only)

**Database Tables**:
- WRITE: `stop_config` - INSERT/UPDATE stop config

**Response**: `200 OK`
```json
{
  "symbol": "btcusdt",
  "stop_loss": 41000.0,
  "created_at": "2025-10-12T10:00:00Z",
  "updated_at": "2025-10-12T12:00:00Z"
}
```

**Example**:
```bash
curl -X POST http://localhost:8088/api/v1/stops \
  -H "Content-Type: application/json" \
  -d '{"symbol": "BTCUSDT", "stop_loss": 41000.0}'
```

---

#### `DELETE /api/v1/stops/{symbol}`

**Description**: Delete stop loss configuration.

**Authentication**: None

**Path Parameters**:
- `symbol` (string): Trading pair

**Bybit API Calls**: None

**Database Tables**:
- WRITE: `stop_config` - DELETE stop config

**Response**: `200 OK`
```json
{
  "deleted": true,
  "symbol": "btcusdt"
}
```

**Example**:
```bash
curl -X DELETE http://localhost:8088/api/v1/stops/BTCUSDT
```

---

### Trade Execution

#### `POST /api/v1/trades/preview`

**Description**: Preview trade with position sizing, leg breakdown, and validations. Does not place any orders.

**Authentication**: Bybit API Key (for market data)

**Request Body**: `TradePreviewRequest`

**Sizing Modes**:

1. **Risk Amount** (original):
```json
{
  "symbol": "BTCUSDT",
  "side": "long",
  "entry_type": "limit",
  "limit_price": 42000.0,
  "stop_loss": 41000.0,
  "sizing_mode": "risk_amount",
  "risk_usd": 500.0,
  "dca_levels": 2,
  "entry_pct": 50.0,
  "dca1_pct": 30.0,
  "dca2_pct": 20.0,
  "take_profits": [
    {"price": 43000.0, "size_pct": 50.0},
    {"price": 44000.0, "size_pct": 50.0}
  ],
  "account_name": "main"
}
```

2. **USD Value**:
```json
{
  "symbol": "BTCUSDT",
  "side": "long",
  "entry_type": "market",
  "stop_loss": 41000.0,
  "sizing_mode": "usd_value",
  "position_usd": 21000.0,
  "account_name": "main"
}
```

3. **Quantity**:
```json
{
  "symbol": "BTCUSDT",
  "side": "short",
  "entry_type": "limit",
  "limit_price": 42000.0,
  "stop_loss": 43000.0,
  "sizing_mode": "quantity",
  "position_qty": 0.5,
  "account_name": "main"
}
```

**Request Fields**:
- `symbol` (string, required): Trading pair
- `side` (string, required): `"long"` or `"short"`
- `entry_type` (string, required): `"market"` or `"limit"`
- `limit_price` (float, required if entry_type="limit"): Entry limit price
- `stop_loss` (float, required): Stop loss price
- `sizing_mode` (string, required): `"risk_amount"`, `"usd_value"`, or `"quantity"`
- `risk_usd` (float, required if sizing_mode="risk_amount"): Desired risk in USD
- `position_usd` (float, required if sizing_mode="usd_value"): Total position value in USD
- `position_qty` (float, required if sizing_mode="quantity"): Exact position quantity
- `dca_levels` (int, optional): Number of DCA levels (0-5)
- `entry_pct` (float, optional): Entry allocation percentage
- `dca1_pct`, `dca2_pct`, etc. (float, optional): DCA allocation percentages
- `take_profits` (array, optional): Take profit levels
  - `price` (float): TP price
  - `size_pct` (float): TP size percentage
- `account_name` (string, optional): Account to use

**Bybit API Calls**:
1. `GET /v5/market/instruments-info?category={category}&symbol={SYMBOL}` - Instrument metadata
2. `GET /v5/market/tickers?category={category}&symbol={SYMBOL}` - Live price (if entry_type="market")

**Database Tables**: None (preview cached in-memory)

**Response**: `200 OK`
```json
{
  "preview_id": "px_a1b2c3d4e5f6",
  "symbol": "btcusdt",
  "side": "long",
  "entry_type": "limit",
  "entry_price_used": 42000.0,
  "avg_entry": 41700.0,
  "stop_loss": 41000.0,
  "risk_per_unit": 700.0,
  "computed_qty": 0.714,
  "resolved_percents": {
    "entry_pct": 50.0,
    "dca1_pct": 30.0,
    "dca2_pct": 20.0
  },
  "legs": [
    {
      "kind": "entry",
      "order_kind": "limit",
      "price": 42000.0,
      "qty": 0.357
    },
    {
      "kind": "dca",
      "order_kind": "limit",
      "price": 41500.0,
      "qty": 0.214
    },
    {
      "kind": "dca",
      "order_kind": "limit",
      "price": 41000.0,
      "qty": 0.143
    }
  ],
  "take_profit_levels": [
    {
      "from": "entry",
      "price": 43000.0,
      "size_pct": 50.0,
      "qty": 0.357
    },
    {
      "from": "entry",
      "price": 44000.0,
      "size_pct": 50.0,
      "qty": 0.357
    }
  ],
  "validations": [
    "All validations passed",
    "Stop loss correctly placed below entry for long position"
  ]
}
```

**Preview Fields**:
- `preview_id`: Unique identifier for this preview (use in `/trades/submit`)
- `symbol`: Trading pair (normalized)
- `computed_qty`: Total position quantity calculated
- `avg_entry`: Weighted average entry price across all legs
- `risk_per_unit`: Risk per unit of the asset
- `legs`: Array of entry/DCA legs with prices and quantities
- `take_profit_levels`: Array of TP levels
- `validations`: Array of validation messages/warnings

**Example**:
```bash
curl -X POST http://localhost:8088/api/v1/trades/preview \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTCUSDT",
    "side": "long",
    "entry_type": "limit",
    "limit_price": 42000.0,
    "stop_loss": 41000.0,
    "sizing_mode": "risk_amount",
    "risk_usd": 500.0,
    "account_name": "main"
  }'
```

---

#### `POST /api/v1/trades/submit`

**Description**: Submit trade based on preview. Places orders on Bybit exchange.

**Authentication**: Bybit API Key

**Request Body**: `TradeSubmitRequest`
```json
{
  "preview_id": "px_a1b2c3d4e5f6"
}
```

**Bybit API Calls** (per leg):
1. `POST /v5/order/create` - Entry/DCA legs
2. `POST /v5/order/create` - Take profit legs (regular or conditional)
3. `POST /v5/order/create` - Stop loss (conditional order)

**Database Tables**:
- WRITE: `trade_intent` - INSERT trade intent record
- WRITE: `order_leg` - INSERT order leg records (per order)

**Response**: `200 OK` (success), `502 Bad Gateway` (Bybit error)
```json
{
  "trade_intent_id": 1247,
  "status": "submitted",
  "message": "Trade submitted successfully",
  "order_legs": [
    {
      "leg_id": 5001,
      "leg_type": "entry",
      "order_kind": "limit",
      "exchange_order_id": "bybit-order-123456",
      "status": "submitted"
    },
    {
      "leg_id": 5002,
      "leg_type": "dca",
      "order_kind": "limit",
      "exchange_order_id": "bybit-order-123457",
      "status": "submitted"
    },
    {
      "leg_id": 5003,
      "leg_type": "tp",
      "order_kind": "limit",
      "exchange_order_id": "bybit-order-123458",
      "status": "submitted"
    },
    {
      "leg_id": 5004,
      "leg_type": "stop",
      "order_kind": "market",
      "exchange_order_id": "bybit-order-123459",
      "status": "submitted"
    }
  ]
}
```

**Status Values**:
- `"submitted"`: All orders placed successfully
- `"partial"`: Some orders failed
- `"error"`: All orders failed

**Order Placement Logic**:

**Entry/DCA Legs**:
- Placed as limit orders (if entry_type="limit") or market orders (if entry_type="market")
- Uses hedge mode for futures (`positionIdx=1` for long, `positionIdx=2` for short)

**Take Profit Legs**:
- **Market entries**: Regular TP limit orders placed immediately
- **Limit entries/DCAs**: Conditional TP orders with `triggerPrice = entry_price`
  - Triggers when entry fills
  - Ensures TPs only activate after position is opened

**Stop Loss**:
- Conditional market order at trigger price
- **Linear/Inverse futures**: `qty="0"` with `closeOnTrigger=True` (closes entire position)
- **Spot**: Actual quantity (Bybit rejects qty="0" for spot)
- `triggerDirection=2` for long (triggers below), `triggerDirection=1` for short (triggers above)

**Example**:
```bash
curl -X POST http://localhost:8088/api/v1/trades/submit \
  -H "Content-Type: application/json" \
  -d '{"preview_id": "px_a1b2c3d4e5f6"}'
```

---

#### `POST /api/v1/trades/preview-bybit-orders`

**Description**: Preview exact Bybit API payloads that would be sent, without submitting. Useful for debugging and manual editing.

**Authentication**: None (read-only preview)

**Request Body**: `TradeSubmitRequest`
```json
{
  "preview_id": "px_a1b2c3d4e5f6"
}
```

**Bybit API Calls**: None

**Database Tables**: None

**Response**: `200 OK`
```json
{
  "preview_id": "px_a1b2c3d4e5f6",
  "symbol": "btcusdt",
  "side": "long",
  "environment": "real",
  "base_url": "https://api.bybit.com",
  "orders": [
    {
      "leg_type": "entry",
      "order_kind": "limit",
      "endpoint": "/v5/order/create",
      "method": "POST",
      "params": {
        "category": "linear",
        "symbol": "BTCUSDT",
        "side": "Buy",
        "orderType": "Limit",
        "qty": "0.357",
        "price": "42000.0",
        "timeInForce": "GTC",
        "positionIdx": 1
      }
    },
    {
      "leg_type": "stop",
      "order_kind": "market",
      "endpoint": "/v5/order/create",
      "method": "POST",
      "params": {
        "category": "linear",
        "symbol": "BTCUSDT",
        "side": "Sell",
        "orderType": "Market",
        "qty": "0",
        "triggerPrice": "41000.0",
        "triggerDirection": 2,
        "orderFilter": "StopOrder",
        "positionIdx": 1,
        "reduceOnly": true,
        "closeOnTrigger": true
      }
    },
    {
      "leg_type": "tp",
      "order_kind": "limit",
      "endpoint": "/v5/order/create",
      "method": "POST",
      "params": {
        "category": "linear",
        "symbol": "BTCUSDT",
        "side": "Sell",
        "orderType": "Limit",
        "qty": "0.178",
        "price": "43000.0",
        "timeInForce": "GTC",
        "positionIdx": 1,
        "reduceOnly": true,
        "triggerPrice": "42000.0",
        "triggerBy": "LastPrice"
      }
    }
  ]
}
```

**Use Cases**:
- Debug order parameters before submission
- Export order payloads for manual editing
- Verify order logic (conditional vs. regular)
- Test trade configurations

**Example**:
```bash
curl -X POST http://localhost:8088/api/v1/trades/preview-bybit-orders \
  -H "Content-Type: application/json" \
  -d '{"preview_id": "px_a1b2c3d4e5f6"}'
```

---

#### `POST /api/v1/trades/submit-json`

**Description**: Submit trade directly from edited JSON orders. Allows manual override of order parameters.

**Authentication**: Bybit API Key

**Request Body**: `TradeSubmitJsonRequest`
```json
{
  "symbol": "BTCUSDT",
  "side": "long",
  "orders": [
    {
      "category": "linear",
      "symbol": "BTCUSDT",
      "side": "Buy",
      "orderType": "Limit",
      "qty": "0.5",
      "price": "42000.0",
      "timeInForce": "GTC",
      "positionIdx": 1
    },
    {
      "category": "linear",
      "symbol": "BTCUSDT",
      "side": "Sell",
      "orderType": "Market",
      "qty": "0",
      "triggerPrice": "41000.0",
      "triggerDirection": 2,
      "orderFilter": "StopOrder",
      "positionIdx": 1,
      "reduceOnly": true,
      "closeOnTrigger": true
    }
  ],
  "account_name": "main"
}
```

**Bybit API Calls**:
- `POST /v5/order/create` (per order in request)

**Database Tables**:
- WRITE: `trade_intent` - INSERT trade intent record
- WRITE: `order_leg` - INSERT order leg records

**Response**: Same as `/trades/submit`

**Use Case**: Advanced users who want to manually customize order parameters after previewing.

**Example**:
```bash
curl -X POST http://localhost:8088/api/v1/trades/submit-json \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTCUSDT",
    "side": "long",
    "orders": [...],
    "account_name": "main"
  }'
```

---

### Audit Trail

#### `GET /api/v1/audit`

**Description**: List trade audit trail with pagination.

**Authentication**: None

**Query Parameters**:
- `symbol` (string, optional): Filter by symbol
- `status` (string, optional): Filter by status (`"submitted"`, `"partial"`, `"error"`)
- `limit` (int, default: 50): Result limit

**Bybit API Calls**: None

**Database Tables**:
- READ: `trade_intent`

**Response**: `200 OK`
```json
{
  "trade_intents": [
    {
      "trade_intent_id": 1247,
      "symbol": "btcusdt",
      "side": "long",
      "entry_type": "limit",
      "status": "submitted",
      "created_at": "2025-10-12T10:30:00Z"
    },
    {
      "trade_intent_id": 1246,
      "symbol": "ethusdt",
      "side": "short",
      "entry_type": "market",
      "status": "submitted",
      "created_at": "2025-10-12T09:15:00Z"
    }
  ]
}
```

**Example**:
```bash
curl http://localhost:8088/api/v1/audit
curl http://localhost:8088/api/v1/audit?symbol=BTCUSDT&status=submitted&limit=100
```

---

#### `GET /api/v1/audit/{trade_intent_id}`

**Description**: Get detailed audit trail for specific trade, including all order legs.

**Authentication**: None

**Path Parameters**:
- `trade_intent_id` (int): Trade intent ID

**Bybit API Calls**: None

**Database Tables**:
- READ: `trade_intent`
- READ: `order_leg`

**Response**: `200 OK`
```json
{
  "trade_intent_id": 1247,
  "symbol": "btcusdt",
  "side": "long",
  "entry_type": "limit",
  "limit_price": 42000.0,
  "stop_loss": 41000.0,
  "desired_risk_usd": 500.0,
  "computed_qty": 0.714,
  "status": "submitted",
  "created_at": "2025-10-12T10:30:00Z",
  "order_legs": [
    {
      "leg_id": 5001,
      "leg_type": "entry",
      "order_kind": "limit",
      "price": 42000.0,
      "qty": 0.357,
      "exchange_order_id": "bybit-order-123456",
      "status": "submitted",
      "created_at": "2025-10-12T10:30:05Z"
    },
    {
      "leg_id": 5002,
      "leg_type": "dca",
      "order_kind": "limit",
      "price": 41500.0,
      "qty": 0.214,
      "exchange_order_id": "bybit-order-123457",
      "status": "submitted",
      "created_at": "2025-10-12T10:30:06Z"
    },
    {
      "leg_id": 5003,
      "leg_type": "stop",
      "order_kind": "market",
      "price": 41000.0,
      "qty": 0.0,
      "exchange_order_id": "bybit-order-123459",
      "status": "submitted",
      "created_at": "2025-10-12T10:30:08Z"
    }
  ]
}
```

**Errors**:
- `404 Not Found`: Trade intent does not exist

**Example**:
```bash
curl http://localhost:8088/api/v1/audit/1247
```

---

### SmartTrade Templates

#### `GET /api/v1/templates`

**Description**: List all saved trade templates.

**Authentication**: None

**Query Parameters**:
- `user_id` (string, optional): Filter by user ID

**Bybit API Calls**: None

**Database Tables**:
- READ: `smarttrade_templates`

**Response**: `200 OK`
```json
[
  {
    "id": 1,
    "template_name": "BTC Conservative",
    "symbol": "BTCUSDT",
    "is_default": false,
    "updated_at": "Oct 12 2025 10:30:00"
  },
  {
    "id": 2,
    "template_name": "ETH Aggressive",
    "symbol": "ETHUSDT",
    "is_default": true,
    "updated_at": "Oct 11 2025 15:20:00"
  }
]
```

**Example**:
```bash
curl http://localhost:8088/api/v1/templates
curl http://localhost:8088/api/v1/templates?user_id=user123
```

---

#### `GET /api/v1/templates/{template_id}`

**Description**: Get specific template details with full configuration.

**Authentication**: None

**Path Parameters**:
- `template_id` (int): Template ID

**Bybit API Calls**: None

**Database Tables**:
- READ: `smarttrade_templates`

**Response**: `200 OK`
```json
{
  "id": 1,
  "user_id": null,
  "template_name": "BTC Conservative",
  "symbol": "BTCUSDT",
  "config": {
    "symbol": "BTCUSDT",
    "marketType": "usdt_perp",
    "side": "long",
    "entry": {
      "type": "limit",
      "limit_price": 42000.0
    },
    "dca_levels": [
      {"price": 41500.0, "size_pct": 30.0},
      {"price": 41000.0, "size_pct": 20.0}
    ],
    "stop_loss": 40500.0,
    "position_sizing": {
      "mode": "risk_amount",
      "risk_usd": 500.0
    },
    "take_profits": [
      {"price": 43000.0, "size_pct": 50.0},
      {"price": 44000.0, "size_pct": 50.0}
    ]
  },
  "is_default": false,
  "created_at": "Oct 12 2025 10:00:00",
  "updated_at": "Oct 12 2025 10:30:00"
}
```

**Errors**:
- `404 Not Found`: Template does not exist

**Example**:
```bash
curl http://localhost:8088/api/v1/templates/1
```

---

#### `POST /api/v1/templates`

**Description**: Create new trade template.

**Authentication**: None

**Request Body**: `TemplateCreate`
```json
{
  "template_name": "BTC Conservative",
  "symbol": "BTCUSDT",
  "config": {
    "symbol": "BTCUSDT",
    "marketType": "usdt_perp",
    "side": "long",
    "entry": {
      "type": "limit",
      "limit_price": 42000.0
    },
    "dca_levels": [
      {"price": 41500.0, "size_pct": 30.0}
    ],
    "stop_loss": 40500.0,
    "position_sizing": {
      "mode": "risk_amount",
      "risk_usd": 500.0
    },
    "take_profits": [
      {"price": 43000.0, "size_pct": 100.0}
    ]
  },
  "user_id": null,
  "is_default": false
}
```

**Bybit API Calls**: None

**Database Tables**:
- WRITE: `smarttrade_templates` - INSERT template

**Response**: `200 OK` (returns created template with generated `id`)
```json
{
  "id": 3,
  "user_id": null,
  "template_name": "BTC Conservative",
  "symbol": "BTCUSDT",
  "config": {...},
  "is_default": false,
  "created_at": "Oct 12 2025 11:00:00",
  "updated_at": "Oct 12 2025 11:00:00"
}
```

**Example**:
```bash
curl -X POST http://localhost:8088/api/v1/templates \
  -H "Content-Type: application/json" \
  -d '{
    "template_name": "BTC Conservative",
    "symbol": "BTCUSDT",
    "config": {...}
  }'
```

---

#### `PUT /api/v1/templates/{template_id}`

**Description**: Update existing template.

**Authentication**: None

**Path Parameters**:
- `template_id` (int): Template ID

**Request Body**: `TemplateUpdate` (partial update supported)
```json
{
  "template_name": "BTC Very Conservative",
  "config": {
    "stop_loss": 40000.0
  }
}
```

**Bybit API Calls**: None

**Database Tables**:
- WRITE: `smarttrade_templates` - UPDATE template

**Response**: `200 OK` (returns updated template)

**Errors**:
- `404 Not Found`: Template does not exist

**Example**:
```bash
curl -X PUT http://localhost:8088/api/v1/templates/1 \
  -H "Content-Type: application/json" \
  -d '{
    "template_name": "BTC Very Conservative"
  }'
```

---

#### `DELETE /api/v1/templates/{template_id}`

**Description**: Delete trade template.

**Authentication**: None

**Path Parameters**:
- `template_id` (int): Template ID

**Bybit API Calls**: None

**Database Tables**:
- WRITE: `smarttrade_templates` - DELETE template

**Response**: `200 OK`
```json
{
  "message": "Template deleted successfully"
}
```

**Errors**:
- `404 Not Found`: Template does not exist

**Example**:
```bash
curl -X DELETE http://localhost:8088/api/v1/templates/1
```

---

## Database Tables

### Tables Read by API

| Table | Endpoints | Purpose |
|-------|-----------|---------|
| `accounts` | `/api/v1/accounts` (if include_inactive=true) | Account metadata storage |
| `order_leg_live` | `/api/v1/portfolio`, `/api/v1/positions`, `/api/v1/spot` | Stop loss prices for open positions |
| `spot_position_live` | `/api/v1/portfolio`, `/api/v1/spot` | Spot WAEP and opened_at timestamps (primary source) |
| `position_lifecycle_hist` | `/api/v1/positions` | Position open timestamps for futures (fallback) |
| `stop_config` | `/api/v1/stops` | Stop loss configurations (deprecated feature) |
| `trade_intent` | `/api/v1/audit`, `/api/v1/audit/{id}` | Trade intent audit trail |
| `order_leg` | `/api/v1/audit/{id}` | Order leg details for audit |
| `smarttrade_templates` | `/api/v1/templates/*` | Trade template storage |

### Tables Written by API

| Table | Endpoints | Operations | Purpose |
|-------|-----------|------------|---------|
| `stop_config` | `POST /api/v1/stops`, `DELETE /api/v1/stops/{symbol}` | INSERT, UPDATE, DELETE | Stop loss config (deprecated) |
| `trade_intent` | `POST /api/v1/trades/submit`, `POST /api/v1/trades/submit-json` | INSERT | Record trade submission |
| `order_leg` | `POST /api/v1/trades/submit`, `POST /api/v1/trades/submit-json` | INSERT | Record individual order legs |
| `smarttrade_templates` | `POST /api/v1/templates`, `PUT /api/v1/templates/{id}`, `DELETE /api/v1/templates/{id}` | INSERT, UPDATE, DELETE | Template CRUD operations |

### Table Schemas

**`accounts`**:
```sql
CREATE TABLE accounts (
    account_id INT IDENTITY PRIMARY KEY,
    account_name VARCHAR(100) NOT NULL UNIQUE,
    exchange VARCHAR(50) NOT NULL,
    account_type VARCHAR(20),
    is_active CHAR(1) DEFAULT 'Y',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
)
```

**`order_leg_live`**:
```sql
CREATE TABLE order_leg_live (
    order_id VARCHAR(100) PRIMARY KEY,
    account_id INT NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    side VARCHAR(10),
    order_type VARCHAR(20),
    qty NUMERIC(18,8),
    price NUMERIC(18,8),
    stop_loss NUMERIC(18,8),
    leg_class VARCHAR(20),  -- 'entry', 'dca', 'tp', 'stop', 'conditional_tp'
    created_time DATETIME
)
```

**`spot_position_live`**:
```sql
CREATE TABLE spot_position_live (
    account_id INT NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    qty NUMERIC(18,8),
    waep NUMERIC(18,8),       -- Weighted Average Entry Price
    opened_at DATETIME,
    updated_at DATETIME,
    PRIMARY KEY (account_id, symbol)
)
```

**`trade_intent`**:
```sql
CREATE TABLE trade_intent (
    trade_intent_id INT IDENTITY PRIMARY KEY,
    account_id INT NOT NULL,
    symbol VARCHAR(50) NOT NULL,
    side VARCHAR(10) NOT NULL,
    entry_type VARCHAR(20),
    limit_price NUMERIC(18,8),
    stop_loss NUMERIC(18,8),
    desired_risk_usd NUMERIC(18,2),
    computed_qty NUMERIC(18,8),
    status VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
)
```

**`order_leg`**:
```sql
CREATE TABLE order_leg (
    leg_id INT IDENTITY PRIMARY KEY,
    trade_intent_id INT NOT NULL,
    leg_type VARCHAR(20),     -- 'entry', 'dca', 'tp', 'stop'
    order_kind VARCHAR(20),   -- 'market', 'limit'
    price NUMERIC(18,8),
    qty NUMERIC(18,8),
    exchange_order_id VARCHAR(100),
    status VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (trade_intent_id) REFERENCES trade_intent(trade_intent_id)
)
```

**`smarttrade_templates`**:
```sql
CREATE TABLE smarttrade_templates (
    id INT IDENTITY PRIMARY KEY,
    user_id VARCHAR(100),
    template_name VARCHAR(200) NOT NULL,
    symbol VARCHAR(50),
    config TEXT,              -- JSON configuration
    is_default CHAR(1) DEFAULT 'N',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
)
```

---

## Bybit API Calls

### Market Data (Unauthenticated)

| Bybit Endpoint | Parameters | Purpose | Used By |
|----------------|------------|---------|---------|
| `GET /v5/market/tickers` | `category=linear`, `symbol=BTCUSDT` | Health check, latest price | `/health`, `/portfolio`, `/spot` |
| `GET /v5/market/instruments-info` | `category={category}`, `symbol={SYMBOL}` | Symbol metadata (tick size, lot size) | `/trades/preview`, `/portfolio` |
| `GET /v5/market/kline` | `category={category}`, `symbol={SYMBOL}`, `interval={interval}`, `limit=200` | Candlestick data for ATR calculation | `/portfolio` |

**Caching**:
- `instruments-info`: Cached in file for 6 hours (`cache/market_metadata.json`)
- `kline`: Cached in-memory per request (per symbol, per timeframe)

---

### Account & Positions (Authenticated)

| Bybit Endpoint | Parameters | Purpose | Used By |
|----------------|------------|---------|---------|
| `GET /v5/account/wallet-balance` | `accountType=UNIFIED` | Account balance, equity, spot holdings | `/account`, `/portfolio`, `/spot` |
| `GET /v5/position/list` | `category=linear`, `settleCoin=USDT` | Linear USDT perpetual positions | `/portfolio`, `/positions` |
| `GET /v5/position/list` | `category=inverse` | Inverse perpetual positions | `/portfolio`, `/positions` |
| `GET /v5/execution/list` | `category=spot`, `symbol={SYMBOL}`, `limit=100` | Trade execution history (WAEP fallback) | `/portfolio`, `/spot` |

---

### Order Management (Authenticated)

| Bybit Endpoint | Parameters | Purpose | Used By |
|----------------|------------|---------|---------|
| `POST /v5/order/create` | Various (see trade execution) | Place order (market/limit/conditional) | `/trades/submit`, `/trades/submit-json` |
| `POST /v5/position/trading-stop` | `category`, `symbol`, `stopLoss` | Set position stop loss (deprecated) | `POST /stops` |

**Order Types**:
- **Regular Market**: `orderType=Market`, no trigger
- **Regular Limit**: `orderType=Limit`, no trigger
- **Conditional Market**: `orderType=Market`, `triggerPrice`, `orderFilter=StopOrder`
- **Conditional Limit**: `orderType=Limit`, `triggerPrice`, `orderFilter=TpslOrder`

---

### Authentication

**Method**: HMAC SHA256 signature

**Headers**:
```
X-BAPI-API-KEY: {api_key}
X-BAPI-TIMESTAMP: {timestamp_ms}
X-BAPI-RECV-WINDOW: 5000
X-BAPI-SIGN: {signature}
```

**Signature String (GET)**:
```
timestamp + api_key + recv_window + queryString
```

**Signature String (POST)**:
```
timestamp + api_key + recv_window + jsonBody
```

**Signature Calculation**:
```python
import hmac
import hashlib

signature = hmac.new(
    api_secret.encode('utf-8'),
    sign_string.encode('utf-8'),
    hashlib.sha256
).hexdigest()
```

---

## Data Flow

### Portfolio Fetch Flow

```
1. Client Request
   GET /api/v1/portfolio?account=main

2. Account Resolution
   resolve_account("main") → account_id=1

3. Create Bybit Client
   BybitClient(account_name="main")
   → Loads API key/secret from accounts.yml

4. Parallel Bybit API Calls
   ├─ GET /v5/position/list (linear USDT)
   ├─ GET /v5/position/list (inverse)
   ├─ GET /v5/account/wallet-balance (spot balances)
   ├─ GET /v5/market/tickers (spot prices, per coin)
   ├─ GET /v5/account/wallet-balance (total equity)
   └─ GET /v5/market/kline (ATR, per position, per timeframe)

5. Database Queries (Parallel)
   ├─ SELECT FROM order_leg_live WHERE account_id=1
   ├─ SELECT FROM spot_position_live WHERE account_id=1
   └─ SELECT FROM position_lifecycle_hist WHERE account_id=1

6. Data Enrichment
   For each position:
   ├─ Add stop_loss from order_leg_live
   ├─ Add WAEP from spot_position_live (spot only)
   ├─ Calculate ATR metrics (15m, 4h)
   ├─ Add market metadata (tick_size)
   ├─ Add created_at timestamp
   └─ Calculate risk metrics

7. Response Assembly
   ├─ positions: Array of enriched positions
   └─ totals: Aggregated metrics

8. Return JSON Response
```

---

### Trade Submission Flow

```
1. Preview Trade
   POST /api/v1/trades/preview
   {symbol, side, stop_loss, risk_usd, ...}

   ├─ GET live price from Bybit (if market entry)
   ├─ GET instrument metadata (tick size, lot size)
   ├─ Calculate position sizing
   ├─ Generate preview_id
   └─ Cache preview in-memory

2. Return Preview
   {preview_id, legs, take_profit_levels, validations}

3. Client Confirms
   POST /api/v1/trades/submit
   {preview_id}

4. Retrieve Cached Preview
   preview = get_cached_preview(preview_id)

5. Create Trade Intent Record
   INSERT INTO trade_intent (account_id, symbol, side, ...)
   → trade_intent_id

6. Place Orders on Bybit (Sequential)
   For each leg:
   ├─ POST /v5/order/create (Bybit)
   ├─ Get exchange_order_id from response
   └─ INSERT INTO order_leg (trade_intent_id, leg_type, exchange_order_id, ...)

7. Place Stop Loss
   POST /v5/order/create (conditional market order)
   ├─ Linear/Inverse: qty="0", closeOnTrigger=True
   └─ Spot: actual quantity

8. Place Take Profit Orders
   If market entry:
   └─ POST /v5/order/create (regular limit orders)

   If limit entry:
   └─ POST /v5/order/create (conditional limit orders with triggerPrice=entry_price)

9. Return Submission Result
   {trade_intent_id, status, order_legs: [{leg_id, exchange_order_id, status}, ...]}
```

---

## Configuration

### Configuration Files

**`etc/config.yml`**:
```yaml
# Database Configuration
database:
  db_server: "ZR_SYBCENTRAL_SQL"
  db_name: "tradelens"
  db_user: "infologin"
  db_password: "${DB_PASSWORD}"

# Trading Configuration
default_risk_usd: 500.0
trading:
  min_position_value: 1.0

# ATR Settings
atr_settings:
  - timeframe: "15m"
    period: 14
  - timeframe: "4h"
    period: 14

# API Server Configuration
api_host: "0.0.0.0"
api_port: 8088
logging_level: "info"

# Data Lookback Configuration
order_history_lookback_days: 30
journal_lookback_days: 60
```

**Environment Variables**:
- `DB_PASSWORD`: Database password
- `BYBIT_API_KEY`: Bybit API key (per account)
- `BYBIT_API_SECRET`: Bybit API secret (per account)

---

**`etc/accounts.yml`**:
```yaml
# Default account name
default_account: "main"

# Account definitions
accounts:
  # Production account
  - name: "main"
    exchange: "bybit"
    account_type: "real"
    api_key: "${BYBIT_API_KEY}"
    api_secret: "${BYBIT_API_SECRET}"
    base_url: "https://api.bybit.com"

  # Demo account
  - name: "demo"
    exchange: "bybit"
    account_type: "demo"
    api_key: "${BYBIT_DEMO_API_KEY}"
    api_secret: "${BYBIT_DEMO_API_SECRET}"
    base_url: "https://api-demo.bybit.com"

  # Testnet account
  - name: "testnet"
    exchange: "bybit"
    account_type: "testnet"
    api_key: "${BYBIT_TESTNET_API_KEY}"
    api_secret: "${BYBIT_TESTNET_API_SECRET}"
    base_url: "https://api-testnet.bybit.com"
```

**Account Types**:
- `real`: Production trading account
- `demo`: Paper trading account (demo.bybit.com)
- `testnet`: Testnet account (testnet.bybit.com)

---

### Startup Commands

**Setup Environment**:
```bash
cd /app/syb/tradesuite
source ./sourceme.sh
```

**Start API Server**:
```bash
./tradelens/bin/api start
```

**Stop API Server**:
```bash
./tradelens/bin/api stop
```

**Restart API Server**:
```bash
./tradelens/bin/api restart
```

**View API Logs**:
```bash
tail -f /app/syb/tradesuite/tradelens/logs/api.log
```

**Access Swagger UI**:
```
http://localhost:8088/docs
```

---

## Authentication

### Current Implementation

**API Authentication**: None (open API)

**Bybit Authentication**: Per-account API keys stored in `accounts.yml`

---

### Bybit API Authentication

**Method**: HMAC SHA256 signature

**Required Headers**:
```http
X-BAPI-API-KEY: {api_key}
X-BAPI-TIMESTAMP: {timestamp_ms}
X-BAPI-RECV-WINDOW: 5000
X-BAPI-SIGN: {signature}
Content-Type: application/json
```

**Signature Generation**:

For **GET** requests:
```python
timestamp = str(int(time.time() * 1000))
recv_window = "5000"
query_string = "category=linear&symbol=BTCUSDT"

sign_string = timestamp + api_key + recv_window + query_string
signature = hmac.new(
    api_secret.encode('utf-8'),
    sign_string.encode('utf-8'),
    hashlib.sha256
).hexdigest()
```

For **POST** requests:
```python
timestamp = str(int(time.time() * 1000))
recv_window = "5000"
json_body = '{"category":"linear","symbol":"BTCUSDT",...}'

sign_string = timestamp + api_key + recv_window + json_body
signature = hmac.new(
    api_secret.encode('utf-8'),
    sign_string.encode('utf-8'),
    hashlib.sha256
).hexdigest()
```

**Implementation**:
- Handled by `BybitClient` adapter (`lib/tradelens/adapters/bybit_client.py`)
- Signature generated automatically for all authenticated requests

---

## Error Handling

### HTTP Status Codes

| Code | Status | Meaning | Example |
|------|--------|---------|---------|
| 200 | OK | Success | Request completed successfully |
| 400 | Bad Request | Validation error | Invalid request parameters |
| 404 | Not Found | Resource not found | Account/template does not exist |
| 500 | Internal Server Error | Unexpected server error | Unhandled exception |
| 502 | Bad Gateway | External API error | Bybit API error |
| 503 | Service Unavailable | Service not ready | No data fetched yet |

---

### Error Response Format

**Standard Error**:
```json
{
  "detail": "Account 'invalid' not found"
}
```

**Validation Error** (FastAPI):
```json
{
  "detail": [
    {
      "loc": ["body", "symbol"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

**Bybit Error** (wrapped):
```json
{
  "detail": "Bybit API error: Invalid symbol"
}
```

---

### Exception Hierarchy

**Custom Exceptions** (`lib/tradelens/core/exceptions.py`):

```python
ConfigurationError      # Account/config issues
ValidationError         # Input validation failures
SizingError            # Position sizing errors
ExchangeError          # Bybit API errors
DatabaseError          # Database operation failures
```

**Error Handling Pattern**:
```python
try:
    # API logic
except ValidationError as e:
    raise HTTPException(status_code=400, detail=str(e))
except ExchangeError as e:
    raise HTTPException(status_code=502, detail=str(e))
except Exception as e:
    logger.error(f"Unexpected error: {e}")
    raise HTTPException(status_code=500, detail="Internal server error")
```

---

## Caching & Optimization

### In-Memory Caches

**1. Trade Preview Cache**:
- **Key**: `preview_id` (e.g., "px_a1b2c3d4e5f6")
- **TTL**: Session-based (until server restart)
- **Contents**: Full trade preview data
- **Purpose**: Enable submission without re-calculating

**2. ATR Cache**:
- **Key**: `(symbol, timeframe)` (e.g., ("BTCUSDT", "15m"))
- **TTL**: Per-request (cleared between portfolio requests)
- **Contents**: ATR values
- **Purpose**: Avoid duplicate kline API calls within single request

**3. Data Status Cache**:
- **Type**: Global singleton
- **Contents**: Last Bybit fetch timestamp, staleness level
- **Update**: On each portfolio fetch
- **Used By**: `/api/v1/status/data`

---

### File Caches

**1. Market Metadata Cache**:
- **File**: `cache/market_metadata.json`
- **Source**: `GET /v5/market/instruments-info`
- **TTL**: 6 hours
- **Contents**: Tick size, lot size, price filters for all symbols
- **Purpose**: Avoid repeated instrument info API calls

**Cache Structure**:
```json
{
  "timestamp": "2025-10-12T10:00:00Z",
  "metadata": {
    "BTCUSDT": {
      "tick_size": "0.1",
      "lot_size": "0.001",
      "min_order_qty": "0.001"
    },
    "ETHUSDT": {
      "tick_size": "0.01",
      "lot_size": "0.001",
      "min_order_qty": "0.001"
    }
  }
}
```

---

### Database Query Optimization

**1. Indexed Lookups**:
```sql
-- order_leg_live indexed on (account_id, symbol)
SELECT * FROM order_leg_live
WHERE account_id = 1 AND symbol = 'BTCUSDT'

-- spot_position_live primary key on (account_id, symbol)
SELECT * FROM spot_position_live
WHERE account_id = 1 AND symbol = 'ATOMUSDT'
```

**2. Batch Queries**:
```sql
-- Fetch all stop losses in single query
SELECT symbol, stop_loss FROM order_leg_live
WHERE account_id = 1 AND leg_class = 'stop'
```

**3. Parameterized Queries**:
```sql
-- Parameterized queries with psycopg2
INSERT INTO trade_intent (..., config_json, ...)
VALUES (..., %s, ...)
```

---

## Multi-Account Support

### Account Context Architecture

**AccountContext Singleton** (`lib/tradelens/core/account_context.py`):
- Loads `accounts.yml` at startup
- Maps account names → account_id (from database)
- Provides account lookup and resolution
- Expands environment variables in credentials

---

### Account Resolution Flow

```
1. Request with Query Parameter
   GET /api/v1/portfolio?account=demo

2. Resolve Account Name
   resolve_account("demo")
   ├─ If account specified: use specified account
   └─ If not specified: use default_account from config

3. Get Account ID
   AccountContext.get_account("demo")
   ├─ SELECT account_id FROM accounts WHERE account_name='demo'
   └─ Returns: ("demo", account_id=2)

4. Create Bybit Client
   BybitClient(account_name="demo")
   ├─ Load API key/secret from accounts.yml
   ├─ base_url = "https://api-demo.bybit.com"
   └─ Initialize authenticated client

5. Query Database with Account ID
   SELECT * FROM order_leg_live WHERE account_id = 2
   SELECT * FROM spot_position_live WHERE account_id = 2

6. Fetch Bybit Data
   All Bybit API calls use demo account credentials

7. Return Response
   Combined data for account_id=2 (demo account)
```

---

### Account Synchronization

**Sync Script**: `bin/setup/sync_accounts.py`

**Purpose**: Sync `accounts.yml` → `accounts` database table

**Behavior**:
- Inserts new accounts from YAML
- Marks accounts not in YAML as inactive (`is_active='N'`)
- Preserves historical data (soft delete)
- Maintains referential integrity (account_id stable)

**Usage**:
```bash
source /app/syb/tradesuite/sourceme.sh
./tradelens/bin/setup/sync_accounts.py
```

---

### Multi-Account Query Patterns

**Filter by Account ID**:
```sql
SELECT * FROM order_leg_live
WHERE account_id = ?
```

**Account Context in Responses**:
```json
{
  "account_name": "demo",
  "account_id": 2,
  "positions": [...]
}
```

---

## Design Patterns

### 1. Database Pattern: Parameterized Queries with psycopg2

**Pattern**: Parameterized queries with psycopg2 for all database operations.

**Implementation**:
```python
cursor.execute("""
    INSERT INTO table_name (text_column)
    VALUES (%s)
""", (large_text,))
```

**Used In**:
- `trade_intent.config_json` (TEXT field)
- `smarttrade_templates.config` (TEXT field)

---

### 2. Service Layer Pattern

**Pattern**: Encapsulate business logic in service modules separate from API routes.

**Structure**:
```
lib/tradelens/
├── api/                  # Route handlers (thin)
│   ├── portfolio.py      # → calls services
│   ├── positions.py
│   └── trades.py
└── services/             # Business logic (thick)
    ├── portfolio.py      # Portfolio aggregation
    ├── sizing.py         # Position sizing
    ├── audit.py          # Trade tracking
    └── stops.py          # Stop loss management
```

**Example**:
```python
# api/portfolio.py (route handler)
@router.get("/portfolio")
def get_portfolio(account: str = None):
    account_name, account_id = resolve_account(account)
    bybit = BybitClient(account_name=account_name)
    return get_combined_portfolio(bybit, conn, account_id)

# services/portfolio.py (business logic)
def get_combined_portfolio(bybit, conn, account_id):
    # Complex logic: fetch positions, enrich data, calculate metrics
    ...
```

---

### 3. Adapter Pattern

**Pattern**: Abstract external API (Bybit) behind a clean interface.

**Implementation** (`lib/tradelens/adapters/bybit_client.py`):
```python
class BybitClient:
    def __init__(self, account_name: str):
        # Load credentials from accounts.yml
        self.api_key = ...
        self.api_secret = ...
        self.base_url = ...

    def get_positions(self, category: str):
        # Handle authentication, signature, request/response
        ...

    def place_order(self, params: dict):
        # Handle order creation with proper error handling
        ...
```

**Benefits**:
- Isolates Bybit API details
- Simplifies testing (mock adapter)
- Centralizes authentication logic

---

### 4. Factory Pattern

**Pattern**: Create application instance with configurable components.

**Implementation** (`lib/tradelens/main.py`):
```python
def create_app() -> FastAPI:
    app = FastAPI(title="TradeLens API", version="0.1.0")

    # Add middleware
    app.add_middleware(CORSMiddleware, ...)

    # Register routers
    app.include_router(health.router, prefix="/api/v1", tags=["health"])
    app.include_router(accounts.router, prefix="/api/v1", tags=["accounts"])
    app.include_router(portfolio.router, prefix="/api/v1", tags=["portfolio"])
    # ...

    return app

app = create_app()
```

---

### 5. Repository Pattern (Partial)

**Pattern**: Abstract database operations behind query functions.

**Implementation**:
```python
# services/stops.py
def get_stop_configs(conn, symbol: str = None):
    """Fetch stop configs from database"""
    cursor = conn.cursor()
    if symbol:
        cursor.execute(f"SELECT * FROM stop_config WHERE symbol = '{symbol.lower()}'")
    else:
        cursor.execute("SELECT * FROM stop_config")
    return cursor.fetchall()
```

---

## Important Notes

### Position Sizing Modes

**1. Risk Amount** (`risk_amount`) - Original:
- User specifies: `risk_usd` (e.g., $500)
- System calculates: `qty = risk_usd / risk_per_unit`
- Use case: "I want to risk $500 on this trade"

**2. USD Value** (`usd_value`):
- User specifies: `position_usd` (e.g., $21,000)
- System calculates: `qty = position_usd / entry_price`
- Use case: "I want a $21,000 position"

**3. Quantity** (`quantity`):
- User specifies: `position_qty` (e.g., 0.5 BTC)
- System uses: exact quantity
- Use case: "I want to buy exactly 0.5 BTC"

---

### Stop Loss Implementation

**Current Implementation**: Conditional market orders via `/v5/order/create`

**Linear/Inverse Futures**:
```json
{
  "category": "linear",
  "symbol": "BTCUSDT",
  "side": "Sell",
  "orderType": "Market",
  "qty": "0",
  "triggerPrice": "41000.0",
  "triggerDirection": 2,
  "orderFilter": "StopOrder",
  "positionIdx": 1,
  "reduceOnly": true,
  "closeOnTrigger": true
}
```
- `qty="0"` + `closeOnTrigger=True` closes entire position
- Works for any position size

**Spot**:
```json
{
  "category": "spot",
  "symbol": "BTCUSDT",
  "side": "Sell",
  "orderType": "Market",
  "qty": "0.5",
  "triggerPrice": "41000.0",
  "triggerDirection": 2,
  "orderFilter": "StopOrder"
}
```
- Must specify actual quantity (Bybit rejects qty="0" for spot)

**Deprecated**: `POST /stops` with `/v5/position/trading-stop` (only works for futures)

---

### Take Profit Order Logic

**Market Entries**:
- Place **regular TP limit orders** immediately after entry
- TPs active instantly
- Example: Entry at market → TP orders at 43000, 44000

**Limit Entries/DCAs**:
- Place **conditional TP limit orders** with `triggerPrice = entry_price`
- TPs activate only when entry fills
- Prevents TPs from executing before position opens
- Example: Entry limit @ 42000 → TP triggers when 42000 fills

**Implementation**:
```python
if entry_type == "market":
    # Regular TP orders
    place_tp_order(symbol, tp_price, qty)
else:
    # Conditional TP orders
    place_conditional_tp_order(
        symbol=symbol,
        tp_price=tp_price,
        trigger_price=entry_price,  # Trigger when entry fills
        qty=qty
    )
```

---

### WAEP Calculation Priority

**Spot Positions**:

1. **Primary Source**: `spot_position_live.waep` (database cache)
   - Populated by `bin/pipeline/refresh_spot_positions.py`
   - Accurate, fast, updated periodically

2. **Fallback**: Calculate from execution history
   - `GET /v5/execution/list` (last 100 fills)
   - Expensive API call, slower
   - Used when cache is missing/stale

**Implementation**:
```python
def calculate_spot_waep(symbol, bybit, conn, account_id):
    # Try cache first
    cursor.execute(f"SELECT waep FROM spot_position_live WHERE symbol='{symbol}' AND account_id={account_id}")
    row = cursor.fetchone()
    if row:
        return Decimal(str(row[0]))

    # Fallback to API calculation
    fills = bybit.get_execution_list(category="spot", symbol=symbol, limit=100)
    # ... calculate WAEP from fills ...
```

---

### Position Timestamp Priority

**Futures**:
1. **Primary**: Bybit's `createdTime` from position API
2. **Fallback**: Query `position_lifecycle_hist` table

**Spot**:
1. **Primary**: `spot_position_live.opened_at` (database)
2. **No Bybit fallback** (spot positions don't have `createdTime`)

---

### ATR Calculation

**Timeframes**: Configurable in `config.yml` (default: 15m, 4h)

**Process**:
1. Fetch 200 candles via `GET /v5/market/kline`
2. Calculate True Range per candle: `max(high-low, abs(high-prev_close), abs(low-prev_close))`
3. Calculate ATR: Simple Moving Average of True Range over 14 periods (configurable)
4. Cache in-memory per `(symbol, timeframe)`

**Usage**:
- `stop_distance_xatr_15m`: Stop distance in multiples of 15m ATR
- `stop_distance_xatr_4h`: Stop distance in multiples of 4h ATR
- Risk assessment: "Is my stop 2x or 5x the average volatility?"

---

### Hedge Mode vs. One-Way Mode

**TradeLens Default**: Hedge mode (dual-side positions)

**Futures Orders**:
- `positionIdx=1`: Long side
- `positionIdx=2`: Short side
- Allows simultaneous long and short positions on same symbol

**Bybit Account Setting**:
- Must enable "Hedge Mode" in Bybit account settings
- API will reject orders with `positionIdx` if one-way mode active

---

### Preview Cache Lifetime

**Lifetime**: Session-based (until server restart)

**Implications**:
- Server restart clears all previews
- Clients must re-preview after server restarts
- `404 Not Found` error if preview expired

**Future Enhancement**: TTL-based cache with automatic cleanup

---

### Order Submission Error Handling

**Partial Success**:
- If some orders succeed and some fail, status = `"partial"`
- Successfully placed orders remain on exchange
- Client can retry failed legs or cancel successful ones

**Full Failure**:
- If all orders fail, status = `"error"`
- No orders on exchange
- Client can retry entire submission

**Trade Intent Records**:
- Created even if orders fail (audit trail)
- `order_leg` records show per-leg status

---

### Database Connection Management

**Pattern**: Connection passed to service functions (no connection pooling)

**Shared Database**: Same database (`tradelens`) used by pipeline scripts

**Connection Setup**:
```python
import psycopg2
conn = psycopg2.connect(
    host=db_host,
    port=db_port,
    dbname=db_name,
    user=db_user,
    password=db_password
)
conn.autocommit = True
cursor = conn.cursor()
cursor.execute("SET timezone TO 'UTC'")
```

---

## Appendix: Quick Reference

### Common Operations

**Check API Health**:
```bash
curl http://localhost:8088/api/v1/health
```

**Get Portfolio**:
```bash
curl http://localhost:8088/api/v1/portfolio?account=main
```

**Preview Trade**:
```bash
curl -X POST http://localhost:8088/api/v1/trades/preview \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTCUSDT",
    "side": "long",
    "entry_type": "limit",
    "limit_price": 42000.0,
    "stop_loss": 41000.0,
    "sizing_mode": "risk_amount",
    "risk_usd": 500.0
  }'
```

**Submit Trade**:
```bash
curl -X POST http://localhost:8088/api/v1/trades/submit \
  -H "Content-Type: application/json" \
  -d '{"preview_id": "px_a1b2c3d4e5f6"}'
```

---

### Swagger UI Navigation

**URL**: `http://localhost:8088/docs`

**Sections**:
- **health**: System health checks
- **accounts**: Account management
- **account**: Account balance queries
- **portfolio**: Portfolio and position endpoints
- **positions**: Futures positions only
- **spot**: Spot holdings only
- **stops**: Stop loss configuration (deprecated)
- **trades**: Trade execution and preview
- **templates**: SmartTrade templates
- **status**: Data freshness status

---

### Environment Variables Quick Reference

```bash
# Required
export DB_PASSWORD="your_db_password"
export BYBIT_API_KEY="your_api_key"
export BYBIT_API_SECRET="your_api_secret"

# Optional (multi-account)
export BYBIT_DEMO_API_KEY="demo_key"
export BYBIT_DEMO_API_SECRET="demo_secret"
export BYBIT_TESTNET_API_KEY="testnet_key"
export BYBIT_TESTNET_API_SECRET="testnet_secret"

# System (set by sourceme.sh)
export TSHOME=/app/syb/tradesuite
export TLHOME=$TSHOME/tradelens
```

---

### Key Files Quick Reference

| File | Purpose |
|------|---------|
| `lib/tradelens/main.py` | FastAPI application entry point |
| `lib/tradelens/api/portfolio.py` | Portfolio endpoints |
| `lib/tradelens/api/trades.py` | Trade execution endpoints |
| `lib/tradelens/services/portfolio.py` | Portfolio business logic |
| `lib/tradelens/adapters/bybit_client.py` | Bybit API client |
| `lib/tradelens/core/account_context.py` | Multi-account management |
| `etc/config.yml` | Main configuration |
| `etc/accounts.yml` | Account definitions |
| `bin/server/start_api.sh` | Start API server |
| `logs/api.log` | API server logs |

---

**Last Updated**: 2025-11-14
**Maintained By**: Development Team
**API Version**: 0.1.0
