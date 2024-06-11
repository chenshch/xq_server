local skynet = require "skynet"

local debug_port = tonumber(skynet.getenv("debug_console_port")) or 4040
local watchdog_port = tonumber(skynet.getenv("ws_watchdog_port")) or 8888
local max_online_client = tonumber(skynet.getenv("ws_watchdog_max_online_client")) or 1
local ws_protocol = skynet.getenv("ws_watchdog_protocol") 

skynet.start(function()
    skynet.error("[main.lua] start")

    if not skynet.getenv "daemon" then
        -- 不是 daemon 模式启动则开启 console 服务
		local console = skynet.newservice("console")
	end
    -- 开启 debug console 服务
    skynet.newservice("debug_console", debug_port)

    -- 开启 pb服务
    skynet.newservice("pb")

    -- 开启 ws_watchdog 服务
    local ws_watchdog = skynet.newservice("ws_watchdog")

    -- 通知 ws_watchdog 启动服务
    skynet.call(ws_watchdog, "lua", "start", {
        port = watchdog_port, 
        maxclient = max_online_client,
        nodelay = true, 
        protocol = ws_protocol,
    })

    skynet.error("[main.lua] websocket watchdog listen on", watchdog_port)

    -- main 服务只作为入口，启动完所需的服务后就可以退出
    skynet.exit()
end)