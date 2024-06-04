local _M = {}
local RPC = {}
local gm_cmds = {} -- 指令模块

-- 删除首尾空格
local function trim(str)
    return str:match("^%s*(.-)%s*$")
end 

-- 解析指令参数
local function parse_cmd_args(uid, args_format, ...)
    local args = table.pack(...)
    local real_args = {}
    local n = 0 

    local parse_cnt = 0 
    for i = 1, #args_format do 
        local arg_type = args_format[i]
        if arg_type == "uid" then 
            n = n + 1
            real_args[n] = uid 
        elseif arg_type == "string" then 
            n = n + 1
            parse_cnt = parse_cnt + 1
            local arg = args[parse_cnt]
            if not arg then arg = "nil" end 
            if arg == "nil" then 
                real_args[n] = nil 
            else 
                real_args[n] = arg
            end 
        elseif arg_type == "number" then 
            n = n + 1
            parse_cnt = parse_cnt + 1
            local arg = args[parse_cnt]
            if not arg then arg = "nil" end 
            if arg == "nil" then 
                real_args[n] = nil 
            else 
                real_args[n] = tonumber(arg) 
            end 
        elseif arg_type == "boolean" then 
            n = n + 1
            parse_cnt = parse_cnt + 1
            local arg = args[parse_cnt]
            if arg and arg == "true" then
                real_args[n] = true
            else 
                real_args[n] = false
            end 
        end 
    end 
    return true, n, real_args
end 

-- 执行对应模块下的 CMD 中对应的指令 cmd
function _M.do_cmd(CMD, uid, cmd, ...)
    if not cmd then return false, "empty command" end 
    local cb = CMD[cmd]
    if not cb then return false, "unknow command" end 

    local func = cb.func 
    local args_format = cb.args 

    local ok, n, args = parse_cmd_args(uid, args_format, ...)
    if not ok then 
        return ok, "invalid args"
    end 

    return func(table.unpack(args, 1, n))
end 


-------- RPC ---------

-- req.cmd: "user" "setname" "cauchy" 
-- GM 指令:   模块、指令、参数
function RPC.c2s_gm_run_cmd(req, fd, uid)
    local iter = string.gmatch(trim(req.cmd), "[^ ,]+")
    local mod = iter() -- 获取第一个参数：cmd
    local args = {}
    for v in iter do 
        table.insert(args, v)
    end 

    local ok = false
    local msg 
    -- 获取对应模块
    local m = gm_cmds[mod]
    if m then 
        ok, msg = _M.do_cmd(m.CMD, uid, table.unpack(args))
    else 
        msg = "invalid cmd!"
    end 

    local res = {
        pid = "c2s_gm_run_cmd",
        ok = ok, 
        msg = msg,
    }
    return res
end 

function _M.init() 
    gm_cmds.user = require "ws_agent.gm.user"
end 

_M.RPC = RPC

return _M 