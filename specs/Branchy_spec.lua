require('middleclass-extras.init')

context( 'Branchy', function()

  local Tree = class('Tree'):include(Branchy)
  
  local root = Tree:new()
  local child1 = root:addChild(Tree:new())
  local subchild1 = child1:addChild(Tree:new())

  context('parents', function()
    test('Root object should have no parent', function()
      assert_nil(root.parent)
    end)
    test('Root children should point to the root as their parent', function()
      assert_equal(root, child1.parent)
    end)
  end)


end)
