-----------------------------------------------------------------------------------
-- Stateful.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com ) - 19 Oct 2009
-- Adds stateful behaviour to classes. Based on Unrealscript's stateful objects
-----------------------------------------------------------------------------------
--[[ Usage:

  require 'middleclass' -- or similar
  require 'middleclass-extras.init' -- or 'middleclass-extras'

  -- create a normal class, and make it implement Stateful
  MyClass = class('MyClass')
  MyClass:include(Stateful)

  function MyClass:foo() print('Normal foo') end
  
  -- add a state to that class using addState, and re-define the method
  local Hidden = MyClass:addState('Hidden')
  function Hidden:foo() print('Hidden foo') end
  
  -- create an instance, and test the different behaviour when changing the state
  local obj = MyClass:new()
  obj:foo() -- prints 'Normal foo'
  obj:gotoState('Hidden')
  obj:foo() -- prints 'Hidden foo'

]]

-- There's much more! States are inherited by subclasses. States can inherit from other states.
-- States can be stacked
-- There are hook methods (ex: exitState) called when the state information of an object changes


assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before using Stateful')

--[[ Stateful Mixin declaration
  * Stateful classes have a list of states (accesible through class.states).
  * When a method is invoked on an instance of such classes, it is first looked up on the class current state (accesible through class.currentState)
  * If a method is not found on the current state, or if current state is nil, the method is looked up on the class itself
  * It is possible to change states by doing class:gotoState(stateName)
]]
Stateful = {}

------------------------------------
-- PRIVATE ATTRIBUTES AND METHODS
------------------------------------
-- helper function used to call state callbacks (enterState, exitState, etc)
local function _invokeCallback(self, state, callbackName, ... )
  if state == nil then return end
  local callback = state[callbackName]
  if(type(callback)=='function') then callback(self, ...) end
end

-- returns the instance's state with the given name. Errors if state not found
local function _getStateFromClass(self, stateName)
  if stateName == nil then return nil end
  local state = self.class.states[stateName]
  assert(state~=nil, "State '" .. tostring(stateName) .. "' not found")
  return state
end

-- looks for a state on the instance stack. Returns the state + position on the stack
-- if stateName is nil, it returns the top of the stack + stackSize
local function _getStateFromStack(self, stateName)
  local stack = self._stateStack
  local stackSize = #stack
  if stateName then
    local state
    for i=1, stackSize do
      state = stack[i]
      if state.name == stateName then 
        return state, i
      end
    end
  end
  return stack[stackSize], stackSize
end

local function _assertString(value, name)
  assert(type(value)=='string', name .. " must be either a string")
end

local function _assertStringOrNil(value, name)
  local tvalue = type(value)
  assert(tvalue=='string' or tvalue=='nil', name .. " must be either a string or nil")
end


-- Changes a class by:
-- * adding a 'states' field to it
-- * re-defining the class __index method so it looks on the state stack before 'going up'
local function makeStateful(theClass)

  -- add the states
  theClass.states = {}

  -- modify the dictionary lookup
  local classDict = theClass.__classDict
  local prevIndex = classDict.__index
  classDict.__index = function(instance, methodName)
    -- look up on the stack to see if the method is re-defined on one state
    local stack = rawget(instance, '_stateStack')
    if stack then
      for i = #stack,1,-1 do -- reversal loop
        local method = stack[i][methodName]
        if method ~= nil then return method end
      end
    end
    --if not found on the state stack, look it up on the regular class dict
    local tpi = type(prevIndex)
    if tpi=='table' then
      return prevIndex[methodName]
    else
      return prevIndex(instance, methodName)
    end
  end

  -- modify the instance creator so instances start with a stack
  local oldAllocate = theClass.allocate
  function theClass.allocate(theClass, ...)
    local instance = oldAllocate(theClass, ...)
    instance._stateStack = {}
    return instance
  end

end

-- true if state is on the stack, false otherwise
local function _inStack(self, stateName)
  for i=1, #self._stateStack do
    local state = self._stateStack[i]
    if state.name == stateName then return true end
  end
  return false
end

local function _getTopState(self)
  return self._stateStack[#self._stateStack]
end

local function _setTopStateWithoutCallbacks(self, nextState)
  local stackSize = #self._stateStack
  local position = stackSize == 0 and 1 or stackSize
  self._stateStack[position] = nextState
end

local function _setTopState(self, newStateName)
  local prevState = _getTopState(self)

  local prevStateName = prevState~=nil and prevState.name or nil
  _invokeCallback(self, prevState, 'exitState', newStateName)

  local nextState = _getStateFromClass(self, newStateName)

  _setTopStateWithoutCallbacks(self, nextState)

  _invokeCallback(self, nextState, 'enterState', prevStateName)
end

------------------------------------
-- STATE CLASS
------------------------------------

-- The State class; is the father of all State objects
Stateful.State = class('Stateful.State')

------------------------------------
-- INSTANCE METHODS
------------------------------------

--[[ Changes the current state.
  If the current state has a method called onExitState, it will be called, with the instance as a parameter.
  If the "next" state exists and has a method called onExitState, it will be called, with the instance as a parameter.
  use gotoState(nil) for setting states to nothing
  This method invokes the exitState and enterState functions if they exist on the current state
  Second parameter is optional. If true, the stack will be conserved (the top state will be replaced).
  Otherwise, all the states on the stack will be popped (with the corresponding callbacks being executed).
]]
function Stateful:gotoState(newStateName, keepStack)
  _assertStringOrNil(newStateName, 'newStateName')
  if(_inStack(self, newStateName)) then return end

  if not keepStack then self:popAllStates() end

  _setTopState(self, newStateName)
end

--[[ Changes the current state, by pushing a new state on the stack.
  If the pushed state is already on the stack, this function does nothing.
  Invokes 'pausedState' on the previous state, if existing
  The new state is pushed on the top of the stack and then
  Invokes 'pushedState' and 'enterState' on the new state, if existing
]]
function Stateful:pushState(newStateName)
  _assertString(newStateName, 'newStateName')
  if(_inStack(self, newStateName)) then return end

  _invokeCallback(self, _getTopState(self), 'pausedState')

  local nextState = _getStateFromClass(self, newStateName)
  table.insert(self._stateStack, nextState)
  _invokeCallback(self, nextState, 'pushedState')
  _invokeCallback(self, nextState, 'enterState')

  return nextState
end

--[[ Removes a state from the state stack
   If a state name is given, it will attempt to remove it from the stack. If not found on the stack it will do nothing.
   If no state name is give, this pops the top state from the stack, if any. Otherwise it does nothing.
   Callbacks will be called when needed.
   Returns the length of the state stack after the pop
]]
function Stateful:popState(stateName)
  _assertStringOrNil(stateName, 'stateName')

  local prevState, position = _getStateFromStack(self, stateName)

  if prevState ~= nil then
    _invokeCallback(self, prevState, 'exitState')
    _invokeCallback(self, prevState, 'poppedState')

    table.remove(self._stateStack, position)

    if position == #self._stateStack + 1 then
      _invokeCallback(self, _getTopState(self), 'continuedState')
    end
  end

  return #self._stateStack
end

--[[ Empties the state stack
   This function will invoke all the popState, exitState callbacks on all the states as they pop out.
]]
function Stateful:popAllStates()
  local sl = self:popState()
  while sl > 0 do sl = self:popState() end
end

--[[
  Returns true if the object is in the state named 'stateName'
  If testStack true, this method returns true if the state is on the stack instead
]]
function Stateful:isInState(stateName, testStack)
  local state = testStack and _getStateFromStack(self, stateName) or _getTopState(self)
  if state~=nil and state.name == stateName then return true end
  return false
end

-- Returns the name of the state on top of the stack or nil if no state
function Stateful:getCurrentStateName()
  local stack = self._stateStack
  local currState = stack[#stack]
  return currState ~= nil and currState.name or nil
end

------------------------------------
-- CLASS METHODS
------------------------------------

--[[ Adds a new state to the "states" class member.
  superState is optional. If nil, State will be the parent class of the new state
  returns the newly created state, or the existing one if it existed
]]
function Stateful.addState(theClass, stateName, superState)
  assert(includes(Stateful, theClass), "Invalid class. Make sure you used class:addState instead of class.addState")
  assert(type(stateName)=="string", "stateName must be a string")

  local prevState = rawget(theClass.states, stateName)

  if prevState~=nil then return prevState end

  -- states are just regular classes. If superState is nil, this uses State as superClass
  local superState = superState or theClass.State
  local state = superState:subclass(stateName, theClass)
  theClass.states[stateName] = state
  return state
end

------------------------------------
-- INCLUDED
------------------------------------

-- When the mixin is included by a class, modify it properly
function Stateful:included(theClass)
  -- do nothing if the mixin is already included
  if includes(Stateful, theClass) then return end
  
  -- add states to theClass and use the state stack on its __index
  makeStateful(theClass)

  -- re-define subclass so it:
  -- * makes sure that the subclasses are stateful
  -- * subclasses must inherit states from superclasses
  local prevSubclass = theClass.subclass
  theClass.subclass = function(aClass, name)
    local theSubClass = prevSubclass(aClass, name)

    makeStateful(theSubClass)

    -- the states of the subclass are subclasses of the superclass' states
    for stateName,state in pairs(aClass.states) do
      theSubClass:addState(stateName, state)
    end

    return theSubClass
  end
  
  -- re-define includes so it accepts 'stateful mixins'
  -- stateful mixins can add states to a class. They must have a 'states' field, with mixins inside them.
  -- for each key,value inside mixin.state:
  --   if the class has a state called 'key', make it implement value
  --   else create a new state called 'key' and make it implement value
  theClass.include = function(theClass, module, ...)
    assert(includes(Stateful, theClass), "Use class:includes instead of class.includes")
    assert(type(module)=='table', "module must be a table")
    for methodName,method in pairs(module) do
      if methodName ~="included" and methodName ~= "states" then
        theClass[methodName] = method
      end
    end
    if type(module.included)=="function" then module:included(theClass, ...) end
    if type(module.states)=="table" then
      for stateName,moduleState in pairs(module.states) do 
        local state = theClass.states[stateName]
        if state == nil then state = theClass:addState(stateName) end
        state:include(moduleState, ...)
      end
    end
    theClass.__modules[module] = module
    return theClass
  end

end
