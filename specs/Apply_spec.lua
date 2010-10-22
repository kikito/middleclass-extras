require('middleclass-extras.init')

context( 'Apply', function()

  context('When included by a class', function()
  
    local MyClass = class('MyClass')
    local list = {}
    
    function MyClass:initialize()
      super.initialize(self)
      self.counter = 0
    end
    
    function MyClass:count(increment)
      self.counter = self.counter + increment
    end

    function MyClass:addToList()
      table.insert(list, self)
    end
    
    function MyClass:__tostring()
      return 'MyClass(' .. tostring(self.counter) .. ')'
    end
   
    MyClass:include(Apply)
    
    local obj1 = MyClass:new()
    local obj2 = MyClass:new()
    
    context('When invoking apply', function()
      before(function()
        obj1.counter = 0
        obj2.counter = 0
      end)
      test('It should work with a method name', function()
        MyClass:apply('count', 1)
        assert_equal(obj1.counter, 1)
        assert_equal(obj2.counter, 1)
        local obj3 = MyClass:new()
        MyClass:apply('count', 1)
        assert_equal(obj1.counter, 2)
        assert_equal(obj3.counter, 1)
        obj3:destroyWithCallbacks()
      end)
      test('It should work with a function', function()
        MyClass:apply(function(obj, c) obj:count(c) end, 1)
        assert_equal(obj1.counter, 1)
        assert_equal(obj2.counter, 1)
      end)
      test('It should allow removing objects from inside the call', function()
        --TODO
      end)
    end)
    
    context('When invoking applySorted', function()
      test('It should sort the instances properly before executing', function()
        obj1.counter = 1
        obj2.counter = 2
        list = {}
        MyClass:applySorted(function(a,b) return a.counter < b.counter end, 'addToList')
        assert_equal(list[1], obj1)
        assert_equal(list[2], obj2)
        list = {}
        MyClass:applySorted(function(a,b) return a.counter > b.counter end, 'addToList')
        assert_equal(list[1], obj2)
        assert_equal(list[2], obj1)
      end)
    end)
    
    context('When destroying elements', function()
      test('DestroyWithCallbacks should remove instances from the list of objects', function()
        --TODO
      end)
      test('Explicit call of removeFromApply should also work', function()
        --TODO
      end)
    end)
    
    context('When subclassing', function()
      --TODO
    end)
  
  end)

end)
