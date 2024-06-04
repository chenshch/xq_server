local _M = {}

function _M.syscmd(cmd)
    local t, popen = {}, io.popen
    local pfile = popen(cmd)
    for l in pfile:lines() do 
        table.insert(t, l)
    end 
    pfile:close()
    return t 
end 

function _M.scandir(dir)
    return _M.syscmd('ls "' .. dir .. '"')
end 

return _M 