local skynet = require "skynet"
local timer = require "timer"
local utils_table = require "utils.table"

local xpcall = xpcall
local pack = table.pack
local unpack = table.unpack
local traceback = debug.traceback

local all_batch_tasks = {} -- taskid: taskinfo
local all_batch_tasks_cnt = 0 -- 待处理任务数

local _M = {}

-- 判断任务是否正在执行
function _M.is_task_running(tid) 
    return all_batch_tasks[tid] or false
end 

-- 创建新任务
local function new_empty_batch_task(tid)
    local info = {}
    all_batch_tasks[tid] = info 
    all_batch_tasks_cnt = all_batch_tasks_cnt + 1
    return info 
end 

-- 删除任务
function _M.remove_batch_task(tid)
    if all_batch_tasks[tid] and all_batch_tasks[tid].timer then 
        timer.cancel(all_batch_tasks[tid].timer)
    end 
    all_batch_tasks[tid] = nil 
    all_batch_tasks_cnt = all_batch_tasks_cnt - 1
end 

-- 任务心跳循环
local function batch_task_heartbeat(tid)
    local info = all_batch_tasks[tid]
    if not info then return end 

    local list_cnt = #info.list 
    local start_idx = info.deal_idx + 1
    if info.deal_idx > list_cnt then 
        _M.remove_batch_task(tid)
        return 
    end 

    local end_idx = start_idx + info.step - 1
    if end_idx > list_cnt then 
        end_idx = list_cnt
        _M.remove_batch_task(tid)
    else 
        -- 这批次还没处理完，开启定时器等下次再处理
        info.deal_idx = end_idx
        info.timer = timer.timeout(info.interval, batch_task_heartbeat, tid)
    end 

    -- logger.info("batch", "batch task is running", "start_idx:", start_idx, "end_idx:", end_idx)

    -- 处理本批次
    for i = start_idx, end_idx do 
        local ok, err = xpcall(info.func, traceback, info.list[i], unpack(info.args, 1, info.args.n))
        if not ok then 
            skynet.error("batch", "run batch task error", "tid:", tid, "key:", info.list[i], "err:", err)
        end 
    end 
end 

-- list: 一个 array 类型的 table，通过utils_table.(k/v)list 获取

-- tid: 批处理任务 id，传入表则不重，传入字符串则防止重入
-- interval: 任务每批次处理间隔时间
-- step: 每批次处理任务数量
-- list: 需要处理逻辑的数组，作为回调函数的第一个参数
-- cb: 任务处理回调
-- ...: 回调函数其余参数
function _M.new_batch_task(tid, interval, step, list, cb, ...)
    if interval <= 0 then return false, "invalid interval for batch task" end 
    if _M.is_task_running(tid) then return true, "batch task already running" end 

    if #list <= 0 then return true, "empty task list" end 

    local info = new_empty_batch_task(tid) 
    info.timer = timer.timeout(interval, batch_task_heartbeat, tid) 
    info.deal_idx = 0 -- 已处理数量
    info.list = list 
    info.interval = interval
    info.step = step 
    info.func = cb 
    info.args = pack(...)
    return true 
end 

return _M 