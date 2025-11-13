local Class = {}
Class.__index = Class

--Default
function Class:new()    end

--Derive Class
function Class:derive(type)
    local class = {}
    class.type = type
    class.__index = class
    class.super = self
    
    -- Set up metatable with __call support
    local mt = {
        __index = self,
        __call = function(tbl, ...)
            local instance = setmetatable({}, tbl)
            instance:new(...)
            return instance
        end
    }
    
    setmetatable(class, mt)
    return class
end

-- Enable calling the base class as a function to create instances
function Class:__call(...)
    local instance = setmetatable({}, self)
    instance:new(...)
    return instance
end

function Class:getType()
    return self.type
end

return Class
