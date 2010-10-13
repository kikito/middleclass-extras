-----------------------------------------------------------------------------------
-- Apply.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com ) - 4 Mar 2010
-- Makes possible to treat all instances of a class
-----------------------------------------------------------------------------------

assert(Object~=nil and class~=nil, 'MiddleClass not detected. Please require it before using Apply')
assert(Sender~=nil, 'The Apply module requires the Sender module in order to work. Please require Sender before requiring Apply')
assert(Callbacks~=nil, 'The Apply module requires the Callbacks module in order to work. Please require Sender before requiring Apply')

-- Private stuff
_instances = {}

-- Adds an instance to the "list of instances" of its class
local function _registerInstance(theClass, instance)
  if not includes(Apply, theClass) then return end
  _instances[theClass] = _instances[theClass] or _G.setmetatable({}, {__mode = "k"})
  _instances[theClass][instance] = instance
  _registerInstance(theClass.superclass, instance)
end

-- Removes an instance from the "list of instances" of its class
local function _unregisterInstance(theClass, instance)
  if not includes(Apply, theClass) then return end
  _unregisterInstance(theClass.superclass, instance)
  _instances[theClass][instance] = nil
end

-- The Apply module
Apply = {}

function Apply:included(theClass)
  if not includes(Callbacks, theClass) then
    theClass:include(Callbacks)
  end
  theClass:addCallback('after', 'initialize', function(instance)
    _registerInstance(instance.class, instance)
  end)
  theClass:addCallback('after', 'destroy', function(instance)
    _unregisterInstance(instance.class, instance)
  end)
end

-- Applies some method to all the instances of this class (not subclasses)
function Apply.apply(theClass, methodOrName, ...)
  for _,instance in pairs(_instances[theClass]) do
    if(Sender.send(instance, methodOrName, ...) == false) then return end
  end
end




