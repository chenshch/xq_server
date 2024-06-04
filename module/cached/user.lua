local mng = require "cached.mng"
local data_lvexp = require "data.lvexp"
local event_type = require "event_type"
local event = require "event"

local _M = {}
local CMD = {}

local function init_cb(uid, cache)
    if not cache.username then 
        cache.username = "New Player"
    end 
    if not cache.lv then
        cache.lv = 1
    end
    if not cache.exp then
        cache.exp = 0
    end
end

function CMD.get_userinfo(uid, cache)
    local userinfo = {
        uid = uid, 
        username = cache.username,
        lv = cache.lv,
        exp = cache.exp,
    }
    return userinfo
end

function CMD.set_username(uid, cache, username)
    if not cache then 
        return false 
    end 
    cache.username = username
    return true 
end 

local function get_next_lv(lv)
    local next_lv = lv + 1
    local cfg = data_lvexp[next_lv]
    if not cfg then 
        return false
    end 

    return true, next_lv, cfg.exp
end 

function CMD.add_exp(uid, cache, exp)
    _M.add_exp(uid, cache, exp)
    return cache.lv, cache.exp
end 

function _M.add_exp(uid, cache, exp)
    cache.exp = cache.exp + exp 

    local lvchanged = false 
    while true do 
        local lv = cache.lv 
        local cur_exp = cache.exp
        local ok, next_lv, next_exp = get_next_lv(lv)

        if ok and cur_exp >= next_exp then 
            cur_exp = cur_exp - next_exp
            cache.exp = cur_exp
            cache.lv = next_lv
            lvchanged = true 
        else
            break  
        end 
    end 

    local res = {
        pid = "s2c_update_lvexp",
        lv = cache.lv,
        exp = cache.exp,
    }
    mng.send_to_client(uid, res)

    if lvchanged then 
        event.fire_event(event_type.EVENT_TYPE_UPLEVEL, uid, cache.lv)
    end 
end 

function _M.init()
    mng.register_cmd("user", "user", CMD)
    mng.register_init_cb("user", "user", init_cb)
end

return _M 