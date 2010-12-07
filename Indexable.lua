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
    super.initialize(self)
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

-- make the class index-aware. Otherwise, index would be a regular method
local function _modifyClass(theClass)
  -- create a dictionary for instances, using the classDict, and store it on the class (so others can use it a little)
  local classDict = theClass.__classDict
  local instanceDict = {}
  
  for _,mmName in ipairs(theClass.__classDict) do
    instanceDict[mmName] = function(...) return classDict[mmName](...) end
  end
  
  instanceDict.__index = function(instance, name) return classDict[name] or instance:index(name) end
  setmetatable(instanceDict, {__index = classDict})
  rawset(theClass, '__instanceDict', instanceDict)
  
  -- modify the instance creator so instances use __instanceDict and not __classDict
  local oldNew = theClass.new
  theClass.new = function(theClass, ...)
    local instance = oldNew(theClass, ...)
    setmetatable(instance, theClass.__instanceDict)
    return instance
  end
end

Indexable = {}

function Indexable:included(theClass) 
  if includes(Indexable, theClass) then return end
  
  -- modify the class
  _modifyClass(theClass)
  
  -- modify all future subclases of theClass the same way
  local prevSubclass = theClass.subclass
  theClass.subclass = function(aClass, name, ...)
    local theSubClass = prevSubclass(aClass, name, ...)
    _modifyClass(theSubClass)
    return theSubClass
  end
end
