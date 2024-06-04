local skynet = require "skynet"

local loglevel = {
	debug = 0,
	info = 1,
	warn = 2,
	error = 3,
}

local logger = {
	_level = nil,
	_fmt = "[%s] [%s] %s", -- [info] [label] msg
	_fmt2 = "[%s] [%s %s] %s", --[info] [label labeldata] msg
}

local function init_log_level()
	if not logger._level then
		local level = skynet.getenv "log_level"
		
		local default_level = loglevel.debug
		local val

		if not level or not loglevel[level] then
			val = default_level
		else
			val = loglevel[level]
		end

		logger._level = val
	end
end

function logger.set_log_level(level)
	local val = loglevel.debug

	if level and loglevel[level] then
		val = loglevel[level]
	end

	logger._level = val
end

local function formatmsg(loglevel, label, labeldata, args)
	local filtered_args = {}
	for _, v in pairs(args) do 
		if v ~= nil then 
			table.insert(filtered_args, tostring(v))
		end 
	end 

	local args_len = #filtered_args

	if args_len > 0 then
		args = table.concat(filtered_args, " ")
	else
		args = ""
	end

	local msg
	local fmt = logger._fmt
	if labeldata ~= nil then
		fmt = logger._fmt2
		msg = string.format(fmt, loglevel, label, labeldata, args)
	else
		msg = string.format(fmt, loglevel, label, args)
	end

	return msg
end

--[[
logger.debug("map", "user", 1024, "entered this map")
logger.debug2("map", 1, "user", 2048, "leaved this map")
]]
function logger.debug(label, ...)
	if logger._level <= loglevel.debug then
		local args = {...}
		local msg = formatmsg("debug", label, nil, args)

		skynet.error(msg)
	end
end
function logger.debug2(label, labeldata, ...)
	if logger._level <= loglevel.debug then
		local args = {...}
		local msg = formatmsg("debug", label, labeldata, args)

		skynet.error(msg)
	end
end

function logger.info(label, ...)
	if logger._level <= loglevel.info then
		local args = {...}
		local msg = formatmsg("info", label, nil, args)

		skynet.error(msg)
	end
end
function logger.info2(label, labeldata, ...)
	if logger._level <= loglevel.info then
		local args = {...}
		local msg = formatmsg("info", label, labeldata, args)

		skynet.error(msg)
	end
end

function logger.warn(label, ...)
	if logger._level <= loglevel.warn then
		local args = {...}
		local msg = formatmsg("warn", label, nil, args)

		skynet.error(msg)
	end
end
function logger.warn2(label, labeldata, ...)
	if logger._level <= loglevel.warn then
		local args = {...}
		local msg = formatmsg("warn", label, labeldata, args)

		skynet.error(msg)
	end
end

function logger.error(label, ...)
	if logger._level <= loglevel.error then
		local args = {...}
		local msg = formatmsg("error", label, nil, args)

		skynet.error(msg)
	end
end
function logger.error2(label, labeldata, ...)
	if logger._level <= loglevel.error then
		local args = {...}
		local msg = formatmsg("error", label, labeldata, args)

		skynet.error(msg)
	end
end

skynet.init(init_log_level)

return logger