-----------------------------------------------------------------------------------
-- Apply.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com ) - 4 Mar 2010
-- Makes possible to treat all instances of a class
-----------------------------------------------------------------------------------

assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before using Apply')
assert(Invoker~=nil, 'The Apply module requires the Invoker module in order to work. Please require Invoker before requiring Apply')

--[[ Usage:

  require 'middleclass' -- or similar
  require 'middleclass-extras.init' -- or 'middleclass-extras'

  MyClass = class('MyClass')
  MyClass:include(Apply)

  function MyClass:initialize()
    self.counter = 0
  end -- the instance will be automatically added to the list here (after initialize)

  function MyClass:count() self.counter = self.counter + 1  end
  
  local obj1 = MyClass:new()
  
  MyClass:apply('count')
  
  local obj2 = MyClass:new()
  
  MyClass:apply('count')
  
  print(obj1.counter, obj2.counter) -- prints 2   1
  
  -- instances will be automatically removed from the list after invoking destroy (obj1:destroy() or obj2:destroy())
  
  
]]


--------------------------------
--      PRIVATE STUFF
--------------------------------

-- Creates the list of instances for a class
local function _modifyClass(theClass)
  theClass._instances = setmetatable({}, {__mode = "kv"})
end

-- subclasses should also have the _istances list
local function _modifySubclassMethod(theClass)
  local prevSubclass = theClass.subclass
  
  theClass.subclass = function(aClass, ...)
    local theSubClass = prevSubclass(aClass, ...)
    _modifyClass(theSubClass)
    return theSubClass
  end
end

-- Adds an instance to the "list of instances" of its class
local function _add(theClass, instance)
  if not includes(Apply, theClass) then return end
  theClass._instances[instance] = instance
  _add(theClass.superclass, instance)
end

-- Removes from the "list of instances"
local function _remove(theClass, instance)
  if not includes(Apply, theClass) then return end
  _remove(theClass.superclass, instance)
  theClass._instances[instance] = nil
end

local function _copyTable(t)
  local copy,i = {},1
  for _,item in pairs(t) do
    copy[i] = item
    i = i + 1
  end
  return copy
end

--------------------------------
--      PUBLIC STUFF
--------------------------------

-- The Apply module
Apply = {}

-- Applies some method to all the instances of this class, including subclasses
function Apply.apply(theClass, methodOrName, ...)
  return Apply.applySorted(theClass, nil, methodOrName, ... )
end

-- Applies some method to all the instances of this class, including subclasses
-- Notes:
--   * sortFunc can be provided as a meaning of sorting (table.sort will be used). Can be nil (no order)
--   * a copy of the instances table is always made so calling removeFromApply is safe inside apply
function Apply.applySorted(theClass, sortFunc, methodOrName, ...)

  -- this copy is needed in case the invoked function results in an item deletion
  local instances = _copyTable(theClass._instances)

  if type(sortFunc)=='function' then
    table.sort(instances, sortFunc)
  end

  for _,instance in ipairs(instances) do
    if Invoker.invoke(instance, methodOrName, ...) == false then return false end
  end
  return true
end

--------------------------------
--      INCLUDED
--------------------------------

-- modifies the class that includes this module. For internal use only.
function Apply:included(theClass)
  if includes(Apply, theClass) then return end

  theClass:include(Callbacks)
  theClass:before('initialize', function(instance) _add(instance.class, instance) end)
  theClass:after('destroy', function(instance) _remove(instance.class, instance) end)

  _modifyClass(theClass)
  _modifySubclassMethod(theClass)

end



