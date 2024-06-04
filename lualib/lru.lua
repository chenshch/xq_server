local list = require "list"

local mt = {}
local lru = {}
mt.__index = lru 

local function lru_remove(self)
    local entry = self.list:Back()

    if entry then 
        local key = entry.key
        local value = entry.value

        self.cache[entry.key] = nil 
        self.list:Remove(entry)
        self.size = self.size - 1
        entry = nil 

        local f = self.on_remove 
        if f then 
            f(key, value)
        end 
    end 
end 

function lru.new(size, on_remove)
    local self = setmetatable({}, mt)
    self.list = list.New()
    self.cache = {} 
    self.capacity = size 
    self.size = 0
    self.on_remove = on_remove
    return self 
end 

function lru.get(self, key)
    local entry = self.cache[key]
    if entry == nil then 
        return 
    end 
    self.list:MoveToFront(entry)
    return entry.value
end 

function lru.set(self, key, value, force)
    local entry = self.cache[key]
    if entry then 
        entry.value = value
        self.list:MoveToFront(entry)
    else 
        local entry = {
            key = key,
            value = value
        }
        self.list:PushFront(entry)
        self.cache[key] = entry
        self.size = self.size + 1
    end 

    while true do 
        if self.size > self.capacity and not force then
            lru_remove(self)
        else
            break 
        end 
    end 
end 

function lru.dump(self)
    local entry = self.list.head 
    while entry do 
        entry = entry.next 
        if entry == self.list.tail then 
            break
        end 
        print(entry.key, entry.value)
    end 
end 

return lru 