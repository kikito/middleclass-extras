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
    
    local function initialize()
      MyClass:apply('destroy') -- destroy all objects
      obj1 = MyClass:new()
      obj2 = MyClass:new()
      list = {}
    end

    context('When invoking apply', function()
      before(initialize)
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
      test('It should allow removing objects from inside the apply call', function()
        local obj4 = MyClass:new()
        MyClass:apply('addToList')
        local n=#list
        MyClass:apply(function(obj)
          if obj==obj4 then obj:destroy() end
        end)
        list = {}
        MyClass:apply('addToList')
        assert_equal(#list, n-1)
      end)
    end)
    
    context('When invoking applySorted', function()
      before(initialize)
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
      before(initialize)

      test('Destroy should remove instances from the list of objects', function()
        local obj5 = MyClass:new()
        MyClass:apply('addToList')
        local n = #list
        obj5:destroy()
        list = {}
        MyClass:apply('addToList')
        assert_equal(#list, n-1)
      end)

    end)
    
    context('When subclassing', function()
      before(initialize)
      local MySubClass = class('MySubClass', MyClass)

      test('Apply on a superclass should include the instances of a subclass, but not viceversa', function()
        MyClass:apply('addToList')
        local n = #list
        
        local subobj = MySubClass:new()
        list = {}
        MyClass:apply('addToList')
        assert_equal(#list, n+1)
        
        list = {}
        MySubClass:apply('addToList')
        assert_equal(#list, 1)
        
        list = {}
        subobj:destroy()
        MyClass:apply('addToList')
        assert_equal(#list, n)
      end)
    end)
  
  end)

end)
