local skynet = require "skynet"
local snowflake = require "snowflake"

local CMD = {}
local f

function CMD.snowflake()
    f = io.open("test/snowflake.log", "a+")
    for i = 1, 20 do 
        local uid = snowflake.snowflake()
        f:write(uid, "\n")
    end 
    f:close()
end 

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        skynet.ret(skynet.pack(f(...)))
    end)

    local debug_port = skynet.getenv("debug_console_port")
    skynet.newservice("debug_console", debug_port)
end)

--[[
    ping 8
    call 8 "snowflake"
]]