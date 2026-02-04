---@class Ghsigns.Cache
---@field private data table<string, Ghsigns.Pr>
local Cache = {}

Cache.new = function()
  return setmetatable({ data = {} }, { __index = Cache })
end

---@param git_info Ghsigns.GitInfo
---@return Ghsigns.Pr?
function Cache:get(git_info)
  return self.data[self:key(git_info)]
end

---@param git_info Ghsigns.GitInfo
---@param pr? Ghsigns.Pr
function Cache:set(git_info, pr)
  self.data[self:key(git_info)] = pr or {}
end

---@private
---@param git_info Ghsigns.GitInfo
---@return string
function Cache:key(git_info)
  return git_info.root .. "::" .. git_info.head
end

return Cache
