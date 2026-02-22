---@class Ghsigns.PrData: Ghsigns.Pr
---@field author_name? string

---@class Ghsigns.Highlight.Group
---@field col integer 0-indexed start column
---@field end_col integer 0-indexed end column (-1 means end of line)
---@field hl string highlight group name

---@class Ghsigns.LineHighlight
---@field line integer 0-indexed line number
---@field groups Ghsigns.Highlight.Group[]

---@class Ghsigns.LinkMetadata
---@field line integer 0-indexed line number
---@field col_start integer 0-indexed start column
---@field col_end integer 0-indexed end column
---@field url string

---@class Ghsigns.PrContent
---@field lines string[]
---@field highlights Ghsigns.LineHighlight[]
---@field link_metadata Ghsigns.LinkMetadata[]
---@field title_line integer
---@field title_text string
---@field close_line_idx integer

---@class Ghsigns.ContentBuilder
---@field lines string[]
---@field highlights Ghsigns.LineHighlight[]
---@field link_metadata Ghsigns.LinkMetadata[]
local ContentBuilder = {}

---@return Ghsigns.ContentBuilder
function ContentBuilder.new()
  return setmetatable({
    lines = {},
    highlights = {},
    link_metadata = {},
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

  if p.mergeable and p.mergeable ~= "" then
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

--- Add date fields (Created, Updated, Merged)
---@param self Ghsigns.ContentBuilder
---@param p Ghsigns.PrData
function ContentBuilder:add_date_fields(p)
  if p.createdAt then
    self:add_labeled("Created", p.createdAt, "DiagnosticHint")
  end
  if p.updatedAt then
    self:add_labeled("Updated", p.updatedAt, "DiagnosticHint")
  end
  if p.mergedAt then
    self:add_labeled("Merged", p.mergedAt, "DiagnosticOk")
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
    local branch_info = string.format("%s ← %s", p.baseRefName, p.headRefName)
    self:add_line(branch_info, {
      { col = 0, end_col = #p.baseRefName, hl = "String" },
      { col = #p.baseRefName + 1, end_col = #p.baseRefName + 3, hl = "Operator" },
      { col = #p.baseRefName + 4, end_col = -1, hl = "Identifier" },
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
---@return Ghsigns.Highlight.Group[][] per_line_highlights Array of highlight lists, one per wrapped line
local function distribute_highlights(md_highlights, wrapped_lines, line_starts, indent, quote_prefix, content_offset)
  local per_line = {}
  for idx, wline in ipairs(wrapped_lines) do
    local line_start_pos = line_starts[idx]
    local line_prefix = quote_prefix ~= "" and (indent .. quote_prefix) or indent
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

      if hl.hl == "FloatBorder" and hl.col == 0 then
        if idx == 1 then
          table.insert(line_hls, {
            col = #indent + hl.col,
            end_col = #indent + hl.end_col,
            hl = hl.hl,
          })
        end
      elseif hl_end > line_start_pos and hl_start < wline_end then
        local local_start = math.max(0, hl_start - line_start_pos)
        local local_end = math.min(#wline, hl_end - line_start_pos)
        table.insert(line_hls, {
          col = local_start + #line_prefix,
          end_col = local_end + #line_prefix,
          hl = hl.hl,
        })
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
---@return Ghsigns.LinkMetadata[] link_entries
local function distribute_links(md_links, wrapped_lines, line_starts, indent, quote_prefix, content_offset, base_line)
  local entries = {}
  for idx, wline in ipairs(wrapped_lines) do
    local line_start_pos = line_starts[idx]
    local line_prefix = quote_prefix ~= "" and (indent .. quote_prefix) or indent

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
function ContentBuilder:add_wrapped_markdown(rendered_text, md_highlights, md_links, indent, max_width, quote_prefix)
  local wrap_text = rendered_text
  local content_offset = 0
  if quote_prefix ~= "" then
    wrap_text = rendered_text:sub(#quote_prefix + 1)
    content_offset = #quote_prefix
  end

  local content_max_width = max_width
  if quote_prefix ~= "" then
    content_max_width = max_width - vim.fn.strdisplaywidth(quote_prefix)
  end

  local wrapped_lines, line_starts = wrap_words(wrap_text, content_max_width)
  local per_line_hls = distribute_highlights(md_highlights, wrapped_lines, line_starts, indent, quote_prefix, content_offset)
  local base_line = #self.lines
  local link_entries = distribute_links(md_links, wrapped_lines, line_starts, indent, quote_prefix, content_offset, base_line)

  for idx, wline in ipairs(wrapped_lines) do
    local line_prefix = quote_prefix ~= "" and (indent .. quote_prefix) or indent
    local line_hls = per_line_hls[idx]
    self:add_line(line_prefix .. wline, #line_hls > 0 and line_hls or nil)
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

--- Add a markdown-rendered line with wrapping support
---@param self Ghsigns.ContentBuilder
---@param text string
---@param indent string
---@param max_width integer
---@param repo_base_url? string
function ContentBuilder:add_markdown_line(text, indent, max_width, repo_base_url)
  local markdown = require "ghsigns.markdown"
  local rendered_text, md_highlights, md_links, special_type = markdown.render(text, repo_base_url)

  local quote_prefix = ""
  if special_type == "blockquote" then
    quote_prefix = rendered_text:match "^([│ ]+)" or ""
  end

  if vim.fn.strdisplaywidth(rendered_text) > max_width then
    self:add_wrapped_markdown(rendered_text, md_highlights, md_links, indent, max_width, quote_prefix)
  else
    self:add_simple_markdown(rendered_text, md_highlights, md_links, indent)
  end
end

--- Wrap long lines for code blocks.
--- Uses segment-based splitting to handle CJK/fullwidth characters correctly.
---@param text string
---@param max_width integer
---@param indent string
---@return string[]
local function wrap_line(text, max_width, indent)
  local lines_out = {}
  local current = ""
  local current_width = 0

  for _, seg in ipairs(split_segments(text)) do
    local seg_width = vim.fn.strdisplaywidth(seg.text)
    local space_width = (seg.has_leading_space and current ~= "") and 1 or 0

    if current_width + space_width + seg_width > max_width and current ~= "" then
      table.insert(lines_out, indent .. current)
      current = seg.text
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
        current_width = seg_width
      end
    end
  end

  if current ~= "" then
    table.insert(lines_out, indent .. current)
  end

  return lines_out
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
function ContentBuilder:build_body(p)
  if not p.body or p.body == "" then
    return
  end

  local repo_base_url = nil
  if p.url then
    repo_base_url = p.url:match "(https://[^/]+/[^/]+/[^/]+)"
  end

  self:add_line ""
  self:add_line("Description:", { { col = 0, end_col = -1, hl = "Comment" } })

  local cleaned_lines = normalize_body(p.body)
  local in_code_block = false
  local lines_shown = 0
  local max_lines = 15
  local max_width = 80

  for _, body_line in ipairs(cleaned_lines) do
    local lines_before = #self.lines

    if body_line:match "^```" then
      in_code_block = not in_code_block
      self:add_line("  " .. body_line, { { col = 0, end_col = -1, hl = "Comment" } })
    elseif in_code_block then
      local display_width = vim.fn.strdisplaywidth(body_line)
      if display_width > max_width then
        local wrapped = wrap_line(body_line, max_width, "  ")
        for _, wline in ipairs(wrapped) do
          self:add_line(wline, { { col = 0, end_col = -1, hl = "String" } })
        end
      else
        self:add_line("  " .. body_line, { { col = 0, end_col = -1, hl = "String" } })
      end
    else
      self:add_markdown_line(body_line, "  ", max_width, repo_base_url)
    end

    local lines_added = #self.lines - lines_before
    lines_shown = lines_shown + lines_added

    if lines_shown >= max_lines then
      self:add_line("  ... (truncated)", { { col = 0, end_col = -1, hl = "Comment" } })
      break
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
return M
