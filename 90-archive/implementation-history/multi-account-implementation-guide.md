# Multi-Account Implementation - Completion Guide

## ✅ COMPLETED (42% - 14/33 tasks)

### Core Infrastructure
- ✅ Database schema (migration + setup_database.py)
- ✅ Configuration (accounts.yml + example)
- ✅ Models (account.py with Pydantic models)
- ✅ AccountContext (singleton manager)
- ✅ BybitClient (updated to require account_name)
- ✅ Config.py (cleaned up)
- ✅ API helper (common.py with resolve_account())
- ✅ Accounts API router (registered in main.py)

### API Routes Updated
- ✅ /api/v1/accounts (list, get, default)
- ✅ /api/v1/account
- ✅ /api/v1/portfolio
- ✅ /api/v1/positions
- ✅ /api/v1/spot

---

## 📋 REMAINING WORK (58% - 19/33 tasks)

### Phase 1: Complete Remaining API Routes (4 routes)

#### Pattern to Follow:
```python
from typing import Optional
from fastapi import Query
from tradelens.api.common import resolve_account

@router.get("/endpoint")
async def handler(account: Optional[str] = Query(None, description="Account name (uses default if not specified)")):
    # Step 1: Resolve account
    account_name, account_id = resolve_account(account)

    # Step 2: Create Bybit client with account
    bybit = BybitClient(account_name=account_name)

    # Step 3: Pass account_id to database queries/services
    result = some_service(conn, account_id)  # Add account_id parameter

    return result
```

---

#### 1.1 Update `/lib/tradelens/api/stops.py`

**3 endpoints to update:**

```python
# Add imports
from tradelens.api.common import resolve_account

# Update @router.get("/stops")
async def list_stops(
    symbol: Optional[str] = Query(None),
    account: Optional[str] = Query(None, description="Account name")
):
    account_name, account_id = resolve_account(account)
    # Pass account_id to get_stop_config
    stops = get_stop_config(conn, symbol, account_id)

# Update @router.post("/stops")
async def create_or_update_stop(
    request: StopConfigRequest,
    account: Optional[str] = Query(None)
):
    account_name, account_id = resolve_account(account)
    bybit = BybitClient(account_name=account_name)
    # Pass account_id to set_stop_config
    result = set_stop_config(conn, request.symbol, request.stop_loss, bybit, account_id)

# Update @router.delete("/stops/{symbol}")
async def remove_stop(
    symbol: str,
    account: Optional[str] = Query(None)
):
    account_name, account_id = resolve_account(account)
    # Pass account_id to delete_stop_config
    deleted = delete_stop_config(conn, symbol, account_id)
```

---

#### 1.2 Update `/lib/tradelens/api/templates.py`

**Pattern:** Add account parameter to all template endpoints, pass account_id to database queries.

```python
from tradelens.api.common import resolve_account

# Update all endpoints (get, create, update, delete templates)
# Add: account: Optional[str] = Query(None)
# Add: account_name, account_id = resolve_account(account)
# Pass account_id to all database queries in WHERE clauses
```

---

#### 1.3 Update `/lib/tradelens/api/status.py`

**Pattern:** Add account parameter, filter data freshness queries by account_id.

```python
from tradelens.api.common import resolve_account

@router.get("/status")
async def get_data_status(account: Optional[str] = Query(None)):
    account_name, account_id = resolve_account(account)
    # Query order_leg_live, order_leg_hist, spot_position_live with account_id filter
    # Example: SELECT MAX(updated_at) FROM order_leg_live WHERE account_id = {account_id}
```

---

#### 1.4 Update `/lib/tradelens/api/trades.py` (COMPLEX - 6 endpoints)

**Endpoints:**
- `/trades/preview` - Add account to request model, resolve in handler
- `/trades/submit` - Add account to request model, pass to audit functions
- `/trades/preview-bybit-orders` - Add account parameter
- `/trades/submit-json` - Add account parameter
- `/audit` - List trade intents for account
- `/audit/{trade_intent_id}` - Get specific trade intent

**Key Changes:**
```python
from tradelens.api.common import resolve_account

# For all endpoints:
# 1. Add account parameter (or to request models if POST)
# 2. Resolve account_name, account_id
# 3. Pass account_name to BybitClient
# 4. Pass account_id to all audit service calls (create_trade_intent, etc.)

# Example for preview:
@router.post("/trades/preview")
async def preview_trade(
    request: TradePreviewRequest,
    account: Optional[str] = Query(None)
):
    account_name, account_id = resolve_account(account)
    bybit = BybitClient(account_name=account_name)
    # ... rest of logic
    # When creating trade_intent: create_trade_intent(..., account_id=account_id)
```

---

### Phase 2: Update Services Layer (2 files)

#### 2.1 Update `/lib/tradelens/services/portfolio.py`

**Functions to update (add `account_id` parameter):**

```python
def get_futures_positions(bybit: BybitClient, conn, account_id: int) -> List[Dict]:
    # Add WHERE account_id = {account_id} to all queries
    cursor.execute(f"""
        SELECT ...
        FROM order_leg_live
        WHERE account_id = {account_id} AND status = 'StopOrder'
    """)

def get_spot_positions(bybit: BybitClient, conn, account_id: int) -> List[Dict]:
    # Filter spot_position_live by account_id
    cursor.execute(f"""
        SELECT ...
        FROM spot_position_live
        WHERE account_id = {account_id}
    """)

def get_combined_portfolio(bybit: BybitClient, conn, account_id: int) -> Dict:
    futures = get_futures_positions(bybit, conn, account_id)
    spot = get_spot_positions(bybit, conn, account_id)
    # ... combine

def track_position_lifecycle(conn, positions: List[Dict], account_id: int) -> List[Dict]:
    # Filter position_tracking queries by account_id
```

#### 2.2 Update `/lib/tradelens/services/stops.py`

**Functions to update:**

```python
def get_stop_config(conn, symbol: Optional[str] = None, account_id: int = 1) -> List[Dict]:
    # Add account_id filter
    sql = f"SELECT ... FROM risk_config WHERE account_id = {account_id}"
    if symbol:
        sql += f" AND symbol = '{symbol.upper()}'"

def set_stop_config(conn, symbol: str, stop_loss: float, bybit=None, account_id: int = 1) -> Dict:
    # INSERT/UPDATE with account_id
    sql = f"""
        INSERT INTO risk_config (account_id, symbol, ...)
        VALUES ({account_id}, '{symbol}', ...)
    """

def delete_stop_config(conn, symbol: str, account_id: int = 1) -> bool:
    # DELETE with account_id filter
    sql = f"DELETE FROM risk_config WHERE account_id = {account_id} AND symbol = '{symbol}'"
```

---

### Phase 3: Update ETL Scripts (4 scripts)

**Pattern for all scripts:**

```python
#!/usr/bin/env python3
import argparse
from tradelens.core.account_context import get_account_context

# Add argument parser
parser = argparse.ArgumentParser(description="Refresh data for specific account")
parser.add_argument('--account', required=True, help='Account name from accounts.yml')
args = parser.parse_args()

# Resolve account
account_ctx = get_account_context()
account_id = account_ctx.get_account_id(args.account)

# Initialize Bybit client for this account
bybit = BybitClient(account_name=args.account)

# Insert/update with account_id
cursor.execute(f"""
    INSERT INTO table_name (account_id, ...)
    VALUES ({account_id}, ...)
""")
```

#### 3.1 `/bin/refresh_order_leg_live.py`
- Add --account argument (required)
- Resolve account_id
- Pass account_name to BybitClient
- INSERT with account_id

#### 3.2 `/bin/refresh_order_leg_hist.py`
- Same pattern as above

#### 3.3 `/bin/refresh_spot_positions.py`
- Same pattern as above

#### 3.4 `/bin/refresh_trade_journal.py`
- Same pattern as above
- Filter queries by account_id when reading order_leg_hist

---

### Phase 4: Create Helper Script

#### 4.1 `/bin/refresh_all_accounts.sh`

```bash
#!/bin/bash
# Refresh data for all configured accounts

set -e  # Exit on error

# Source environment
source /app/syb/tradesuite/sourceme.sh

# Get list of all active accounts from accounts.yml
ACCOUNTS=$(python3 -c "
from tradelens.core.account_context import get_account_context
ctx = get_account_context()
print(' '.join(ctx.list_account_names()))
")

echo "Refreshing data for accounts: $ACCOUNTS"

for account in $ACCOUNTS; do
    echo "========================================"
    echo "Refreshing account: $account"
    echo "========================================"

    $TLHOME/bin/refresh_order_leg_live.py --account "$account" || echo "⚠️  Failed: order_leg_live"
    $TLHOME/bin/refresh_order_leg_hist.py --account "$account" || echo "⚠️  Failed: order_leg_hist"
    $TLHOME/bin/refresh_spot_positions.py --account "$account" || echo "⚠️  Failed: spot_positions"
    $TLHOME/bin/refresh_trade_journal.py --account "$account" || echo "⚠️  Failed: trade_journal"

    echo "✓ Completed: $account"
done

echo ""
echo "=========================================="
echo "All accounts refreshed successfully!"
echo "=========================================="
```

```bash
chmod +x /app/syb/tradesuite/tradelens/bin/refresh_all_accounts.sh
```

---

### Phase 5: Frontend Updates

#### 5.1 `/frontend/web/src/lib/api.ts`

```typescript
// Add account parameter helpers
const getCurrentAccount = (): string | null => {
  return localStorage.getItem('selectedAccount');
};

const addAccountParam = (params: Record<string, any> = {}): Record<string, any> => {
  const account = getCurrentAccount();
  if (account) {
    params.account = account;
  }
  return params;
};

// Update all API calls
export const getPortfolio = async () => {
  const params = addAccountParam();
  return axios.get(`${API_BASE}/portfolio`, { params });
};

export const getPositions = async () => {
  const params = addAccountParam();
  return axios.get(`${API_BASE}/positions`, { params });
};

export const getSpot = async () => {
  const params = addAccountParam();
  return axios.get(`${API_BASE}/spot`, { params });
};

// Add account setter
export const setCurrentAccount = (account: string) => {
  localStorage.setItem('selectedAccount', account);
  window.dispatchEvent(new CustomEvent('accountChanged', { detail: account }));
};

// Add account list fetch
export const getAccounts = async () => {
  return axios.get(`${API_BASE}/accounts`);
};
```

---

#### 5.2 Create `/frontend/web/src/components/AccountSelector.tsx`

```tsx
import React, { useState, useEffect } from 'react';
import { getAccounts, setCurrentAccount } from '../lib/api';

interface Account {
  name: string;
  account_type: string;
  subaccount_ref: string | null;
  display_name: string;
  is_demo: boolean;
  is_testnet: boolean;
}

export const AccountSelector: React.FC = () => {
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [selected, setSelected] = useState<string>('');
  const [defaultAccount, setDefaultAccount] = useState<string>('');

  useEffect(() => {
    // Load accounts from API
    getAccounts().then((response) => {
      setAccounts(response.data.accounts);
      setDefaultAccount(response.data.default_account);

      // Check localStorage or use default
      const stored = localStorage.getItem('selectedAccount');
      const initial = stored || response.data.default_account;
      setSelected(initial);
      setCurrentAccount(initial);
    });
  }, []);

  const handleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const account = e.target.value;
    setSelected(account);
    setCurrentAccount(account);
  };

  const getBadge = (account: Account) => {
    if (account.is_demo) return <span className="ml-2 px-2 py-0.5 text-xs bg-yellow-100 text-yellow-800 rounded">DEMO</span>;
    if (account.is_testnet) return <span className="ml-2 px-2 py-0.5 text-xs bg-gray-100 text-gray-800 rounded">TEST</span>;
    return null;
  };

  return (
    <div className="flex items-center space-x-2">
      <label className="text-sm font-medium text-gray-700">Account:</label>
      <select
        value={selected}
        onChange={handleChange}
        className="px-3 py-1.5 border border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500"
      >
        {accounts.map((account) => (
          <option key={account.name} value={account.name}>
            {account.display_name}
            {account.is_demo ? ' [DEMO]' : ''}
            {account.is_testnet ? ' [TEST]' : ''}
          </option>
        ))}
      </select>
      {selected && accounts.find(a => a.name === selected) && (
        <div>{getBadge(accounts.find(a => a.name === selected)!)}</div>
      )}
    </div>
  );
};
```

---

#### 5.3 Update `/frontend/web/src/pages/dashboard.tsx`

```tsx
import { AccountSelector } from '../components/AccountSelector';
import { useEffect } from 'react';

// Add at top of component
useEffect(() => {
  const handleAccountChange = () => {
    // Reload portfolio data
    fetchPortfolio();
  };

  window.addEventListener('accountChanged', handleAccountChange);
  return () => window.removeEventListener('accountChanged', handleAccountChange);
}, []);

// In JSX, add AccountSelector to header
<div className="header">
  <h1>TradeLens Dashboard</h1>
  <AccountSelector />
</div>
```

---

#### 5.4 Update `/frontend/web/src/pages/smart-trade.tsx`

```tsx
// Same pattern as dashboard - add AccountSelector to header
import { AccountSelector } from '../components/AccountSelector';

// Add account change listener to reload data
useEffect(() => {
  const handleAccountChange = () => {
    // Clear preview, reset form state
  };
  window.addEventListener('accountChanged', handleAccountChange);
  return () => window.removeEventListener('accountChanged', handleAccountChange);
}, []);
```

---

#### 5.5 Update `/frontend/web/src/pages/audit.tsx`

```tsx
// Same pattern - add AccountSelector and reload trades on account change
import { AccountSelector } from '../components/AccountSelector';

useEffect(() => {
  const handleAccountChange = () => {
    loadTradeIntents();
  };
  window.addEventListener('accountChanged', handleAccountChange);
  return () => window.removeEventListener('accountChanged', handleAccountChange);
}, []);
```

---

## 🧪 Testing Checklist

### Database Migration
```bash
# 1. Run migration
psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens -f /app/syb/tradesuite/tradelens/migrations/007_multi_account_support.sql

# 2. Verify accounts table
psql -h 127.0.0.1 -p 5432 -U tradelens -d tradelens
SELECT * FROM accounts;

# 3. Verify account_id columns
\d order_leg_live
```

### Backend API
```bash
# 1. Set environment variables
export BYBIT_MAIN_KEY="your_key"
export BYBIT_MAIN_SECRET="your_secret"

# 2. Sync accounts to database
cd /app/syb/tradesuite/tradelens
source /app/syb/tradesuite/sourceme.sh
python3 -c "
from tradelens.core.account_context import get_account_context
from tradelens.core.pg_db import PostgresDB
from tradelens.core.config import config
from tradelens.core.logging import get_logger

logger = get_logger(__name__)
ctx = get_account_context()
db = PostgresDB(config.database, logger)
conn = db.connect()
ctx.sync_to_database(db)
db.close()
print('Accounts synced successfully!')
"

# 3. Restart API
./bin/start_api.sh

# 4. Test endpoints
curl http://localhost:8088/api/v1/accounts
curl http://localhost:8088/api/v1/portfolio?account=main
curl http://localhost:8088/api/v1/positions?account=main
```

### ETL Scripts
```bash
# Test individual script
./bin/refresh_order_leg_live.py --account main

# Test all accounts
./bin/refresh_all_accounts.sh
```

### Frontend
```bash
# 1. Build frontend
cd frontend/web
npm run build

# 2. Test in browser
# - Open http://localhost:8088
# - Check AccountSelector appears
# - Switch accounts and verify data reloads
# - Check localStorage for selectedAccount
```

---

## 📝 Summary

**Completion Status: 42%**

**To reach 100%, complete:**
1. ✅ 4 remaining API routes (stops, templates, status, trades) - **1-2 hours**
2. ✅ 2 service files (portfolio.py, stops.py) - **30 mins**
3. ✅ 4 ETL scripts + helper - **1 hour**
4. ✅ Frontend (api.ts + component + 3 pages) - **1 hour**
5. ✅ Testing - **1 hour**

**Total estimated time: 4-5 hours**

All patterns are established. Follow this guide step-by-step to complete the implementation.
