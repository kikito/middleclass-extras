require('middleclass-extras.init')

context( 'Apply', function()

  context('When included by a class', function()
  
    local MyClass = class('MyClass')
    
    function MyClass:initialize()
      super.initialize(self)
      self.counter = 0
    end
    
    function MyClass:count(increment)
      self.counter = self.counter + increment
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
      end)
      test('It should work with a function', function()
        MyClass:apply(function(obj, c) obj:count(c) end, 1)
        assert_equal(obj1.counter, 1)
        assert_equal(obj2.counter, 1)
      end)
    
    end)
  
  end)

end)
