-----------------------------------------------------------------------------------
-- Stateful.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com ) - 19 Oct 2009
-- Adds stateful behaviour to classes. Based on Unrealscript's stateful objects
-----------------------------------------------------------------------------------
--[[ Usage:

  require 'MiddleClass' -- or similar
  require 'middleclass-extras.Stateful' -- or 'middleclass-extras.init'

  -- create a normal class, and make it implement Stateful
  MyClass = class('MyClass')
  MyClass:implements(Stateful)

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


assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before using MindState')

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
local _stacks = setmetatable({}, {__mode = "k"})   -- weak table storing private state stacks

-- helper function used to call state callbacks (enterState, exitState, etc)
local _invokeCallback = function(self, state, callbackName, ... )
  if state==nil then return end
  local callback = state[callbackName]
  if(type(callback)=='function') then callback(self, ...) end
end

-- gets creates the state stack of one instance
local _getOrCreateStack=function(instance)
  if _stacks[instance] == nil then
    _stacks[instance] = {}
  end
  return _stacks[instance]
end

-- returns the instance's state with the given name. Errors if state not found
local _getState=function(instance, stateName)
  local state = instance.class.states[stateName]
  assert(state~=nil, "State '" .. tostring(stateName) .. "' not found")
  return state
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
    local stack = _getOrCreateStack(instance)
    for i = #stack,1,-1 do -- reversal loop
      local method = stack[i][methodName]
      if method ~= nil then return method end
    end
    --if not found on the state stack, look it up on the regular class dict
    local tpi = type(prevIndex)
    if tpi=='table' then
      return prevIndex[methodName]
    else
      return prevIndex(instance, methodName)
    end
  end

end

------------------------------------
-- STATE CLASS
------------------------------------

-- The State class; is the father of all State objects
Stateful.State = class('Stateful.State', Object)

-- Extra parameter theRootClass is the class where the state is being added. It is used for method lookup
function Stateful.State.subclass(theClass, name, theRootClass)
  assert(type(name) == 'string', "Must provide a name for the new state")
  assert(includes(Stateful, theRootClass), tostring(theRootClass) .. ' must include the Stateful mixin')

  local theSubClass = Object.subclass(theClass, name)
  theSubClass.subclass = theRootClass.State.subclass

  -- Modify super so it points to :
  --  a) the superState, if we still have 'States up' (parent is not State)
  --  b) theRootClass's superclass if we have 'run out of states' (parent of this class is State)
  local superDict = theClass.__classDict
  if theClass == theRootClass.State then
    superDict = theRootClass.superclass.__classDict
  end
  local mt = getmetatable(theSubClass)
  mt.__newindex = function(_, methodName, method)
    if type(method) == 'function' then
      local fenv = getfenv(method)
      local newenv = setmetatable( {super = superDict},  {__index = fenv, __newindex = fenv} )
      setfenv( method, newenv )
    end
    rawset(theSubClass.__classDict, methodName, method)
  end

  return theSubClass
end

------------------------------------
-- INSTANCE METHODS
------------------------------------

--[[ Changes the current state.
  If the current state has a method called onExitState, it will be called, with the instance as a parameter.
  If the "next" state exists and has a method called onExitState, it will be called, with the instance as a parameter.
  use gotoState(nil) for setting states to nothing
  This method invokes the exitState and enterState functions if they exist on the current state
  Second parameter is optional. If true, the stack will be conserved. Otherwise, it will be popped.
]]
function Stateful:gotoState(newStateName, keepStack)
  local tnsn = type(newStateName)
  assert(tnsn=='string' or tnsn=='nil', "newStateName must be either a string or nil")
  -- If we're trying to go to a state in which we already are, return (do nothing)
  local stack = _getOrCreateStack(self)
  for _,state in ipairs(stack) do 
    if(state.name == newStateName) then return end
  end

  local stackSize = #stack
  local prevState = stack[stackSize] -- need this variable for the last call on this func

  -- Either empty completely the stack, or just call the exitstate callback on current state
  if keepStack==true then
    _invokeCallback(self, prevState, 'exitState', newStateName)
  else
    self:popAllStates()
  end

  if newStateName ~= nil then
    local nextState = _getState(self, newStateName)

    -- replace the top of the stack with the new state
    stack[stackSize == 0 and 1 or stackSize] = nextState

    -- Invoke enterState on the new state. 2nd parameter is the name of the previous state, or nil
    _invokeCallback(self, nextState, 'enterState', prevState~=nil and prevState.name or nil)
  end
end

--[[ Changes the current state, by pushing a new state on the stack.
  If the pushed state is already on the stack, this function does nothing.
  Invokes 'pausedState' on the previous state, if existing
  The new state is pushed on the top of the stack and then
  Invokes 'pushedState' and 'enterState' on the new state, if existing
]]
function Stateful:pushState(newStateName)
  assert(type(newStateName)=='string', "newStateName must be a string.")

  local nextState = _getState(self, newStateName)

  -- If we attempt to push a state and the state is already in the pile then return (do nothing)
  local stack = _getOrCreateStack(self)
  for _,state in ipairs(stack) do
    if state.name == newStateName then return end
  end

  -- Invoke pausedState on the previous state
  _invokeCallback(self, stack[#stack], 'pausedState')

  -- Do the push
  table.insert(stack, nextState)

  -- Invoke pushedState & enterState on the next state
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
  local tsn = type(stateName)
  assert(tsn=='string' or tsn=='nil', "stateName must be either a string or nil.")

  -- Calculate the position of the state to be removed
  local stack, position = _getOrCreateStack(self), 0
  local stackSize = #stack
  if tsn == 'string' then
    for i,state in ipairs(stack) do 
      if state.name == stateName then
        position = i
        break
      end
    end
  else
    position = stackSize
  end

  local prevState = stack[position]

  if prevState~=nil then -- if a state to be removed is found (either the top or a named one)
    -- Invoke exitstate & poppedState on the state being popped out
    _invokeCallback(self, prevState, 'exitState')
    _invokeCallback(self, prevState, 'poppedState')

    -- Remove the state from the stack
    table.remove(stack, position)

    -- If the state on the top of the stack has been popped, invoke continuedState on the new top
    if position == stackSize then _invokeCallback(self, stack[stackSize-1], 'continuedState') end
  end

  return #stack
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
  local stack = _getOrCreateStack(self)

  if testStack == true then
    for _,state in ipairs(stack) do 
      if state.name == stateName then return true end
    end
  else --testStack==false
    local state = stack[#stack]
    if state~=nil and state.name == stateName then return true end
  end

  return false
end

-- Returns the name of the state on top of the stack or nil if no state
function Stateful:getCurrentStateName()
  local stack = _getOrCreateStack(self)
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
  theClass.subclass = function(theClass, name)
    local theSubClass = prevSubclass(theClass, name)

    makeStateful(theSubClass)

    -- the states of the subclass are subclasses of the superclass' states
    for stateName,state in pairs(theClass.states) do
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
    return theClass
  end

end
