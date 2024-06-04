local skynet = require "skynet"
local lru = require "lru"
local db = require "ws_agent.db"

local _M = {}
local lru_cache_data 

local limit = tonumber(skynet.getenv("search_limit")) or 10
local expire = tonumber(skynet.getenv("search_expire")) or 10
local cache_max_cnt = tonumber(skynet.getenv("search_max_cache")) or 100

function _M.search(name)
    local now = skynet.time()
    local cache_ret = lru_cache_data:get(name)
    if cache_ret and cache_ret.expire > now and cache_ret. search_list then 
        return cache_ret.search_list
    end 

    local search_list = db.find_by_name(name, limit)
    lru_cache_data:set(name, {
        expire = now + expire,
        search_list = search_list,
    })
    return search_list
end 

function _M.init()
    lru_cache_data = lru.new(cache_max_cnt)
end 

return _M 