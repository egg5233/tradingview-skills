---
name: tradingview-login
version: "3.0.0"
description: TradingView browser setup and login. Run check-login.sh then launch-chromium.sh. NEVER start chromium directly.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔑",
        "requires": { "bins": ["python3", "node"] },
      },
  }
---

# TradingView 登入

## 唯一規則

**啟動瀏覽器只能用 `bash ~/tradingview-mcp/launch-chromium.sh`。**
**絕對禁止執行 `chromium` 命令。如果你直接執行 chromium，網頁會空白無法使用。**

## 流程

### 1. 檢查狀態

```bash
bash ~/tradingview-mcp/check-login.sh
```

| 結果 | 下一步 |
|------|--------|
| `LOGGED_IN` + `CDP_PORT:xxx` | 直接工作，用該端口 |
| `NOT_LOGGED_IN` + `CDP_PORT:xxx` | 問用戶要不要登入 |
| `NO_BROWSER` | 執行第 2 步 |
| `CHECK_FAILED` | 執行第 3 步 |

### 2. 啟動瀏覽器

```bash
bash ~/tradingview-mcp/launch-chromium.sh
```

等待：
```bash
sleep 8 && bash ~/tradingview-mcp/check-login.sh
```

### 3. 安裝（首次）

```bash
cd ~ && git clone --depth 1 https://github.com/tradesdontlie/tradingview-mcp.git && cd tradingview-mcp && npm install --production
```

設定系統 Wayland 渲染（需要 sudo，只需一次）：
```bash
test -f /etc/chromium.d/99-ozone-wayland && echo "OZONE_OK" || echo "NEED_OZONE"
```

如果 `NEED_OZONE`：
```bash
sudo bash -c 'echo "export CHROMIUM_FLAGS=\"\$CHROMIUM_FLAGS --ozone-platform=wayland\"" > /etc/chromium.d/99-ozone-wayland'
```

這會確保 Chromium 在 Raspberry Pi 上正確使用 Wayland 渲染，否則網頁會空白。

然後建立腳本：
```bash
curl -sL https://raw.githubusercontent.com/egg5233/tradingview-skills/main/scripts/setup.sh | bash
```

如果 curl 失敗，手動建立（見 GitHub README）。

### 4. 登入

問用戶 Email 和密碼，然後（替換 EMAIL、PASSWORD、PORT）：

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

2FA 時問用戶驗證碼，然後：
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

## 安全

帳密只在 exec 中使用，不可記錄、保存或傳送。
