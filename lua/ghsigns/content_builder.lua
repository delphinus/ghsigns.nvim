---@class Ghsigns.PrData: Ghsigns.Pr
---@field author_name? string

---@class Ghsigns.Highlight.Group
---@field col integer 0-indexed start column
---@field end_col integer 0-indexed end column (-1 means end of line)
---@field hl string highlight group name
---@field hl_eol? boolean extend highlight to end of line

---@class Ghsigns.LineHighlight
---@field line integer 0-indexed line number
---@field groups Ghsigns.Highlight.Group[]

---@class Ghsigns.LinkMetadata
---@field line integer 0-indexed line number
---@field col_start integer 0-indexed start column
---@field col_end integer 0-indexed end column
---@field url string

---@class Ghsigns.CodeBlock
---@field language string
---@field start_line integer 0-indexed, first code line
---@field end_line integer   0-indexed, last code line
---@field prefix_len integer byte length of line prefix to strip for treesitter (default 2)
---@field source_lines? string[] original (non-truncated) code lines for accurate treesitter parsing

---@class Ghsigns.CalloutFold
---@field header_line integer 0-indexed rendered line of the callout header
---@field source_line integer 1-indexed source line index
---@field collapsed boolean current fold state

---@class Ghsigns.ExpandableRegion
---@field start_line integer 0-indexed first rendered line of the region
---@field end_line integer 0-indexed last rendered line of the region
---@field block_id integer unique identifier for expand_state lookup
---@field expanded boolean current state

---@class Ghsigns.PrContent
---@field lines string[]
---@field highlights Ghsigns.LineHighlight[]
---@field link_metadata Ghsigns.LinkMetadata[]
---@field code_blocks Ghsigns.CodeBlock[]
---@field callout_folds Ghsigns.CalloutFold[]
---@field expandable_regions Ghsigns.ExpandableRegion[]
---@field title_line integer
---@field title_text string
---@field close_line_idx integer

---@class Ghsigns.ContentBuilder
---@field lines string[]
---@field highlights Ghsigns.LineHighlight[]
---@field link_metadata Ghsigns.LinkMetadata[]
---@field code_blocks Ghsigns.CodeBlock[]
---@field callout_folds Ghsigns.CalloutFold[]
---@field expandable_regions Ghsigns.ExpandableRegion[]
local ContentBuilder = {}

---@return Ghsigns.ContentBuilder
function ContentBuilder.new()
  return setmetatable({
    lines = {},
    highlights = {},
    link_metadata = {},
    code_blocks = {},
    callout_folds = {},
    expandable_regions = {},
  }, { __index = ContentBuilder })
end

---@param text string
---@param hl_groups? Ghsigns.Highlight.Group[]
function ContentBuilder:add_line(text, hl_groups)
  table.insert(self.lines, text)
  if hl_groups then
    table.insert(self.highlights, { line = #self.lines - 1, groups = hl_groups })
  end
end

---@param label string
---@param value string
---@param value_hl? string
function ContentBuilder:add_labeled(label, value, value_hl)
  local line = label .. ": " .. value
  self:add_line(line, {
    { col = 0, end_col = #label, hl = "Comment" },
    { col = #label + 2, end_col = #line, hl = value_hl or "Normal" },
  })
end

---@return Ghsigns.PrContent
function ContentBuilder:result()
  return {
    lines = self.lines,
    highlights = self.highlights,
    link_metadata = self.link_metadata,
    code_blocks = self.code_blocks,
    callout_folds = self.callout_folds,
    expandable_regions = self.expandable_regions,
  }
end

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

--- Add title line with optional DRAFT indicator
---@param self Ghsigns.ContentBuilder
---@param p Ghsigns.PrData
---@return integer title_line
---@return string title_text
function ContentBuilder:add_title_line(p)
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
  self:add_line(title_text, title_hls)
  return #self.lines - 1, title_text
end

--- Add changes line with diff-colored highlights
---@param self Ghsigns.ContentBuilder
---@param p Ghsigns.PrData
function ContentBuilder:add_changes_line(p)
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

  self:add_line(changes_start .. changes, {
    { col = 0, end_col = #changes_start - 1, hl = "Comment" },
    { col = plus_start, end_col = plus_end, hl = "DiffAdd" },
    { col = minus_start, end_col = minus_end, hl = "DiffDelete" },
    { col = minus_end + 1, end_col = -1, hl = "Comment" },
  })
end

--- Add metadata fields (Author, State, Review, Mergeable, Changes, Labels)
---@param self Ghsigns.ContentBuilder
---@param p Ghsigns.PrData
function ContentBuilder:add_metadata_fields(p)
  if p.author_name then
    self:add_labeled("Author", p.author_name, "String")
  end

  if p.state then
    local state_hl = p.state == "OPEN" and "DiagnosticOk" or "DiagnosticError"
    self:add_labeled("State", p.state, state_hl)
  end

  if p.reviewDecision and p.reviewDecision ~= "" then
    local review_hl = "DiagnosticWarn"
    if p.reviewDecision == "APPROVED" then
      review_hl = "DiagnosticOk"
    elseif p.reviewDecision == "CHANGES_REQUESTED" then
      review_hl = "DiagnosticError"
    end
    self:add_labeled("Review", p.reviewDecision:gsub("_", " "), review_hl)
  end

  if p.state == "OPEN" and p.mergeable and p.mergeable ~= "" then
    local merge_hl = p.mergeable == "MERGEABLE" and "DiagnosticOk" or "DiagnosticError"
    self:add_labeled("Mergeable", p.mergeable, merge_hl)
  end

  self:add_changes_line(p)

  if p.labels and p.labels.nodes and #p.labels.nodes > 0 then
    local label_names = vim.tbl_map(function(label)
      return label.name
    end, p.labels.nodes)
    self:add_labeled("Labels", table.concat(label_names, ", "), "Tag")
  end
end

--- Convert an ISO 8601 UTC timestamp to local time string.
--- Falls back to the original string if parsing fails.
---@param iso_str string e.g. "2024-01-01T00:00:00Z"
---@return string e.g. "2024-01-01 09:00:00 JST"
local function format_local_time(iso_str)
  local y, m, d, h, min, s = iso_str:match "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
  if not y then
    return iso_str
  end
  -- os.time treats input as local time; compute UTC offset to correct
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

--- Add date fields (Created, Updated, Merged)
---@param self Ghsigns.ContentBuilder
---@param p Ghsigns.PrData
function ContentBuilder:add_date_fields(p)
  if p.createdAt then
    self:add_labeled("Created", format_local_time(p.createdAt), "DiagnosticHint")
  end
  if p.updatedAt then
    self:add_labeled("Updated", format_local_time(p.updatedAt), "DiagnosticHint")
  end
  if p.mergedAt then
    self:add_labeled("Merged", format_local_time(p.mergedAt), "DiagnosticOk")
  end
end

--- Build the header section (title, branches, metadata, dates)
---@param self Ghsigns.ContentBuilder
---@param p Ghsigns.PrData
---@return integer title_line
---@return string title_text
function ContentBuilder:build_header(p)
  local title_line, title_text = self:add_title_line(p)

  if p.baseRefName and p.headRefName then
    local branch_info = string.format("%s → %s", p.headRefName, p.baseRefName)
    self:add_line(branch_info, {
      { col = 0, end_col = #p.headRefName, hl = "Identifier" },
      { col = #p.headRefName + 1, end_col = #p.headRefName + 3, hl = "Operator" },
      { col = #p.headRefName + 4, end_col = -1, hl = "String" },
    })
  end

  self:add_line ""
  self:add_metadata_fields(p)
  self:add_line ""
  self:add_date_fields(p)

  return title_line, title_text
end

--- Split text into segments for wrapping, handling CJK/fullwidth characters individually.
--- Each CJK/fullwidth character becomes its own segment so it can be wrapped independently.
---@param text string
---@return {text: string, byte_pos: integer, has_leading_space: boolean}[]
local function split_segments(text)
  local segments = {}
  local current_word = ""
  local current_word_start = 0
  local has_leading_space = false
  local byte_pos = 0

  for char in text:gmatch "[%z\1-\127\194-\253][\128-\191]*" do
    if char:match "%s" then
      -- Flush accumulated ASCII word
      if current_word ~= "" then
        table.insert(segments, { text = current_word, byte_pos = current_word_start, has_leading_space = has_leading_space })
        current_word = ""
        has_leading_space = false
      end
      has_leading_space = true
    elseif vim.fn.strdisplaywidth(char) >= 2 then
      -- CJK/fullwidth character: flush word first, then emit as individual segment
      if current_word ~= "" then
        table.insert(segments, { text = current_word, byte_pos = current_word_start, has_leading_space = has_leading_space })
        current_word = ""
        has_leading_space = false
      end
      table.insert(segments, { text = char, byte_pos = byte_pos, has_leading_space = has_leading_space })
      has_leading_space = false
    else
      -- ASCII/narrow character: accumulate into word
      if current_word == "" then
        current_word_start = byte_pos
      end
      current_word = current_word .. char
    end
    byte_pos = byte_pos + #char
  end

  -- Flush remaining word
  if current_word ~= "" then
    table.insert(segments, { text = current_word, byte_pos = current_word_start, has_leading_space = has_leading_space })
  end

  return segments
end

--- Wrap text into lines at word boundaries, tracking original positions.
--- Uses segment-based splitting to handle CJK/fullwidth characters correctly.
---@param text string The text to wrap
---@param max_width integer Maximum display width per line
---@return string[] wrapped_lines
---@return integer[] line_starts 0-indexed start position of each line in the original text
local function wrap_words(text, max_width)
  local wrapped_lines = {}
  local line_starts = {}
  local current = ""
  local current_width = 0
  local current_start = 0

  for _, seg in ipairs(split_segments(text)) do
    local seg_width = vim.fn.strdisplaywidth(seg.text)
    local space_width = (seg.has_leading_space and current ~= "") and 1 or 0

    if current_width + space_width + seg_width > max_width and current ~= "" then
      table.insert(wrapped_lines, current)
      table.insert(line_starts, current_start)
      current = seg.text
      current_start = seg.byte_pos
      current_width = seg_width
    else
      if current ~= "" then
        if space_width > 0 then
          current = current .. " " .. seg.text
          current_width = current_width + 1 + seg_width
        else
          current = current .. seg.text
          current_width = current_width + seg_width
        end
      else
        current = seg.text
        current_start = seg.byte_pos
        current_width = seg_width
      end
    end
  end

  if current ~= "" then
    table.insert(wrapped_lines, current)
    table.insert(line_starts, current_start)
  end

  return wrapped_lines, line_starts
end

--- Distribute markdown highlights across wrapped lines
---@param md_highlights Ghsigns.Markdown.Highlight[]
---@param wrapped_lines string[] The wrapped line texts
---@param line_starts integer[] Start positions of each wrapped line
---@param indent string Indentation prefix
---@param quote_prefix string Blockquote prefix (may be empty)
---@param content_offset integer Byte offset of content within the original rendered text
---@param list_prefix_len? integer Byte length of list marker prefix (0 if none)
---@return Ghsigns.Highlight.Group[][] per_line_highlights Array of highlight lists, one per wrapped line
local function distribute_highlights(md_highlights, wrapped_lines, line_starts, indent, quote_prefix, content_offset, list_prefix_len)
  list_prefix_len = list_prefix_len or 0
  local per_line = {}
  for idx, wline in ipairs(wrapped_lines) do
    local line_start_pos = line_starts[idx]
    local prefix_len = #quote_prefix + list_prefix_len
    local line_prefix = (quote_prefix ~= "" and (indent .. quote_prefix) or indent)
        .. (idx == 1 and "" or string.rep(" ", list_prefix_len))
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

      -- "Special" highlights (list markers) that end at or before the content start
      -- should only appear on line 1 with their original positions
      if hl.end_col <= content_offset and hl.hl == "Special" then
        if idx == 1 then
          table.insert(line_hls, {
            col = #indent + #quote_prefix + hl.col,
            end_col = #indent + #quote_prefix + hl.end_col,
            hl = hl.hl,
          })
        end
      elseif hl.hl == "FloatBorder" and hl.col == 0 then
        if idx == 1 then
          table.insert(line_hls, {
            col = #indent + hl.col,
            end_col = #indent + hl.end_col,
            hl = hl.hl,
          })
        end
      else
        local wline_end = line_start_pos + #wline
        if hl_end > line_start_pos and hl_start < wline_end then
          local local_start = math.max(0, hl_start - line_start_pos)
          local local_end = math.min(#wline, hl_end - line_start_pos)
          table.insert(line_hls, {
            col = local_start + #line_prefix,
            end_col = local_end + #line_prefix,
            hl = hl.hl,
          })
        end
      end
    end

    per_line[idx] = line_hls
  end
  return per_line
end

--- Distribute link metadata across wrapped lines
---@param md_links Ghsigns.Markdown.Link[]
---@param wrapped_lines string[] The wrapped line texts
---@param line_starts integer[] Start positions of each wrapped line
---@param indent string Indentation prefix
---@param quote_prefix string Blockquote prefix (may be empty)
---@param content_offset integer Byte offset of content within the original rendered text
---@param base_line integer Current line count in the builder (0-indexed, before adding wrapped lines)
---@param list_prefix_len? integer Byte length of list marker prefix (0 if none)
---@return Ghsigns.LinkMetadata[] link_entries
local function distribute_links(md_links, wrapped_lines, line_starts, indent, quote_prefix, content_offset, base_line, list_prefix_len)
  list_prefix_len = list_prefix_len or 0
  local entries = {}
  for idx, wline in ipairs(wrapped_lines) do
    local line_start_pos = line_starts[idx]
    local line_prefix = (quote_prefix ~= "" and (indent .. quote_prefix) or indent)
        .. (idx == 1 and "" or string.rep(" ", list_prefix_len))

    for _, link in ipairs(md_links) do
      local link_start = link.col_start - content_offset
      local link_end = link.col_end - content_offset
      local wline_end = line_start_pos + #wline

      if link_end > line_start_pos and link_start < wline_end then
        local local_start = math.max(0, link_start - line_start_pos)
        local local_end = math.min(#wline, link_end - line_start_pos)
        table.insert(entries, {
          line = base_line + idx - 1,
          col_start = local_start + #line_prefix,
          col_end = local_end + #line_prefix,
          url = link.url,
        })
      end
    end
  end
  return entries
end

--- Add a wrapped markdown line with highlights and links distributed across wrapped lines
---@param self Ghsigns.ContentBuilder
---@param rendered_text string
---@param md_highlights Ghsigns.Markdown.Highlight[]
---@param md_links Ghsigns.Markdown.Link[]
---@param indent string
---@param max_width integer
---@param quote_prefix string
---@param list_marker? string
function ContentBuilder:add_wrapped_markdown(rendered_text, md_highlights, md_links, indent, max_width, quote_prefix, list_marker)
  local wrap_text = rendered_text
  local content_offset = 0
  if quote_prefix ~= "" then
    wrap_text = rendered_text:sub(#quote_prefix + 1)
    content_offset = #quote_prefix
  end

  -- Strip list marker from wrap_text so wrapping is based on content only
  local list_prefix_len = 0
  if list_marker and list_marker ~= "" then
    wrap_text = wrap_text:sub(#list_marker + 1)
    content_offset = content_offset + #list_marker
    list_prefix_len = #list_marker
  end

  local content_max_width = max_width
  if quote_prefix ~= "" then
    content_max_width = max_width - vim.fn.strdisplaywidth(quote_prefix)
  end
  if list_prefix_len > 0 then
    content_max_width = content_max_width - vim.fn.strdisplaywidth(list_marker)
  end

  local wrapped_lines, line_starts = wrap_words(wrap_text, content_max_width)
  local per_line_hls = distribute_highlights(md_highlights, wrapped_lines, line_starts, indent, quote_prefix, content_offset, list_prefix_len)
  local base_line = #self.lines
  local link_entries = distribute_links(md_links, wrapped_lines, line_starts, indent, quote_prefix, content_offset, base_line, list_prefix_len)

  local list_prefix = list_marker or ""
  local list_continuation = string.rep(" ", list_prefix_len)

  for idx, wline in ipairs(wrapped_lines) do
    local line_prefix = quote_prefix ~= "" and (indent .. quote_prefix) or indent
    local lm = idx == 1 and list_prefix or list_continuation
    local line_hls = per_line_hls[idx]
    self:add_line(line_prefix .. lm .. wline, #line_hls > 0 and line_hls or nil)
  end

  for _, entry in ipairs(link_entries) do
    table.insert(self.link_metadata, entry)
  end
end

--- Add a simple (non-wrapped) markdown line with highlights and links
---@param self Ghsigns.ContentBuilder
---@param rendered_text string
---@param md_highlights Ghsigns.Markdown.Highlight[]
---@param md_links Ghsigns.Markdown.Link[]
---@param indent string
function ContentBuilder:add_simple_markdown(rendered_text, md_highlights, md_links, indent)
  local line_hls = {}
  for _, hl in ipairs(md_highlights) do
    table.insert(line_hls, {
      col = hl.col + #indent,
      end_col = hl.end_col + #indent,
      hl = hl.hl,
    })
  end

  self:add_line(indent .. rendered_text, #line_hls > 0 and line_hls or nil)

  for _, link in ipairs(md_links) do
    table.insert(self.link_metadata, {
      line = #self.lines - 1,
      col_start = link.col_start + #indent,
      col_end = link.col_end + #indent,
      url = link.url,
    })
  end
end

--- Add a table block with highlights and links
---@param self Ghsigns.ContentBuilder
---@param table_lines string[]
---@param indent string
---@param max_width integer
---@param repo_base_url? string
---@param autolinks? Ghsigns.Autolink[]
function ContentBuilder:add_table(table_lines, indent, max_width, repo_base_url, autolinks)
  local markdown_table = require "ghsigns.markdown_table"
  local parsed = markdown_table.parse(table_lines, repo_base_url, autolinks)
  if not parsed then
    -- Fallback: render each line as markdown
    for _, line in ipairs(table_lines) do
      self:add_markdown_line(line, indent, max_width, repo_base_url, autolinks)
    end
    return
  end
  local lines, per_line_hls, per_line_links = markdown_table.render(parsed, indent, max_width)
  local base_line = #self.lines
  for i, line in ipairs(lines) do
    self:add_line(line, #per_line_hls[i] > 0 and per_line_hls[i] or nil)
    for _, link in ipairs(per_line_links[i] or {}) do
      table.insert(self.link_metadata, {
        line = base_line + i - 1,
        col_start = link.col_start,
        col_end = link.col_end,
        url = link.url,
      })
    end
  end
end

--- Add a markdown-rendered line with wrapping support
---@param self Ghsigns.ContentBuilder
---@param text string
---@param indent string
---@param max_width integer
---@param repo_base_url? string
---@param autolinks? Ghsigns.Autolink[]
---@return string? alert_type Alert type if this line is an alert header
---@return string? fold_mod Fold modifier ("+" or "-") if this is a foldable callout
function ContentBuilder:add_markdown_line(text, indent, max_width, repo_base_url, autolinks)
  local markdown = require "ghsigns.markdown"
  local rendered_text, md_highlights, md_links, special_type, list_marker, alert_type, fold_mod =
    markdown.render(text, repo_base_url, autolinks)

  local quote_prefix = ""
  if special_type == "blockquote" then
    quote_prefix = rendered_text:match "^([│ ]+)" or ""
  end

  if vim.fn.strdisplaywidth(rendered_text) > max_width then
    self:add_wrapped_markdown(rendered_text, md_highlights, md_links, indent, max_width, quote_prefix, list_marker)
  else
    self:add_simple_markdown(rendered_text, md_highlights, md_links, indent)
  end

  return alert_type, fold_mod
end

--- Apply alert styling to lines added between lines_before and current line count
---@param self Ghsigns.ContentBuilder
---@param lines_before integer Line count before adding the alert line(s)
---@param lines_after integer Line count after adding the alert line(s)
---@param alert_type string Alert type key (e.g. "NOTE", "WARNING")
---@param is_header boolean Whether this is the alert header line (with icon+label)
function ContentBuilder:apply_alert_styling(lines_before, lines_after, alert_type, is_header)
  local alert_hl = "GhsignsAlert" .. alert_type:sub(1, 1) .. alert_type:sub(2):lower()
  local alert_bg_hl = alert_hl .. "Bg"

  for _, hl_info in ipairs(self.highlights) do
    if hl_info.line >= lines_before and hl_info.line < lines_after then
      -- Replace FloatBorder highlights with alert-colored border
      for _, group in ipairs(hl_info.groups) do
        if group.hl == "FloatBorder" then
          group.hl = alert_hl
        end
      end

      -- On header line, add alert highlight for content after the bar
      if is_header and hl_info.line == lines_before then
        local line_text = self.lines[hl_info.line + 1]
        if line_text then
          -- Find end of blockquote prefix (after "│ ")
          local bar_end = 0
          for _, group in ipairs(hl_info.groups) do
            if group.hl == alert_hl then
              bar_end = group.end_col
              break
            end
          end
          if bar_end > 0 then
            table.insert(hl_info.groups, { col = bar_end, end_col = #line_text, hl = alert_hl })
          end
        end
      end

      -- Add background highlight for the entire line
      table.insert(hl_info.groups, { col = 0, end_col = -1, hl = alert_bg_hl, hl_eol = true })
    end
  end

  -- Also handle lines that have no existing highlights (shouldn't happen for blockquotes, but be safe)
  for line_idx = lines_before, lines_after - 1 do
    local has_hl = false
    for _, hl_info in ipairs(self.highlights) do
      if hl_info.line == line_idx then
        has_hl = true
        break
      end
    end
    if not has_hl then
      table.insert(self.highlights, {
        line = line_idx,
        groups = { { col = 0, end_col = -1, hl = alert_bg_hl, hl_eol = true } },
      })
    end
  end
end

--- Append a fold indicator (›/∨) to the end of a callout header line
---@param self Ghsigns.ContentBuilder
---@param line_idx integer 0-indexed rendered line
---@param is_collapsed boolean
function ContentBuilder:add_fold_indicator(line_idx, is_collapsed)
  local indicator = is_collapsed and " 󰅂" or " 󰅀"
  local line = self.lines[line_idx + 1]
  if not line then
    return
  end

  -- Append indicator at the end of the line (no highlight shifts needed)
  self.lines[line_idx + 1] = line .. indicator
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

--- Build the body section (description with markdown rendering)
---@param self Ghsigns.ContentBuilder
---@param p Ghsigns.PrData
---@param opts? { max_body_lines?: integer, autolinks?: Ghsigns.Autolink[], fold_state?: table<integer, boolean>, expand_state?: table<integer, boolean> }
function ContentBuilder:build_body(p, opts)
  if not p.body or p.body == "" then
    return
  end

  local repo_base_url = nil
  if p.url then
    repo_base_url = p.url:match "(https://[^/]+/[^/]+/[^/]+)"
  end
  local autolinks = opts and opts.autolinks or nil
  local fold_state = opts and opts.fold_state or {}
  local expand_state = opts and opts.expand_state or {}

  self:add_line ""
  self:add_line("Description:", { { col = 0, end_col = -1, hl = "Comment" } })

  local cleaned_lines = normalize_body(p.body)
  local in_code_block = false
  local code_block_lang = nil
  local code_block_start = nil
  local code_source_lines = nil
  local code_block_id = nil
  local code_block_has_truncation = false
  local lines_shown = 0
  local max_lines = (opts and opts.max_body_lines) or math.huge
  local max_width = 80
  local prev_was_heading = false
  local prev_was_blank = false
  local table_buf = {}
  local table_buf_start_idx = nil
  local truncated = false
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
      local lines_before = #self.lines
      local tbl_expanded = table_buf_start_idx and expand_state[table_buf_start_idx]
      local effective_max = tbl_expanded and math.huge or max_width
      self:add_table(table_buf, "  ", effective_max, repo_base_url, autolinks)
      local lines_added = #self.lines - lines_before
      lines_shown = lines_shown + lines_added
      -- Check if any table line was truncated (has …)
      local has_truncation = false
      if not tbl_expanded then
        for li = lines_before + 1, #self.lines do
          if self.lines[li] and self.lines[li]:match "…" then
            has_truncation = true
            break
          end
        end
      end
      if has_truncation or tbl_expanded then
        table.insert(self.expandable_regions, {
          start_line = lines_before,
          end_line = #self.lines - 1,
          block_id = table_buf_start_idx,
          expanded = tbl_expanded or false,
        })
      end
      table_buf = {}
      table_buf_start_idx = nil
    end
  end

  for src_idx, body_line in ipairs(cleaned_lines) do
    local is_blank = body_line:match "^%s*$" ~= nil
    local is_heading = (not in_code_block) and body_line:match "^#+%s+" ~= nil
    local is_table_line = (not in_code_block) and body_line:match "^%s*|" ~= nil

    -- Skip body lines of a collapsed foldable callout
    if skip_callout_body then
      if body_line:match "^>" then
        goto continue
      else
        skip_callout_body = false
        current_alert_type = nil
      end
    end

    -- Toggle Obsidian block comment (outside code blocks)
    if not in_code_block and body_line:match "^%s*%%%%%s*$" then
      in_comment_block = not in_comment_block
      goto continue
    end
    if in_comment_block then
      goto continue
    end

    -- Accumulate table lines
    if is_table_line then
      if #table_buf == 0 then
        table_buf_start_idx = src_idx
      end
      table.insert(table_buf, body_line)
      goto continue
    end

    -- Flush table buffer when a non-table line is encountered
    if #table_buf > 0 then
      flush_table()
      if lines_shown >= max_lines then
        self:add_line("  ... (truncated)", { { col = 0, end_col = -1, hl = "Comment" } })
        truncated = true
        break
      end
    end

    -- Skip blank lines immediately after headings (outside code blocks)
    if not in_code_block and is_blank and prev_was_heading then
      prev_was_blank = true
      goto continue
    end

    -- Auto-insert blank line before headings if not already preceded by one
    if not in_code_block and is_heading and lines_shown > 0 and not prev_was_blank then
      self:add_line "  "
      lines_shown = lines_shown + 1
      if lines_shown >= max_lines then
        self:add_line("  ... (truncated)", { { col = 0, end_col = -1, hl = "Comment" } })
        truncated = true
        break
      end
    end

    local lines_before = #self.lines

    if body_line:match "^```" then
      if not in_code_block then
        in_code_block = true
        code_block_lang = body_line:match "^```(%S+)" or nil
        code_block_start = #self.lines -- 0-indexed position of next code line
        code_source_lines = {}
        code_block_id = src_idx
        code_block_has_truncation = false
      else
        if code_block_lang and code_block_start < #self.lines then
          table.insert(self.code_blocks, {
            language = code_block_lang,
            start_line = code_block_start,
            end_line = #self.lines - 1,
            source_lines = code_source_lines,
          })
        end
        if code_block_has_truncation or expand_state[code_block_id] then
          table.insert(self.expandable_regions, {
            start_line = code_block_start,
            end_line = #self.lines - 1,
            block_id = code_block_id,
            expanded = expand_state[code_block_id] or false,
          })
        end
        in_code_block = false
        code_block_lang = nil
        code_source_lines = nil
        code_block_id = nil
      end
      -- Don't call add_line: fence lines are hidden and don't count toward lines_shown
    elseif in_code_block then
      table.insert(code_source_lines, body_line)
      local indented = "  " .. body_line
      local display_width = vim.fn.strdisplaywidth(indented)
      if not expand_state[code_block_id] and display_width > max_width then
        code_block_has_truncation = true
        local target = max_width - 1 -- reserve 1 col for "…"
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
        self:add_line(truncated_line, {
          { col = 0, end_col = byte_pos, hl = "String" },
          { col = byte_pos, end_col = #truncated_line, hl = "Underlined" },
        })
      else
        self:add_line(indented, { { col = 0, end_col = -1, hl = "String" } })
      end
    else
      local handled = false

      -- Handle code blocks inside callouts
      if current_alert_type and body_line:match "^>" then
        local stripped = body_line:gsub("^>%s?", "")
        if stripped:match "^```" then
          if not in_callout_code_block then
            in_callout_code_block = true
            callout_code_lang = stripped:match "^```(%S+)" or nil
            callout_code_prefix = "  │ "
            callout_code_start = #self.lines
            callout_code_source_lines = {}
            callout_code_block_id = src_idx
            callout_code_has_truncation = false
          else
            if callout_code_lang and callout_code_start < #self.lines then
              table.insert(self.code_blocks, {
                language = callout_code_lang,
                start_line = callout_code_start,
                end_line = #self.lines - 1,
                prefix_len = #callout_code_prefix,
                source_lines = callout_code_source_lines,
              })
            end
            if callout_code_has_truncation or expand_state[callout_code_block_id] then
              table.insert(self.expandable_regions, {
                start_line = callout_code_start,
                end_line = #self.lines - 1,
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
            self:add_line(truncated_code, {
              { col = 2, end_col = 2 + #"│ ", hl = "FloatBorder" },
              { col = #callout_code_prefix, end_col = byte_pos, hl = "String" },
              { col = byte_pos, end_col = #truncated_code, hl = "Underlined" },
            })
          else
            self:add_line(code_line, {
              { col = 2, end_col = 2 + #"│ ", hl = "FloatBorder" },
              { col = #callout_code_prefix, end_col = -1, hl = "String" },
            })
          end
          self:apply_alert_styling(lines_before, #self.lines, current_alert_type, false)
          handled = true
        end
      end

      if not handled then
        -- Reset callout code block state if we leave the callout
        if in_callout_code_block and not (body_line:match "^>") then
          in_callout_code_block = false
          callout_code_lang = nil
        end

        local alert_type, fold_mod = self:add_markdown_line(body_line, "  ", max_width, repo_base_url, autolinks)
        local lines_after = #self.lines
        if alert_type then
          current_alert_type = alert_type

          if fold_mod then
            local is_collapsed
            if fold_state[src_idx] ~= nil then
              is_collapsed = fold_state[src_idx]
            else
              is_collapsed = (fold_mod == "-")
            end
            self:add_fold_indicator(lines_before, is_collapsed)
            table.insert(self.callout_folds, {
              header_line = lines_before,
              source_line = src_idx,
              collapsed = is_collapsed,
            })
            if is_collapsed then
              skip_callout_body = true
            end
          end

          self:apply_alert_styling(lines_before, #self.lines, current_alert_type, true)
        elseif current_alert_type and body_line:match "^>" then
          self:apply_alert_styling(lines_before, lines_after, current_alert_type, false)
        else
          current_alert_type = nil
        end
      end
    end

    local lines_added = #self.lines - lines_before
    lines_shown = lines_shown + lines_added

    prev_was_heading = is_heading
    prev_was_blank = is_blank

    if lines_shown >= max_lines then
      self:add_line("  ... (truncated)", { { col = 0, end_col = -1, hl = "Comment" } })
      truncated = true
      break
    end

    ::continue::
  end

  -- Flush any remaining table lines at end of body
  if not truncated then
    flush_table()
    if lines_shown >= max_lines then
      self:add_line("  ... (truncated)", { { col = 0, end_col = -1, hl = "Comment" } })
    end
  end
end

--- Build the footer section (close button)
---@param self Ghsigns.ContentBuilder
---@return integer close_line_idx
function ContentBuilder:build_footer()
  self:add_line ""
  local close_text = "✕ Click here to close (or press q/Esc/Enter)"
  self:add_line(
    close_text,
    { { col = 0, end_col = 1, hl = "ErrorMsg" }, { col = 2, end_col = #close_text, hl = "Comment" } }
  )
  return #self.lines - 1
end

local M = {}
M.ContentBuilder = ContentBuilder
M.prepare_pr_data = prepare_pr_data
M.format_local_time = format_local_time
return M
