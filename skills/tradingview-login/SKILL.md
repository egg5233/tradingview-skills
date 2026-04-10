---
name: tradingview-login
version: "4.0.0"
description: TradingView is managed as a system service. Browser is ALREADY RUNNING. Just use "tv status" to check. If login needed, use Playwright.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔑",
        "requires": { "bins": ["python3", "node"] },
      },
  }
---

# TradingView 連接與登入

## 重要：瀏覽器已經在跑

TradingView Chromium 是系統服務，**開機就自動啟動**。你不需要啟動瀏覽器。
**禁止執行 chromium 命令。瀏覽器已經在跑了。**

## 流程

### 1. 檢查連接

```bash
bash ~/tradingview-mcp/check-login.sh
```

| 結果 | 下一步 |
|------|--------|
| `LOGGED_IN` + `CDP_PORT:xxx` | 直接工作 |
| `NOT_LOGGED_IN` + `CDP_PORT:xxx` | 問用戶要不要登入 |
| `NO_BROWSER` | 執行 `systemctl --user start tradingview-chromium.service` 然後重試 |
| `CHECK_FAILED` | 需要安裝（見第 3 步） |

### 2. 登入（如果用戶要）

**A. 問帳密**（帳密只在本機用於登入，不會記錄）

**B. 執行**（替換 EMAIL、PASSWORD、PORT）：
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

**C. 2FA**（問用戶驗證碼）：
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

### 3. 首次安裝

```bash
cd ~ && git clone --depth 1 https://github.com/tradesdontlie/tradingview-mcp.git && cd tradingview-mcp && npm install --production
```

建立腳本和服務：
```bash
curl -sL https://raw.githubusercontent.com/egg5233/tradingview-skills/main/scripts/setup.sh | bash
```
