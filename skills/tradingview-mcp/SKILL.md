---
name: tradingview-mcp
version: "3.1.0"
description: TradingView chart control via CLI. Use when user asks about charts, indicators, price data, Pine Script, screenshots, or TradingView operations.
metadata:
  {
    "openclaw":
      {
        "emoji": "📊",
        "requires": { "bins": ["node"] },
      },
  }
---

# TradingView Chart Control

Control TradingView via `tv` CLI commands executed through exec. All output is JSON.

## Command Format

```bash
cd ~/tradingview-mcp && node src/cli/index.js <command> [options]
```

## First-Time Setup

```bash
test -d ~/tradingview-mcp/src && echo "INSTALLED" || echo "NOT_INSTALLED"
```
If `NOT_INSTALLED`:
```bash
cd ~ && git clone --depth 1 https://github.com/tradesdontlie/tradingview-mcp.git && cd tradingview-mcp && npm install --production
```

---

## Workflow Guide — Match User Intent to Commands

### "What's on my chart?" / "Show me the current state"

```bash
tv status          # symbol, timeframe, chart type
tv values          # all visible indicator readings
tv quote           # real-time price (OHLCV)
```

### "Full analysis" / "Analyze this chart"

Execute in order (batch where possible):

**Batch 1 (parallel)**:
```bash
tv quote           # real-time price
tv ohlcv -s        # OHLCV summary stats
tv values          # all indicator readings
```

**Batch 2 (parallel)**:
```bash
tv data lines      # price levels drawn by Pine indicators
tv data labels     # text labels from Pine indicators
tv data tables     # table data from Pine indicators
```

**Batch 3**:
```bash
tv screenshot      # capture chart (then upload to Giggle per AGENTS.md Rule 5)
```

Format results as a structured report with tables. Include the screenshot URL.

### "Show me XXX" / "Switch to AAPL"

```bash
tv symbol AAPL                   # US stocks
tv symbol BINANCE:BTCUSDT        # crypto
tv symbol ES1!                   # futures
tv symbol NYMEX:CL1!             # crude oil futures
```

Wait 3 seconds after switching, then confirm:
```bash
sleep 3 && tv status
```

### "Switch to daily / 15 minute"

```bash
tv timeframe 1      # 1 min
tv timeframe 5      # 5 min
tv timeframe 15     # 15 min
tv timeframe 60     # 1 hour
tv timeframe D      # daily
tv timeframe W      # weekly
tv timeframe M      # monthly
```

### "Add RSI / Bollinger Bands"

⚠️ **Must use FULL indicator names. Abbreviations will fail.**

```bash
tv indicator add "Relative Strength Index"                # RSI
tv indicator add "Moving Average Exponential"             # EMA
tv indicator add "Moving Average Convergence Divergence"  # MACD
tv indicator add "Bollinger Bands"                        # BB
tv indicator add "Volume"                                 # Volume
```

Wait 2 seconds after adding before reading values:
```bash
sleep 2 && tv values
```

To remove an indicator (get entity ID from `tv state` first):
```bash
tv state                         # get entity IDs
tv indicator remove ENTITY_ID    # remove by ID
```

### "Give me price data"

```bash
tv ohlcv -s          # summary stats (⚠️ ALWAYS prefer this)
tv ohlcv -n 20       # last 20 bars
tv ohlcv -n 100      # last 100 bars
```

### "Take a screenshot"

```bash
tv screenshot                    # full page
tv screenshot -r chart           # chart area only
tv screenshot -r strategy_tester # strategy tester only
```

After screenshot, **must upload to Giggle and send URL to user** (see AGENTS.md Rule 5).

### "What are the Pine indicator levels?"

Custom Pine indicators draw with `line.new()`, `label.new()`, etc. These are invisible to `tv values`. Use:

```bash
tv data lines        # price levels (deduplicated, sorted high→low)
tv data labels       # text labels (e.g. "Support 24550")
tv data tables       # table data
tv data boxes        # price zones/ranges
```

### "Write Pine Script" / "Help me code an indicator"

```bash
tv pine new indicator             # create new indicator
tv pine set --file code.pine      # inject code
tv pine compile                   # smart compile
tv pine errors                    # read compilation errors
tv pine console                   # read log.info() output
tv pine save                      # save to TradingView cloud
tv pine list                      # list saved scripts
tv pine open "Name"               # open a saved script
```

⚠️ **Avoid `tv pine get`** on complex scripts — can return 200KB+.

### "Backtest" / "Replay mode"

```bash
tv replay start --date 2025-03-01    # enter replay from date
tv replay step                        # advance one bar
tv replay autoplay                    # auto-advance
tv replay trade buy                   # buy
tv replay trade sell                  # sell
tv replay trade close                 # close position
tv replay status                      # position & P&L
tv replay stop                        # exit replay, return to realtime
```

### "Draw on chart"

```bash
tv draw shape horizontal_line --price 50000    # horizontal line
tv draw shape trend_line --point1 ... --point2 ...  # trend line
tv draw list                                    # list all drawings
tv draw clear                                   # clear all
tv draw remove ENTITY_ID                        # remove one
```

### "Search for a symbol"

```bash
tv search bitcoin        # search
tv info                   # detailed info on current symbol
```

### "Multi-pane / tabs"

```bash
tv pane layout 2x2        # set 2x2 layout
tv tab list               # list tabs
tv tab new                # new tab
tv tab switch INDEX       # switch tab
```

### "Jump to a date"

```bash
tv scroll 2025-01-15      # ISO format date
```

### "UI panels"

```bash
tv ui panel pine-editor          # toggle Pine editor
tv ui panel strategy-tester      # toggle strategy tester
tv ui panel watchlist            # toggle watchlist
tv ui fullscreen                 # toggle fullscreen
```

---

## Context Management Rules

1. **Always use `tv ohlcv -s`** (summary) unless user explicitly wants individual bars
2. **Use `tv screenshot`** instead of pulling large datasets — one image beats 1000 words
3. Cap bar count with `-n 20` for quick analysis
4. **Avoid `tv pine get`** on complex scripts (200KB+)
5. Run `tv state` once to get entity IDs — don't repeat

## Output Size Reference

| Command | Approx Size |
|---------|-------------|
| `tv quote` | ~200 bytes |
| `tv values` | ~500 bytes |
| `tv ohlcv -s` | ~500 bytes |
| `tv ohlcv -n 20` | ~1.5 KB |
| `tv data lines` | ~1-3 KB |
| `tv data labels` | ~2-5 KB |
| `tv screenshot` | ~300 bytes (returns file path) |

## Important Notes

- All commands output JSON: `{ "success": true/false, ... }`
- Entity IDs from `tv state` are session-scoped — don't cache across sessions
- Pine indicators must be **visible on chart** to read their data
- Indicator names must be **full names** — abbreviations fail
- Screenshots save to `~/tradingview-mcp/screenshots/`
