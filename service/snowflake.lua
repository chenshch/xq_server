local skynet = require "skynet"
require "skynet.manager"

local mode, slave_id = ... 
local CMD = {}

if mode == "slave" then 

-------- slave --------

-- 将 2000-01-01 形式日期，转为时间戳
local function parse_date(date)
    local year, month, day = date:match("(%d+)-(%d+)-(%d+)")
    return os.time({year = year, month = month, day = day})
end 
local start_date = skynet.getenv("snowflake_start_date") or "2000-01-01"
local START_TIMESTAMP = parse_date(start_date)

-- 每一部分占用位数
local TIME_BIT      = 39    -- 时间占用位数
local SEQUENCE_BIT  = 12    -- 序列号占用位数
local MACHINE_BIT   = 12    -- 机器标识占用位数

-- 每一部分最大值
local MAX_TIME      = 1 << TIME_BIT     -- 时间最大值      ((1 << 39) / 365 * 24 * 3600 * 100) ==> 174 year
local MAX_SEQUENCE  = 1 << SEQUENCE_BIT -- 序列号最大值     (4096)
local MAX_MACHINE   = 1 << MACHINE_BIT  -- 机器标识最大值   (4096)

-- 每一部分向左的偏移
local LEFT_MACHINE  = SEQUENCE_BIT                  -- 12
local LEFT_TIME     = SEQUENCE_BIT + MACHINE_BIT    -- 24

-- 机器标识id
slave_id = tonumber(slave_id)
 -- 服务名
local service_name = string.format(".snowflake_%s", slave_id)

-- 序列号
local sequence = 0
-- 上一次时间戳
local last_timestamp = -1

-- 10ms
local function get_cur_timestamp()
    return math.floor(skynet.time() * 100)
end 

local function get_next_timestamp()
    local cur = get_cur_timestamp()
    while cur <= last_timestamp do 
        cur = get_cur_timestamp()
    end 
    return cur
end 

-- 每 3s 保存最后一次时间戳
local function auto_save_last_timestamp()
    skynet.timeout(3 * 100, auto_save_last_timestamp)

    local f = io.open(service_name, "w+")
    f:write(last_timestamp)
    f:close()
end 

-- 启动从节点服务前，读取上次最后时间戳
skynet.init(function()
    local f = io.open(service_name)
    if f then 
        local save_file_timestamp = f:read("*a")
        f:close()
        last_timestamp = tonumber(save_file_timestamp) or last_timestamp
    end
end)

-- snowflake 接口
function CMD.snowflake()
    local cur = get_cur_timestamp()
    if cur < last_timestamp then 
        error("Clock moved backwards.  Refusing to generate id")
    end 
    if cur == last_timestamp then 
        -- 相同 10ms 内，序列号自增
        sequence = (sequence + 1) & MAX_SEQUENCE

        if sequence == 0 then 
            cur = get_next_timestamp()
        end 
    else 
        -- 不同 10ms 内，序列号置 0
        sequence = 0
    end 
    
    last_timestamp = cur

    return (cur - START_TIMESTAMP) << LEFT_TIME | slave_id << LEFT_MACHINE | sequence
end 

-- 启动从节点服务
skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(...)))
    end)
    auto_save_last_timestamp()
    skynet.register(service_name)
end)

else 

-------- master --------
    
-- 启动主节点服务，创建多个从节点服务
skynet.start(function()
    local snowflake_begin = tonumber(skynet.getenv("snowflake_begin")) or 1
    local snowflake_end = tonumber(skynet.getenv("snowflake_end")) or 10
    assert(snowflake_begin <= snowflake_end, "snowflake_begin or snowflake_end error")

    for id = snowflake_begin, snowflake_end do 
        skynet.newservice(SERVICE_NAME, "slave", id)
    end 
    skynet.register(".snowflake")
end)

end 