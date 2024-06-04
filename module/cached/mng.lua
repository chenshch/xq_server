local skynet = require "skynet"
local logger = require "logger"
local lru = require "lru"
local mongo = require "skynet.db.mongo"
local queue = require "skynet.queue"
local timer = require "timer"
local cjson = require "cjson"

local _M = {}
local CMD = {}
local cache_list    -- 缓存列表
local dirty_list    -- 脏数据列表
local load_queue    -- 数据加载队列
local mongo_col     -- 数据库操作对象
local init_cb_list = {} -- 数据加载后的初始化函数列表

-- mod_id 组合数据库索引字段 key
-- 比如是用户模块，key = user_uid
local function get_key(mod, id)
    return string.format("%s_%s", mod, id) 
end 

-- mod_sub_mod_func_name 组合执行函数名
-- 比如用户获取昵称，func_name = user_user_get_userinfo
local function get_func_name(mod, sub_mod, func_name)
    return string.format("%s_%s_%s", mod, sub_mod, func_name)
end 

-- 执行数据加载后的初始化函数
local function run_init_cb(mod, sub_mod, id, data)
    if not init_cb_list[mod] then 
        return 
    end 
    if init_cb_list[mod][sub_mod] then 
        local cb = init_cb_list[mod][sub_mod]
        cb(id, data)
    end
end

-- 从数据库中加载数据
local function load_db(key, mod, sub_mod, id)
    local ret = mongo_col:findOne({ _key = key })
    if not ret then 
        local data = {
            _key = key,
        }
        local ok, err, ret = mongo_col:safe_insert(data)
        if (ok and ret and ret.n == 1) then 
            logger.info(SERVICE_NAME, "New data insert success", "key: ", key)
            run_init_cb(mod, sub_mod, id, data)
            return key, data 
        else
            return 0, "New data error: " .. err
        end
    else
        if not ret._key then 
            return 0, "cannot load data. key: " .. key
        end 
        run_init_cb(mod, sub_mod, id, ret)
        return ret._key, ret
    end 
end

-- 从缓存中加载数据
function _M.load_cache(mod, sub_mod, id)
    local key = get_key(mod, id)
    local cache = cache_list:get(key)
    if cache then 
        cache._ref = cache._ref + 1
        dirty_list[key] = true 
        return cache
    end 

    local _key, cache = load_queue(load_db, key, mod, sub_mod, id)
    assert(_key == key)
    cache_list:set(key, cache)
    cache._ref = 1
    dirty_list[key] = true
    return cache
end 

-- 释放缓存
function _M.release_cache(mod, id, cache)
    local key = get_key(mod, id)
    cache._ref = cache._ref - 1
    if cache._ref < 0 then 
        logger.error(SERVICE_NAME, "cache ref wrong", "key: ", key, "ref: ", ref)
    end 
end

-- 获取执行函数
function _M.get_func(mod, sub_mod, func_name)
    func_name = get_func_name(mod, sub_mod, func_name)
    logger.debug(SERVICE_NAME, "Get func_name: ", func_name)

    local f = assert(CMD[func_name])
    return function(id, cache, ...)
        local ret = table.pack(pcall(f, id, cache, ...))
        _M.release_cache(mod, id, cache)
        return select(2, table.unpack(ret))
    end
end 

-- 注册模块执行函数
function _M.register_cmd(mod, sub_mod, func_list)
    for func_name, func in pairs(func_list) do 
        func_name = get_func_name(mod, sub_mod, func_name)
        CMD[func_name] = func
    end 
end 

-- 注册模块数据初始化函数
function _M.register_init_cb(mod, sub_mod, init_cb)
    if not init_cb_list[mod] then 
        init_cb_list[mod] = {}
    end 
    init_cb_list[mod][sub_mod] = init_cb
end


-------------- 模块初始化工作 -------------

-- 缓存移除回调函数
local function cache_remove_cb(key, cache)
    -- 数据脏或仍有引用，继续存入缓存
    if cache._ref > 0 or dirty_list[cache] then 
        cache_list:set(key, cache, true)
    end 
end

-- 缓存同步到数据库
local function cache_save_db(key, cache)
    local data = {
        ['$set'] = cache
    }
    local xpcallok, updateok, err, ret = xpcall(mongo_col.safe_update, debug.traceback, mongo_col, { _key = key }, data, true, false)
    if not xpcallok or not (updateok and ret and ret.n == 1) then 
        logger.error(SERVICE_NAME, "cache save db failed", "key: ", key, "cache: ", cjson.encode(cache))
    end 
end

-- 脏的缓存数据写到数据库
function _M.do_save_loop()
    for key, _ in pairs(dirty_list) do
        logger.debug(SERVICE_NAME, "save key: ", key)

        local cache = cache_list:get(key)
        if cache then 
            cache_save_db(key, cache)
        else
            logger.error(SERVICE_NAME, "Not key cache, save failed", "key: ", key)
        end
        dirty_list[key] = nil  
    end 
end

-- 初始化数据库
local function init_db()
    local mongo_host = skynet.getenv("mongodb_ip") or "localhost"
    local mongo_port = tonumber(skynet.getenv("mongodb_port")) or 27017
    local mongo_user = skynet.getenv("mongodb_user")
    local mongo_pwd  = skynet.getenv("mongodb_pwd")
    local mongo_db   = skynet.getenv("cache_db_name") or "cache"

    local c = mongo.client({
        host = mongo_host,
        port = mongo_port,
    })
    local db = c[mongo_db]
    db:auth(mongo_user, mongo_pwd)
    logger.info("db", "connect to db: ", mongo_db)

    mongo_col = db.cached 
    mongo_col:createIndex({{_key = 1}, unique = true})
end 

function _M.init()
    init_db()
    local max_cache_cnt = tonumber(skynet.getenv("cache_max_cnt")) or 10240
    local save_interval = tonumber(skynet.getenv("cache_save_interval")) or 60

    cache_list = lru.new(max_cache_cnt, cache_remove_cb)
    dirty_list = {}
    load_queue = queue()

    timer.timeout_repeat(save_interval, _M.do_save_loop)
end

function _M.send_to_client(uid, res)
    skynet.send(".ws_agent", "lua", "send_to_client", tonumber(uid), res)
end 

---- 监控缓存列表
function _M.monitor_cache_list()
    cache_list:dump()
end
----

return _M 