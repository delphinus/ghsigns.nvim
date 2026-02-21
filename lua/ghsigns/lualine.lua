---@class Ghsigns.Lualine
local Lualine = {}

Lualine.component = function()
  local ghsigns = require("ghsigns").ghsigns
  local colors = assert(ghsigns.opts.colors)
  local lualine_require = require "lualine_require"
  local M = lualine_require.require("lualine.component"):extend()

  function M:init(options)
    options = vim.tbl_extend("force", { on_click = Lualine.on_click }, options or {})
    M.super.init(self, options)
    self.highlights = {
      arrow = self:create_hl(colors.arrow, "arrow"),
      base = self:create_hl(colors.base, "base"),
      head = self:create_hl(colors.head, "head"),
      icon = self:create_hl(colors.icon, "icon"),
    }
  end

  function M:update_status()
    local hl = vim.iter(self.highlights):fold({}, function(a, k, v)
      a[k] = self:format_hl(v)
      return a
    end)
    local git, pr = Lualine.get_info()
    if git and git.revision and pr then
      local revision = git.revision:gsub("^origin/", "")
      return table.concat({
        hl.icon .. "",
        hl.head .. git.head,
        hl.arrow .. "←",
        ("%s%s #%d"):format(hl.base, revision, pr.number),
      }, " ")
    elseif git then
      return table.concat({
        hl.icon .. "",
        hl.head .. git.head,
      }, " ")
    end
    return ""
  end

  return M
end

---@return Ghsigns.GitInfo?
---@return Ghsigns.Pr?
Lualine.get_info = function()
  local ghsigns = require("ghsigns").ghsigns
  if not ghsigns.enabled then
    return
  end
  return ghsigns:get(vim.api.nvim_get_current_buf())
end

local wait_double_click = false

---@param clicks integer
Lualine.on_click = function(clicks)
  if clicks > 2 then
    return
  end
  local _, pr = Lualine.get_info()
  if not pr or not pr.url then
    vim.notify "No PR information available for this buffer"
    return
  end
  if clicks == 1 then
    wait_double_click = true
    assert(vim.uv.new_timer()):start(300, 0, function()
      if wait_double_click then
        wait_double_click = false
        vim.schedule_wrap(Lualine.show_pr_info)(pr)
      end
    end)
  elseif clicks == 2 then
    wait_double_click = false
    vim.notify("opening PR: " .. pr.url)
    vim.ui.open(pr.url)
  end
end

local pr_display = require "ghsigns.pr_display"

Lualine.build_pr_content = pr_display.build_pr_content
Lualine.show_pr_info = pr_display.show_pr_info

return Lualine
