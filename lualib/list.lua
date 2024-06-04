local list = {} 
local mt = { __index = list }

-- entry { key, value, next, prev }

function list.New()
    local self = setmetatable({}, mt)
    self.size = 0
    self.head = {}
    self.tail = {} 
    self.head.next = self.tail 
    self.tail.prev = self.head 
    return self 
end 

function list.Back(self)
    if self.size ~= 0 then 
        return self.tail.prev 
    end 
    return nil 
end 

-- insert entry after at; list.size++; return entry
local function insert(self, entry, at)
    entry.prev = at 
    entry.next = at.next 
    entry.prev.next = entry 
    entry.next.prev = entry
    self.size = self.size + 1
    return entry
end 

function list.PushFront(self, entry)
    return insert(self, entry, self.head)
end 

-- move entry after at;
local function move(self, entry, at)
    if entry == at then 
        return 
    end 

    entry.prev.next = entry.next 
    entry.next.prev = entry.prev

    entry.prev = at
    entry.next = at.next

    entry.prev.next = entry
    entry.next.prev = entry
end 

function list.MoveToFront(self, entry)
    if entry == self.head or self.size <= 1 then 
        return 
    end 

    move(self, entry, self.head)
end 

function list.Remove(self, entry)
    if entry == nil then 
        return 
    end

    entry.prev.next = entry.next
    entry.next.prev = entry.prev
    entry.next, entry.prev, entry.key, entry.value = nil, nil, nil, nil
    entry = nil  

    self.size = self.size - 1
end 

return list 