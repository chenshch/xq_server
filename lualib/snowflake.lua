local skynet = require "skynet"

local _M = {}
local snowflake_service = {} -- service: begin - end 
local max_service_id
local cur_service_id = 0

-- 获取一个 snowflake 服务
local function get_snowflake_service()
    cur_service_id = cur_service_id + 1
    if cur_service_id > max_service_id then 
        cur_service_id = 1
    end 

    return snowflake_service[cur_service_id]
end 

-- 对外接口，雪花 id 算法生成
function _M.snowflake()
    local addr = get_snowflake_service()
    return skynet.call(addr, "lua", "snowflake")
end 

skynet.init(function()
    skynet.uniqueservice("snowflake")

    local snowflake_begin = tonumber(skynet.getenv("snowflake_begin")) or 1
    local snowflake_end = tonumber(skynet.getenv("snowflake_end")) or 10
    assert(snowflake_begin <= snowflake_end, "snowflake_begin or snowflake_end error")

    local i = 0
    for id = snowflake_begin, snowflake_end do  
        i = i + 1
        local service_name = string.format(".snowflake_%s", id)
        snowflake_service[i] = skynet.localname(service_name) --  返回同一进程内，用 register 注册的具名服务的地址。
    end 
    max_service_id = i
end)

return _M 