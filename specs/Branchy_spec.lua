require('middleclass-extras.init')

context( 'Branchy', function()

  local root, a1, a2, b1, b2, list

  local Tree = class('Tree'):include(Branchy)
  function Tree:initialize(name)
    super.initialize(self)
    self.name = name
  end
  function Tree:addToList()
    table.insert(list, self)
  end
  function Tree:__tostring()
    return 'Tree instance('.. self.name .. ')'
  end
  
  -- used for sorting
  local function alphabetically(x,y) return x.name < y.name end
  local function omegalogically(x,y) return x.name > y.name end

  local function createNodes()
    --[[ Structure:

           root
           /  \
          a1  a2
         / \
        b1 b2
    ]]
    
    list = {}
    root = Tree:new('root')
    a1 = root:addChild(Tree:new('a1'))
    a2 = root:addChild(Tree:new('a2'))
    b1 = a1:addChild(Tree:new('b1'), 'b1')
    b2 = a1:addChild(Tree:new('b2'), 'b2')
  end

  before(createNodes)

  test('The parent node should be correctly set up', function()
    assert_nil(root.parent)
    assert_equal(a1.parent, root)
    assert_equal(a2.parent, root)
    assert_equal(b1.parent, a1)
    assert_equal(b1.parent, a1)
  end)
  test('The children are correctly set up', function()
    assert_equal(root.children[1], a1)
    assert_equal(root.children[2], a2)
    assert_equal(a1.children.b1, b1)
    assert_equal(a1.children.b2, b2)
  end)
  test('removing children should work', function()
    a1:removeChild(b1)
    assert_nil(a1.children.b1)
  end)
  test('getAncestors works ok', function()
    local ancestors = b1:getAncestors()
    assert_equal(ancestors[1], a1)
    assert_equal(ancestors[2], root)
  end)
  test('getDescendants works ok', function()
    local descendants = root:getDescendants()
    assert_equal(descendants[1], a1)
    assert_equal(descendants[2], b2)
    assert_equal(descendants[3], b1)
    assert_equal(descendants[4], a2)
  end)
  test('getSiblings works ok', function()
    local siblings = b2:getSiblings()
    assert_equal(siblings[1], b1)
  end)
  test('getDepth works ok', function()
    assert_equal(root:getDepth(), 0)
    assert_equal(a1:getDepth(), 1)
    assert_equal(a2:getDepth(), 1)
    assert_equal(b1:getDepth(), 2)
    assert_equal(b2:getDepth(), 2)
  end)
  test('applyToChildren', function()
    a1:applyToChildren('addToList')
    assert_equal(#list, 2)
  end)
  test('applyToChildrenSorted', function()
    a1:applyToChildrenSorted(alphabetically, 'addToList')
    assert_equal(list[1], b1)
    assert_equal(list[2], b2)
    
    list = {}
    a1:applyToChildrenSorted(omegalogically, 'addToList')
    assert_equal(list[1], b2)
    assert_equal(list[2], b1)
  end)
  test('applyToDescendants', function()
    root:applyToDescendants('addToList')
    assert_equal(#list, 4)
  end)
  test('applyToDescendantsSorted', function()
    root:applyToDescendantsSorted(alphabetically, 'addToList')
    assert_equal(list[1], a1)
    assert_equal(list[2], a2)
    assert_equal(list[3], b1)
    assert_equal(list[4], b2)
    
    list = {}
    root:applyToDescendantsSorted(omegalogically, 'addToList')
    assert_equal(list[1], b2)
    assert_equal(list[2], b1)
    assert_equal(list[3], a2)
    assert_equal(list[4], a1)
  end)
end)
