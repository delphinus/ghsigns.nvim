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
  -- Obsidian additional types
  Abstract = "DiagnosticHint",
  Todo = "DiagnosticInfo",
  Success = "DiagnosticOk",
  Question = "DiagnosticWarn",
  Failure = "DiagnosticError",
  Danger = "DiagnosticError",
  Bug = "DiagnosticError",
  Example = "Special",
  Quote = "Comment",
}

--- Build PR content for display (extracted for testability)
---@param pr Ghsigns.Pr
---@param opts? { max_body_lines?: integer, autolinks?: Ghsigns.Autolink[], fold_state?: table<integer, boolean> }
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

--- Set up heading highlight groups (GhsignsH1..GhsignsH6)
--- Links to @markup.heading.N.markdown if available, otherwise falls back to Title
function PrDisplay.setup_heading_highlights()
  for level = 1, 6 do
    local hl_name = "GhsignsH" .. level
    local ts_name = "@markup.heading." .. level .. ".markdown"
    local ts_hl = vim.api.nvim_get_hl(0, { name = ts_name, link = false })
    if ts_hl.fg then
      vim.api.nvim_set_hl(0, hl_name, { fg = ts_hl.fg, bold = true, default = true })
    else
      vim.api.nvim_set_hl(0, hl_name, { link = "Title", default = true })
    end
  end
end

--- Set up alert highlight groups (GhsignsAlert* and GhsignsAlert*Bg)
function PrDisplay.setup_alert_highlights()
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

  -- Obsidian ==highlight== marker
  vim.api.nvim_set_hl(0, "GhsignsHighlight", { bg = "#3b3600", fg = "#ffec80", default = true })

  PrDisplay.setup_heading_highlights()
  PrDisplay.setup_alert_highlights()

  local fold_state = {}
  local expand_state = {}
  opts = opts or {}
  local content

  local function rebuild()
    opts.fold_state = fold_state
    opts.expand_state = expand_state
    local new_content = PrDisplay.build_pr_content(pr, opts)
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    display_utils.apply_content_to_buffer(buf, ns, new_content, { title_url = pr.url })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    -- Toggle wrap based on whether any block is expanded
    local any_expanded = false
    for _, v in pairs(expand_state) do
      if v then any_expanded = true; break end
    end
    vim.api.nvim_set_option_value("wrap", not any_expanded, { win = win })
    content = new_content
  end

  content = PrDisplay.build_pr_content(pr, opts)
  display_utils.apply_content_to_buffer(buf, ns, content, { title_url = pr.url })
  local win = display_utils.open_float_window(buf, content, float_win)

  -- Initialize fold_state from default fold states
  for _, fold in ipairs(content.callout_folds) do
    fold_state[fold.source_line] = fold.collapsed
  end

  display_utils.setup_float_keymaps(buf, ns, win, content, float_win, {
    close_line_idx = content.close_line_idx,
    get_content = function()
      return content
    end,
    on_fold_toggle = function(source_line, collapsed)
      fold_state[source_line] = collapsed
      rebuild()
    end,
    on_expand_toggle = function(block_id, expanded)
      expand_state[block_id] = expanded
      rebuild()
    end,
  })
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
    "### Lists",
    "",
    "- Unordered item 1",
    "- Unordered item 2",
    "- Unordered item 3",
    "",
    "1. Ordered item one",
    "2. Ordered item two",
    "3. Ordered item three",
    "",
    "### Blockquotes",
    "",
    "> Blockquote line 1",
    "> Blockquote line 2",
    ">> Nested blockquote",
    "",
    "### Code Blocks",
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
    "### Tables",
    "",
    "| Feature | Syntax | Highlight Group |",
    "|---------|--------|-----------------|",
    "| **Bold** | `**text**` | `Bold` |",
    "| ~~Strikethrough~~ | `~~text~~` | `DiagnosticDeprecated` |",
    "",
    "### Inline Elements",
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
    "",
    "> [!NOTE]- Collapsed by default",
    "> This content is hidden until you click the header.",
    "> It supports multiple lines.",
    "",
    "> [!TIP]+ Expanded by default",
    "> This content is visible but can be collapsed by clicking.",
    "",
    "> [!custom] Unknown callout types",
    "> Any `[!type]` works as a callout, even unlisted ones like `[!custom]`.",
    "",
    "> [!NOTE] Code block inside callout",
    "> ```lua",
    "> local greeting = 'Hello from inside a callout!'",
    "> print(greeting)",
    "> ```",
    "> The code above has treesitter highlighting.",
    "",
    "## Expandable Content",
    "",
    "Click the underlined `…` on truncated lines to expand. Click the block again to collapse.",
    "",
    "```bash",
    "# This line is intentionally very long to demonstrate the expandable code block feature — click the … to see the full content and scroll horizontally",
    "echo 'short line'",
    "```",
    "",
    "| Feature | Description | Status |",
    "|---------|-------------|--------|",
    "| Foldable callouts | Click header to toggle `[!TYPE]+` / `[!TYPE]-` | Implemented |",
    "| Code in callouts | Treesitter highlighting inside `> ```lang` blocks | Implemented |",
    "| Expandable blocks | Click underlined `…` to show full truncated content | Implemented |",
    "",
    "### 日本語の折り返しと禁則処理",
    "",
    "テキストの折り返し時に、句読点が次の行の先頭に送られないようにする処理が禁則処理。この行では句点と一緒に直前の文字も次の行に送られています。",
    "",
    "また開き括弧が折り返し位置の付近にある場合は次の行の先頭に送る処理も実施される「行末禁則」と呼ばれています。",
    "",
    "> [!NOTE] 日本語のコールアウト",
    "> コールアウト内で句読点が折返し位置の直後にある場合は前の行に戻す禁則処理が有効。確認しましょう。",
    "",
    "Obsidian ==highlight== markers and `%%hidden comments%%` are also supported.",
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
