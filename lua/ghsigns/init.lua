local ghsigns = require("ghsigns.ghsigns").new()

---@class Ghsigns
local M = { ghsigns = ghsigns }

---@param opts? Ghsigns.Config
function M.setup(opts)
  ghsigns:setup(opts)
end

return M
