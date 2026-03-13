local md_render = require "md-render"
local FloatWin = md_render.FloatWin
local ContentBuilder = md_render.ContentBuilder
local display_utils = md_render.display_utils

local float_win = FloatWin.new "ghsigns_pr_float"

local PrDisplay = {}

--- Prepare PR data by deep-copying and extracting author name
---@param pr Ghsigns.Pr
---@return Ghsigns.PrData
local function prepare_pr_data(pr)
  local p = vim.deepcopy(pr) --[[@as Ghsigns.PrData]]
  if p.author then
    p.author_name = (p.author.name and p.author.name ~= "") and p.author.name or (p.author.login or "Unknown")
  end
  return p
end

--- Convert an ISO 8601 UTC timestamp to local time string.
---@param iso_str string e.g. "2024-01-01T00:00:00Z"
---@return string e.g. "2024-01-01 09:00:00 JST"
local function format_local_time(iso_str)
  local y, m, d, h, min, s = iso_str:match "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
  if not y then
    return iso_str
  end
  local t = os.time {
    year = tonumber(y),
    month = tonumber(m),
    day = tonumber(d),
    hour = tonumber(h),
    min = tonumber(min),
    sec = tonumber(s),
  }
  local ref = os.time()
  local offset = os.difftime(ref, os.time(os.date("!*t", ref)))
  return os.date("%Y-%m-%d %H:%M:%S %Z", t + offset)
end

--- Normalize body text: fix line endings, strip HTML, compress blank lines
---@param body string
---@return string[]
local function normalize_body(body)
  local text = body:gsub("\r\n", "\n"):gsub("\r", "\n")
  text = text:gsub("<!%-%-.-%-%->", "")
  text = text:gsub("<[^>]+>", "")

  local raw_lines = vim.split(text, "\n")
  local cleaned = {}
  local prev_blank = false
  for _, line in ipairs(raw_lines) do
    local is_blank = line:match "^%s*$" ~= nil
    if not (is_blank and prev_blank) then
      table.insert(cleaned, line)
    end
    prev_blank = is_blank
  end
  return cleaned
end

--- Add title line with optional DRAFT indicator
---@param b MdRender.ContentBuilder
---@param p Ghsigns.PrData
---@return integer title_line
---@return string title_text
local function add_title_line(b, p)
  local title_prefix = (p.isDraft == true) and "[DRAFT] " or ""
  local title_text = "#" .. (p.number or 0) .. " " .. title_prefix .. (p.title or "")
  local number_str = tostring(p.number or 0)
  local title_hls = {
    { col = 0, end_col = #number_str + 1, hl = "Number" },
  }
  if p.isDraft == true then
    local draft_start = #number_str + 2
    table.insert(title_hls, { col = draft_start, end_col = draft_start + 7, hl = "WarningMsg" })
    table.insert(title_hls, { col = draft_start + 8, end_col = -1, hl = "GhsignsPrTitle" })
  else
    table.insert(title_hls, { col = #number_str + 2, end_col = -1, hl = "GhsignsPrTitle" })
  end
  b:add_line(title_text, title_hls)
  return #b.lines - 1, title_text
end

--- Add changes line with diff-colored highlights
---@param b MdRender.ContentBuilder
---@param p Ghsigns.PrData
local function add_changes_line(b, p)
  local commit_count = 0
  if p.commits then
    if p.commits.nodes then
      commit_count = #p.commits.nodes
    elseif type(p.commits) == "table" then
      commit_count = #p.commits
    end
  end
  local changed_files = p.changedFiles or 0
  local additions_str = tostring(p.additions or 0)
  local deletions_str = tostring(p.deletions or 0)
  local changes =
    string.format("+%s -%s (%d files, %d commits)", additions_str, deletions_str, changed_files, commit_count)
  local changes_start = "Changes: "

  local plus_start = #changes_start
  local plus_end = plus_start + 1 + #additions_str
  local minus_start = plus_end + 1
  local minus_end = minus_start + 1 + #deletions_str

  b:add_line(changes_start .. changes, {
    { col = 0, end_col = #changes_start - 1, hl = "Comment" },
    { col = plus_start, end_col = plus_end, hl = "DiffAdd" },
    { col = minus_start, end_col = minus_end, hl = "DiffDelete" },
    { col = minus_end + 1, end_col = -1, hl = "Comment" },
  })
end

--- Add metadata fields (Author, State, Review, Mergeable, Changes, Labels)
---@param b MdRender.ContentBuilder
---@param p Ghsigns.PrData
local function add_metadata_fields(b, p)
  if p.author_name then
    b:add_labeled("Author", p.author_name, "String")
  end

  if p.state then
    local state_hl = p.state == "OPEN" and "DiagnosticOk" or "DiagnosticError"
    b:add_labeled("State", p.state, state_hl)
  end

  if p.reviewDecision and p.reviewDecision ~= "" then
    local review_hl = "DiagnosticWarn"
    if p.reviewDecision == "APPROVED" then
      review_hl = "DiagnosticOk"
    elseif p.reviewDecision == "CHANGES_REQUESTED" then
      review_hl = "DiagnosticError"
    end
    b:add_labeled("Review", p.reviewDecision:gsub("_", " "), review_hl)
  end

  if p.state == "OPEN" and p.mergeable and p.mergeable ~= "" then
    local merge_hl = p.mergeable == "MERGEABLE" and "DiagnosticOk" or "DiagnosticError"
    b:add_labeled("Mergeable", p.mergeable, merge_hl)
  end

  add_changes_line(b, p)

  if p.labels and p.labels.nodes and #p.labels.nodes > 0 then
    local label_names = vim.tbl_map(function(label)
      return label.name
    end, p.labels.nodes)
    b:add_labeled("Labels", table.concat(label_names, ", "), "Tag")
  end
end

--- Add date fields (Created, Updated, Merged)
---@param b MdRender.ContentBuilder
---@param p Ghsigns.PrData
local function add_date_fields(b, p)
  if p.createdAt then
    b:add_labeled("Created", format_local_time(p.createdAt), "DiagnosticHint")
  end
  if p.updatedAt then
    b:add_labeled("Updated", format_local_time(p.updatedAt), "DiagnosticHint")
  end
  if p.mergedAt then
    b:add_labeled("Merged", format_local_time(p.mergedAt), "DiagnosticOk")
  end
end

--- Build the header section (title, branches, metadata, dates)
---@param b MdRender.ContentBuilder
---@param p Ghsigns.PrData
---@return integer title_line
---@return string title_text
local function build_header(b, p)
  local title_line, title_text = add_title_line(b, p)

  if p.baseRefName and p.headRefName then
    local branch_info = string.format("%s → %s", p.headRefName, p.baseRefName)
    b:add_line(branch_info, {
      { col = 0, end_col = #p.headRefName, hl = "Identifier" },
      { col = #p.headRefName + 1, end_col = #p.headRefName + 3, hl = "Operator" },
      { col = #p.headRefName + 4, end_col = -1, hl = "String" },
    })
  end

  b:add_line ""
  add_metadata_fields(b, p)
  b:add_line ""
  add_date_fields(b, p)

  return title_line, title_text
end

--- Build the body section (description with markdown rendering)
---@param b MdRender.ContentBuilder
---@param p Ghsigns.PrData
---@param opts? { max_body_lines?: integer, autolinks?: Ghsigns.Autolink[], fold_state?: table<integer, boolean>, expand_state?: table<integer, boolean> }
local function build_body(b, p, opts)
  if not p.body or p.body == "" then
    return
  end

  local repo_base_url = nil
  if p.url then
    repo_base_url = p.url:match "(https://[^/]+/[^/]+/[^/]+)"
  end

  b:add_line ""
  b:add_line("Description:", { { col = 0, end_col = -1, hl = "Comment" } })

  local cleaned_lines = normalize_body(p.body)

  b:render_document(cleaned_lines, {
    max_width = 80,
    max_lines = opts and opts.max_body_lines or math.huge,
    repo_base_url = repo_base_url,
    autolinks = opts and opts.autolinks,
    fold_state = opts and opts.fold_state,
    expand_state = opts and opts.expand_state,
  })
end

--- Build the footer section (close button)
---@param b MdRender.ContentBuilder
---@return integer close_line_idx
local function build_footer(b)
  b:add_line ""
  local close_text = "✕ Click here to close (or press q/Esc/Enter)"
  b:add_line(
    close_text,
    { { col = 0, end_col = 1, hl = "ErrorMsg" }, { col = 2, end_col = #close_text, hl = "Comment" } }
  )
  return #b.lines - 1
end

--- Build PR content for display (extracted for testability)
---@param pr Ghsigns.Pr
---@param opts? { max_body_lines?: integer, autolinks?: Ghsigns.Autolink[], fold_state?: table<integer, boolean> }
---@return MdRender.Content
PrDisplay.build_pr_content = function(pr, opts)
  local b = ContentBuilder.new()
  local p = prepare_pr_data(pr)
  local title_line, title_text = build_header(b, p)
  build_body(b, p, opts)
  local close_line_idx = build_footer(b)
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

  md_render.setup_highlights()

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
  local win = display_utils.open_float_window(buf, content, float_win, { title = " PR Info " })

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
PrDisplay._blend_color = md_render._blend_color
PrDisplay._format_local_time = format_local_time

return PrDisplay
