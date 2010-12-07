-----------------------------------------------------------------------------------------------------------------------
-- middleclass-extras.lua - v0.7
-- Enrique García ( enrique.garcia.cota [AT] gmail [DOT] com ) - 19 Oct 2009
-- Complementary lib for middleclass
-----------------------------------------------------------------------------------------------------------------------

local _path = ({...})[1]:gsub("%.init", "")
local _modules = {
  'Invoker', 'GetterSetter', 'Branchy', 'Callbacks', 'Apply', 'Beholder', 'Stateful', 'Indexable'
}

for _,module in ipairs(_modules) do
  require(_path .. '.' .. module)
end
