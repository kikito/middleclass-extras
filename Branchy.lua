-----------------------------------------------------------------------------------
-- Branchy.lua
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com ) - 24 Oct 2010
-- Allows a class to act like a tree - getting children, ancestors, etc.
-----------------------------------------------------------------------------------

--[[
  --Example:
  --root
  --  \_ child1
  --       \_ subchild1
  --       \_ subchild2

  Tree = class('Tree'):include(Branchy)
  
  local root = Tree:new()
  local child1 = root:addChild(Tree:new())
  local subchild1 = child1:addChild(Tree:new())

  root.parent -- => nil
  child1.parent -- => root
  root.children -- => { child1 }
  root.children[1].children[1] => subchild1
]]

--------------------------------
--    PRIVATE STUFF
--------------------------------
local function _makeNode(instance)
  instance.children = instance.children or {}
end


--------------------------------
--    PUBLIC STUFF
--------------------------------

Branchy = {}

-- add a child to the children list
function Branchy:addChild(child)
  _makeNode(child)
  if child.parent ~= nil then
    parent:removeChild(child)
  end

  table.insert(self.children, child)
  child.parent = self
  return child
end

-- gets the position of a child on the children list
function Branchy:getChildPosition(child)
  for i,c in ipairs(self.children) do
    if c==child then return i end
  end
end

-- removes a child from the children list
function Branchy:removeChild(child)
  local position = getChildPosition(child)

  if position~=nil then
    child.parent = nil
    table.remove(self.children, position)
  end
end

-- empties the children list
function Branchy:removeAllChildren()
  for i,c in ipairs(self.children) do c.parent = nil end
  self.children = {}
end

-- applies a method or a function to all children
function Branchy:applyToChildren(methodOrName, ...)
  self:applyToChildrenSorted(nil, methodOrName, ...)
end

-- applies a method to all children, sorting them first
function Branchy:applyToChildrenSorted(sortFunc, methodOrName, ...)
  local copy = {}
  for i,c in ipairs(self.children) do copy[i] = c end

  if type(sortFunc)=='function' then
    table.sort(copy, sortFunc)
  end

  for _,c in ipairs(copy) do
    Invoker.invoke(c, methodOrName, ...)
  end
end

--------------------------------
--    INCLUDED callback
--------------------------------

function Branchy:included(theClass)
  if not includes(Callbacks, theClass) then
    theClass:include(Callbacks)
  end

  theClass:before('initialize', _makeNode)
  theClass:after('destroy', 'removeAllChildren')
end




