local skynet = require "skynet"
local logger = require "logger"
local mng = require "ws_watchdog.mng"
local cjson = require "cjson"

local CMD = {} -- 服务操作接口
local SOCKET = {} -- socket 相关操作接口
local GATE -- gate 服务地址
local AGENT -- agent 服务地址

--------- SOCKET ----------

-- call by ws_gate(handler.connect)
function SOCKET.open(fd, addr)
	logger.debug(SERVICE_NAME, "New client from : " .. addr)
    mng.open_fd(fd)
end

-- call by ws_gate(handler.close)
function SOCKET.close(fd)
	logger.debug(SERVICE_NAME, "socket close",fd)
	mng.close_fd(fd)
end

-- call by ws_gate(handler.error)
function SOCKET.error(fd, msg)
	logger.error(SERVICE_NAME, "socket error",fd, msg)
	mng.close_fd(fd)
end

-- call by ws_gate(handler.warning)
function SOCKET.warning(fd, size)
	-- size K bytes havn't send out in fd
	logger.warn(SERVICE_NAME, "socket warning", fd, size, "K")
end

-- call by ws_gate(handler.message)
function SOCKET.data(fd, msg)
    logger.info(SERVICE_NAME, "SOCKET data", "fd: ", fd, "msg: ", msg) 
	local req = cjson.decode(msg)
	if not req.pid then 
		logger.error(SERVICE_NAME, "Unknow proto, fd: ", fd, ", msg: ", msg)
		return 
	end 

	-- 判断客户端认证是否通过
	if not mng.check_auth(fd) then 
		-- 没认证，且不是登录协议，踢下线
		if not mng.is_no_auth(req.pid) then 
			logger.warn(SERVICE_NAME, "auth failed, fd: ", fd, ", msg: ", msg)
			mng.close_fd(fd)
			return 
		end 
	end 

	-- 登录协议 or 其他协议处理
	local res = mng.handle_proto(req, fd)
	if res then 
		skynet.call(GATE, "lua", "response", fd, cjson.encode(res))
	end 
end

---------- CMD ----------

function CMD.start(conf)
    -- 开启 gate 服务
    skynet.call(GATE, "lua", "open", conf)
end

function CMD.kick(fd)
    -- 踢客户端下线
	mng.close_fd(fd)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "socket" then
			local f = SOCKET[subcmd]
			f(...)
			-- socket api don't need return
		else
			local f = assert(CMD[cmd])
			skynet.ret(skynet.pack(f(subcmd, ...)))
		end
	end)

	GATE = skynet.newservice("ws_gate")
    AGENT = skynet.newservice("ws_agent")
    mng.init(GATE, AGENT)
    skynet.call(AGENT, "lua", "init", GATE, skynet.self())
end)