-----------------------------------------------------------------------------------
-- Indexable.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com ) - 11 Aug 2010
-- mixin that includes index method (*NOT* an __index metamethod) on instances of middleclass
-----------------------------------------------------------------------------------

--[[ Usage:

  require 'middleclass' -- or similar
  require 'middleclass-extras.init' -- or 'middleclass-extras'

  MyClass = class('MyClass'):include(Indexable)
  function MyClass:initialize(a,b,c)
    self.a, self.b, self.c = a,b,c
  end
  
  function MyClass:index(name) -- attention! index, not __index !
    return 'could not find ' .. tostring(name)
  end
  
  local x = MyClass:new(1,2,3)
  
  print(x.a) -- 1
  print(x.b) -- 2
  print(x.c) -- 3
  print(x.d) -- 'could not find d'

]]

assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before using Indexable')

local _metamethods = { -- all metamethods except __index
  '__add', '__call', '__concat', '__div', '__le', '__lt', '__mod', '__mul', '__pow', '__sub', '__tostring', '__unm' 
}


local function _createInstanceDict(theClass)
  local classDict = theClass.__classDict
  local instanceDict = {}
  
  for _,mmName in ipairs(_metamethods) do
    instanceDict[mmName] = function(...) return classDict[mmName](...) end
  end
  
  instanceDict.__index = function(instance, name) return classDict[name] or instance:index(name) end
  setmetatable(instanceDict, {__index = classDict})
  return instanceDict
end

local function _modifyAllocateMethod(theClass)
  local instanceDict = _createInstanceDict(theClass)
  local classDict = theClass.__classDict

  rawset(theClass, '__instanceDict', instanceDict)
  
  -- modify the instance creator so instances use __instanceDict and not __classDict
  local oldAllocate = theClass.allocate
  function theClass.allocate(theClass, ...)
    return setmetatable(oldAllocate(theClass, ...), theClass.__instanceDict)
  end
  
  return theClass
end

local function _modifySubclassMethod(theClass)
  local prevSubclass = theClass.subclass
  theClass.subclass = function(aClass, name, ...)
    return _modifyAllocateMethod(prevSubclass(aClass, name, ...))
  end
end

Indexable = {}

function Indexable:included(theClass) 
  if includes(Indexable, theClass) then return end
  _modifyAllocateMethod(theClass)
  _modifySubclassMethod(theClass)
end
