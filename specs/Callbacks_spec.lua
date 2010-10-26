require('middleclass-extras.init')

context( 'Callbacks', function()
  local A
  
  before(function()
    A = class('A')
    function A:initialize()
      super.initialize(self)
      self.calls = {}
    end
  end)
  
  local function defineRegularMethods(theClass)
    function theClass:foo() table.insert(self.calls, 'foo') end
    function theClass:bar() table.insert(self.calls, 'bar') end
    function theClass:baz() table.insert(self.calls, 'baz') end
  end
  
  local function addCallbacks(theClass)
    theClass:include(Callbacks)
    theClass:addCallback('before', 'bar', 'foo')
    theClass:addCallback('after', 'bar', function(myself) myself:baz() end )
  end
  
  local function testInstance(theClass)
    local obj = theClass:new()
    obj:barWithCallbacks()

    assert_equal(obj.calls[1], 'foo')
    assert_equal(obj.calls[2], 'bar')
    assert_equal(obj.calls[3], 'baz')
  end

  test('Should work when declared before the methods', function()
    addCallbacks(A)
    defineRegularMethods(A)
    testInstance(A)
  end)
  
  test('Should work when declared after the methods', function()
    defineRegularMethods(A)
    addCallbacks(A)
    testInstance(A)
  end)
  
  context('When subclassing', function()
    local B
    before(function()
      B = class('B', A)
    end)

    test('The subclass should include Callbacks', function()
      A:include(Callbacks)
      assert_true(includes(Callbacks, B))
    end)
    
    test('Callbacks in subclasses should work on inherited methods, even if declared before', function()
      addCallbacks(B)
      defineRegularMethods(A)
      testInstance(B)
    end)
    
    test('Callbacks in subclasses should work on inherited methods when declared after', function()
      defineRegularMethods(A)
      addCallbacks(B)
      testInstance(B)
    end)
    
    test('Callbacks should be conserved in subclasses', function()
      addCallbacks(A)
      defineRegularMethods(A)
      testInstance(B)
    end)
    
    test('Callbacks in subclasses can be used as well as in superclasses', function()
      addCallbacks(A)
      defineRegularMethods(A)
      addCallbacks(B)
      local obj = B:new()
      obj:barWithCallbacks()

      assert_equal(obj.calls[1], 'foo')
      assert_equal(obj.calls[2], 'foo')
      assert_equal(obj.calls[3], 'bar')
      assert_equal(obj.calls[4], 'baz')
      assert_equal(obj.calls[5], 'baz')
    end)

  end)
  
  context('When creating an instance', function()
    test('afterInitialize should be called', function()
      defineRegularMethods(A)
      A:include(Callbacks)
      A:addCallback('after', 'initialize', 'foo')
      assert_equal(A:new().calls[1], 'foo')
    end)
  end)
  
  context('When destroying an instance', function()
    test('before and afterDestroy callbacks should be called', function()
      defineRegularMethods(A)
      A:include(Callbacks)
      A:addCallback('before', 'destroy', 'foo')
      A:addCallback('after', 'destroy', 'bar')
      
      local a = A:new()
      a:destroy()
      
      assert_equal(a.calls[1], 'foo')
      assert_equal(a.calls[2], 'bar')
    end)
  end)


end)
