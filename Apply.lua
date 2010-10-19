-----------------------------------------------------------------------------------
-- Apply.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com ) - 4 Mar 2010
-- Makes possible to treat all instances of a class
-----------------------------------------------------------------------------------

assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before using Apply')
assert(Invoker~=nil, 'The Apply module requires the Invoker module in order to work. Please require Invoker before requiring Apply')

--[[ Usage:

  require 'MiddleClass' -- or similar
  require 'middleclass-extras.Apply' -- or 'middleclass-extras.init'

  MyClass = class('MyClass')
  MyClass:includes(Apply)
  
  function MyClass:initialize()
    super.initialize(self)
    self.counter = 0
  end
  
  function MyClass:destroy()
     -- Remove from the list immediately, instead of waiting for the gc
    self:removeFromApply()
    super.destroy(self)
  end
  
  -- If you use object:destroyWithCallbacks() instead of object:destroy() removeFromApply will be used automatically
  
  function MyClass:count() self.counter = self.counter + 1  end
  
  local obj1 = MyClass:new()
  
  MyClass:apply('count')
  
  local obj2 = MyClass:new()
  
  MyClass:apply('count')
  
  print(obj1, obj2) -- prints 2   1
  
  
]]


-- Private stuff


-- The list of instances
_instances = {}

-- Adds an instance to the "list of instances" of its class
local function _add(theClass, instance)
  if not includes(Apply, theClass) then return end
  _instances[theClass] = _instances[theClass] or _G.setmetatable({}, {__mode = "k"})
  _instances[theClass][instance] = instance
  _add(theClass.superclass, instance)
end

-- Removes from the "list of instances"
local function _remove(theClass, instance)
  if not includes(Apply, theClass) then return end
  _remove(theClass.superclass, instance)
  if _instances[theClass] ~= nil then _instances[theClass][instance] = nil end
end

-- The Apply module
Apply = {}

function Apply:included(theClass)
  if not includes(Callbacks, theClass) then
    theClass:include(Callbacks)
  end
  theClass:addCallback('after', 'initialize', function(instance) _add(instance.class, instance) end)
  theClass:addCallback('after', 'destroy', 'removeFromApply')
end

function Apply:removeFromApply()
  _remove(self.class, self)
end

-- Applies some method to all the instances of this class, including subclasses
function Apply.apply(theClass, methodOrName, ...)
  return Apply.applySorted(theClass, nil, methodOrName, ... )
end

-- Applies some method to all the instances of this class, including subclasses
-- Notes:
--   * sortFunc can be provided as a meaning of sorting (table.sort will be used)
--   * a copy of the instances table is allways made so it is safe to call removeFromApply
function Apply.applySorted(theClass, sortFunc, methodOrName, ...)

  local copy,i = {},1
  for _,instance in pairs(_instances[theClass]) do
    copy[i] = instance
    i = i + 1
  end

  if type(sortFunc)=='function' then
    table.sort(copy, sortFunc)
  end

  for _,instance in ipairs(copy) do
    if Invoker.invoke(instance, methodOrName, ...) == false then return false end
  end
  return true
end



