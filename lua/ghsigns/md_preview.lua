local FloatWin = require "ghsigns.float_win"
local cb = require "ghsigns.content_builder"
local display_utils = require "ghsigns.display_utils"
local ContentBuilder = cb.ContentBuilder

local float_win = FloatWin.new "ghsigns_md_preview_float"

local MdPreview = {}

--- Build rendered content from markdown lines (extracted for testability)
---@param lines string[]
---@param opts? { max_width?: integer }
---@return Ghsigns.PrContent
--- Parse simple YAML frontmatter lines into key-value pairs
---@param fm_lines string[]
---@return {key: string, value: string}[]
local function parse_frontmatter(fm_lines)
  local entries = {}
  local current_key = nil
  local current_list = {}

  local function flush_list()
    if current_key and #current_list > 0 then
      table.insert(entries, {
        key = current_key,
        value = table.concat(current_list, ", "),
      })
      current_key = nil
      current_list = {}
    end
  end

  for _, line in ipairs(fm_lines) do
    local list_value = line:match "^%s+%-%s+(.+)$"
    if list_value and current_key then
      table.insert(current_list, list_value)
    else
      flush_list()
      local key, value = line:match "^([%w_%-]+):%s*(.*)$"
      if key then
        if value and value ~= "" then
          table.insert(entries, { key = key, value = value })
          current_key = nil
        else
          current_key = key
          current_list = {}
        end
      end
    end
  end
  flush_list()

  return entries
end

MdPreview.build_content = function(lines, opts)
  opts = opts or {}
  local max_width = opts.max_width or 80

  local b = ContentBuilder.new()

  -- Detect and extract frontmatter
  local body_start = 1
  if lines[1] and lines[1]:match "^%-%-%-$" then
    local frontmatter_lines = {}
    for i = 2, #lines do
      if lines[i]:match "^%-%-%-$" then
        body_start = i + 1
        break
      end
      table.insert(frontmatter_lines, lines[i])
    end
    if body_start > 1 and #frontmatter_lines > 0 then
      local entries = parse_frontmatter(frontmatter_lines)
      if #entries > 0 then
        b:add_line("  Properties", {
          { col = 2, end_col = 2 + #"Properties", hl = "Title" },
        })
        for _, entry in ipairs(entries) do
          b:add_labeled("  " .. entry.key, entry.value, "String")
        end
        b:add_line ""
      end
    end
  end

  local fold_state = opts.fold_state or {}
  local expand_state = opts.expand_state or {}

  local in_code_block = false
  local code_block_lang = nil
  local code_block_start = nil
  local code_source_lines = nil
  local code_block_id = nil
  local code_block_has_truncation = false
  local prev_was_heading = false
  local prev_was_blank = false
  local table_buf = {}
  local table_buf_start_idx = nil
  local lines_shown = 0
  local current_alert_type = nil
  local skip_callout_body = false
  local in_callout_code_block = false
  local callout_code_lang = nil
  local callout_code_start = nil
  local callout_code_prefix = nil
  local callout_code_source_lines = nil
  local callout_code_block_id = nil
  local callout_code_has_truncation = false
  local in_comment_block = false

  --- Flush accumulated table lines
  local function flush_table()
    if #table_buf > 0 then
      local lines_before_tbl = #b.lines
      local tbl_expanded = table_buf_start_idx and expand_state[table_buf_start_idx]
      local effective_max = tbl_expanded and math.huge or max_width
      b:add_table(table_buf, "  ", effective_max)
      local has_truncation = false
      if not tbl_expanded then
        for li = lines_before_tbl + 1, #b.lines do
          if b.lines[li] and b.lines[li]:match "…" then
            has_truncation = true
            break
          end
        end
      end
      if has_truncation or tbl_expanded then
        table.insert(b.expandable_regions, {
          start_line = lines_before_tbl,
          end_line = #b.lines - 1,
          block_id = table_buf_start_idx,
          expanded = tbl_expanded or false,
        })
      end
      table_buf = {}
      table_buf_start_idx = nil
    end
  end

  for i = body_start, #lines do
    local line = lines[i]
    local is_blank = line:match "^%s*$" ~= nil
    local is_heading = (not in_code_block) and line:match "^#+%s+" ~= nil
    local is_table_line = (not in_code_block) and line:match "^%s*|" ~= nil

    -- Skip body lines of a collapsed foldable callout
    if skip_callout_body then
      if line:match "^>" then
        goto continue
      else
        skip_callout_body = false
        current_alert_type = nil
      end
    end

    -- Toggle Obsidian block comment (outside code blocks)
    if not in_code_block and line:match "^%s*%%%%%s*$" then
      in_comment_block = not in_comment_block
      goto continue
    end
    if in_comment_block then
      goto continue
    end

    -- Accumulate table lines
    if is_table_line then
      if #table_buf == 0 then
        table_buf_start_idx = i
      end
      table.insert(table_buf, line)
      goto continue
    end

    -- Flush table buffer when a non-table line is encountered
    if #table_buf > 0 then
      flush_table()
    end

    -- Skip blank lines immediately after headings (outside code blocks)
    if not in_code_block and is_blank and prev_was_heading then
      prev_was_blank = true
      goto continue
    end

    -- Auto-insert blank line before headings if not already preceded by one
    if not in_code_block and is_heading and lines_shown > 0 and not prev_was_blank then
      b:add_line "  "
      lines_shown = lines_shown + 1
    end

    local lines_before = #b.lines

    if line:match "^```" then
      if not in_code_block then
        in_code_block = true
        code_block_lang = line:match "^```(%S+)" or nil
        code_block_start = #b.lines
        code_source_lines = {}
        code_block_id = i
        code_block_has_truncation = false
      else
        if code_block_lang and code_block_start < #b.lines then
          table.insert(b.code_blocks, {
            language = code_block_lang,
            start_line = code_block_start,
            end_line = #b.lines - 1,
            source_lines = code_source_lines,
          })
        end
        if code_block_has_truncation or expand_state[code_block_id] then
          table.insert(b.expandable_regions, {
            start_line = code_block_start,
            end_line = #b.lines - 1,
            block_id = code_block_id,
            expanded = expand_state[code_block_id] or false,
          })
        end
        in_code_block = false
        code_block_lang = nil
        code_source_lines = nil
        code_block_id = nil
      end
    elseif in_code_block then
      table.insert(code_source_lines, line)
      local indented = "  " .. line
      local display_width = vim.fn.strdisplaywidth(indented)
      if not expand_state[code_block_id] and display_width > max_width then
        code_block_has_truncation = true
        local target = max_width - 1
        local current_width = 0
        local byte_pos = 0
        for char in indented:gmatch "[%z\1-\127\194-\253][\128-\191]*" do
          local char_width = vim.fn.strdisplaywidth(char)
          if current_width + char_width > target then
            break
          end
          current_width = current_width + char_width
          byte_pos = byte_pos + #char
        end
        local truncated_line = indented:sub(1, byte_pos) .. "…"
        b:add_line(truncated_line, {
          { col = 0, end_col = byte_pos, hl = "String" },
          { col = byte_pos, end_col = #truncated_line, hl = "Underlined" },
        })
      else
        b:add_line(indented, { { col = 0, end_col = -1, hl = "String" } })
      end
    else
      local handled = false

      -- Handle code blocks inside callouts
      if current_alert_type and line:match "^>" then
        local stripped = line:gsub("^>%s?", "")
        if stripped:match "^```" then
          if not in_callout_code_block then
            in_callout_code_block = true
            callout_code_lang = stripped:match "^```(%S+)" or nil
            callout_code_prefix = "  │ "
            callout_code_start = #b.lines
            callout_code_source_lines = {}
            callout_code_block_id = i
            callout_code_has_truncation = false
          else
            if callout_code_lang and callout_code_start < #b.lines then
              table.insert(b.code_blocks, {
                language = callout_code_lang,
                start_line = callout_code_start,
                end_line = #b.lines - 1,
                prefix_len = #callout_code_prefix,
                source_lines = callout_code_source_lines,
              })
            end
            if callout_code_has_truncation or expand_state[callout_code_block_id] then
              table.insert(b.expandable_regions, {
                start_line = callout_code_start,
                end_line = #b.lines - 1,
                block_id = callout_code_block_id,
                expanded = expand_state[callout_code_block_id] or false,
              })
            end
            in_callout_code_block = false
            callout_code_lang = nil
            callout_code_source_lines = nil
            callout_code_block_id = nil
          end
          handled = true
        elseif in_callout_code_block then
          table.insert(callout_code_source_lines, stripped)
          local code_line = callout_code_prefix .. stripped
          local display_width = vim.fn.strdisplaywidth(code_line)
          if not expand_state[callout_code_block_id] and display_width > max_width then
            callout_code_has_truncation = true
            local target = max_width - 1
            local current_width = 0
            local byte_pos = 0
            for char in code_line:gmatch "[%z\1-\127\194-\253][\128-\191]*" do
              local char_width = vim.fn.strdisplaywidth(char)
              if current_width + char_width > target then
                break
              end
              current_width = current_width + char_width
              byte_pos = byte_pos + #char
            end
            local truncated_code = code_line:sub(1, byte_pos) .. "…"
            b:add_line(truncated_code, {
              { col = 2, end_col = 2 + #"│ ", hl = "FloatBorder" },
              { col = #callout_code_prefix, end_col = byte_pos, hl = "String" },
              { col = byte_pos, end_col = #truncated_code, hl = "Underlined" },
            })
          else
            b:add_line(code_line, {
              { col = 2, end_col = 2 + #"│ ", hl = "FloatBorder" },
              { col = #callout_code_prefix, end_col = -1, hl = "String" },
            })
          end
          b:apply_alert_styling(lines_before, #b.lines, current_alert_type, false)
          handled = true
        end
      end

      if not handled then
        -- Reset callout code block state if we leave the callout
        if in_callout_code_block and not (line:match "^>") then
          in_callout_code_block = false
          callout_code_lang = nil
        end

        local alert_type, fold_mod = b:add_markdown_line(line, "  ", max_width)
        local lines_after = #b.lines
        if alert_type then
          current_alert_type = alert_type

          if fold_mod then
            local is_collapsed
            if fold_state[i] ~= nil then
              is_collapsed = fold_state[i]
            else
              is_collapsed = (fold_mod == "-")
            end
            b:add_fold_indicator(lines_before, is_collapsed)
            table.insert(b.callout_folds, {
              header_line = lines_before,
              source_line = i,
              collapsed = is_collapsed,
            })
            if is_collapsed then
              skip_callout_body = true
            end
          end

          b:apply_alert_styling(lines_before, #b.lines, current_alert_type, true)
        elseif current_alert_type and line:match "^>" then
          b:apply_alert_styling(lines_before, lines_after, current_alert_type, false)
        else
          current_alert_type = nil
        end
      end
    end

    local lines_added = #b.lines - lines_before
    lines_shown = lines_shown + lines_added

    prev_was_heading = is_heading
    prev_was_blank = is_blank

    ::continue::
  end

  -- Flush any remaining table lines
  flush_table()

  return b:result()
end

--- Show a floating window previewing the current buffer's markdown content
---@param opts? { max_width?: integer }
MdPreview.show = function(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local name = vim.api.nvim_buf_get_name(bufnr)

  if ft ~= "markdown" and not name:match "%.md$" and not name:match "%.markdown$" then
    vim.notify("ghsigns: current buffer is not a Markdown file", vim.log.levels.WARN)
    return
  end

  if float_win:close_if_valid() then
    return
  end

  local source_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local fold_state = {}
  local expand_state = {}
  opts = opts or {}

  local buf = vim.api.nvim_create_buf(false, true)
  local ns = vim.api.nvim_create_namespace "ghsigns_md_preview"

  -- Obsidian ==highlight== marker
  vim.api.nvim_set_hl(0, "GhsignsHighlight", { bg = "#3b3600", fg = "#ffec80", default = true })

  -- Set up alert highlight groups (shared with pr_display)
  local pr_display = require "ghsigns.pr_display"
  pr_display.setup_alert_highlights()

  local content

  local function rebuild()
    opts.fold_state = fold_state
    opts.expand_state = expand_state
    local new_content = MdPreview.build_content(source_lines, opts)
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    display_utils.apply_content_to_buffer(buf, ns, new_content)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    -- Toggle wrap based on whether any block is expanded
    local any_expanded = false
    for _, v in pairs(expand_state) do
      if v then any_expanded = true; break end
    end
    vim.api.nvim_set_option_value("wrap", not any_expanded, { win = win })
    content = new_content
  end

  content = MdPreview.build_content(source_lines, opts)
  display_utils.apply_content_to_buffer(buf, ns, content)
  local win = display_utils.open_float_window(buf, content, float_win, {
    title = " Markdown Preview ",
    position = "center",
    enter = true,
  })

  -- Initialize fold_state from default fold states
  for _, fold in ipairs(content.callout_folds) do
    fold_state[fold.source_line] = fold.collapsed
  end

  display_utils.setup_float_keymaps(buf, ns, win, content, float_win, {
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

return MdPreview
