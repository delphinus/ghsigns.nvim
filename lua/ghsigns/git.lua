---@class Ghsigns.Git
local Git = {}

---@param bin? string
---@return Ghsigns.Git
Git.new = function(bin)
  return setmetatable({ bin = bin or "git" }, { __index = Git })
end

return Git
