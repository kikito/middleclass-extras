local modules = {
  'Invoker', 'GetterSetter', 'Branchy', 'Callbacks', 'Apply', 'Beholder', 'Stateful'
}

local basename = ({...})[1]:gsub("init", "")
for _,module in ipairs(modules) do
  require(basename..'.' .. module)
end
