local cjson = require "cjson"
local websocket = require "http.websocket"

local _M = {}

------------  CMD -----------------

-- 执行指令
function _M.run_command(ws_id, ...)
    local cmd = table.concat({...}, " ")
    local req = {
        pid = "c2s_gm_run_cmd",
        cmd = cmd,
    }
    websocket.write(ws_id, cjson.encode(req))
end 

return _M 