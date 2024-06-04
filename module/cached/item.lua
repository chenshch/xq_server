local skynet = require "skynet"
local event = require "event"
local mng = require "cached.mng"
local logger = require "logger"
local event_type = require "event_type"

local _M = {}
local CMD = {} 

local function init_cb(uid, cache)
    if not cache.items then 
        cache.items = {}
    end 
end

local function on_uplevel(uid, lv)
    logger.debug("item", "on_uplevel", "uid:", uid, "lv:", lv)
end 

function _M.init()
    mng.register_cmd("user", "item", CMD)
    mng.register_init_cb("user", "item", init_cb)
    event.add_listener(event_type.EVENT_TYPE_UPLEVEL, on_uplevel)
end

return _M 