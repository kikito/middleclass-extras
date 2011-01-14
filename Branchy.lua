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

  require 'middleclass' -- or similar
  require 'middleclass-extras.init' -- or 'middleclass-extras'

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
local function _applySorted(collection, sortFunc, methodOrName, ...)
  local copy, i = {}, 1
  for _,c in pairs(collection) do
    copy[i] = c
    i = i+1
  end

  if type(sortFunc)=='function' then
    table.sort(copy, sortFunc)
  end

  for _,elem in ipairs(copy) do
    Invoker.invoke(elem, methodOrName, ...)
  end
end


--------------------------------
--    PUBLIC STUFF
--------------------------------

Branchy = {}

-- add a child to the children list
-- the key parameter is optional. If not given, it will be #(self.children)
function Branchy:addChild(child, key)
  assert(includes(Branchy, child.class, true), tostring(child.class) .. " must include Branchy")
  if child.parent ~= nil then
    child.parent:removeChild(child)
  end

  if key == nil then
    table.insert(self.children, child)
  else
    local prevChild = self.children[key]
    if prevChild~=nil then prevChild.parent = nil end
    self.children[key] = child
  end
  child.parent = self
  child.root = self.root
  return child
end

-- gets the position of a child on the children list
-- returns nil if not found
function Branchy:getChildKey(child)
  for k,c in pairs(self.children) do
    if c==child then return k end
  end
end

-- removes a child from the children list
function Branchy:removeChild(child)
  local key = self:getChildKey(child)

  if key~=nil then
    child.parent = nil
    child.root = nil
    if type(key)=='number' then
      table.remove(self.children, position)
    else
      self.children[key]= nil
    end
  end
end

-- empties the children list
function Branchy:removeAllChildren()
  for _,c in pairs(self.children) do c.parent = nil end
  self.children = {}
end

-- returns the number of levels that a node has until it reaches root (or self)
-- returns 0 if root
function Branchy:getDepth()
  local level = 0
  local parent = self.parent
  while parent~=nil and parent~=self do
    parent = parent.parent
    level = level + 1
  end
  return level
end

-- returns a list with { parent, grantparent, ... , root } of a brancy node
function Branchy:getAncestors()
  local ancestors = {}
  
  local parent = self.parent
  while parent ~= nil do
    table.insert(ancestors, parent)
    parent = parent.parent
  end
  
  return ancestors
end

-- returns all the children, grandchildren, etc a branchy object
function Branchy:getDescendants()
  local descendants = {}
  for _,child in pairs(self.children) do
    table.insert(descendants, child)
    for _,descendant in ipairs(child:getDescendants()) do
      table.insert(descendants, descendant)
    end
  end
  return descendants
end

-- applies a method or a function to all children
function Branchy:applyToChildren(methodOrName, ...)
  _applySorted(self.children, nil, methodOrName, ...)
end

-- applies a method to all children, sorting them first
function Branchy:applyToChildrenSorted(sortFunc, methodOrName, ...)
  _applySorted(self.children, sortFunc, methodOrName, ...)
end

-- applies a method or a function to all descendants
function Branchy:applyToDescendants(methodOrName, ...)
  _applySorted(self:getDescendants(), nil, methodOrName, ...)
end

-- applies a method to all descendants, sorting them first
function Branchy:applyToDescendantsSorted(sortFunc, methodOrName, ...)
  _applySorted(self:getDescendants(), sortFunc, methodOrName, ...)
end

-- returns the 'brothers' of a brancy object (children of self.parent that are ~= self)
function Branchy:getSiblings()
  local siblings = {}
  if self.parent~=nil then
    for _,sibling in pairs(self.parent.children) do
      if sibling ~= self then table.insert(siblings, sibling) end
    end
  end
  return siblings
end

--------------------------------
--    INCLUDED callback
--------------------------------

function Branchy:included(theClass)
  if not includes(Callbacks, theClass) then
    theClass:include(Callbacks)
  end

  theClass:before('initialize', function(self)
    self.children = {}
    self.root = self
  end)
  theClass:after('destroy', 'removeAllChildren')
end




