local skynet = require "skynet"
local mng = require "ws_agent.mng"
local cache = require "cache"
local cjson = require "cjson"
local search = require "ws_agent.search"

local _M = {}

local function set_name(uid, name)
    local ret = mng.set_username(uid, name)
    return true, "set name success"
end 

local function add_exp(uid, exp)
    local lv, exp = cache.call_cached("add_exp", "user", "user", uid, exp)
    return true, string.format("user(%s): LV(%d), EXP(%d)", mng.get_username(uid), lv, exp)
end 

local function broadcast_msg(msg)
    local res = {
        pid = "s2c_broadcast_msg", 
        msg = msg,
    }
    skynet.send(".ws_gate", "lua", "broadcast", cjson.encode(res))
end 

local function search_name(name)
    local search_list = search.search(name)

    local res = {
        pid = "s2c_search_name",
        msg = search_list,
    }
    return true, res
end 

_M.CMD = {
    setname = {
        func = set_name,
        args = { "uid", "string" },
    },
    addexp = {
        func = add_exp, 
        args = { "uid", "number" },
    },
    bmsg = {
        func = broadcast_msg,
        args = { "string" },
    },
    search = {
        func = search_name,
        args = { "string" },
    }
}

return _M 