local skynet = require "skynet"
local logger = require "logger"

local pack = table.pack 
local unpack = table.unpack
local traceback = debug.traceback 
local xpcall = xpcall

local _M = {} 

-- 前置理解：每个timerid都只会映射到一个帧上，不会同时多个

local is_init = false   -- 标记模块是否初始化
local timer_inc_id = 1  -- 定时器的自增 ID
local cur_frame = 0     -- 当前帧，一帧对应一秒
local cur_timestamp = 0 -- 当前时间戳，运行到的秒数
local timer_size = 0    -- 定时器数量
local frame_size = 0    -- 帧数量

local timer2frame = {}  -- 定时器ID 映射 帧
local frame2cbs = {}    -- 帧 映射 多个回调任务
--[[
    frame: {
        timers: {
            timerid: { sec, cb, args, is_repeat },
            timerid: { sec, cb, args, is_repeat }
        }, 
        size: 1
    }
]]

local function now() 
    return skynet.time() // 1 -- 截断小数：.0
end     

-- 删除定时器
local function del_timer(id) 
    -- 获取定时器id 映射 帧
    local frame = timer2frame[id]
    if not frame then return end 

    -- 获取该帧对应的任务
    local cbs = frame2cbs[frame]
    if not cbs or not cbs.timers then return end 

    -- 如果这个帧中的定时器任务存在
    if cbs.timers[id] then 
        cbs.timers[id] = nil -- 删除该定时器任务
        cbs.size = cbs.size - 1 -- 当前帧的任务数 -1
    end 

    -- 当前删掉了这一帧的最后一个定时器任务
    if cbs.size == 0 then 
        frame2cbs[frame] = nil -- 置空
        frame_size = frame_size - 1 -- 帧数 -1 
    end 

    -- 当前定时器id对应的帧置空，且定时器数量 -1
    timer2frame[id] = nil 
    timer_size = timer_size - 1
end 

local function init_timer(id, sec, f, args, is_repeat)
    -- 第一步：定时器 id 映射 帧
    local offset_frame = sec -- sec 帧后开始当前任务 
    
    -- 矫正帧数
    if now() > cur_timestamp then 
        offset_frame = offset_frame + 1
    end 
    -- 实际计算执行帧
    local fix_frame = cur_frame + offset_frame

    -- 第二步：该帧 映射 定时器任务
    local cbs = frame2cbs[fix_frame]
    if not cbs then 
        -- 创新当前帧的任务集
        cbs = { timers = {}, size = 1 }
        frame2cbs[fix_frame] = cbs 
        frame_size = frame_size + 1 
    else 
        cbs.size = cbs.size + 1
    end 

    cbs.timers[id] = {sec, f, args, is_repeat}
    timer2frame[id] = fix_frame

    timer_size = timer_size + 1

    if timer_size >= 500 then 
        logger.warn("timer", "timer is too many!")
    end 
end 

-- 逐帧执行
local function main_loop()
    skynet.timeout(100, main_loop)
    cur_timestamp = now()
    cur_frame = cur_frame + 1

    -- 当前没有定时器任务
    if timer_size <= 0 then return end 

    -- 当前帧对应的回调任务
    local cbs = frame2cbs[cur_frame]
    if not cbs then return end 

    -- 当前帧的回调任务数量为0
    if cbs.size <= 0 then 
        frame2cbs[cur_frame] = nil 
        frame_size = frame_size - 1 -- 该帧执行完毕
        return 
    end 

    -- task: {sec, cb, args, is_repeat}
    for timerid, task in pairs(cbs.timers) do 
        local f = task[2] 
        local args = task[3]
        local ok, err = xpcall(f, traceback, unpack(args, 1, args.n))
        if not ok then 
            logger.error("timer", "crontab is run in error:", err)
        end 
        del_timer(timerid) -- 执行成功与否都需要删掉当前这个定时器

        local is_repeat = task[4]
        if is_repeat then 
            local sec = task[1]
            init_timer(timerid, sec, f, args, is_repeat)
        end 
    end 

    -- 当前这一帧所有任务执行完，并且这一帧没有删(双重保障（del_timer）)，删掉当前帧
    if frame2cbs[cur_frame] then 
        frame2cbs[cur_frame] = nil 
        frame_size = frame_size - 1
    end 
end 

if not is_init then 
    is_init = true -- 初始化定时器模块
    skynet.timeout(100, main_loop)
end 



------- API ------ 

-- 新增定时器 timer，sec 秒后执行函数 f
-- 返回定时器 ID
function _M.timeout(sec, f, ...)
    assert(sec > 0)
    timer_inc_id = timer_inc_id + 1
    init_timer(timer_inc_id, sec, f, pack(...), false)
    return timer_inc_id
end 

function _M.timeout_repeat(sec, f, ...) 
    assert(sec > 0)
    timer_inc_id = timer_inc_id + 1
    init_timer(timer_inc_id, sec, f, pack(...), true)
    return timer_inc_id
end 

-- 取消定时器任务
function _M.cancel(id)
    del_timer(id)
end 

-- 检查定时器是否存在
function _M.exist(id)
    if timer2frame[id] then return true end 
    return false 
end 

-- 获取定时器还有多久执行
function _M.get_remain(id)
    local frame = timer2frame[id] 
    if frame then 
        return frame - cur_frame
    end 
    return -1
end 

return _M 