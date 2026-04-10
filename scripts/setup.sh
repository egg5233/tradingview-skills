#!/bin/bash
# Setup scripts for TradingView agent on Raspberry Pi

# Ensure Wayland ozone-platform is in system Chromium flags
if [ ! -f /etc/chromium.d/99-ozone-wayland ]; then
  echo "Setting up Wayland rendering for Chromium..."
  sudo bash -c 'echo "export CHROMIUM_FLAGS=\"\$CHROMIUM_FLAGS --ozone-platform=wayland\"" > /etc/chromium.d/99-ozone-wayland' 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "✅ Wayland ozone-platform configured"
  else
    echo "⚠️ Could not write to /etc/chromium.d/ (need sudo). Chromium may not render correctly."
  fi
else
  echo "✅ Wayland ozone-platform already configured"
fi

echo "Creating launch-chromium.sh..."
cat > ~/tradingview-mcp/launch-chromium.sh << 'LAUNCHEOF'
#!/bin/bash
rm -f ~/.openclaw/tradingview-browser/SingletonLock ~/.openclaw/tradingview-browser/SingletonSocket 2>/dev/null
rm -rf /tmp/.org.chromium.Chromium.* 2>/dev/null
mkdir -p ~/.openclaw/tradingview-browser
CHROMIUM_FLAGS=""
for f in /etc/chromium.d/*; do . "$f" 2>/dev/null; done
URL="${1:-https://www.tradingview.com/chart/}"
/usr/lib/chromium/chromium $CHROMIUM_FLAGS --ozone-platform=wayland --remote-debugging-port=9222 --user-data-dir="$HOME/.openclaw/tradingview-browser" --no-first-run --no-default-browser-check --disable-sync --disable-background-networking --disable-dev-shm-usage --password-store=basic "$URL" >/dev/null 2>&1 &
echo "CHROMIUM_STARTED:$!"
LAUNCHEOF
chmod +x ~/tradingview-mcp/launch-chromium.sh

echo "Creating check-login.sh..."
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

# Patch CDP port
sed -i "s/const CDP_PORT = 9222;/const CDP_PORT = parseInt(process.env.TV_CDP_PORT || '9222', 10);/" ~/tradingview-mcp/src/connection.js 2>/dev/null
sed -i "s/const CDP_HOST = 'localhost';/const CDP_HOST = process.env.TV_CDP_HOST || 'localhost';/" ~/tradingview-mcp/src/connection.js 2>/dev/null

echo "SETUP_COMPLETE"
