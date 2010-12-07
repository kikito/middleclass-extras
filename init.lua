local _path = ({...})[1]:gsub("%.init", "")
local _modules = {
  'Invoker', 'GetterSetter', 'Branchy', 'Callbacks', 'Apply', 'Beholder', 'Stateful', 'Indexable'
}

for _,module in ipairs(_modules) do
  require(_path .. '.' .. module)
end
