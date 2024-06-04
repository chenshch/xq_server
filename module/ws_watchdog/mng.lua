local skynet = require "skynet"
local timer = require "timer"
local logger = require "logger"
local md5 = require "md5"

local _M = {} -- 模块接口
local RPC = {} -- 协议绑定处理函数
local GATE -- gate 服务地址
local AGENT -- agent 服务地址

local noauth_fds = {} -- 未通过认证的服务端
local TIMEOUT_AUTH = tonumber(skynet.getenv("ws_watchdog_timeout_auth")) or 10

-- 标记哪些协议不用登录就能访问
local no_auth_proto_list = {
    c2s_login = true, 
}

function _M.is_no_auth(pid)
    return no_auth_proto_list[pid]
end 

-- 超时检测，踢掉没通过认证的客户端
local function timeout_auth(fd)
    local time = noauth_fds[fd]
    if not time then return end 

    if skynet.time() - time < TIMEOUT_AUTH then 
        return 
    end 

    _M.close_fd(fd)
end

function _M.init(gate, agent)
    GATE = gate 
    AGENT = agent
end 

function _M.open_fd(fd)
    noauth_fds[fd] = skynet.time()
    timer.timeout(TIMEOUT_AUTH + 1, timeout_auth, fd)
end 

function _M.close_fd(fd)
    skynet.send(GATE, "lua", "kick", fd)
    skynet.send(AGENT, "lua", "disconnect", fd)
    noauth_fds[fd] = nil 
end

function _M.check_auth(fd)
    if noauth_fds[fd] then 
        return false
    end 
    return true 
end 

----- RPC ------

local function check_sign(token, acc, sign)
    local checkstr = token .. acc 
    local checksum = md5.sumhexa(checkstr)
    if checksum == sign then 
        return true 
    end 
    return false 
end 

-- 登录协议处理函数
function RPC.c2s_login(req, fd)
    -- token 验证
    if not check_sign(req.token, req.acc, req.sign) then 
        logger.debug("ws_watchdog", "login filed, token: ", req.token, ", acc: ", req.acc, ", sign: ", req.sign)
        _M.close_fd(fd)
        return 
    end 

    -- 登录成功，分配代理，移除超时队列
    local res = skynet.call(AGENT, "lua", "login", req.acc, fd)
    noauth_fds[fd] = nil 
    return res 
end

-- 协议根据 pid 执行对应函数
function _M.handle_proto(req, fd)
    local f = RPC[req.pid]
    local res = f(req, fd)
    return res 
end 

return _M 