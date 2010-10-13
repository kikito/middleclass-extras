local modules = {
 'middleclass.MiddleClass', 'Sender', 'GetterSetter', 'Callbacks', 'Apply', 'Beholder', 'MindState'
}

for _,module in ipairs(modules) do
  require('middleclass-extras.' .. module)
end
