--[[
FFXI Auto Sell Shop (Windower Lua)

用途：自動將指定道具賣給目前目標 NPC。
注意：此腳本採用 `/item "道具名" <t>` 方式把道具交給 NPC，
實際是否可販售取決於 NPC 是否接受收購（不同 NPC 行為可能不同）。

Commands:
  //asell start        開始自動賣
  //asell stop         停止
  //asell once         只跑一輪
  //asell status       顯示狀態
  //asell reload       重新讀取背包快照

設定：
  - config.item_names: 要販售的道具名稱白名單（完全比對）
  - config.keep_per_item: 每個道具保留數量（可選）
--]]

_addon.name = 'AutoSellShop'
_addon.author = 'Codex'
_addon.version = '1.0.0'
_addon.commands = {'asell', 'autosellshop'}

local config = {
    interval = 1.2, -- 每次販售間隔（秒）
    max_target_distance = 6,

    -- 只會賣出清單內的道具（建議先用便宜垃圾測試）
    item_names = {
        ['Bat Wing'] = true,
        ['Goblin Armor'] = true,
        ['Beetle Jaw'] = true,
    },

    -- 每種道具保留數量（不填代表不保留）
    keep_per_item = {
        ['Bat Wing'] = 12,
    },
}

local res_items = require('resources').items

local state = {
    running = false,
    queue = {},
    index = 1,
    last_action_time = 0,
    run_once = false,
}

local function info(msg)
    windower.add_to_chat(207, ('[AutoSell] %s'):format(msg))
end

local function warn(msg)
    windower.add_to_chat(123, ('[AutoSell] %s'):format(msg))
end

local function now()
    return os.clock()
end

local function get_target_npc()
    local t = windower.ffxi.get_mob_by_target('t')
    if not t then
        return nil, '沒有目標。請先選取商店 NPC。'
    end

    if t.distance and math.sqrt(t.distance) > config.max_target_distance then
        return nil, ('離目標太遠（%.2f）。'):format(math.sqrt(t.distance))
    end

    if t.spawn_type ~= 2 then
        return nil, '目前目標不是 NPC。'
    end

    return t
end

local function push_sell_entry(name, count)
    state.queue[#state.queue + 1] = {name = name, count = count}
end

local function rebuild_queue()
    state.queue = {}
    state.index = 1

    local bag = windower.ffxi.get_items(0) -- inventory
    if not bag or not bag.max then
        return false, '無法讀取背包。'
    end

    local counts = {}

    for slot = 1, bag.max do
        local entry = bag[slot]
        if entry and entry.id and entry.id > 0 and entry.count and entry.count > 0 then
            local item = res_items[entry.id]
            if item and config.item_names[item.en] then
                counts[item.en] = (counts[item.en] or 0) + entry.count
            end
        end
    end

    for item_name, total in pairs(counts) do
        local keep = config.keep_per_item[item_name] or 0
        local sell_count = total - keep
        if sell_count > 0 then
            push_sell_entry(item_name, sell_count)
        end
    end

    table.sort(state.queue, function(a, b)
        return a.name < b.name
    end)

    return true
end

local function start(run_once)
    local target, err = get_target_npc()
    if not target then
        warn(err)
        return
    end

    local ok, queue_err = rebuild_queue()
    if not ok then
        warn(queue_err)
        return
    end

    if #state.queue == 0 then
        warn('沒有符合清單且可賣出的道具。')
        return
    end

    state.running = true
    state.run_once = run_once and true or false
    state.last_action_time = 0

    info(('開始販售，共 %d 種道具，目標 NPC：%s'):format(#state.queue, target.name or 'Unknown'))
end

local function stop(reason)
    state.running = false
    state.run_once = false
    if reason then
        info(reason)
    else
        info('已停止。')
    end
end

local function status_text()
    return ('running=%s index=%d/%d'):format(tostring(state.running), state.index, #state.queue)
end

windower.register_event('addon command', function(cmd)
    cmd = (cmd or ''):lower()

    if cmd == 'start' then
        start(false)
        return
    end

    if cmd == 'once' then
        start(true)
        return
    end

    if cmd == 'stop' then
        stop('手動停止。')
        return
    end

    if cmd == 'reload' then
        local ok, err = rebuild_queue()
        if ok then
            info(('已重建販售隊列，共 %d 種道具。'):format(#state.queue))
        else
            warn(err)
        end
        return
    end

    if cmd == 'status' then
        info(status_text())
        return
    end

    warn('Usage: //asell [start|once|stop|status|reload]')
end)

windower.register_event('prerender', function()
    if not state.running then
        return
    end

    if now() - state.last_action_time < config.interval then
        return
    end

    local target, err = get_target_npc()
    if not target then
        stop('停止：' .. err)
        return
    end

    local entry = state.queue[state.index]
    if not entry then
        if state.run_once then
            stop('單輪販售完成。')
            return
        end

        local ok = rebuild_queue()
        if not ok or #state.queue == 0 then
            stop('沒有更多可賣道具，停止。')
            return
        end

        entry = state.queue[state.index]
    end

    if entry.count <= 0 then
        state.index = state.index + 1
        return
    end

    windower.send_command(('input /item "%s" <t>'):format(entry.name))
    entry.count = entry.count - 1
    state.last_action_time = now()

    if entry.count <= 0 then
        state.index = state.index + 1
    end
end)
