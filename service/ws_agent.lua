local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local logger = require "logger"
local cjson = require "cjson"
local mng = require "ws_agent.mng"

local WATCHDOG -- watchdog 服务地址
local GATE -- gate 服务地址

local CMD = {}

function CMD.init(gate, watchdog)
    WATCHDOG = watchdog
    GATE = gate
    mng.init(GATE, WATCHDOG)
end

function CMD.disconnect(fd)
    mng.disconnect(fd)
end 

-- call by ws_watchdog(RPC.c2s_login)
function CMD.login(acc, fd)
    local res = mng.login(acc, fd)
    return res 
end 

function CMD.send_to_client(uid, res)
    local fd = mng.get_fd(uid)
    if fd then 
        mng.send_res(fd, res)
    end 
end 

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = skynet.tostring, 
    dispatch = function(fd, address, msg)
        skynet.ignoreret()  -- session is fd, don't call skynet.ret

        logger.debug(SERVICE_NAME, "socket data", fd, msg)
        -- 解析消息，pid：协议id
        local req = cjson.decode(msg)
        if not req.pid then 
            logger.error(SERVICE_NAME, "Unknow proto, fd: ", fd, ", msg: ", msg)
            return 
        end 

        -- 登录成功会绑定 fd: uid
        local uid = mng.get_uid(fd)
        if not uid then 
            logger.warn(SERVICE_NAME, "No uid. fd: ", fd, ", msg: ", msg)
            mng.close_fd(fd) 
        end     

        local res = mng.handle_proto(req, fd, uid) 
        if res then 
            skynet.call(GATE, "lua", "response", fd, cjson.encode(res))
        end 
    end
}

skynet.start(function()
    skynet.dispatch("lua", function(_, _, command, ...)
        -- skynet.trace()
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)
    skynet.register(".ws_agent")
end)