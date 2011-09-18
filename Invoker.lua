-----------------------------------------------------------------------------------
-- Invoker.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com ) - 4 Mar 2010
-- Helper function that simplifies method invocation via method names or functions
-----------------------------------------------------------------------------------

--[[ Usage:

  require 'middleclass' -- or similar
  require 'middleclass-extras.init' -- or 'middleclass-extras'

  MyClass = class('MyClass')
  MyClass:include(Invoker)
  function MyClass:foo(x,y) print('foo executed with params', x, y) end

  local obj = MyClass:new()

  obj:invoke('foo', 1,2) -- foo executed with params 1 2
  obj:invoke( function(self, x, y)
    print('nameless function executed with params', x, y)
  , 3, 4) -- nameless function executed with params 3, 4
  
  Notes:
   * The function first parameter must allways be self
   * You can use Invoker independently: Invoker.invoke(obj, 'method')
]]

assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before using Beholder')


local function _invokeString(self, methodName, ...)
  local method = self[methodName]
  assert(type(method)=='function', 'Could not find ' .. methodName .. ' in ' .. tostring(self))
  return method(self, ...)
end

local function _invokeFunction(self, func, ...)
  return func(self, ...)
end

local _functionByType = { ['string'] = _invokeString, ['function'] = _invokeFunction }

Invoker = {

  invoke = function(self, methodOrName, ...)
    local f = _functionByType[type(methodOrName)]
    if f then return f(self, methodOrName, ...) end

    error('methodOrName should be either a function or string. It was a '.. type(methodOrName) .. ': ' .. tostring(methodOrName))
    
  end

}


