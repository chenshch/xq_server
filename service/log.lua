local skynet = require "skynet"
require "skynet.manager"
local time = require "utils.time"

-- 日志目录
local logpath = skynet.getenv("logpath") or "log"
-- 日志文件名
local logtag  = skynet.getenv("logtag") or "game"
local logfilename = string.format("%s/%s.log", logpath, logtag)
local logfile = io.open(logfilename, "a+")

-- 写文件
local function write_log(file, str) 
    file:write(str, "\n")
    file:flush()

    print(str)
end 

-- 切割日志文件，重新打开日志
local function reopen_log() 
    -- 下一天零点再次执行
    local future = time.get_next_zero() - time.get_current_sec()
    skynet.timeout(future * 100, reopen_log)

    if logfile then logfile:close() end 

    local date_name = os.date("%Y%m%d%H%M%S", time.get_current_sec())
    local newname = string.format("%s/%s-%s.log", logpath, logtag, date_name)
    os.rename(logfilename, newname) -- logfilename文件内容剪切到newname文件
    logfile = io.open(logfilename, "a+") -- 重新持有logfilename文件
end 

-- 注册日志服务处理函数
skynet.register_protocol {
    name = "text", 
    id = skynet.PTYPE_TEXT, 
    unpack = skynet.tostring, 
    dispatch = function(_, source, str)
        local now = time.get_current_time()
        str = string.format("[%08x][%s] %s", source, now, str)
        write_log(logfile, str)
    end 
}

-- 捕捉sighup信号（kill -1） 执行安全关服逻辑
skynet.register_protocol {
    name = "SYSTEM", 
    id = skynet.PTYPE_SYSTEM, 
    unpack = function(...) return ... end,
    dispatch = function()
        -- 执行必要服务的安全退出操作
        local cached = skynet.localname(".cached")
        if cached then 
            skynet.call(cached, "lua", "SIGHUP")
        end 

        skynet.sleep(100)
        skynet.abort()
    end 
}

local CMD = {} 

skynet.start(function()
    skynet.register(".log")
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then 
            skynet.ret(skynet.pack(f(...)))
        else 
            skynet.error(string.format("invalid command: [%s]", cmd))
        end
    end)

    local ok, msg = pcall(reopen_log)
    if not ok then 
        print(msg)
    end 
end)