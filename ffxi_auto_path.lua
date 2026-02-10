--[[
FFXI Auto Path Walker (Windower Lua)

How to use:
1) Load this file in a Windower Lua environment.
2) Edit `config.path` with your own waypoint list.
3) Commands:
   //ap start     -> start walking the path
   //ap stop      -> stop immediately
   //ap pause     -> pause movement
   //ap resume    -> resume movement
   //ap status    -> print current state
   //ap reset     -> reset to waypoint 1

This script moves your character toward waypoints by repeatedly issuing
`windower.ffxi.run(x, y, z)` commands and stopping when the point is reached.
It supports loop and ping-pong patrol modes.
--]]

_addon.name = 'AutoPathWalker'
_addon.author = 'Codex'
_addon.version = '1.0.0'
_addon.commands = {'ap', 'autopath'}

local config = {
    -- Replace with your own route.
    -- FFXI uses X/Z for horizontal plane and Y for height.
    path = {
        {x = 100.0, y = 0.0, z = 100.0},
        {x = 120.0, y = 0.0, z = 100.0},
        {x = 120.0, y = 0.0, z = 120.0},
        {x = 100.0, y = 0.0, z = 120.0},
    },
    reach_distance = 1.4, -- waypoint considered reached inside this distance
    loop = true,          -- if false, route stops at final point
    ping_pong = false,    -- if true: 1->2->3->2->1 pattern
    update_interval = 0.08,
}

local state = {
    active = false,
    paused = false,
    index = 1,
    direction = 1,
    last_update = 0,
}

local function info(msg)
    windower.add_to_chat(207, ('[AutoPath] %s'):format(msg))
end

local function warn(msg)
    windower.add_to_chat(123, ('[AutoPath] %s'):format(msg))
end

local function distance(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function stop_running()
    windower.ffxi.run(false)
end

local function player_position()
    local me = windower.ffxi.get_mob_by_target('me')
    if not me then
        return nil
    end
    return {x = me.x, y = me.y, z = me.z}
end

local function get_waypoint(i)
    return config.path[i]
end

local function advance_waypoint()
    local max_index = #config.path

    if max_index <= 1 then
        return
    end

    if config.ping_pong then
        state.index = state.index + state.direction

        if state.index >= max_index then
            state.index = max_index
            state.direction = -1
        elseif state.index <= 1 then
            state.index = 1
            state.direction = 1
        end
        return
    end

    state.index = state.index + 1
    if state.index > max_index then
        if config.loop then
            state.index = 1
        else
            state.active = false
            stop_running()
            info('Route finished.')
        end
    end
end

local function validate_path()
    if #config.path == 0 then
        warn('Path is empty. Please add waypoints in config.path.')
        return false
    end

    for i, point in ipairs(config.path) do
        if type(point.x) ~= 'number' or type(point.y) ~= 'number' or type(point.z) ~= 'number' then
            warn(('Waypoint %d is invalid. Expected {x=number,y=number,z=number}.'):format(i))
            return false
        end
    end

    return true
end

local function reset_route()
    state.index = 1
    state.direction = 1
end

windower.register_event('addon command', function(command)
    command = (command or ''):lower()

    if command == 'start' then
        if not validate_path() then
            return
        end

        state.active = true
        state.paused = false
        info(('Started. Waypoints: %d'):format(#config.path))
        return
    end

    if command == 'stop' then
        state.active = false
        state.paused = false
        stop_running()
        info('Stopped.')
        return
    end

    if command == 'pause' then
        if not state.active then
            warn('Route is not active.')
            return
        end
        state.paused = true
        stop_running()
        info('Paused.')
        return
    end

    if command == 'resume' then
        if not state.active then
            warn('Route is not active.')
            return
        end
        state.paused = false
        info('Resumed.')
        return
    end

    if command == 'reset' then
        reset_route()
        stop_running()
        info('Waypoint index reset to 1.')
        return
    end

    if command == 'status' then
        info(('active=%s paused=%s waypoint=%d/%d'):format(
            tostring(state.active),
            tostring(state.paused),
            state.index,
            #config.path
        ))
        return
    end

    warn('Usage: //ap [start|stop|pause|resume|status|reset]')
end)

windower.register_event('prerender', function()
    if not state.active or state.paused then
        return
    end

    local now = os.clock()
    if now - state.last_update < config.update_interval then
        return
    end
    state.last_update = now

    local me = player_position()
    if not me then
        return
    end

    local target = get_waypoint(state.index)
    if not target then
        warn('Waypoint missing. Stopping route.')
        state.active = false
        stop_running()
        return
    end

    local d = distance(me, target)
    if d <= config.reach_distance then
        advance_waypoint()
        target = get_waypoint(state.index)
        if not target or not state.active then
            return
        end
    end

    windower.ffxi.run(target.x, target.y, target.z)
end)

windower.register_event('unload', function()
    stop_running()
end)
