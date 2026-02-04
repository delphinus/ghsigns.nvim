---@class Ghsigns.Gitsigns
---@field bufnr integer
local Gitsigns = {}

---@param bufnr integer
Gitsigns.new = function(bufnr)
  return setmetatable({ bufnr = bufnr }, { __index = Gitsigns })
end

---@return boolean
Gitsigns.is_callable = function()
  local ok = pcall(require, "gitsigns")
  return ok
end

---@class Ghsigns.GitInfo
---@field root string
---@field head string
---@field revision? string

---@return Ghsigns.GitInfo?
function Gitsigns:info()
  local status = vim.b[self.bufnr].gitsigns_status_dict
  if not status then
    return
  end
  local root, head = status.root, status.head
  local cache = require("gitsigns.cache").cache
  local bcache = cache[self.bufnr]
  if head == "HEAD" or not bcache then
    -- NOTE: head == "head" means it is on detached HEAD.
    return { root = root, head = head }
  end
  return { root = root, head = head, revision = bcache.git_obj.revision }
end

---@param revision string
---@param baseRefName? string
function Gitsigns:change_base(revision, baseRefName)
  if not baseRefName or revision == baseRefName then
    return
  end
  vim.schedule_wrap(vim.api.nvim_buf_call)(self.bufnr, function()
    require("gitsigns.actions").change_base(baseRefName, nil, function(err)
      if err then
        vim.notify("ghsigns: failed to change base: " .. err, vim.log.levels.ERROR)
      end
    end)
  end)
end

return Gitsigns
