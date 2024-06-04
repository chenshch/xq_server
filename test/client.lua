local skynet = require "skynet"
require "skynet.manager"
local dns = require "skynet.dns"
local cjson = require "cjson"
local websocket = require "http.websocket"
local socket = require "skynet.socket"
local utils_file = require "utils.file"
local utils_string = require "utils.string"
local logger = require "logger"

local ws_id -- websocket 连接 ID
local cmds = {} -- 命令模块，ws: ws.lua、gm: gm.lua

local function handle_resp(ws_id, res)
    for _, cmd_mod in pairs(cmds) do 
        if cmd_mod.handle_res then 
            cmd_mod.handle_res(ws_id, res)
        end 
    end 
end 

-- 网络循环
local function websocket_main_loop()
    -- 连接服务器
    local ws_protocol = skynet.getenv("ws_watchdog_protocol")
    local ws_port = skynet.getenv("ws_watchdog_port")
    local server_host = skynet.getenv("server_host")
    local url = string.format("%s://%s:%s/client", ws_protocol, server_host, ws_port)
    ws_id = websocket.connect(url) -- https://github.com/cloudwu/skynet/blob/89b47f93723d03f4dd275a9dbab52b267a40dd89/lualib/http/websocket.lua#L442C1-L442C41

    logger.debug(SERVICE_NAME, "websocket connected. ws_id:", ws_id)

    while true do 
        local ok, err = pcall(websocket.read, ws_id)
        if not ok then 
            logger.error(SERVICE_NAME, "websocket read error", "err:", err)
            cmds["ws"].disconnect()
            break
        end 
        local res = err 
        if not res then 
            logger.error(SERVICE_NAME, "disconnect.")
            cmds["ws"].disconnect()
            break
        end 

        -- logger.debug(SERVICE_NAME, "res: ", ws_id, res)
        local ok, err = xpcall(handle_resp, debug.traceback, ws_id, cjson.decode(res))
        if not ok then 
            logger.debug(SERVICE_NAME, err)
        end 
        websocket.ping(ws_id)
    end 

    skynet.abort()
end 

-- 分割命令
local function split_cmdline(cmdline)
    local split = {}
    for v in string.gmatch(cmdline, "%S+") do 
        table.insert(split, v)
    end 
    return split
end 

-- 搜索加载命令模块
local function fetch_cmds()
    local t = utils_file.scandir("test/cmds")
    for _, v in pairs(t) do 
        local cmd = utils_string.split(v, ".")[1] -- ws、gm
        local cmd_mod = "test.cmds." .. cmd 
        cmds[cmd] = require(cmd_mod)
    end 
end 

-- 执行注册的命令
local function run_command(cmd, ...)
    -- logger.debug(SERVICE_NAME, "run_command: ", cmd, ...)
    local cmd_mod = cmds[cmd]
    if cmd_mod then 
        cmd_mod.run_command(ws_id, ...) 
    end 
end 

-- 命令交互
-- ws login acc
local function console_main_loop()
    local stdin = socket.stdin()
    while true do 
        local cmdline = socket.readline(stdin, "\n")
        if cmdline ~= "" then 
            local split = split_cmdline(cmdline)
            local cmd = split[1]
            local ok, err = xpcall(run_command, debug.traceback, cmd, select(2, table.unpack(split)))
            if not ok then 
                logger.debug(SERVICE_NAME, err)
            end 
        end 
    end 
end 

skynet.start(function()
    dns.server() -- 初始化 dns
    fetch_cmds()
    skynet.fork(websocket_main_loop)
    skynet.fork(console_main_loop)
end)