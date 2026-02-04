---@class Ghsigns.Color
---@field bg string
---@field fg string

---@class Ghsigns.Colors
---@field arrow Ghsigns.Color
---@field base Ghsigns.Color
---@field head Ghsigns.Color
---@field icon Ghsigns.Color

---@class Ghsigns.Config
---@field bin? string
---@field colors? Ghsigns.Colors

---@class Ghsigns.Ghsigns
---@field augroup integer
---@field enabled boolean
---@field gh Ghsigns.Gh
---@field opts Ghsigns.Config
---@field private cache Ghsigns.Cache
local Ghsigns = {}

---@return Ghsigns.Ghsigns
Ghsigns.new = function()
  local Cache = require "ghsigns.cache"
  local Gh = require "ghsigns.gh"

  return setmetatable({
    augroup = vim.api.nvim_create_augroup("ghsigns", {}),
    cache = Cache.new(),
    enabled = false,
    gh = Gh.new(),
    opts = {},
  }, { __index = Ghsigns })
end

---@param opts? Ghsigns.Config
---@return nil
function Ghsigns:setup(opts)
  local gitsigns = require "ghsigns.gitsigns"

  self.opts = vim.tbl_deep_extend(
    "force",
    ---@type Ghsigns.Config
    {
      bin = "gh",
      colors = {
        arrow = { fg = "#e7a06a" },
        base = { fg = "#73a3f3" },
        head = { fg = "#d087e8" },
        icon = { fg = "#dddde7" },
      },
    },
    opts or {}
  )
  self.gh.bin = self.opts.bin
  if not self.gh:is_callable() then
    vim.notify(self.gh.bin .. " not found", vim.log.levels.ERROR)
    return
  end
  if not gitsigns.is_callable() then
    vim.notify("gitsigns.nvim not found", vim.log.levels.ERROR)
    return
  end
  self.enabled = true
  self:setup_autocmd()
end

---@param bufnr integer
---@return Ghsigns.GitInfo? git
---@return Ghsigns.Pr? pr
function Ghsigns:get(bufnr)
  if not self.enabled then
    return
  end
  local gs = require("ghsigns.gitsigns").new(bufnr)
  local git_info = gs:info()
  if not git_info then
    return
  end
  return git_info, self.cache:get(git_info)
end

---@return nil
function Ghsigns:setup_autocmd()
  vim.api.nvim_create_autocmd("User", {
    group = self.augroup,
    pattern = { "GitSignsUpdate" },
    callback = function(args)
      if not self.enabled then
        return
      end
      local bufnr = vim.tbl_get(args, "data", "buffer")
      if not bufnr then
        return
      end
      local gs = require("ghsigns.gitsigns").new(bufnr)
      local git_info = gs:info()
      if not git_info then
        return
      end
      local pr = self.cache:get(git_info)
      if pr then
        gs:change_base(git_info.revision, pr.baseRefName)
        return
      end
      local async = require "gitsigns.async"
      async
        .run(function()
          local err, fetched = self.gh:fetch_pr(git_info.root)
          if err then
            self:show_warning(bufnr, err)
            self.cache:set(git_info)
          elseif fetched then
            self.cache:set(git_info, fetched)
            gs:change_base(git_info.revision, fetched.baseRefName)
            ---@diagnostic disable-next-line: missing-return
          end
        end)
        :raise_on_error()
    end,
  })
end

---@param bufnr integer
---@param err string
function Ghsigns:show_warning(bufnr, err)
  vim.schedule(function()
    vim.b[bufnr].ghsigns_errors = vim.b[bufnr].ghsigns_errors or {}
    local ghsigns_errors = vim.b[bufnr].ghsigns_errors
    if err:match "no pull request found for branch" then
      return
    elseif err:match "No default remote repository has been set" then
      if not ghsigns_errors.NO_DEFAULT_REMOTE_REPOSITORY then
        ghsigns_errors.NO_DEFAULT_REMOTE_REPOSITORY = true
        vim.notify("ghsigns: " .. err, vim.log.levels.WARN)
      end
      return
    end
    vim.notify("ghsigns: " .. err, vim.log.levels.WARN)
  end)
end

return Ghsigns
