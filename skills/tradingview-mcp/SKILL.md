---
name: tradingview-mcp
version: "3.0.0"
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

# TradingView 圖表控制

通過 exec 執行 `tv` CLI 命令控制 TradingView。所有命令輸出 JSON。

## 命令格式

```bash
cd ~/tradingview-mcp && node src/cli/index.js <command> [options]
```

## 前置安裝（首次使用）

```bash
test -d ~/tradingview-mcp/src && echo "INSTALLED" || echo "NOT_INSTALLED"
```
如果 `NOT_INSTALLED`：
```bash
cd ~ && git clone --depth 1 https://github.com/tradesdontlie/tradingview-mcp.git && cd tradingview-mcp && npm install --production
```

---

## 工作流指南

### 「看一下我的圖表」

```bash
tv status          # 標的、時間週期、圖表類型
tv values          # 所有指標當前數值
tv quote           # 即時報價
```

### 「完整分析」/ 「full analysis」

按順序執行（同一批的可以並行）：

**第 1 批（並行）**：
```bash
tv quote           # 即時報價
tv ohlcv -s        # K 線摘要
tv values          # 指標數值
```

**第 2 批（並行）**：
```bash
tv data lines      # Pine 指標的價位線
tv data labels     # Pine 指標的文字標籤
tv data tables     # Pine 指標的表格
```

**第 3 批**：
```bash
tv screenshot      # 截圖（然後上傳到 Giggle，見 AGENTS.md 規則 5）
```

用表格格式整理成報告，附上截圖 URL。

### 「切換標的」

```bash
tv symbol AAPL                   # 美股
tv symbol BINANCE:BTCUSDT        # 加密貨幣
tv symbol ES1!                   # 期貨
tv symbol NYMEX:CL1!             # 原油
```

切換後等 3 秒確認：
```bash
sleep 3 && tv status
```

### 「切換時間週期」

```bash
tv timeframe 1      # 1 分鐘
tv timeframe 5      # 5 分鐘
tv timeframe 15     # 15 分鐘
tv timeframe 60     # 1 小時
tv timeframe D      # 日線
tv timeframe W      # 週線
tv timeframe M      # 月線
```

### 「加指標」

⚠️ **必須用完整名稱，不能用縮寫。**

```bash
tv indicator add "Relative Strength Index"                # RSI
tv indicator add "Moving Average Exponential"             # EMA
tv indicator add "Moving Average Convergence Divergence"  # MACD
tv indicator add "Bollinger Bands"                        # 布林帶
tv indicator add "Volume"                                 # 成交量
```

加完後等 2 秒再讀數值：
```bash
sleep 2 && tv values
```

移除指標（先用 `tv state` 取得 entity ID）：
```bash
tv state                         # 取得 entity ID
tv indicator remove ENTITY_ID    # 移除
```

### 「K 線數據」

```bash
tv ohlcv -s          # 摘要統計（⚠️ 優先用這個）
tv ohlcv -n 20       # 最近 20 根
tv ohlcv -n 100      # 最近 100 根
```

### 「截圖」

```bash
tv screenshot                    # 全畫面
tv screenshot -r chart           # 只圖表
tv screenshot -r strategy_tester # 只策略測試面板
```

截圖後**必須上傳到 Giggle 再發給用戶**（見 AGENTS.md 規則 5）。

### 「Pine 指標數據」

自訂 Pine 指標用 `line.new()`、`label.new()` 畫的東西，`tv values` 看不到。用：

```bash
tv data lines        # 價位線（去重、高→低排序）
tv data labels       # 文字標籤（如「支撐 24550」）
tv data tables       # 表格數據
tv data boxes        # 價格區間
```

### 「Pine Script 開發」

```bash
tv pine new indicator             # 新建指標
tv pine set --file code.pine      # 注入代碼
tv pine compile                   # 編譯（智能檢測）
tv pine errors                    # 讀取錯誤
tv pine console                   # 讀取 log 輸出
tv pine save                      # 保存到雲端
tv pine list                      # 列出已保存腳本
tv pine open "Name"               # 打開腳本
```

⚠️ **避免 `tv pine get`** — 複雜腳本可能返回 200KB+。

### 「回測」

```bash
tv replay start --date 2025-03-01    # 進入回放模式
tv replay step                        # 前進一根 K 線
tv replay autoplay                    # 自動播放
tv replay trade buy                   # 買入
tv replay trade sell                  # 賣出
tv replay trade close                 # 平倉
tv replay status                      # 持倉和盈虧
tv replay stop                        # 結束，回到即時
```

### 「畫線」

```bash
tv draw shape horizontal_line --price 50000    # 水平線
tv draw shape trend_line --point1 ... --point2 ...  # 趨勢線
tv draw list                                    # 列出繪圖
tv draw clear                                   # 清除全部
tv draw remove ENTITY_ID                        # 移除單個
```

### 「搜尋」

```bash
tv search bitcoin        # 搜索標的
tv info                   # 當前標的詳細信息
```

### 「多窗格 / 標籤」

```bash
tv pane layout 2x2        # 2x2 佈局
tv tab list               # 列出標籤頁
tv tab new                # 新增標籤頁
tv tab switch INDEX       # 切換
```

### 「跳轉日期」

```bash
tv scroll 2025-01-15      # ISO 格式日期
```

### 「UI 面板」

```bash
tv ui panel pine-editor          # 開啟/關閉 Pine 編輯器
tv ui panel strategy-tester      # 開啟/關閉策略測試器
tv ui panel watchlist            # 開啟/關閉自選列表
tv ui fullscreen                 # 全螢幕
```

---

## Context 管理規則

1. **永遠用 `tv ohlcv -s`**（摘要），除非用戶要個別 K 線
2. **善用 `tv screenshot`** 代替大量數據 — 一張圖勝千字
3. K 線用 `-n 20` 控制數量
4. **避免 `tv pine get`** 在複雜腳本上
5. `tv state` 跑一次就好，不要重複

## 輸出大小參考

| 命令 | 輸出大小 |
|------|---------|
| `tv quote` | ~200 bytes |
| `tv values` | ~500 bytes |
| `tv ohlcv -s` | ~500 bytes |
| `tv ohlcv -n 20` | ~1.5 KB |
| `tv data lines` | ~1-3 KB |
| `tv data labels` | ~2-5 KB |
| `tv screenshot` | ~300 bytes（返回檔案路徑） |

## 注意事項

- 所有命令輸出 JSON：`{ "success": true/false, ... }`
- Entity ID 從 `tv state` 取得，跨 session 無效
- Pine 指標必須**在圖表上可見**才能讀取
- 指標名必須用**完整名稱**
- 截圖保存在 `~/tradingview-mcp/screenshots/`
