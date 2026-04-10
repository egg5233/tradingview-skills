---
name: tradingview-mcp
version: "2.0.0"
description: TradingView chart control via CLI. Use when user asks about charts, indicators, price data, Pine Script, or TradingView operations. All commands via exec.
metadata:
  {
    "openclaw":
      {
        "emoji": "📊",
        "requires": { "bins": ["node"] },
      },
  }
---

# TradingView 圖表控制技能

通過 exec 執行 `tv` CLI 命令控制瀏覽器中的 TradingView 圖表。
不依賴 MCP tool calling，所有模型都能使用。

## 前置：安裝 tradingview-mcp CLI

```bash
test -d ~/tradingview-mcp/src && echo "INSTALLED" || echo "NOT_INSTALLED"
```
如果 `NOT_INSTALLED`：
```bash
cd ~ && git clone --depth 1 https://github.com/tradesdontlie/tradingview-mcp.git && cd tradingview-mcp && npm install --production && echo "INSTALL_OK"
```

修補 CDP 端口（只需一次）：
```bash
grep -q 'TV_CDP_PORT' ~/tradingview-mcp/src/connection.js && echo "PATCHED" || sed -i "s/const CDP_PORT = 9222;/const CDP_PORT = parseInt(process.env.TV_CDP_PORT || '9222', 10);/" ~/tradingview-mcp/src/connection.js && sed -i "s/const CDP_HOST = 'localhost';/const CDP_HOST = process.env.TV_CDP_HOST || 'localhost';/" ~/tradingview-mcp/src/connection.js && echo "PATCHED_OK"
```

## 命令格式

```bash
cd ~/tradingview-mcp && TV_CDP_PORT=$PORT node src/cli/index.js <command> [options]
```

所有輸出為 JSON。`$PORT` 由 `tradingview-login` 技能找到的端口。

## 命令參考

### 連接與狀態
- `tv status` — CDP 連接 + 當前標的
- `tv discover` — 可用 API
- `tv ui-state` — UI 面板

### 圖表操控
- `tv symbol` / `tv symbol AAPL` — 查看/切換標的
- `tv timeframe` / `tv timeframe D` — 查看/切換週期
- `tv type Candles` — 圖表類型
- `tv scroll 2025-01-15` — 跳轉日期
- `tv search bitcoin` — 搜索

### 數據
- `tv quote` — 即時報價
- `tv ohlcv -s` — K 線摘要（**優先用**）
- `tv ohlcv -n 20` — 最近 20 根 K 線
- `tv values` — 所有指標數值

### 指標（用完整名稱）
- `tv indicator add "Relative Strength Index"`
- `tv indicator add "Moving Average Exponential"`
- `tv indicator remove ENTITY_ID`
- `tv state` — 查看所有指標和 entity ID

### Pine Script
- `tv pine compile` / `tv pine errors` / `tv pine console` / `tv pine save`
- `tv pine list` / `tv pine open "Name"`

### Pine 數據
- `tv data lines` / `tv data labels` / `tv data tables` / `tv data boxes`

### 截圖
- `tv screenshot` / `tv screenshot -r chart`

### 回測
- `tv replay start --date 2025-03-01`
- `tv replay step` / `tv replay trade buy/sell/close`
- `tv replay status` / `tv replay stop`

### 繪圖
- `tv draw shape horizontal_line --price 50000`
- `tv draw list` / `tv draw clear`

### 多標籤
- `tv tab list` / `tv tab new` / `tv tab switch`
- `tv pane layout 2x2`

## Context 管理

- **永遠用 `tv ohlcv -s`**（摘要），除非用戶要個別 K 線
- **善用 `tv screenshot`** 代替大量數據
- K 線用 `-n 20` 控制數量
- **避免 `tv pine get`** 在複雜腳本上（可能 200KB+）
