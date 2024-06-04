local skynet = require "skynet"
local logger = require "logger"
local xpcall = xpcall

local _M = {}

local handler_inc_id = 1
local dispatchs = {}  -- event type: { id: func }
local handlers = {}   -- id: event type

function _M.add_listener(event_type, func)
    local cbs = dispatchs[event_type]
    if not cbs then 
        cbs = {} 
        dispatchs[event_type] = cbs
    end 

    handler_inc_id = handler_inc_id + 1
    local id = handler_inc_id
    cbs[id] = func 
    handlers[id] = event_type

    return id 
end 

function _M.del_listener(id)
    local event_type = handlers[id]
    if not event_type then return end 

    handlers[id] = nil 
    local cbs = dispatchs[event_type] 
    if not cbs then return end 
    cbs[id] = nil 
end 

function _M.fire_event(event_type, ...)
    local cbs = dispatchs[event_type]
    if not cbs or not next(cbs) then return end 

    local res = true
    for id, func in pairs(cbs) do 
        local ok, err = xpcall(func, debug.traceback, ...)
        if not ok then 
            logger.error("[event]", "fire event error", "event type:", event_type, "handle id:", id, "err:", err)
            res = false 
        end 
    end 
    return res 
end 

return _M 