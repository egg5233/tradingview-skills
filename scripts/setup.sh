#!/bin/bash
# Setup scripts for TradingView agent on Raspberry Pi

echo "=== TradingView Agent Setup ==="

# 1. Ensure Wayland ozone-platform in system Chromium flags
if [ ! -f /etc/chromium.d/99-ozone-wayland ]; then
  echo "Setting up Wayland rendering..."
  sudo bash -c 'echo "export CHROMIUM_FLAGS=\"\$CHROMIUM_FLAGS --ozone-platform=wayland\"" > /etc/chromium.d/99-ozone-wayland' 2>/dev/null
  [ $? -eq 0 ] && echo "✅ Wayland configured" || echo "⚠️ Need sudo for /etc/chromium.d/"
else
  echo "✅ Wayland already configured"
fi

# 2. Create launch script (fallback)
echo "Creating launch-chromium.sh..."
cat > ~/tradingview-mcp/launch-chromium.sh << 'LAUNCHEOF'
#!/bin/bash
rm -f ~/.openclaw/tradingview-browser/SingletonLock ~/.openclaw/tradingview-browser/SingletonSocket 2>/dev/null
rm -rf /tmp/.org.chromium.Chromium.* 2>/dev/null
mkdir -p ~/.openclaw/tradingview-browser
CHROMIUM_FLAGS=""
for f in /etc/chromium.d/*; do . "$f" 2>/dev/null; done
URL="${1:-https://www.tradingview.com/chart/}"
/usr/lib/chromium/chromium $CHROMIUM_FLAGS --remote-debugging-port=9222 --user-data-dir="$HOME/.openclaw/tradingview-browser" --no-first-run --no-default-browser-check --disable-sync --disable-background-networking --disable-dev-shm-usage --password-store=basic "$URL" >/dev/null 2>&1 &
echo "CHROMIUM_STARTED:$!"
LAUNCHEOF
chmod +x ~/tradingview-mcp/launch-chromium.sh
echo "✅ launch-chromium.sh created"

# 3. Create check-login script
echo "Creating check-login.sh..."
cat > ~/tradingview-mcp/check-login.sh << 'CHECKEOF'
#!/bin/bash
for port in 9222 18800; do
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
echo "✅ check-login.sh created"

# 4. Create systemd service (auto-start Chromium)
echo "Creating systemd service..."
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/tradingview-chromium.service << 'SVCEOF'
[Unit]
Description=TradingView Chromium (CDP on :9222)
After=graphical-session.target

[Service]
Type=simple
ExecStartPre=/bin/bash -c 'rm -f %h/.openclaw/tradingview-browser/SingletonLock %h/.openclaw/tradingview-browser/SingletonSocket 2>/dev/null; rm -rf /tmp/.org.chromium.Chromium.* 2>/dev/null; mkdir -p %h/.openclaw/tradingview-browser'
ExecStart=/usr/bin/chromium --remote-debugging-port=9222 --user-data-dir=%h/.openclaw/tradingview-browser --no-first-run --no-default-browser-check --disable-sync --disable-background-networking --password-store=basic https://www.tradingview.com/chart/
Restart=on-failure
RestartSec=5
Environment=DISPLAY=:0
Environment=WAYLAND_DISPLAY=wayland-0
Environment=XDG_RUNTIME_DIR=/run/user/1000

[Install]
WantedBy=default.target
SVCEOF
systemctl --user daemon-reload
systemctl --user enable tradingview-chromium.service 2>/dev/null
systemctl --user start tradingview-chromium.service 2>/dev/null
echo "✅ systemd service created and started"

# 5. Create chromium shim (intercepts bad launches)
echo "Creating chromium shim..."
mkdir -p ~/.local/bin
cat > ~/.local/bin/chromium << 'SHIMEOF'
#!/bin/bash
for port in 9222 18800; do
  if curl -s --max-time 1 "http://localhost:$port/json/version" | grep -q Browser 2>/dev/null; then
    echo "Chromium already running on port $port"
    exit 0
  fi
done
systemctl --user start tradingview-chromium.service 2>/dev/null
sleep 3
for port in 9222 18800; do
  if curl -s --max-time 1 "http://localhost:$port/json/version" | grep -q Browser 2>/dev/null; then
    echo "Chromium started via service on port $port"
    exit 0
  fi
done
[ -f ~/tradingview-mcp/launch-chromium.sh ] && bash ~/tradingview-mcp/launch-chromium.sh && exit $?
echo "ERROR: Could not start Chromium"
exit 1
SHIMEOF
chmod +x ~/.local/bin/chromium
ln -sf ~/.local/bin/chromium ~/.local/bin/chromium-browser 2>/dev/null
echo "✅ chromium shim installed"

# 6. Patch CDP port in connection.js
sed -i "s/const CDP_PORT = 9222;/const CDP_PORT = parseInt(process.env.TV_CDP_PORT || '9222', 10);/" ~/tradingview-mcp/src/connection.js 2>/dev/null
sed -i "s/const CDP_HOST = 'localhost';/const CDP_HOST = process.env.TV_CDP_HOST || 'localhost';/" ~/tradingview-mcp/src/connection.js 2>/dev/null
echo "✅ CDP port patched"

echo ""
echo "=== SETUP COMPLETE ==="
echo "TradingView Chromium is now a system service."
echo "It will auto-start on boot and restart on crash."
