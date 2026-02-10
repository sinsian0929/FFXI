_addon.name = 'sparkscp'
_addon.author = 'Gemini & Brax (optimized by Codex)'
_addon.version = '1.9.0'
_addon.command = 'sparkscp'

require('chat')
require('logger')
local packets = require('packets')
local texts = require('texts')
local coroutine = require('coroutine')

-- ========================
-- 設定值
-- ========================
local cp_settings = {
    npc_name = 'Rabid Wolf, I.M.',
    purchase_option = 32837,
    confirm_option = 32837,
    item_index = 0,

    purchase_delay = 1.2,
    confirm_delay = 0.8,
    repeat_delay = 1.5,
    retry_timeout = 3.0,

    interaction_distance = 6,
    retry_when_npc_missing = 5.0,

    party_notify = true,
}

local state = {
    busy = false,
    current_count = 0,
    total_count = 0,
    hud_enabled = true,
    menu_id = nil,
    target_info = nil,
    retry_token = 0,
}

local hud = texts.new('', {
    pos = { x = 120, y = 320 },
    text = { size = 11, font = 'Arial' },
    bg = { alpha = 180, red = 0, green = 0, blue = 0 },
    padding = 8,
    flags = { draggable = true, bold = true },
})

-- ========================
-- 輔助工具
-- ========================
local function add_chat(color, msg)
    windower.add_to_chat(color, ('[SparksCP] %s'):format(msg))
end

local function party_notify(msg)
    if not cp_settings.party_notify then
        return
    end

    local player = windower.ffxi.get_player()
    if player and player.name then
        windower.send_command(('input /p [%s] %s'):format(player.name, msg))
    end
end

local function get_jitter_delay(base)
    return math.max(0.1, base + (math.random() * 0.8 - 0.4))
end

local function update_hud(msg)
    if not state.hud_enabled then
        hud:hide()
        return
    end

    local progress = ''
    if state.busy and state.total_count > 0 then
        progress = (' [%d/%d]'):format(state.current_count + 1, state.total_count)
    end

    local status = state.busy and ('Buying' .. progress) or 'Ready'
    hud:text('[SparksCP] ' .. (msg or status))
    hud:show()
end

local function get_inventory_info()
    return windower.ffxi.get_bag_info(0)
end

local function inventory_is_full()
    local inv = get_inventory_info()
    if not inv then
        return false
    end
    return inv.count >= inv.max
end

local function release_npc()
    local player = windower.ffxi.get_player()
    if not player or not player.index then
        return
    end

    local exit_packet = packets.new('outgoing', 0x016, {
        ['Target Index'] = player.index,
    })
    packets.inject(exit_packet)
end

local function abort_process(reason)
    state.busy = false
    state.total_count = 0
    state.menu_id = nil
    state.target_info = nil
    state.retry_token = 0

    release_npc()

    local why = reason or 'Inventory Full or Error'
    update_hud(why)
    add_chat(123, 'STOPPED: ' .. why)
    party_notify('STOPPED: ' .. why)
end

local function find_npc()
    local mobs = windower.ffxi.get_mob_array() or {}
    local max_distance = cp_settings.interaction_distance

    for _, mob in pairs(mobs) do
        if mob.name == cp_settings.npc_name and mob.valid_target then
            if math.sqrt(mob.distance) < max_distance then
                return mob
            end
        end
    end

    return nil
end

local function send_choice(option, unk1, is_auto)
    if not state.menu_id or not state.target_info then
        return
    end

    local zone = windower.ffxi.get_info().zone
    local packet = packets.new('outgoing', 0x05B, {
        Target = state.target_info.id,
        ['Target Index'] = state.target_info.index,
        Zone = zone,
        ['Menu ID'] = state.menu_id,
        ['Option Index'] = option,
        _unknown1 = unk1,
        ['Automated Message'] = is_auto,
        _unknown2 = 0,
    })

    packets.inject(packet)
end

local start_buy_cycle

start_buy_cycle = function()
    if not state.busy then
        return
    end

    if state.current_count >= state.total_count then
        state.busy = false
        update_hud('Finished!')
        party_notify(('Finished! Bought %d items.'):format(state.current_count))
        return
    end

    if inventory_is_full() then
        abort_process('Inventory Full')
        return
    end

    local npc = find_npc()
    if not npc then
        update_hud('NPC Not Found')
        coroutine.schedule(start_buy_cycle, cp_settings.retry_when_npc_missing)
        return
    end

    state.target_info = npc
    state.menu_id = nil
    state.retry_token = state.retry_token + 1
    local current_token = state.retry_token

    local open_menu_packet = packets.new('outgoing', 0x01A, {
        Target = npc.id,
        ['Target Index'] = npc.index,
        Category = 0,
        Param = 0,
        _unknown1 = 0,
    })

    packets.inject(open_menu_packet)
    update_hud('Opening Menu...')

    coroutine.schedule(function()
        if not state.busy then
            return
        end

        if state.menu_id then
            return
        end

        if state.retry_token ~= current_token then
            return
        end

        if inventory_is_full() then
            abort_process('Inventory Full')
            return
        end

        start_buy_cycle()
    end, cp_settings.retry_timeout)
end

-- ========================
-- 事件處理
-- ========================
windower.register_event('incoming chunk', function(id, data)
    if not ((id == 0x034 or id == 0x032) and state.busy and not state.menu_id) then
        return
    end

    local packet = packets.parse('incoming', data)
    if not packet then
        return
    end

    state.menu_id = packet['Menu ID']

    coroutine.schedule(function()
        if not state.busy then
            return
        end

        coroutine.sleep(get_jitter_delay(cp_settings.purchase_delay))
        update_hud('Purchasing...')
        send_choice(cp_settings.purchase_option, cp_settings.item_index, true)

        coroutine.sleep(get_jitter_delay(cp_settings.confirm_delay))
        update_hud('Confirming...')
        send_choice(cp_settings.confirm_option, 0, false)

        coroutine.sleep(1.0)
        release_npc()

        state.current_count = state.current_count + 1
        add_chat(207, ('Progress: %d/%d'):format(state.current_count, state.total_count))

        if state.current_count < state.total_count then
            if inventory_is_full() then
                abort_process('Inventory Full')
                return
            end

            local next_wait = get_jitter_delay(cp_settings.repeat_delay)
            update_hud(('Wait %.1fs...'):format(next_wait))
            coroutine.sleep(next_wait)
            start_buy_cycle()
            return
        end

        state.busy = false
        update_hud('Done')
        add_chat(200, 'All tasks finished.')
        party_notify(('All tasks finished. Total: %d'):format(state.current_count))
    end, 0.1)

    return true
end)

-- ========================
-- 指令處理
-- ========================
windower.register_event('addon command', function(cmd, ...)
    cmd = (cmd or ''):lower()
    local args = T { ... }

    if cmd == 'buycp' then
        if state.busy then
            add_chat(123, 'Already running. Use //sparkscp stop first.')
            return
        end

        local requested = tonumber(args[1]) or 1
        requested = math.floor(requested)

        if requested <= 0 then
            add_chat(123, 'Amount must be a positive integer.')
            return
        end

        if inventory_is_full() then
            abort_process('Inventory Full')
            return
        end

        state.total_count = requested
        state.current_count = 0
        state.busy = true

        add_chat(207, ('Buying %d items...'):format(state.total_count))
        party_notify(('Start buying %d items.'):format(state.total_count))
        start_buy_cycle()
        return
    end

    if cmd == 'stop' then
        abort_process('Manual Stop')
        return
    end

    if cmd == 'hud' then
        local mode = (args[1] or ''):lower()
        if mode == 'on' then
            state.hud_enabled = true
            update_hud('HUD Enabled')
        elseif mode == 'off' then
            state.hud_enabled = false
            update_hud('HUD Disabled')
        else
            add_chat(207, 'Usage: //sparkscp hud on|off')
        end
        return
    end

    add_chat(207, 'Commands: //sparkscp buycp <count> | stop | hud on|off')
end)

windower.register_event('load', function()
    math.randomseed(os.time())
    update_hud('Ready')
end)

windower.register_event('unload', function()
    hud:hide()
end)
