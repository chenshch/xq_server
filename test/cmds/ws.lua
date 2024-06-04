local cjson = require "cjson"
local md5 = require "md5"
local websocket = require "http.websocket"
local mng = require "test.mng"
local timer = require "timer"
local logger = require "logger"

local _M = {}
local CMD = {}
local RPC = {} 


------------  RPC -----------------

local function send_heartbeat(ws_id)
    local req = {
        pid = "c2s_heartbeat",
    }
    websocket.write(ws_id, cjson.encode(req))
end 

function RPC.s2c_login(ws_id, res)
    mng.set_uid(res.uid)
    _M.timer = timer.timeout_repeat(5, send_heartbeat, ws_id)
    logger.debug(SERVICE_NAME, "s2c_login: ", cjson.encode(res))
end 

function RPC.s2c_get_userinfo(ws_id, res)
    logger.debug(SERVICE_NAME, "s2c_get_userinfo: ", cjson.encode(res))
end

function RPC.s2c_get_username(ws_id, res)
    logger.debug(SERVICE_NAME, "s2c_get_username: ", cjson.encode(res))
end 

function RPC.s2c_set_username(ws_id, res)
    logger.debug(SERVICE_NAME, "s2c_set_username: ", cjson.encode(res))
end 

function RPC.s2c_broadcast_msg(ws_id, res)
    logger.debug(SERVICE_NAME, "s2c_broadcast_msg: ", cjson.encode(res))
end 

-- 处理网络消息
function _M.handle_res(ws_id, res)
    local f = RPC[res.pid]
    if f then 
        f(ws_id, res)
    else
        logger.debug(SERVICE_NAME, "recv: ", cjson.encode(res))
    end 
end

------------  CMD -----------------

-- 登录指令
function CMD.login(ws_id, acc)
    local token = "token"
    local checkstr = token .. acc 
    local sign = md5.sumhexa(checkstr)
    local req = {
        pid = "c2s_login",
        acc = acc, 
        token = token, 
        sign = sign,
    }
    websocket.write(ws_id, cjson.encode(req))
end 

function CMD.echo(ws_id, ...)
    local msg = {...} 
    local req = {
        pid = "c2s_echo",
        msg = msg,
    }
    websocket.write(ws_id, cjson.encode(req))
end 

function CMD.get_userinfo(ws_id)
    local req = {
        pid = "c2s_get_userinfo",
    }
    websocket.write(ws_id, cjson.encode(req))
end

function CMD.get_username(ws_id)
    local req = {
        pid = "c2s_get_username",
    }
    websocket.write(ws_id, cjson.encode(req))
end 

function CMD.set_username(ws_id, username)
    local req = {
        pid = "c2s_set_username",
        username = username,
    }
    websocket.write(ws_id, cjson.encode(req))
end 

-- 执行指令
function _M.run_command(ws_id, cmd, ...)
    local f = CMD[cmd]
    if not f then 
        logger.debug(SERVICE_NAME, "Not exist command: [" .. cmd .. "]")
        return 
    end 
    f(ws_id, ...)
end 

------

function _M.disconnect()
    if _M.timer then 
        timer.cancel(_M.timer)
    end 
end 

------

return _M 