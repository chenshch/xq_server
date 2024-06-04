local skynet = require "skynet"
local mongo = require "skynet.db.mongo"
local logger = require "logger"
local utils_table = require "utils.table"
local snowflake = require "snowflake"

local _M = {}

local mongo_host = skynet.getenv("mongodb_ip") or "localhost"
local mongo_port = tonumber(skynet.getenv("mongodb_port")) or 27017
local mongo_user = skynet.getenv("mongodb_user")
local mongo_pwd  = skynet.getenv("mongodb_pwd")
local mongo_db   = skynet.getenv("mongodb_db_name")

local mongo_col -- account 表操作对象

-- game.account
function _M.init()
    local c = mongo.client({
        host = mongo_host,
        port = mongo_port,
    })
    local db = c[mongo_db]
    db:auth(mongo_user, mongo_pwd)

    logger.info("db", "connect to db: ", mongo_db)

    mongo_col = db.account

    -- 创建索引
    mongo_col:createIndex({{acc = 1}, unique = true})
    mongo_col:createIndex({{uid = 1}, unique = true})
    mongo_col:createIndex({{name = 1}, unique = false})
end 

local function call_create_new_user(acc)
    local uid = tostring(snowflake.snowflake())
    local user_data = {
        uid = uid,
        acc = acc, 
    }
    local ok, err, ret = mongo_col:safe_insert(user_data)
    if (ok and ret and ret.n == 1) then 
        logger.info("db", "New uid success", "acc: ", acc, "uid: ", uid)
        return uid, user_data
    else
        return 0, "New user error: " .. err
    end 
end 

local function call_load_user(acc)
    local ret = mongo_col:findOne({acc = acc})
    if not ret then 
        return call_create_new_user(acc)
    else 
        if not ret.uid then 
            return 0, "Load user error, acc: " .. acc 
        end 
        return ret.uid, ret 
    end 
end 

local loading_user = {}
function _M.find_and_create_user(acc)
    if loading_user[acc] then 
        logger.info("db", "account is loading", "acc: ", acc)
        return 0, "already loading"
    end 
    loading_user[acc] = true 
    local ok, uid, data = xpcall(call_load_user, debug.traceback, acc)
    loading_user[acc] = nil 
    if not ok then 
        local err = uid 
        logger.error("db", "load user error", "acc: ", acc, "err: ", err)
        return 0, err 
    end 
    return uid, data
end 

-- 用户名更新 game 数据库的 account 表
function _M.update_username(uid, username)
    local data = {
        ['$set'] = {
            name = username
        }
    }
    local xpcallok, updateok, err, ret = xpcall(mongo_col.safe_update, debug.traceback, mongo_col, {uid = uid}, data, true, false)
    if not xpcallok or not (updateok and ret and ret.n == 1) then 
        logger.error("db", "update_username error", "uid:", uid)
    end 
end 

-- 根据 name 名字查找，忽略大小写
function _M.find_by_name(name, limit) 
    -- 查询语法
    local query = {
        name = {
            ['$regex'] = name,
            ["$options"] = 'i',
        }
    }
    -- 映射集
    local proj = {
        ["_id"] = 0,
        ["uid"] = 1,
        ["name"] = 1,
    }

    local ret = mongo_col:find(query, proj):limit(limit)
    local ret_list = {}
    while ret:hasNext() do 
        local data = ret:next()
        table.insert(ret_list, {
            uid = data.uid,
            name = data.name,
        })
    end 
    return ret_list
end 

return _M 