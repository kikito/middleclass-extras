-----------------------------------------------------------------------------------
-- Callbacks.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com )
-- Mixin that adds callbacks support (i.e. beforeXXX or afterYYY) to classes)
-----------------------------------------------------------------------------------

assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before requiring Callbacks')
assert(Invoker~=nil, 'Invoker not detected. Please require it before requiring Callbacks')
--[[ Usage:

  require 'MiddleClass' -- or similar
  require 'middleclass-extras.Callbacks' -- or 'middleclass-extras.init'
  
  MyClass = class('MyClass')
  MyClass:include(Callbacks)

  -- The following lines create a new method called barWithCallbacks. When executing it:
  --   * obj:foo() will be executed before
  --   * obj:bar() will be executed in the middle
  --   * The function must be executed after bar, printing 'baz'
  MyClass:addCallback('before', 'bar', 'foo')
  MyClass:addCallback('after', 'bar', function() print('baz') end)

  -- It is possible to add more callbacks before or after a given method.

  function MyClass:foo() print 'foo' end
  function MyClass:bar() print 'bar' end

  local obj = MyClass:new()

  obj:barWithCallbacks() -- prints 'foo bar baz'
]]

--------------------------------
--      PRIVATE STUFF
--------------------------------

--[[ holds all the callbacks entries.
     callback entries are just lists of methods to be called before / after some other method is called

  -- m1, m2, m3 & m4 can be method names (strings) or functions
  _entries = {
    Actor = {                           -- class
      update = {                          -- method
        before = {                          -- 'before' actions
          { method = m1, params={} },
          { method = m2, params={'blah', 'bleh'} },
          { method = m3, params={'foo', 'bar'} }
        }
        after = {                           -- 'after' actions
          { method = 'm4', params={1,2} }
        }
      }
    }
  }

]]
local _entries = setmetatable({}, {__mode = "k"}) -- weak table

-- cache for not re-creating methods every time they are needed
local _methodCache = setmetatable({}, {__mode = "k"})

-- private class methods

local function _getEntry(theClass, methodName)
  if  _entries[theClass] ~= nil and _entries[theClass][methodName] ~= nil then
    return _entries[theClass][methodName]
  end
end

local function _getOrCreateEntry(theClass, methodName)
  if  _entries[theClass] == nil then
    _entries[theClass] = {}
  end
  if _entries[theClass][methodName] == nil then
    _entries[theClass][methodName] = { before = {}, after = {} }
  end
  return _entries[theClass][methodName]
end

--[[
Returns all the actions that should be called when a callback is invoked, parsing superclasses
Warning: it returns two separate lists
Format:
{ -- before
  { method='m1', params={1,2} }, 
  { method='m2', params={3,4} }
},
{ -- after
  { method='m3', params={'a','b'} }, 
  { method='m4', params={'foo'} }
}
]]
local function _getActions(instance, methodName)
  local theClass = instance.class
  local before, after = {}, {}
  
  while theClass~=nil do
    local entry = _getEntry(theClass, methodName)
    if entry~=nil then
      for _,action in ipairs(entry.before) do table.insert(before, action) end
      for _,action in ipairs(entry.after) do table.insert(after, action) end
    end
    theClass = theClass.superclass
  end

  return before, after
end

function _invokeActions(instance, actions)
  for _,action in ipairs(actions) do
    if Invoker.invoke(instance, action.method, unpack(action.params)) == false then return false end
  end
end

local function _buildMethodWithCallbacks(methodName, previousMethod)
  return function(instance, ...)
    local before, after = _getActions(instance, methodName)
    local result = nil
    if _invokeActions(instance, before) == false then return false end
    if previousMethod == nil then
      result = { instance[methodName](instance, ...) }
    else
      result = { previousMethod(instance, ...) }
    end
    if _invokeActions(instance, after) == false then return false end
    return unpack(result)
  end
end

local function _addCallbacksToDestroy(theClass)
  -- modify __newindex so it adds callbacks to destroy automatically
  local mt = getmetatable(theClass)
  local prev__newindex = mt.__newindex
  mt.__newindex = function(_, methodName, method)
    prev__newindex(theClass, methodName, method)
    if methodName=='destroy' and type(method)=='function' then
      method = rawget(theClass.__classDict, 'destroy')
      local newMethod = _buildMethodWithCallbacks(methodName, method)
      rawset(theClass.__classDict, 'destroy', newMethod)
    end
  end

  -- re-set destroy so by default it has callbacks
  local existingMethod = rawget(theClass.__classDict, 'destroy')
  if existingMethod == nil then
    existingMethod = function(self)
      super.destroy(self)
    end
  end
  
  theClass.destroy = existingMethod
end

--------------------------------
--      PUBLIC STUFF
--------------------------------

Callbacks = {}

function Callbacks:included(theClass)
  local oldNew = theClass.new
  
  -- add special treatment for initialize
  theClass.new = function(theClass2, ...)
    local instance = oldNew(theClass2, ...)
    
    local _, after = _getActions(instance, 'initialize')
    _invokeActions(instance, after)
    
    return instance
  end

  --add special treatment for destroy on the class itself
  _addCallbacksToDestroy(theClass)

  --add special treatment for destroy on subclasses
  local prevSubclass = theClass.subclass
  theClass.subclass = function(aClass, name, ...)
    local theSubClass = prevSubclass(aClass, name, ...)
    _addCallbacksToDestroy(theSubClass)
    return theSubClass
  end

end

--[[ addCallbacks class method
Usage:

    Actor:addCallback('before', 'update', 'doSomething', 1, 2)

Also valid:

    Actor:addCallback('before', 'update', function(actor, x,y) actor:doSomething(x,y) end, 1, 2)

First parameter must be the string 'before' or the string 'after'
methodName must be a string designatign a method (can be non-existing)
callback can be either a method name or a function
Note: before initialize callbacks will never be executed (after initialize will)
]]
function Callbacks.addCallback(theClass, beforeOrAfter, methodName, callback, ...)
  assert(type(methodName)=='string', 'methodName must be a string')
  assert(beforeOrAfter == 'before' or beforeOrAfter == 'after', 'beforeOrAfter must be either "before" or "after"')
  local tCallback = type(callback)
  assert(tCallback == 'string' or tCallback == 'function', 'callback must be a method name or a function')

  local entry = _getOrCreateEntry(theClass, methodName)

  table.insert(entry[beforeOrAfter], {method = callback, params = {...}})

  if methodName~='initialize' and methodName~='destroy' then
    local methodWithCallbacksName = methodName .. 'WithCallbacks'

    if type(theClass[methodWithCallbacksName]) ~= 'function' then
      theClass[methodWithCallbacksName] = _buildMethodWithCallbacks(methodName)
    end
  end
end


