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

local click_count = 0

---@param clicks integer
Lualine.on_click = function(clicks)
  if clicks > 2 then
    return
  end
  local _, pr = Lualine.get_info()
  if pr and pr.url then
    if clicks == 1 then
      click_count = 1
      assert(vim.uv.new_timer()):start(300, 0, function()
        if click_count == 1 then
          click_count = 0
          vim.schedule_wrap(Lualine.show_pr_info)(pr)
        end
      end)
    elseif clicks == 2 then
      click_count = 0
      vim.notify("opening PR: " .. pr.url)
      vim.ui.open(pr.url)
    end
  else
    vim.notify "no PR found for this buffer"
  end
end

local pr_template = [[
#{{ .number }} {{ .title }}
{{ .author_name }}
{{ .additions }}{{ .deletions }}
state: {{ .state }}

{{ .short_body }}

created: {{ .createdAt }}
updated: {{ .updatedAt }}
]]

--- @param pr Ghsigns.Pr
Lualine.show_pr_info = function(pr)
  local p = vim.deepcopy(pr)
  p.author_name = p.author.name == "" and p.author.login or p.author.name
  p.short_body = vim.trim(table.concat(vim.list_slice(vim.split(p.body, "\n"), 1, 5), "\n"))
  local output = pr_template:gsub("{{ (.-) }}", function(key)
    return tostring(p[key:match "^%.(.*)$"] or "")
  end)
  vim.notify(output)
end

return Lualine
