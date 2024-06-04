local skynet = require "skynet"
require "skynet.manager"
local logger = require "logger"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local socketdriver = require "skynet.socketdriver"

local utils_table = require "utils.table"
local batch = require "batch"


local WATCHDOG -- ws_watchdog 服务地址
local MAXCLIENT -- 客户端数量上限

local connection = {} -- fd -> connection : { fd, client, agent, ip }
local forwarding = {} -- agent -> connection
local CMD = {} -- gate 服务接口
local handler = {} -- websocket 操作接口
local client_number = 0 -- 在线客户端数量

local function unforward(c)
    if c.agent then 
        forwarding[c.agent] = nil 
        c.agent = nil 
        c.client = nil 
    end 
end 

local function close_fd(fd)
    local c = connection[fd]
    if c then 
        unforward(c) 
        connection[fd] = nil 
        client_number = client_number - 1
    end     
end 


------- handler --------

function handler.connect(fd)
    logger.debug(SERVICE_NAME, "ws connect from: ", tostring(fd))
    if client_number >= MAXCLIENT then 
        socketdriver.close(fd) -- skynet/lualib-src/lua-socket.c
        return 
    end 
    if nodelay then 
        socketdriver.nodelay(fd)
    end 

    client_number = client_number + 1
    local addr = websocket.addrinfo(fd) -- skynet/lualib/http/websocket.lua
    local c = {
        fd = fd,
        ip = addr, 
    }
    connection[fd] = c

    skynet.send(WATCHDOG, "lua", "socket", "open", fd, addr)
end 

function handler.handshake(fd, header, url) 
    local addr = websocket.addrinfo(fd) 
    logger.debug(SERVICE_NAME, "ws handshake from: ", tostring(fd), ", url: ", url, ", addr: ", addr)
end 

function handler.message(fd, msg)
    logger.debug(SERVICE_NAME, "ws message from: ", tostring(fd), ", msg: ", msg)
    -- recv a package, forward it
    local c = connection[fd]
    local agent = c and c.agent 
    if agent then 
        -- msg is string
        skynet.redirect(agent, c.client, "client", fd, msg) -- https://github.com/cloudwu/skynet/wiki/APIList#:~:text=redirect(addr%2C%20source%2C%20type%2C%20...)%20%E4%BC%AA%E8%A3%85%E6%88%90%20source%20%E5%9C%B0%E5%9D%80%EF%BC%8C%E5%90%91%20addr%20%E5%8F%91%E9%80%81%E4%B8%80%E4%B8%AA%E6%B6%88%E6%81%AF%E3%80%82
    else
        skynet.send(WATCHDOG, "lua", "socket", "data", fd, msg)
    end 
end 

function handler.ping(fd)
    logger.debug(SERVICE_NAME, "ws ping from: ", tostring(fd))
end

function handler.pong(fd)
    logger.debug(SERVICE_NAME, "ws pong from: ", tostring(fd))
end

function handler.close(fd, code)
    logger.debug(SERVICE_NAME, "ws close from: ", tostring(fd))
    close_fd(fd)
    skynet.send(WATCHDOG, "lua", "socket", "close", fd)
end

function handler.error(fd)
    logger.error(SERVICE_NAME, "ws error from: ", tostring(fd))
    close_fd(fd)
    skynet.send(WATCHDOG, "lua", "socket", "error", fd)
end

function handler.warning(fd, size)
    skynet.send(WATCHDOG, "lua", "socket", "warning", fd, size)
end

----- CMD -------

-- call by ws_watchdog(start)
function CMD.open(source, conf) 
    WATCHDOG = conf.watchdog or source 
    MAXCLIENT = conf.maxclient or 1024
    nodelay = conf.nodelay
    local protocol = conf.protocol or "ws"
    local port = assert(conf.port)

    local address = conf.address or "0.0.0.0"
    local fd = socket.listen(address, port)
    logger.info(SERVICE_NAME, string.format("Listen websocket port: %s protocol: %s", port, protocol))
    socket.start(fd, function(fd, addr) -- https://github.com/cloudwu/skynet/wiki/Socket#:~:text=socket.start(id%20%2C%20accept)%20accept%20%E6%98%AF%E4%B8%80%E4%B8%AA%E5%87%BD%E6%95%B0%E3%80%82%E6%AF%8F%E5%BD%93%E4%B8%80%E4%B8%AA%E7%9B%91%E5%90%AC%E7%9A%84%20id%20%E5%AF%B9%E5%BA%94%E7%9A%84%20socket%20%E4%B8%8A%E6%9C%89%E8%BF%9E%E6%8E%A5%E6%8E%A5%E5%85%A5%E7%9A%84%E6%97%B6%E5%80%99%EF%BC%8C%E9%83%BD%E4%BC%9A%E8%B0%83%E7%94%A8%20accept%20%E5%87%BD%E6%95%B0%E3%80%82%E8%BF%99%E4%B8%AA%E5%87%BD%E6%95%B0%E4%BC%9A%E5%BE%97%E5%88%B0%E6%8E%A5%E5%85%A5%E8%BF%9E%E6%8E%A5%E7%9A%84%20id%20%E4%BB%A5%E5%8F%8A%20ip%20%E5%9C%B0%E5%9D%80%E3%80%82%E4%BD%A0%E5%8F%AF%E4%BB%A5%E5%81%9A%E5%90%8E%E7%BB%AD%E6%93%8D%E4%BD%9C%E3%80%82
        logger.info(SERVICE_NAME, string.format("accept client socket_fd: %s addr: %s", fd, addr))
        websocket.accept(fd, handler, protocol, addr) -- https://github.com/cloudwu/skynet/blob/89b47f93723d03f4dd275a9dbab52b267a40dd89/lualib/http/websocket.lua#L407
    end)
end 

-- call by ws_watchdog(SOCKET.close)
-- call by ws_agent(mng.close_fd)
function CMD.kick(source, fd)
    websocket.close(fd)
end 

function CMD.response(source, fd, msg)
    logger.debug(SERVICE_NAME, "ws response: ", tostring(fd), ", msg: ", msg)
    websocket.write(fd, msg)
end 

function CMD.forward(source, fd, client, address)
    local c = assert(connection[fd])
    unforward(c)
    c.client = client or 0 
    c.agent = address or source 
    forwarding[c.agent] = c 
end 

-- 发送消息接口
local function send_msg(fd, msg)
    logger.debug(SERVICE_NAME, "send_msg", "fd:", fd, "msg:", msg)
    if connection[fd] then 
        websocket.write(fd, msg)
    end 
end 

-- 广播消息接口
function CMD.broadcast(source, msg)
    logger.debug(SERVICE_NAME, "broadcast: ", msg)
    local fds = utils_table.klist(connection)
    -- 调用批处理接口
    local ok, err = batch.new_batch_task({"broadcast", source, msg}, 1, 100, fds, send_msg, msg)
    if not ok then 
        logger.error(SERVICE_NAME, "broadcast error", "err:", err)
    end 
end 

----------------------------------


skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
}

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if not f then 
            logger.error(SERVICE_NAME, "Can't dispatch cmd:", (cmd or "nil"))
            skynet.ret(skynet.pack({ok=false}))
            return 
        end 
        if session == 0 then 
            f(source, ...) -- 如果会话ID等于0，表示这是一个不需要回应的消息，也就是用skynet.send发送的消息。
        else 
            skynet.ret(skynet.pack(f(source, ...)))
        end 
    end)

    skynet.register(".ws_gate")
    logger.info(SERVICE_NAME, "ws_gate", "start")
end)