local skynet = require "skynet"

local _M = {}

-- 一秒只转一次时间戳
local last_sec 
local current_str  

-- 获取当前时间戳
function _M.get_current_sec()
    return math.floor(skynet.time())
end

-- 获取下一天零点的时间戳
function _M.get_next_zero(cur_time, zero_point)
    zero_point = zero_point or 0 
    cur_time = cur_time or _M.get_current_sec() 
    local t = os.date("*t", cur_time) 
    if t.hour >= zero_point then 
        t = os.date("*t", cur_time + 24 * 3600) 
    end 
    local zero_date = {
        year = t.year, 
        month = t.month, 
        day = t.day, 
        hour = zero_point,
        min = 0, 
        sec = 0,
    }
    return os.time(zero_date)
end 

-- 获取当前可视化时间
function _M.get_current_time() 
    local cur = _M.get_current_sec()
    if last_sec ~= cur then 
        current_str = os.date("%Y-%m-%d %H:%M:%S", cur)
        last_sec = cur 
    end
    return current_str
end

return _M 