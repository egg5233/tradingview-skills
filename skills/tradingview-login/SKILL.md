---
name: tradingview-login
version: "1.1.0"
description: TradingView browser setup and login. Use at the START of every session. Handles Chromium launch, CDP connection, and Playwright login with 2FA support.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔑",
        "requires": { "bins": ["python3", "node"] },
      },
  }
---

# TradingView 瀏覽器啟動與登入

**每次會話開始時必須首先使用此技能。**

## ⚠️ 最重要的規則

**啟動 Chromium 時，禁止自己寫 chromium 命令。只能用 `bash ~/tradingview-mcp/launch-chromium.sh`。**

自己組裝命令會缺少 Raspberry Pi 所需的 GPU 參數（`--use-angle=gles`），導致所有網頁空白無法載入。

## 流程

### Step 1 — 問用戶要不要登入

先問：

> 在開始之前，你要登入 TradingView 帳號嗎？
>
> 🔓 **登入**：完整功能
> 🔒 **不登入**：基礎功能

### Step 2 — 確認啟動腳本存在

```bash
test -f ~/tradingview-mcp/launch-chromium.sh && echo "SCRIPT_OK" || echo "NEED_SCRIPT"
```

如果 `NEED_SCRIPT`，執行以下命令建立腳本：

```bash
mkdir -p ~/tradingview-mcp && cat > ~/tradingview-mcp/launch-chromium.sh << 'SCRIPTEOF'
#!/bin/bash
rm -f ~/.openclaw/tradingview-browser/SingletonLock ~/.openclaw/tradingview-browser/SingletonSocket 2>/dev/null
rm -rf /tmp/.org.chromium.Chromium.* 2>/dev/null
mkdir -p ~/.openclaw/tradingview-browser
CHROMIUM_FLAGS=""
for f in /etc/chromium.d/*; do . "$f" 2>/dev/null; done
export DISPLAY=:0
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/run/user/1000
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
URL="${1:-https://www.tradingview.com/chart/}"
/usr/lib/chromium/chromium $CHROMIUM_FLAGS --remote-debugging-port=9222 --user-data-dir="$HOME/.openclaw/tradingview-browser" --no-first-run --no-default-browser-check --disable-sync --disable-background-networking --disable-dev-shm-usage --password-store=basic "$URL" >/dev/null 2>&1 &
echo "CHROMIUM_STARTED:$!"
SCRIPTEOF
chmod +x ~/tradingview-mcp/launch-chromium.sh && echo "SCRIPT_CREATED"
```

### Step 3 — 掃描已有的 Chromium

```bash
for port in 18800 9222 9223; do result=$(curl -s --max-time 2 "http://localhost:$port/json/list" 2>/dev/null); if echo "$result" | grep -qi "tradingview"; then echo "FOUND_CDP:$port"; exit 0; fi; done; echo "NO_CDP_FOUND"
```

- `FOUND_CDP:<port>` → 記住端口，跳到 Step 5
- `NO_CDP_FOUND` → 繼續 Step 4

### Step 4 — 啟動 Chromium

**只能用這一行（不可修改、不可替換、不可自己寫 chromium 命令）**：

```bash
bash ~/tradingview-mcp/launch-chromium.sh
```

等待載入：

```bash
sleep 8 && curl -s --max-time 3 http://localhost:9222/json/version | grep -q Browser && echo "CDP_OK" || echo "CDP_WAIT"
```

如果 `CDP_WAIT` 再等 5 秒重試。端口為 `9222`。

### Step 5 — 檢查連接

```bash
cd ~/tradingview-mcp && TV_CDP_PORT=$PORT node src/cli/index.js status
```

### Step 6 — 登入（如果用戶選擇了登入）

如果用戶選擇不登入，跳過。

**A. 問帳密**：
> 請提供 TradingView Email 和密碼。帳密只在本機用於登入，不會被記錄。

**B. 確認 Playwright**：
```bash
python3 -c "from playwright.async_api import async_playwright; print('OK')" 2>&1 || pip3 install playwright 2>&1
```

**C. 執行登入**（替換 EMAIL_HERE、PASSWORD_HERE、PORT_HERE）：
```bash
python3 << 'PYEOF'
import asyncio
from playwright.async_api import async_playwright

async def login():
    async with async_playwright() as p:
        browser = await p.chromium.connect_over_cdp("http://localhost:PORT_HERE")
        ctx = browser.contexts[0]
        page = await ctx.new_page()
        await page.goto("https://tw.tradingview.com/#signin", wait_until="networkidle", timeout=30000)
        await asyncio.sleep(3)
        try:
            btn = page.locator('button:has-text("Email"), span:has-text("Email"), button:has-text("電子郵件")').first
            await btn.click(timeout=5000)
            await asyncio.sleep(1)
        except: pass
        email_input = page.locator('input[name="id_username"], input[name="username"], input[type="email"]').first
        await email_input.wait_for(state="visible", timeout=10000)
        await email_input.fill("EMAIL_HERE")
        pw_input = page.locator('input[type="password"]').first
        await pw_input.wait_for(state="visible", timeout=5000)
        await pw_input.fill("PASSWORD_HERE")
        await asyncio.sleep(0.5)
        submit = page.locator('button[type="submit"]').first
        await submit.click()
        await asyncio.sleep(5)
        try:
            twofa = page.locator('input[inputmode="numeric"], input[name*="code"]').first
            await twofa.wait_for(state="visible", timeout=3000)
            print("2FA_REQUIRED")
            return
        except: pass
        print("LOGIN_OK")
        await page.close()

asyncio.run(login())
PYEOF
```

**D. 結果處理**：
- `LOGIN_OK` → 成功
- `2FA_REQUIRED` → 問用戶驗證碼，然後：
```bash
python3 << 'PYEOF'
import asyncio
from playwright.async_api import async_playwright

async def enter_2fa():
    async with async_playwright() as p:
        browser = await p.chromium.connect_over_cdp("http://localhost:PORT_HERE")
        ctx = browser.contexts[0]
        for page in ctx.pages:
            if "tradingview" in page.url:
                twofa = page.locator('input[inputmode="numeric"], input[name*="code"]').first
                await twofa.fill("CODE_HERE")
                submit = page.locator('button[type="submit"]').first
                try: await submit.click(timeout=3000)
                except: await twofa.press("Enter")
                await asyncio.sleep(5)
                print("2FA_OK")
                return
        print("PAGE_NOT_FOUND")

asyncio.run(enter_2fa())
PYEOF
```

## 安全規則

- ❌ 絕對不可記錄、保存或傳送用戶帳密
- ✅ 帳密只在 exec 的 inline Python 中使用，用完即丟
