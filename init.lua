local modules = {
 'middleclass.MiddleClass', 'Invoker', 'GetterSetter', 'Callbacks', 'Apply', 'Beholder', 'MindState'
}

for _,module in ipairs(modules) do
  require('middleclass-extras.' .. module)
end
