local FloatWin = require "ghsigns.float_win"
local cb = require "ghsigns.content_builder"
local display_utils = require "ghsigns.display_utils"
local ContentBuilder = cb.ContentBuilder
local prepare_pr_data = cb.prepare_pr_data

local float_win = FloatWin.new()

local PrDisplay = {}

--- Blend two colors by alpha (0.0 = bg, 1.0 = fg)
---@param fg integer foreground color (0xRRGGBB)
---@param bg integer background color (0xRRGGBB)
---@param alpha number blend factor (0.0–1.0)
---@return integer blended color
local function blend_color(fg, bg, alpha)
  local r = math.floor(bit.rshift(fg, 16) * alpha + bit.rshift(bg, 16) * (1 - alpha) + 0.5)
  local g = math.floor(bit.band(bit.rshift(fg, 8), 0xFF) * alpha + bit.band(bit.rshift(bg, 8), 0xFF) * (1 - alpha) + 0.5)
  local b = math.floor(bit.band(fg, 0xFF) * alpha + bit.band(bg, 0xFF) * (1 - alpha) + 0.5)
  return bit.lshift(r, 16) + bit.lshift(g, 8) + b
end

--- Alert type definitions: base highlight group for each alert type
local ALERT_HL_BASES = {
  Note = "DiagnosticInfo",
  Tip = "DiagnosticHint",
  Important = "Special",
  Warning = "DiagnosticWarn",
  Caution = "DiagnosticError",
}

--- Build PR content for display (extracted for testability)
---@param pr Ghsigns.Pr
---@param opts? { max_body_lines?: integer, autolinks?: Ghsigns.Autolink[] }
---@return Ghsigns.PrContent
PrDisplay.build_pr_content = function(pr, opts)
  local b = ContentBuilder.new()
  local p = prepare_pr_data(pr)
  local title_line, title_text = b:build_header(p)
  b:build_body(p, opts)
  local close_line_idx = b:build_footer()
  local result = b:result()
  result.title_line = title_line
  result.title_text = title_text
  result.close_line_idx = close_line_idx
  return result
end

--- @param pr Ghsigns.Pr
--- @param opts? { max_body_lines?: integer, autolinks?: Ghsigns.Autolink[] }
PrDisplay.show_pr_info = function(pr, opts)
  if float_win:close_if_valid() then
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local ns = vim.api.nvim_create_namespace "ghsigns_pr_info"

  local title_hl = vim.api.nvim_get_hl(0, { name = "Title" })
  title_hl.underline = true
  vim.api.nvim_set_hl(0, "GhsignsPrTitle", title_hl)

  -- Create alert highlight groups
  local normal_hl = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false })
  if not normal_hl.bg then
    normal_hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  end
  local normal_bg = normal_hl.bg or 0x1e1e2e

  for name, base_hl_name in pairs(ALERT_HL_BASES) do
    local base_hl = vim.api.nvim_get_hl(0, { name = base_hl_name, link = false })
    local fg = base_hl.fg or 0xFFFFFF
    vim.api.nvim_set_hl(0, "GhsignsAlert" .. name, { fg = fg, bold = true, default = true })
    vim.api.nvim_set_hl(0, "GhsignsAlert" .. name .. "Bg", { bg = blend_color(fg, normal_bg, 0.1), default = true })
  end

  local content = PrDisplay.build_pr_content(pr, opts)
  display_utils.apply_content_to_buffer(buf, ns, content, { title_url = pr.url })
  local win = display_utils.open_float_window(buf, content, float_win)
  display_utils.setup_float_keymaps(buf, ns, win, content, float_win, { close_line_idx = content.close_line_idx })
end

--- Show a demo floating window with all supported Markdown notations
PrDisplay.show_demo = function()
  local demo_body = table.concat({
    "## Heading Example",
    "",
    "This is **bold text** and this is `inline code` in a paragraph. Normal prose that exceeds the max width is wrapped at word boundaries to keep the floating window compact.",
    "",
    "Visit [Neovim](https://neovim.io) for more info. Also see ~~deprecated feature~~.",
    "",
    "Related to #123 and #456.",
    "",
    "- Unordered item 1",
    "- Unordered item 2",
    "- Unordered item 3",
    "",
    "1. Ordered item one",
    "2. Ordered item two",
    "3. Ordered item three",
    "",
    "> Blockquote line 1",
    "> Blockquote line 2",
    ">> Nested blockquote",
    "",
    "```lua",
    'local M = {}',
    "",
    "function M.greet(name)",
    '  return "Hello, " .. name',
    "end",
    "",
    "return M",
    "```",
    "",
    "```",
    "Plain code block without language.",
    "Should use String highlight as fallback.",
    "This line is intentionally long to demonstrate that code lines exceeding the max width are truncated with an ellipsis character.",
    "```",
    "",
    "| Feature | Syntax | Highlight Group |",
    "|---------|--------|-----------------|",
    "| **Bold** | `**text**` | `Bold` |",
    "| ~~Strikethrough~~ | `~~text~~` | `DiagnosticDeprecated` |",
    "",
    "Bare URL (short): https://neovim.io stays as-is.",
    "",
    "Bare URL (long): https://github.com/neovim/neovim/blob/master/src/nvim/api/buffer.c#L123-L456 is truncated.",
    "",
    "Combined: **bold** with `code` and [link](https://example.com) on one line.",
    "",
    "Autolink reference: JIRA-42 is linked, but `JIRA-99` in backticks is not.",
    "",
    "> [!NOTE]",
    "> This is a note alert.",
    "",
    "> [!TIP]",
    "> This is a tip alert.",
    "",
    "> [!IMPORTANT]",
    "> This is an important alert.",
    "",
    "> [!WARNING]",
    "> This is a warning alert.",
    "",
    "> [!CAUTION]",
    "> This is a caution alert.",
  }, "\n")

  local demo_pr = {
    number = 42,
    title = "Markdown Rendering Demo",
    isDraft = true,
    author = { login = "demo-user", name = "Demo User" },
    headRefName = "feat/markdown-demo",
    baseRefName = "main",
    state = "OPEN",
    reviewDecision = "APPROVED",
    mergeable = "MERGEABLE",
    additions = 128,
    deletions = 32,
    changedFiles = 5,
    commits = { nodes = { {}, {}, {} } },
    labels = { nodes = { { name = "enhancement" }, { name = "documentation" } } },
    createdAt = "2025-01-15T10:30:00Z",
    updatedAt = "2025-01-16T14:20:00Z",
    url = "https://github.com/demo/repo/pull/42",
    body = demo_body,
  }

  PrDisplay.show_pr_info(demo_pr, {
    max_body_lines = math.huge,
    autolinks = {
      { key_prefix = "JIRA-", url_template = "https://jira.example.com/browse/JIRA-<num>" },
    },
  })
end

-- Exported for testing
PrDisplay._supports_osc8 = display_utils.supports_osc8
PrDisplay._reset_osc8_cache = display_utils.reset_osc8_cache
PrDisplay._blend_color = blend_color

return PrDisplay
