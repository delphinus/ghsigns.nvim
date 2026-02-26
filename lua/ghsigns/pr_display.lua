local FloatWin = require "ghsigns.float_win"
local cb = require "ghsigns.content_builder"
local ContentBuilder = cb.ContentBuilder
local prepare_pr_data = cb.prepare_pr_data

local float_win = FloatWin.new()

local _osc8_supported = nil

--- Check if the terminal supports OSC 8 hyperlinks
---@return boolean
local function supports_osc8()
  if _osc8_supported ~= nil then
    return _osc8_supported
  end

  local term = vim.env.TERM_PROGRAM
  if term then
    local osc8_terminals = {
      ["iTerm.app"] = true,
      ["WezTerm"] = true,
      ["kitty"] = true,
      ["foot"] = true,
      ["contour"] = true,
      ["rio"] = true,
      ["alacritty"] = true,
      ["ghostty"] = true,
    }
    if osc8_terminals[term] then
      _osc8_supported = true
      return true
    end
  end

  -- VTE-based terminals (GNOME Terminal, etc.)
  if vim.env.VTE_VERSION then
    _osc8_supported = true
    return true
  end

  -- Windows Terminal
  if vim.env.WT_SESSION then
    _osc8_supported = true
    return true
  end

  _osc8_supported = false
  return false
end

local PrDisplay = {}

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

--- Apply treesitter syntax highlighting to code blocks
---@param buf integer
---@param ns integer
---@param content Ghsigns.PrContent
local function apply_treesitter_highlights(buf, ns, content)
  for _, block in ipairs(content.code_blocks or {}) do
    local code_lines = {}
    for i = block.start_line, block.end_line do
      local line = content.lines[i + 1] or ""
      table.insert(code_lines, line:sub(3)) -- remove "  " indent
    end
    local code_text = table.concat(code_lines, "\n")

    local ok, parser = pcall(vim.treesitter.get_string_parser, code_text, block.language)
    if not ok or not parser then goto continue end

    local trees = parser:parse()
    if not trees or #trees == 0 then goto continue end

    local query = vim.treesitter.query.get(block.language, "highlights")
    if not query then goto continue end

    for id, node in query:iter_captures(trees[1]:root(), code_text) do
      local name = query.captures[id]
      local sr, sc, er, ec = node:range()
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, block.start_line + sr, sc + 2, {
        end_row = block.start_line + er,
        end_col = ec + 2,
        hl_group = "@" .. name .. "." .. block.language,
        priority = 4200,
      })
    end

    ::continue::
  end
end

--- Apply highlights, link extmarks, and title extmark to a buffer
---@param buf integer
---@param ns integer
---@param content Ghsigns.PrContent
---@param pr_url? string
local function apply_content_to_buffer(buf, ns, content, pr_url)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content.lines)

  for _, hl_info in ipairs(content.highlights) do
    local line_text = content.lines[hl_info.line + 1]
    if line_text then
      for _, group in ipairs(hl_info.groups) do
        local end_col = group.end_col
        if end_col == -1 or end_col > #line_text then
          end_col = #line_text
        end
        vim.api.nvim_buf_set_extmark(buf, ns, hl_info.line, group.col, {
          end_col = end_col,
          hl_group = group.hl,
        })
      end
    end
  end

  for _, link in ipairs(content.link_metadata) do
    vim.api.nvim_buf_set_extmark(buf, ns, link.line, link.col_start, {
      end_col = link.col_end,
      hl_group = "Underlined",
      url = link.url,
    })
  end

  if pr_url then
    vim.api.nvim_buf_set_extmark(buf, ns, content.title_line, 0, {
      end_col = #content.title_text,
      url = pr_url,
    })
  end

  apply_treesitter_highlights(buf, ns, content)
end

--- Calculate window size and position, open the floating window
---@param buf integer
---@param content Ghsigns.PrContent
---@return integer win
local function open_float_window(buf, content)
  local width = 0
  for _, line in ipairs(content.lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width + 2, math.floor(vim.o.columns * 0.8))
  local height = math.min(#content.lines, math.floor(vim.o.lines * 0.8))

  local mouse_pos = vim.fn.getmousepos()
  local row = mouse_pos.screenrow
  local col = mouse_pos.screencol

  local total_height = height + 2
  local max_row = vim.o.lines - vim.o.cmdheight - 1

  if row + total_height > max_row then
    row = math.max(0, max_row - total_height)
  end
  if col + width > vim.o.columns then
    col = math.max(0, vim.o.columns - width)
  end

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " PR Info ",
    title_pos = "center",
  })
  float_win:setup(win)

  vim.api.nvim_set_option_value("wrap", true, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.wo[win].statusline = " "
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  return win
end

--- Set up keymaps and mouse click handlers for the floating window
---@param buf integer
---@param ns integer
---@param win integer
---@param content Ghsigns.PrContent
local function setup_float_keymaps(buf, ns, win, content)
  local close_keys = { "q", "<Esc>", "<CR>" }
  for _, key in ipairs(close_keys) do
    vim.api.nvim_buf_set_keymap(buf, "n", key, ":close<CR>", { noremap = true, silent = true })
  end

  vim.keymap.set("n", "<LeftRelease>", function()
    local mouse = vim.fn.getmousepos()
    if mouse.winid == win then
      if mouse.line == content.close_line_idx + 1 then
        float_win:close_if_valid()
        return
      end

      -- In OSC 8 terminals, the terminal handles link clicks natively.
      -- Only use Neovim-level link handling as a fallback for non-OSC 8 terminals.
      if not supports_osc8() then
        local click_line = mouse.line - 1
        local click_col = mouse.column - 1
        local extmarks =
          vim.api.nvim_buf_get_extmarks(buf, ns, { click_line, 0 }, { click_line + 1, 0 }, { details = true })
        for _, mark in ipairs(extmarks) do
          local _, _, start_col, details = unpack(mark)
          if details.url then
            local end_col = details.end_col or (start_col + 1)
            if click_col >= start_col and click_col < end_col then
              vim.notify("Opening: " .. details.url, vim.log.levels.INFO)
              vim.ui.open(details.url)
              return
            end
          end
        end
      end
    end
  end, { buffer = buf, noremap = true, silent = true })
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

  local content = PrDisplay.build_pr_content(pr, opts)
  apply_content_to_buffer(buf, ns, content, pr.url)
  local win = open_float_window(buf, content)
  setup_float_keymaps(buf, ns, win, content)
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
PrDisplay._supports_osc8 = supports_osc8
PrDisplay._reset_osc8_cache = function()
  _osc8_supported = nil
end

return PrDisplay
