local Enums = require("./types")

local cardwire_mode = Enums.CardwireMode.UNKNOWN;

noctalia.setUpdateInterval(1000)

function update()
  noctalia.state.set("gpu", cardwire_mode)
end
