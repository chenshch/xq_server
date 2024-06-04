local skynet = require "skynet"
local lru = require "lru"

local CMD = {}

local lru_list = {} 
local lru_list_size = 0

function CMD.new_lru(size)
    size = tonumber(size)

    local l = lru.new(size)
    lru_list_size = lru_list_size + 1
    lru_list[lru_list_size] = l 
    return "OK"
end 

function CMD.set_lru(index, key, value)
    index = tonumber(index)

    local l = lru_list[index]
    lru.set(l, key, value)
    print("SET: ", "key = " .. key, " value = " .. value)

    local res = "SET: " .. "key = " .. key .. " value = " .. value
    return res
end 

function CMD.get_lru(index, key)
    index = tonumber(index)

    local l = lru_list[index]
    local v = lru.get(l, key)
    print("GET: ", "key = " .. key, " value = " .. v)

    local res = "GET: " .. "key = " .. key .. " value = " .. v
    return res
end 

function CMD.size_lru(index)
    index = tonumber(index)

    local l = lru_list[index]
    print("size_lru:", l.size)

    return l.size
end 

function CMD.dump_lru(index)
    index = tonumber(index)

    local l = lru_list[index]
    lru.dump(l)

    return "OK"
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
    -- ["LRUCache","put","put","get","put","get","put","get","get","get"]
    -- [[2],    [1,1],  [2,2],  [1],    [3,3],  [2],    [4,4],  [1],    [3],    [4] --]
    -- [null,   null,   null,   1,      null,   -1,     null,   -1,     3,      4]
    ping 8
    call 8 "new_lru", "2"
    call 8 "set_lru", "1", "1", "1"
    call 8 "set_lru", "1", "2", "2"
    call 8 "get_lru", "1", "1"
    call 8 "set_lru", "1", "3", "3"
    call 8 "get_lru", "1", "2"
    call 8 "set_lru", "1", "4", "4"
    call 8 "get_lru", "1", "1"
    call 8 "get_lru", "1", "3"
    call 8 "get_lru", "1", "4"
    call 8 "dump_lru", "1"              --[ [4, 4], [3, 3] --]
]]

--[[
    -- ["LRUCache","put","put","get","put","get","put","get","get","get"]
    -- [[2],    [1,0],  [2,2],  [1],    [3,3],  [2],    [4,4],  [1],    [3],    [4] --]
    -- [null,   null,   null,   0,      null,   -1,     null,   -1,     3,       4]

    ping 8
    call 8 "new_lru", "2"
    call 8 "set_lru", "2", "1", "0"
    call 8 "set_lru", "2", "2", "2"
    call 8 "get_lru", "2", "1"
    call 8 "set_lru", "2", "3", "3"
    call 8 "get_lru", "2", "2"
    call 8 "set_lru", "2", "4", "4"
    call 8 "get_lru", "2", "1"
    call 8 "get_lru", "2", "3"
    call 8 "get_lru", "2", "4"
    call 8 "dump_lru", "2"              --[ [4, 4], [3, 3] --]
]]

-- call 8 "size_lru", "1"