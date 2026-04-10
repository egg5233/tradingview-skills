---
name: tradingview-login
version: "2.0.0"
description: TradingView browser setup and login. Run "bash ~/tradingview-mcp/check-login.sh" to check status. If NOT_LOGGED_IN, ask user if they want to login.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔑",
        "requires": { "bins": ["python3", "node"] },
      },
  }
---

# TradingView 登入狀態檢查與登入

## 檢查登入狀態

像 `vercel whoami` 一樣，先跑一行命令檢查：

```bash
bash ~/tradingview-mcp/check-login.sh
```

結果：
- `LOGGED_IN` + `CDP_PORT:xxxx` → 已登入，用該端口操作
- `NOT_LOGGED_IN` + `CDP_PORT:xxxx` → 未登入，問用戶要不要登入
- `NO_BROWSER` → 需要啟動瀏覽器（見下方）
- `CHECK_FAILED` → 需要安裝依賴（見下方）

## 未登入 → 問用戶

```
TradingView 目前未登入。你要登入嗎？
🔓 登入 → 完整功能（保存圖表、所有指標、Pine Script、回測）
🔒 不登入 → 基礎功能（查看圖表、即時報價）
```

## 安裝依賴（CHECK_FAILED 時）

```bash
cd ~ && git clone --depth 1 https://github.com/tradesdontlie/tradingview-mcp.git && cd tradingview-mcp && npm install --production
```

修補 CDP 端口：
```bash
sed -i "s/const CDP_PORT = 9222;/const CDP_PORT = parseInt(process.env.TV_CDP_PORT || '9222', 10);/" ~/tradingview-mcp/src/connection.js && sed -i "s/const CDP_HOST = 'localhost';/const CDP_HOST = process.env.TV_CDP_HOST || 'localhost';/" ~/tradingview-mcp/src/connection.js
```

建立檢查腳本和啟動腳本：
```bash
bash ~/tradingview-mcp/create-scripts.sh
```

如果 `create-scripts.sh` 不存在，見下方「建立腳本」。

## 啟動瀏覽器（NO_BROWSER 時）

**只能用腳本啟動，禁止自己寫 chromium 命令：**

```bash
bash ~/tradingview-mcp/launch-chromium.sh
```

等待載入：
```bash
sleep 8 && bash ~/tradingview-mcp/check-login.sh
```

## 登入流程

**A. 問帳密**：帳密只在本機用於登入，不會被記錄。

**B. 確認 Playwright**：
```bash
python3 -c "from playwright.async_api import async_playwright; print('OK')" 2>&1 || pip3 install playwright
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

**D. 2FA**（如果需要，問用戶要驗證碼）：
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

## 建立腳本（如果不存在）

如果 `~/tradingview-mcp/check-login.sh` 或 `~/tradingview-mcp/launch-chromium.sh` 不存在：

```bash
cat > ~/tradingview-mcp/check-login.sh << 'CHECKEOF'
#!/bin/bash
for port in 18800 9222 9223; do
  if curl -s --max-time 2 "http://localhost:$port/json/version" | grep -q Browser 2>/dev/null; then
    CDP_PORT=$port; break
  fi
done
if [ -z "$CDP_PORT" ]; then echo "NO_BROWSER"; exit 1; fi
NODE_PATH=$(npm root -g) node -e "
const CDP = require('chrome-remote-interface');
(async () => {
  try {
    const client = await CDP({port: $CDP_PORT});
    const {Runtime} = client;
    await Runtime.enable();
    const {result} = await Runtime.evaluate({
      expression: '(document.querySelector(\"[data-name=header-user-menu-button]\") || document.querySelector(\"button[aria-label*=User]\")) ? \"LOGGED_IN\" : \"NOT_LOGGED_IN\"',
      returnByValue: true
    });
    console.log(result.value);
    console.log('CDP_PORT:' + $CDP_PORT);
    await client.close();
  } catch(e) { console.log('CHECK_FAILED'); }
})();
" 2>/dev/null
CHECKEOF
chmod +x ~/tradingview-mcp/check-login.sh

cat > ~/tradingview-mcp/launch-chromium.sh << 'LAUNCHEOF'
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
LAUNCHEOF
chmod +x ~/tradingview-mcp/launch-chromium.sh
echo "SCRIPTS_CREATED"
```

## 安全規則

- ❌ 絕對不可記錄、保存或傳送用戶帳密
- ✅ 帳密只在 exec 的 inline Python 中使用，用完即丟
