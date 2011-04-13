-----------------------------------------------------------------------------------
-- Accessible.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com ) - 11 April 2011
-- Small mixin for classes with properties (get + set)
-----------------------------------------------------------------------------------

--[[ Usage:

  require 'middleclass' -- or similar
  require 'middleclass-extras.init' -- or 'middleclass-extras'

  MyClass = class('MyClass'):include(Accessible)

  MyClass:propertyGet('name') -- read-only, real variable is self._name
  MyClass:propertySet('age')  -- write-only, real variable is self._age
  MyClass:property('color')   -- read + write on property _color

]]

assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before using Accessible')

local function _addAccessorsToClass(theClass)
  theClass.accessors = {}
  if theClass.superclass then
    setmetatable(theClass.accessors, { __index = theClass.superclass.accessors })
  end
  return theClass
end

local function _copyMetamethods(oldDict, newDict)
  local metamethods = oldDict.__metamethods
  for i = 1,#metamethods do
    local mmName = metamethods[i]
    newDict[mmName] = oldDict[mmName]
  end
  return newDict
end

local function _modifyInstanceDict(instance)
  local oldDict = getmetatable(instance)
  local newDict = _copyMetamethods(oldDict, {})
  newDict.__index = function() end -- FIXME
  return instance
end

local function _modifyAllocateMethod(theClass)
  local oldAllocate = theClass.allocate
  theClass.allocate = function(aClass)
    return _modifyInstanceDict(oldAllocate(aClass))
  end
end

local function _modifySubclassMethod(theClass)
  local oldSubclass = theClass.subclass
  theClass.subclass = function(aClass, name)
    return _modifyClass(oldSubClass(aClass, name))
  end
end

Accessible = {}

function Accessible:included(theClass)
  _addAccessorsToClass(theClass)
  _modifySubclassMethod(theClass)
  _modifyAllocateMethod(theClass)
end

function Accessible.accessor(theClass, name)

end
