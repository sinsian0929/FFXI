# FFXI

FF11 自動按路徑行走 Lua 腳本：`ffxi_auto_path.lua`

## 使用方式（Windower Lua）
1. 將 `ffxi_auto_path.lua` 放到 Windower 的 addons/lua 可載入位置。
2. 依需求修改 `config.path` 座標（`x, y, z`）。
3. 載入後使用：
   - `//ap start`：開始走路
   - `//ap stop`：停止
   - `//ap pause`：暫停
   - `//ap resume`：繼續
   - `//ap reset`：路點重置到第 1 點
   - `//ap status`：顯示狀態

## 功能
- 可設定多個 waypoint。
- 到點距離容許值（`reach_distance`）可調。
- 支援 `loop` 循環模式。
- 支援 `ping_pong` 來回巡邏模式。

## 自動賣商店腳本：`ffxi_auto_sell_shop.lua`

### 使用方式（Windower Lua）
1. 將 `ffxi_auto_sell_shop.lua` 放到 Windower addons 可載入位置。
2. 修改 `config.item_names`（要賣的道具白名單）與 `config.keep_per_item`（每種保留量）。
3. 在遊戲中先選取商店 NPC（target）。
4. 使用指令：
   - `//asell start`：開始持續自動賣
   - `//asell once`：只跑一輪
   - `//asell stop`：停止
   - `//asell status`：查看狀態
   - `//asell reload`：重新掃描背包

### 注意
- 腳本使用 `input /item "道具名" <t>` 對目前目標 NPC 連續出貨。
- 不同 NPC 是否接受此流程可能不同，建議先用便宜素材測試。
- 請務必使用白名單（`item_names`）避免誤賣。
