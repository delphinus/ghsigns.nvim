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

---@class Ghsigns.FloatWin
---@field private augroup string
---@field private win? integer
local FloatWin = {}

FloatWin.new = function()
  return setmetatable({ augroup = "ghsigns_pr_float" }, { __index = FloatWin })
end

function FloatWin:setup(win)
  self.win = win
  vim.api.nvim_create_autocmd({ "WinEnter", "CursorMoved" }, {
    group = vim.api.nvim_create_augroup(self.augroup, { clear = false }),
    callback = function()
      if self.win ~= vim.api.nvim_get_current_win() then
        self:close_if_valid()
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = vim.api.nvim_create_augroup(self.augroup, { clear = false }),
    pattern = tostring(win),
    once = true,
    callback = function()
      self:close_if_valid()
    end,
  })
end

---@return boolean
function FloatWin:close_if_valid()
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
    pcall(vim.api.nvim_del_augroup_by_name, self.augroup)
    return true
  end
  return false
end

local float_win = FloatWin.new()

---@class Ghsigns.PrData: Ghsigns.Pr
---@field author_name? string
---@field short_body? string

--- Build PR content for display (extracted for testability)
---@param pr Ghsigns.Pr
---@return table content { lines, highlights, link_metadata, title_line, close_line_idx, title_text }
Lualine.build_pr_content = function(pr)
  local p = vim.deepcopy(pr) --[[@as Ghsigns.PrData]]
  if p.author then
    p.author_name = (p.author.name and p.author.name ~= "") and p.author.name or (p.author.login or "Unknown")
  end

  -- Build content with metadata for highlighting
  local lines = {}
  local highlights = {}

  -- Helper to add a line with highlights
  local function add_line(text, hl_groups)
    table.insert(lines, text)
    if hl_groups then
      table.insert(highlights, { line = #lines - 1, groups = hl_groups })
    end
  end

  -- Helper to add a labeled line
  local function add_labeled(label, value, value_hl)
    local line = label .. ": " .. value
    add_line(line, {
      { col = 0, end_col = #label, hl = "Comment" },
      { col = #label + 2, end_col = #line, hl = value_hl or "Normal" },
    })
  end

  -- Title with Draft indicator (clickable)
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
  add_line(title_text, title_hls)

  -- Store title line for URL extmark
  local title_line = #lines - 1

  -- Branches
  if p.baseRefName and p.headRefName then
    local branch_info = string.format("%s ← %s", p.baseRefName, p.headRefName)
    add_line(branch_info, {
      { col = 0, end_col = #p.baseRefName, hl = "String" },
      { col = #p.baseRefName + 1, end_col = #p.baseRefName + 3, hl = "Operator" },
      { col = #p.baseRefName + 4, end_col = -1, hl = "Identifier" },
    })
  end

  add_line ""

  -- Author
  if p.author_name then
    add_labeled("Author", p.author_name, "String")
  end

  -- State
  if p.state then
    local state_hl = p.state == "OPEN" and "DiagnosticOk" or "DiagnosticError"
    add_labeled("State", p.state, state_hl)
  end

  -- Review Decision
  if p.reviewDecision and p.reviewDecision ~= "" then
    local review_hl = "DiagnosticWarn"
    if p.reviewDecision == "APPROVED" then
      review_hl = "DiagnosticOk"
    elseif p.reviewDecision == "CHANGES_REQUESTED" then
      review_hl = "DiagnosticError"
    end
    add_labeled("Review", p.reviewDecision:gsub("_", " "), review_hl)
  end

  -- Mergeable
  if p.mergeable and p.mergeable ~= "" then
    local merge_hl = p.mergeable == "MERGEABLE" and "DiagnosticOk" or "DiagnosticError"
    add_labeled("Mergeable", p.mergeable, merge_hl)
  end

  -- Changes
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

  -- Calculate highlight positions: "Changes: +103 -30 (5 files, 6 commits)"
  local plus_start = #changes_start
  local plus_end = plus_start + 1 + #additions_str -- "+103" = 4 chars
  local minus_start = plus_end + 1 -- space after +103
  local minus_end = minus_start + 1 + #deletions_str -- "-30" = 3 chars

  add_line(changes_start .. changes, {
    { col = 0, end_col = #changes_start - 1, hl = "Comment" },
    { col = plus_start, end_col = plus_end, hl = "DiffAdd" },
    { col = minus_start, end_col = minus_end, hl = "DiffDelete" },
    { col = minus_end + 1, end_col = -1, hl = "Comment" },
  })

  -- Labels
  if p.labels and p.labels.nodes and #p.labels.nodes > 0 then
    local label_names = vim.tbl_map(function(label)
      return label.name
    end, p.labels.nodes)
    add_labeled("Labels", table.concat(label_names, ", "), "Tag")
  end

  add_line ""

  -- Dates
  if p.createdAt then
    add_labeled("Created", p.createdAt, "DiagnosticHint")
  end
  if p.updatedAt then
    add_labeled("Updated", p.updatedAt, "DiagnosticHint")
  end
  if p.mergedAt then
    add_labeled("Merged", p.mergedAt, "DiagnosticOk")
  end

  -- Store clickable links metadata
  local link_metadata = {}

  -- Extract base repository URL from PR URL
  local repo_base_url = nil
  if p.url then
    -- Extract https://github.com/owner/repo from https://github.com/owner/repo/pull/123
    repo_base_url = p.url:match "(https://[^/]+/[^/]+/[^/]+)"
  end

  -- Import markdown rendering module
  local markdown = require "ghsigns.markdown"

  -- Helper function to add markdown line with wrapping support
  local function add_markdown_line(text, indent, max_width)
    indent = indent or "  "
    max_width = max_width or 80

    local rendered_text, md_highlights, md_links, special_type = markdown.render(text, repo_base_url)

    -- Extract blockquote prefix for continuation lines
    local quote_prefix = ""
    if special_type == "blockquote" then
      quote_prefix = rendered_text:match "^([│ ]+)" or ""
    end

    -- Wrap if necessary
    local display_width = vim.fn.strdisplaywidth(rendered_text)
    if display_width > max_width then
      -- For blockquotes, wrap only the content after the prefix
      local wrap_text = rendered_text
      local content_offset = 0
      if quote_prefix ~= "" then
        wrap_text = rendered_text:sub(#quote_prefix + 1)
        content_offset = #quote_prefix
      end

      -- Wrap the text and track positions
      local wrapped_lines = {}
      local line_starts = {} -- Track where each wrapped line starts in the original text
      local current = ""
      local current_width = 0
      local current_start = 0
      local char_pos = 0

      -- Split into words while tracking positions
      local words = {}
      local word_positions = {}
      for word in wrap_text:gmatch "%S+" do
        local word_start = wrap_text:find(word, char_pos + 1, true)
        table.insert(words, word)
        table.insert(word_positions, word_start - 1) -- 0-indexed relative to wrap_text
        char_pos = word_start + #word - 1
      end

      -- Available width for content (account for prefix on continuation lines)
      local content_max_width = max_width
      if quote_prefix ~= "" then
        content_max_width = max_width - vim.fn.strdisplaywidth(quote_prefix)
      end

      -- Wrap words
      for i, word in ipairs(words) do
        local word_width = vim.fn.strdisplaywidth(word)
        local space_width = current == "" and 0 or 1

        if current_width + space_width + word_width > content_max_width and current ~= "" then
          table.insert(wrapped_lines, current)
          table.insert(line_starts, current_start)
          current = word
          current_start = word_positions[i]
          current_width = word_width
        else
          if current ~= "" then
            current = current .. " " .. word
            current_width = current_width + 1 + word_width
          else
            current = word
            current_start = word_positions[i]
            current_width = word_width
          end
        end
      end

      if current ~= "" then
        table.insert(wrapped_lines, current)
        table.insert(line_starts, current_start)
      end

      -- Add each wrapped line
      for idx, wline in ipairs(wrapped_lines) do
        local line_start_pos = line_starts[idx]
        local line_prefix = indent
        local extra_offset = 0

        -- Prepend blockquote prefix to each wrapped line
        if quote_prefix ~= "" then
          line_prefix = indent .. quote_prefix
          extra_offset = #quote_prefix
        end

        local line_hls = {}

        -- Add FloatBorder highlight for blockquote prefix on continuation lines
        if quote_prefix ~= "" and idx > 1 then
          table.insert(line_hls, {
            col = #indent,
            end_col = #indent + #quote_prefix,
            hl = "FloatBorder",
          })
        end

        for _, hl in ipairs(md_highlights) do
          local hl_start = hl.col - content_offset
          local hl_end = hl.end_col - content_offset
          local wline_end = line_start_pos + #wline

          -- Skip the FloatBorder highlight for the prefix (already handled above)
          if hl.hl == "FloatBorder" and hl.col == 0 then
            if idx == 1 then
              -- First line: use the original highlight as-is
              table.insert(line_hls, {
                col = #indent + hl.col,
                end_col = #indent + hl.end_col,
                hl = hl.hl,
              })
            end
          elseif hl_end > line_start_pos and hl_start < wline_end then
            -- Check if highlight overlaps with this wrapped line
            local local_start = math.max(0, hl_start - line_start_pos)
            local local_end = math.min(#wline, hl_end - line_start_pos)
            table.insert(line_hls, {
              col = local_start + #line_prefix,
              end_col = local_end + #line_prefix,
              hl = hl.hl,
            })
          end
        end

        add_line(line_prefix .. wline, #line_hls > 0 and line_hls or nil)

        -- Add link metadata for any wrapped line that contains a link
        for _, link in ipairs(md_links) do
          local link_start = link.col_start - content_offset
          local link_end = link.col_end - content_offset
          local wline_end = line_start_pos + #wline

          -- Check if link overlaps with this wrapped line
          if link_end > line_start_pos and link_start < wline_end then
            local local_start = math.max(0, link_start - line_start_pos)
            local local_end = math.min(#wline, link_end - line_start_pos)
            table.insert(link_metadata, {
              line = #lines - 1,
              col_start = local_start + #line_prefix,
              col_end = local_end + #line_prefix,
              url = link.url,
            })
          end
        end
      end
    else
      -- No wrapping needed
      local line_hls = {}
      for _, hl in ipairs(md_highlights) do
        table.insert(line_hls, {
          col = hl.col + #indent,
          end_col = hl.end_col + #indent,
          hl = hl.hl,
        })
      end

      add_line(indent .. rendered_text, #line_hls > 0 and line_hls or nil)

      -- Add link metadata
      for _, link in ipairs(md_links) do
        table.insert(link_metadata, {
          line = #lines - 1,
          col_start = link.col_start + #indent,
          col_end = link.col_end + #indent,
          url = link.url,
        })
      end
    end
  end

  -- Helper function to wrap long lines
  local function wrap_line(text, max_width, indent)
    local lines_out = {}
    local current = ""
    local current_width = 0

    for word in text:gmatch "%S+" do
      local word_width = vim.fn.strdisplaywidth(word)
      local space_width = current == "" and 0 or 1

      if current_width + space_width + word_width > max_width and current ~= "" then
        table.insert(lines_out, indent .. current)
        current = word
        current_width = word_width
      else
        if current ~= "" then
          current = current .. " " .. word
          current_width = current_width + 1 + word_width
        else
          current = word
          current_width = word_width
        end
      end
    end

    if current ~= "" then
      table.insert(lines_out, indent .. current)
    end

    return lines_out
  end

  -- Body with markdown rendering
  if p.body and p.body ~= "" then
    add_line ""
    add_line("Description:", { { col = 0, end_col = -1, hl = "Comment" } })

    -- Normalize line endings (remove CR)
    local normalized_body = p.body:gsub("\r\n", "\n"):gsub("\r", "\n")

    -- Remove HTML comments
    normalized_body = normalized_body:gsub("<!%-%-.-%-%->", "")

    -- Remove HTML tags
    normalized_body = normalized_body:gsub("<[^>]+>", "")

    local body_lines = vim.split(normalized_body, "\n")

    -- Remove consecutive blank lines
    local cleaned_lines = {}
    local prev_blank = false
    for _, line in ipairs(body_lines) do
      local is_blank = line:match "^%s*$" ~= nil
      if not (is_blank and prev_blank) then
        table.insert(cleaned_lines, line)
      end
      prev_blank = is_blank
    end

    local in_code_block = false
    local lines_shown = 0
    local max_lines = 15
    local max_width = 80

    for _, body_line in ipairs(cleaned_lines) do
      local lines_before = #lines

      -- Code blocks ```
      if body_line:match "^```" then
        in_code_block = not in_code_block
        add_line("  " .. body_line, { { col = 0, end_col = -1, hl = "Comment" } })
      elseif in_code_block then
        -- Wrap code block lines if too long
        local display_width = vim.fn.strdisplaywidth(body_line)
        if display_width > max_width then
          local wrapped = wrap_line(body_line, max_width, "  ")
          for _, wline in ipairs(wrapped) do
            add_line(wline, { { col = 0, end_col = -1, hl = "String" } })
          end
        else
          add_line("  " .. body_line, { { col = 0, end_col = -1, hl = "String" } })
        end
      else
        add_markdown_line(body_line, "  ", max_width)
      end

      -- Count lines added
      local lines_added = #lines - lines_before
      lines_shown = lines_shown + lines_added

      -- Check if we've exceeded max lines
      if lines_shown >= max_lines then
        add_line("  ... (truncated)", { { col = 0, end_col = -1, hl = "Comment" } })
        break
      end
    end
  end

  -- Add close button at the bottom
  add_line ""
  local close_text = "✕ Click here to close (or press q/Esc/Enter)"
  add_line(
    close_text,
    { { col = 0, end_col = 1, hl = "ErrorMsg" }, { col = 2, end_col = #close_text, hl = "Comment" } }
  )
  local close_line_idx = #lines - 1

  return {
    lines = lines,
    highlights = highlights,
    link_metadata = link_metadata,
    title_line = title_line,
    close_line_idx = close_line_idx,
    title_text = title_text,
  }
end

--- @param pr Ghsigns.Pr
Lualine.show_pr_info = function(pr)
  -- Close existing floating window if present
  if float_win:close_if_valid() then
    return
  end

  -- Create a floating window
  local buf = vim.api.nvim_create_buf(false, true)
  local ns = vim.api.nvim_create_namespace "ghsigns_pr_info"

  -- Create custom highlight group for PR title (Title + underline)
  local title_hl = vim.api.nvim_get_hl(0, { name = "Title" })
  title_hl.underline = true
  vim.api.nvim_set_hl(0, "GhsignsPrTitle", title_hl)

  -- Build content
  local content = Lualine.build_pr_content(pr)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content.lines)

  -- Calculate window size
  local width = 0
  for _, line in ipairs(content.lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width + 2, math.floor(vim.o.columns * 0.8))
  local height = math.min(#content.lines, math.floor(vim.o.lines * 0.8))

  -- Apply highlights
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

  -- Apply clickable links
  for _, link in ipairs(content.link_metadata) do
    vim.api.nvim_buf_set_extmark(buf, ns, link.line, link.col_start, {
      end_col = link.col_end,
      hl_group = "Underlined",
      url = link.url,
    })
  end

  -- Apply URL extmark to title line for hover effect
  if pr.url then
    vim.api.nvim_buf_set_extmark(buf, ns, content.title_line, 0, {
      end_col = #content.title_text,
      url = pr.url,
    })
  end

  -- Get mouse position
  local mouse_pos = vim.fn.getmousepos()
  local row = mouse_pos.screenrow
  local col = mouse_pos.screencol

  -- Calculate available space (excluding status line and command line)
  -- vim.o.lines includes all lines (0-indexed rows from 0 to lines-1)
  -- Border adds 2 rows (top and bottom), so total window height is height + 2
  local total_height = height + 2 -- content + borders
  local max_row = vim.o.lines - vim.o.cmdheight - 1 -- Last row before cmdline

  -- Adjust position to avoid going off screen and overlapping with status line
  -- Ensure the bottom of the window doesn't exceed max_row
  if row + total_height > max_row then
    row = math.max(0, max_row - total_height)
  end
  if col + width > vim.o.columns then
    col = math.max(0, vim.o.columns - width)
  end

  -- Window options
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " PR Info ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, false, opts)
  float_win:setup(win)

  -- Set window options
  vim.api.nvim_set_option_value("wrap", true, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.wo[win].statusline = " " -- Hide status line in floating window
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  -- Key mappings to close the window
  local close_keys = { "q", "<Esc>", "<CR>" }
  for _, key in ipairs(close_keys) do
    vim.api.nvim_buf_set_keymap(buf, "n", key, ":close<CR>", { noremap = true, silent = true })
  end

  -- Mouse click handler: close button uses position check, URLs use extmarks
  vim.keymap.set("n", "<LeftRelease>", function()
    local mouse = vim.fn.getmousepos()
    if mouse.winid == win then
      -- Check if close button was clicked
      if mouse.line == content.close_line_idx + 1 then -- 1-indexed
        float_win:close_if_valid()
        return
      end

      -- Check for clickable extmarks with url property
      local click_line = mouse.line - 1 -- 0-indexed
      local click_col = mouse.column - 1 -- 0-indexed
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
  end, { buffer = buf, noremap = true, silent = true })
end

return Lualine
