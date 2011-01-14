-----------------------------------------------------------------------------------
-- Callbacks.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com )
-- Mixin that adds callbacks support (i.e. beforeXXX or afterYYY) to classes)
-----------------------------------------------------------------------------------

assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before requiring Callbacks')
assert(Invoker~=nil, 'Invoker not detected. Please require it before requiring Callbacks')
--[[ Usage:

  require 'middleclass' -- or similar
  require 'middleclass-extras.init' -- or 'middleclass-extras'
  
  MyClass = class('MyClass')
  MyClass:include(Callbacks)

  function MyClass:foo() print 'foo' end
  function MyClass:bar() print 'bar' end

  -- The following lines modify method bar so:
  MyClass:before('bar', 'foo') -- foo is executed before
  MyClass:after('bar', function() print('baz') end) -- a function invoking bar is executed after

  local obj = MyClass:new()

  obj:bar() -- prints 'foo bar baz'
  obj:barWithoutCallbacks() -- prints 'bar'

  -- It is possible to add more callbacks before or after any method
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
        },
        after = {                           -- 'after' actions
          { method = 'm4', params={1,2} }
        }

      }
    }
  }

]]
local _entries = setmetatable({}, {__mode = "k"}) -- weak table
local _methodCache = setmetatable({}, {__mode = "k"}) -- weak table

-- private class methods

local function _getEntry(theClass, methodName)
  if  _entries[theClass] ~= nil and _entries[theClass][methodName] ~= nil then
    return _entries[theClass][methodName]
  end
end

local function _hasEntry(theClass, methodName)
  if not includes(Callbacks, theClass) then return false end
  if _getEntry(theClass, methodName) ~= nil then return true end
  return _hasEntry(theClass.superclass, methodName)
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

-- invokes the 'before' or 'after' actions obtained with _getActions
function _invokeActions(instance, actions)
  for _,action in ipairs(actions) do
    if Invoker.invoke(instance, action.method, unpack(action.params)) == false then return false end
  end
end

-- returns a function that executes "method", but with before and after actions
-- it also does some optimizations. It uses a cache, and returns the method itself when it
-- doesn't have any entries on the entry list (hence no callbacks)
local function _callbackizeMethod(theClass, methodName, method)

  if type(method)~='function' or not _hasEntry(theClass, methodName) then return method end

  _methodCache[theClass] = _methodCache[theClass] or {}
  
  _methodCache[theClass][method] = _methodCache[theClass][method] or function(instance, ...)
    local before, after = _getActions(instance, methodName)

    if _invokeActions(instance, before) == false then return false end

    local result = { instance[methodName .. 'WithoutCallbacks'](instance, ...) }

    if _invokeActions(instance, after) == false then return false end
    return unpack(result)
  end
  
  return _methodCache[theClass][method]
end

-- modifies a class so:
--   * Its instances return callbackized versions of their methods
--   * But they returns the un-callbackized version of method 'foo' when asked for 'fooWithoutCallbacks'
local function _changeClassDict(theClass)

  -- throw an error when attempting to override an already-overriden new method.
  -- if theClass is the class that originally implemented Callbacks, (not a subclass of it)
  -- and it has a non-standard implementation of new, then throw the error.
  assert( includes(Callbacks, theClass.superclass) or
          theClass.new == Object.new,
          "Could not override the new method twice. Include Callbacks before modifying the 'new' method on " .. tostring(theclass) )

  local classDict = theClass.__classDict
  local tcd = type(classDict)
  assert(tcd == 'function' or tcd == 'table', 'invalid type for an index; must be function or table, was ' .. tostring(tcd))

  -- aux function used to look on the class index. Changes depending on whether classIndex is a table or function
  local searchOnClassIndex = tdc == 'function' and classIndex or function(_, x) return classDict[x] end

  -- a copy of classDict, with a modified __index that adds/removes callbacks when needed
  local instanceDict = {}
  
  for k,v in pairs(classDict) do instanceDict[k] = v end
  
  instanceDict.__index = function(instance, methodName)
    -- try to obtain method normally
    local method = searchOnClassIndex(instance, methodName)

    -- if method found, return it callbackized
    if method ~= nil then return _callbackizeMethod(theClass, methodName, method) end

    -- if method not found, test if methoName ends in "WithoutCallbacks". If yes, return the method without callbacks
    methodName = methodName:match('(.+)WithoutCallbacks')
    if methodName ~= nil then return searchOnClassIndex(instance, methodName) end
  end

  -- modify theClass:new so instances use callbacks when needed.
  function theClass:new(...)
    assert(subclassOf(Object, self), "Use class:new instead of class.new")
    local instance = setmetatable({ class = theClass }, instanceDict) -- using instanceDict instead of classDict here
    instance:initialize(...)
    return instance
  end

end


-- adds callbacks to a method. Used by addCallbacksBefore and addCallbacksAfter, below
local function _addCallback( theClass, beforeOrAfter, methodName, callback, ...)
  assert(type(methodName)=='string', 'methodName must be a string')
  local tCallback = type(callback)
  assert(tCallback == 'string' or tCallback == 'function', 'callback must be a method name or a function')

  local entry = _getOrCreateEntry(theClass, methodName)

  table.insert(entry[beforeOrAfter], {method = callback, params = {...}})
end


--------------------------------
--      PUBLIC STUFF
--------------------------------

Callbacks = {}

function Callbacks:included(theClass)
  if includes(Callbacks, theClass) then return end

  -- change how __index works on the class itself
  _changeClassDict(theClass)

  -- change how __index works on on subclasses
  local prevSubclass = theClass.subclass
  theClass.subclass = function(aClass, name, ...)
    local theSubClass = prevSubclass(aClass, name, ...)
    _changeClassDict(theSubClass)
    return theSubClass
  end

end

--[[ before class method
Usage (the following two are equivalent):

    Actor:before('update', 'doSomething', 1, 2)
    Actor:before('update', function(actor, x,y) actor:doSomething(x,y) end, 1, 2)

  * methodName must be a string designatign a method (can be non-existing)
  * callback can be either a method name or a function
]]
function Callbacks.before(theClass, methodName, callback, ...)
  _addCallback( theClass, 'before', methodName, callback, ... )
end

--Same as before, but for adding callbacks *after* a method
function Callbacks.after(theClass, methodName, callback, ...)
  _addCallback( theClass, 'after', methodName, callback, ... )
end



