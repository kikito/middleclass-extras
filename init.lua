local modules = {
 'middleclass.MiddleClass', 'Invoker', 'GetterSetter', 'Callbacks', 'Apply', 'Beholder', 'Stateful'
}

for _,module in ipairs(modules) do
  require('middleclass-extras.' .. module)
end
