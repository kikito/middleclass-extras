require('middleclass-extras.init')

context( 'Branchy', function()

  local Tree = class('Tree'):include(Branchy)
  function Tree:initialize(name)
    super.initialize(self)
    self.name = name
  end
  function Tree:__tostring()
    return 'Tree instance('.. self.name .. ')'
  end
  
  local root, a1, a2, b1, b2

  local function createNodes()
    --[[ Structure:

           root
           /  \
          a1  a2
         / \
        b1 b2
    ]]
    
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
  test('apply and applySorted should work', function()
    -- TODO
  end)
  
  
  
  
  
  


end)
