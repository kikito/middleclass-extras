-----------------------------------------------------------------------------------
-- Callbacks.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com )
-- Mixin that adds callbacks support (i.e. beforeXXX or afterYYY) to classes)
-----------------------------------------------------------------------------------

assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before using Callbacks')
assert(Sender~=nil, 'The Callbacks module requires the Sender module in order to work. Please require Sender before requiring Callbacks')

--[[ Usage:

  require 'MiddleClass' -- or similar
  require 'middleclass-extras.Callbacks' -- or 'middleclass-extras.init'
  
  MyClass = class('MyClass')
  MyClass:include(Callbacks)

  -- This means: on MyClass instances, every time the user writes obj:foo(),
  --   * obj:bar() must be executed before
  --   * The function must be executed after
  MyClass:addCallbackAround('foo', 'bar', function() print('baz') end)

  function MyClass:foo() print 'foo' end
  function MyClass:bar() print 'bar' end

  local obj = MyClass:new()

  obj:foo() -- prints 'bar foo baz'
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
local function _getActions(theClass, methodName)
  if theClass==nil then return {} end
  
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

-- given a class and a method, this returns a new version of that method that invokes callbacks
-- uses a cache for not calculating the methods every time
function _getChainedMethod(theClass, methodName, method)

  _methodCache[theClass] = _methodCache[theClass] or setmetatable({}, {__mode = "k"})
  local classCache = _methodCache[theClass]
  
  local chainedMethod = classCache[methodName]
  
  if chainedMethod == nil then
    chainedMethod = function(instance, ...)
      local before, after = _getActions(theClass, methodName)
      if _invokeActions(instance, before) == false then return false end
      local result = method(instance, ...)
      if _invokeActions(instance, after) == false then return false end
      return result
    end
    classCache[methodName] = chainedMethod
  end

  return chainedMethod
end

-- private instance methods

function _invokeActions(instance, actions)
  for _,action in ipairs(actions) do
    if Sender.send(instance, action.method, unpack(action.params)) == false then return false end
  end
  return true
end


--------------------------------
--      PUBLIC STUFF
--------------------------------

Callbacks = {}

function Callbacks:included(theClass)

  if includes(Callbacks, theClass) then return end

  -- Modify the instances __index metamethod so it adds callback chains to methods with callback entries

  local oldNew = theClass.new
  
  theClass.new = function(theClass, ...)
    local instance = oldNew(theClass, ...)

    local prevIndex = getmetatable(instance).__index
    local tIndex = type(prevIndex)

    setmetatable(instance, {
      __index = function(instance, methodName)
        local method

        if     tIndex == 'table'    then method = prevIndex[methodName]
        elseif tIndex == 'function' then method = prevIndex(instance, methodName)
        end

        if type(method)~='function' or _isPlainMethod(theClass, methodName) then return method end

        return _getChainedMethod(theClass, methodName, method)
      end
    })

    -- special treatment for afterInitialize callbacks
    local _, afterInitialize = _getActions(theClass, 'initialize')
    _invokeActions(instance, afterInitialize)

    return instance
  end
 
end

--[[
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


