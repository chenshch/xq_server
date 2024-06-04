local string = require "string"

local _M = {}

function _M.vlist(t)
    local vlist = {}
    local idx = 1
    for _, v in pairs(t) do 
        vlist[idx] = k
        idx = idx + 1
    end 
    return vlist
end 

function _M.klist(t)
    local klist = {}
    local idx = 1
    for k, _ in pairs(t) do 
        klist[idx] = k
        idx = idx + 1
    end 
    return klist
end 

-- table 人类可读
function _M.dump(t) 
    local print_r_cache = {}
    local function sub_print_table(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_table(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end
    if (type(t) == "table") then
        print(tostring(t) .. " {")
        sub_print_table(t, "  ")
        print("}")
    else
        sub_print_table(t, "  ")
    end
    print()
end

return _M 