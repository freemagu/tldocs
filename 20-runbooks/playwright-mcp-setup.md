# Playwright MCP Setup for Claude Code

Browser automation for inspecting and testing the TradeLens web UI from the VM.

## What Was Installed

| Component | Version | Location |
|-----------|---------|----------|
| `@playwright/mcp` | 0.0.68 | `node_modules/@playwright/mcp/` |
| `playwright` | 1.58.2 | `node_modules/playwright/` |
| Chromium (headless) | 146.0.7680.0 + 145.0.7632.6 | `~/.cache/ms-playwright/` |

Installed as devDependencies in `package.json`. No global installs.

## Configuration

**MCP config**: `/app/syb/tradesuite/tradelens/.mcp.json`

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--headless"]
    }
  }
}
```

Claude Code picks this up automatically when working in the tradelens directory.

## Dashboard URL

From the VM: **http://127.0.0.1:3000/**

- Dashboard (Vite/React): port 3000
- API (FastAPI): port 8088

## Usage

### From Claude Code

Just ask Claude to use the Playwright MCP tools. Examples:

- "Navigate to http://127.0.0.1:3000/ and take a screenshot"
- "Click on the Journal tab and show me what's there"
- "Check if the portfolio page loads without errors"

Claude Code will have access to tools like `browser_navigate`, `browser_take_screenshot`,
`browser_snapshot`, `browser_click`, etc.

### Standalone Smoke Test

```bash
cd /app/syb/tradesuite/tradelens
node artifacts/smoke_test.js
```

This navigates to the dashboard, takes a screenshot to `artifacts/dashboard_smoke_test.png`,
and reports any console/network errors.

### Reinstall Browsers (if needed)

```bash
cd /app/syb/tradesuite/tradelens
npx playwright install chromium
```

## Notes

- Rocky Linux 8 is not officially supported by Playwright but works with the Ubuntu fallback build
- Google Fonts (fonts.googleapis.com) may be slow/unreachable from the VM — the smoke test blocks them
- The `--headless` flag in `.mcp.json` is required since the VM has no display server
- `node_modules/` and `package-lock.json` are in `.gitignore`
