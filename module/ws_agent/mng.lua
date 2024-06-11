local skynet = require "skynet"
local logger = require "logger"
local cjson = require "cjson"
local timer = require "timer"
local db = require "ws_agent.db"
local cache = require "cache"
local gm = require "ws_agent.gm.main"
local search = require "ws_agent.search"
local protopack = require "protopack"

local WATCHDOG 
local GATE 
local user_alive_keep_time = 60 -- 玩家 60 秒没上行心跳协议就踢掉

local _M = {} 
local RPC = {} 

local fd2uid = {}  -- fd: uid 
local online_users = {}  -- uid: user{fd, acc, heartbeat, timerid}

function _M.init(gate, watchdog)
    GATE = gate 
    WATCHDOG = watchdog
    db.init()
    gm.init()
    _M.register_rpc(gm.RPC)
    search.init()
end 

function _M.disconnect(fd)
    local uid = fd2uid[fd]
    if uid then 
        local user = online_users[uid]
        timer.cancel(user.timerid) 
        
        online_users[uid] = nil 
        fd2uid[fd] = nil 
    end 
end 

function _M.close_fd(fd)
    skynet.send(GATE, "lua", "kick", fd)
    _M.disconnect(fd)
end 

function _M.get_fd(uid)
    local user = online_users[uid]
    if user then 
        return user.fd
    end 
end 

function _M.get_uid(fd)
    return fd2uid[fd]
end 

function _M.send_res(fd, res)
    local res = protopack.encode(res)
    skynet.send(GATE, "lua", "response", fd, res)
end 

function _M.check_user_online(uid)
    local user = online_users[uid]
    if user then 
        -- 心跳超时踢出
        if not user.heartbeat or skynet.time() - user.heartbeat >= user_alive_keep_time then 
            _M.close_fd(user.fd)
        end 
    end 
end 

function _M.login(acc, fd)
    assert(not fd2uid[fd], string.format("Already Login. acc: %s, fd: %s", acc, fd))

    -- 数据库加载数据
    local uid = db.find_and_create_user(acc)
    if uid == 0 then 
        _M.close_fd(fd)
        return 
    end 

    local user = {
        fd = fd, 
        acc = acc,
    }
    online_users[uid] = user 
    fd2uid[fd] = uid 

    -- 通知 gate 消息由 agent 接管
    skynet.call(GATE, "lua", "forward", fd)

    -- 定时检查心跳
    local timerid = timer.timeout_repeat(user_alive_keep_time, _M.check_user_online, uid)
    user.timerid = timerid

    -- 加载玩家信息
    local userinfo = cache.call_cached("get_userinfo", "user", "user", uid)
    logger.info(SERVICE_NAME, "Login Success", "acc: ", acc, "fd: ", fd)

    local res = {
        pid = "s2c_login",
        msg = "Login success",
        uid = userinfo.uid, 
        username = userinfo.username, 
        lv = userinfo.lv, 
        exp = userinfo.exp,
    }
    return res
end 

function _M.get_username(uid)
    local userinfo = cache.call_cached("get_userinfo", "user", "user", uid)
    return userinfo.username
end 

function _M.set_username(uid, username)
    local ok = cache.call_cached("set_username", "user", "user", uid, username)
    if ok then 
        db.update_username(uid, username)
    end 
    return ok 
end 

---- RPC -----
function _M.register_rpc(rpc)
    for k, v in pairs(rpc) do 
        RPC[k] = v
    end 
end 

-- c2s_echo
function RPC.c2s_echo(req, fd, uid)
    local res = {
        pid = "s2c_echo",
        msg = req.msg, 
        uid = uid,
    }
    return res
end 

-- c2s_heartbeat
function RPC.c2s_heartbeat(req, fd, uid)
    local user = online_users[uid]
    if not user then
        return 
    end 
    user.heartbeat = skynet.time()
end 

-- c2s_get_userinfo
function RPC.c2s_get_userinfo(req, fd, uid)
    local userinfo = cache.call_cached("get_userinfo", "user", "user", uid)
    local res = {
        pid = "s2c_get_userinfo",
        userinfo = userinfo,
    }
    return res 
end

-- c2s_get_username
function RPC.c2s_get_username(req, fd, uid)
    local username = _M.get_username(uid)
    local res = {
        pid = "s2c_get_username",
        username = username
    }
    return res 
end

-- c2s_set_username
function RPC.c2s_set_username(req, fd, uid)
    local ok = _M.set_username(uid, req.username)
    local msg = "success set username: " .. (req.username or "nil")
    if not ok then
        msg = "failed set username"
    end 

    local res = {
        pid = "s2c_set_username",
        msg = msg,
    }
    return res 
end

function _M.handle_proto(req, fd, uid)
    local f = RPC[req.pid]
    local res = f(req, fd, uid)
    return res
end 

return _M 