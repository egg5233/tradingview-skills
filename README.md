# TradingView Agent Skills

OpenClaw skills for TradingView chart control and login on Raspberry Pi (StoryClaw devices).

## Skills

### tradingview-login
Browser setup, CDP connection, and Playwright login with 2FA support.
- Manages Chromium as a systemd service (auto-start, auto-restart)
- Chromium shim intercepts bad launches from any model
- Persistent browser profile preserves login state

### tradingview-mcp
TradingView CLI command reference — charts, data, Pine Script, replay, screenshots.
- Workflow-oriented: maps user intent to exact CLI commands
- Context management rules to avoid token bloat
- Screenshot upload flow via Giggle CDN

## Install

Via StoryClaw TalentHub:
```bash
npx @storyclaw/talenthub agent install tradingview
```

Or install skills individually:
```bash
npx skills add egg5233/tradingview-skills --skill tradingview-login
npx skills add egg5233/tradingview-skills --skill tradingview-mcp
```

## Architecture

```
User → OpenClaw Agent → exec: tv <command> → CDP → Chromium (systemd) → TradingView
```

### Three-Layer Defense (ensures Chromium always works)

1. **systemd service** — Chromium starts on boot, restarts if closed
2. **chromium shim** (`~/.local/bin/chromium`) — intercepts bad model launches, delegates to service
3. **SKILL.md** — tells agent "browser is already running, never launch chromium"
