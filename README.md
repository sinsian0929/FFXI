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
