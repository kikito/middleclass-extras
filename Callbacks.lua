-----------------------------------------------------------------------------------
-- Callbacks.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com )
-- Mixin that adds callbacks support (i.e. beforeXXX or afterYYY) to classes)
-----------------------------------------------------------------------------------

assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before using Callbacks')

--[[ Usage:

  require 'MiddleClass' -- or similar
  require 'middleclass-extras.Callbacks' -- or 'middleclass-extras.init'
  
  MyClass = class('MyClass')
  MyClass:include(Callbacks)

  -- This means:
  --   * obj:bar() must be executed before before foo as a callback
  --   * The function must be executed after after foo
  MyClass:addCallback('before', 'bar', 'foo')
  MyClass:addCallback('after', 'bar', function() print('baz') end)

  function MyClass:foo() print 'foo' end
  function MyClass:bar() print 'bar' end

  local obj = MyClass:new()

  obj:invokeWithCallbacks('bar') -- prints 'foo bar baz'
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

-- returns true only if there is the method has no entries on theClass or any of theClass' superclasses
local function _isPlainMethod(theClass, methodName)
  if theClass == nil then return true end
  if _entries[theClass] ~= nil and _entries[theClass][methodName] ~= nil then return false end
  return _isPlainMethod(theClass.superclass, methodName)
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
  if actions == nil then return end
  for _,action in ipairs(actions) do
    if instance:invokeWithCallbacks(action.method, unpack(action.params)) == false then return false end
  end
end

--------------------------------
--      PUBLIC STUFF
--------------------------------

Callbacks = {}

function Callbacks:included(theClass)
  local oldNew = theClass.new
  
  theClass.new = function(theClass2, ...)
    local instance = oldNew(theClass2, ...)
    
    local _, after = _getActions(instance, 'initialize')
    _invokeActions(instance, after)
    
    return instance
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
end

--[[ invokeWithCallbacks method
Usage:
    Actor:addCallback('before', 'update', 'foo', 1, 2)
    Actor:addCallback('after', 'update', 'bar', 3, 4)

    local actor = Actor:new()

    local actor:invokeWithCallbacks('update', dt)

This method will invoke:
  1. The callbacks that where added 'before' update. In this case, actor:foo(1,2)
  2. The update method itself
  3. The callbacks that where added 'after' update. In this case, actor:bar(3,4)

Notes:
  * If any of the callbacks returns false, the execution is halted and the method returns false.
  * Otherwise, this method returns what actor:update(dt) returns
  * Callbacks with other callbacks attached will also be executed
]]
function Callbacks:invokeWithCallbacks(functionOrName, ...)
  if type(functionOrName)=='function' then return functionOrName(self, ...)
  elseif type(functionOrName)=='string' then
    local before, after = _getActions(self, functionOrName)
    if _invokeActions(self, before) == false then return false end
    local result = self[functionOrName](self, ...)
    if _invokeActions(self, after) == false then return false end
    return result
  else
    error('functionOrName must be either a string or a function. Was a ' .. type(functionOrName))
  end
end


