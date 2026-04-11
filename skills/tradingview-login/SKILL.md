---
name: tradingview-login
version: "4.1.0"
description: TradingView browser management and login. Browser runs as systemd service. Use check-login.sh to check status. If NOT_LOGGED_IN, offer login via Playwright.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔑",
        "requires": { "bins": ["python3", "node"] },
      },
  }
---

# TradingView Browser & Login

## IMPORTANT: Browser is a System Service

TradingView Chromium runs as a systemd service — it starts on boot and auto-restarts if closed.
**Do NOT run chromium commands directly. The browser is already running.**

## Workflow

### 1. Check Connection Status

```bash
bash ~/tradingview-mcp/check-login.sh
```

| Result | Next Step |
|--------|-----------|
| `LOGGED_IN` + `CDP_PORT:xxx` | Ready to work. Use that port. |
| `NOT_LOGGED_IN` + `CDP_PORT:xxx` | Ask user if they want to login. |
| `NO_BROWSER` | Run `systemctl --user start tradingview-chromium.service`, wait 8s, retry. |
| `CHECK_FAILED` | First-time setup needed (see Step 3). |

### 2. Login (if user wants to)

**A. Ask for credentials:**
> Credentials are only used locally for login. They are never saved, logged, or transmitted.

**B. Execute login** (replace EMAIL, PASSWORD, PORT):
```bash
python3 -c "
import asyncio
from playwright.async_api import async_playwright
async def login():
    async with async_playwright() as p:
        browser = await p.chromium.connect_over_cdp('http://localhost:PORT')
        ctx = browser.contexts[0]
        page = await ctx.new_page()
        await page.goto('https://tw.tradingview.com/#signin', wait_until='networkidle', timeout=30000)
        await asyncio.sleep(3)
        try:
            btn = page.locator('button:has-text(\"Email\"), button:has-text(\"電子郵件\")').first
            await btn.click(timeout=5000)
            await asyncio.sleep(1)
        except: pass
        email_input = page.locator('input[name=\"id_username\"], input[type=\"email\"]').first
        await email_input.wait_for(state='visible', timeout=10000)
        await email_input.fill('EMAIL')
        pw = page.locator('input[type=\"password\"]').first
        await pw.wait_for(state='visible', timeout=5000)
        await pw.fill('PASSWORD')
        await asyncio.sleep(0.5)
        await page.locator('button[type=\"submit\"]').first.click()
        await asyncio.sleep(5)
        try:
            await page.locator('input[inputmode=\"numeric\"]').first.wait_for(state='visible', timeout=3000)
            print('2FA_REQUIRED')
            return
        except: pass
        print('LOGIN_OK')
        await page.close()
asyncio.run(login())
"
```

**C. Handle result:**
- `LOGIN_OK` → Login successful.
- `2FA_REQUIRED` → Ask user for 6-digit code, then:
```bash
python3 -c "
import asyncio
from playwright.async_api import async_playwright
async def twofa():
    async with async_playwright() as p:
        browser = await p.chromium.connect_over_cdp('http://localhost:PORT')
        for page in browser.contexts[0].pages:
            if 'tradingview' in page.url:
                await page.locator('input[inputmode=\"numeric\"]').first.fill('CODE')
                await page.locator('button[type=\"submit\"]').first.click()
                await asyncio.sleep(5)
                print('2FA_OK')
                return
asyncio.run(twofa())
"
```

### 3. First-Time Setup

```bash
cd ~ && git clone --depth 1 https://github.com/tradesdontlie/tradingview-mcp.git && cd tradingview-mcp && npm install --production
```

Create scripts and systemd service:
```bash
curl -sL https://raw.githubusercontent.com/egg5233/tradingview-skills/main/scripts/setup.sh | bash
```

## Security

- ❌ NEVER save, log, or transmit user credentials
- ✅ Credentials are used only in the inline exec Python script, then discarded
