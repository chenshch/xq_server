local skynet = require "skynet"
local mng = require "cached.mng"
local user = require "cached.user"
local item = require "cached.item"
local logger = require "logger"
require "skynet.manager"

local CMD = {}

function CMD.run(func_name, mod, sub_mod, id, ...)
    local func = mng.get_func(mod, sub_mod, func_name)
    local cache = mng.load_cache(mod, sub_mod, id)
    return func(id, cache, ...)
end 

function CMD.SIGHUP()
    logger.info(SERVICE_NAME, "SIGHUP to save db. Doing.")
    mng.do_save_loop()
    logger.info(SERVICE_NAME, "SIGHUP to save db. Down.")
end

function CMD.monitor_lru()
    mng.monitor_cache_list()
end

skynet.start(function()
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(...)))
    end)

    skynet.register(".cached")

    mng.init()
    user.init()
    item.init()
end)