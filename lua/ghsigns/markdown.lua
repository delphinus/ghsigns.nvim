---@class Ghsigns.Markdown.Highlight
---@field col integer 0-indexed start column
---@field end_col integer 0-indexed end column
---@field hl string highlight group name

---@class Ghsigns.Markdown.Link
---@field col_start integer 0-indexed start column
---@field col_end integer 0-indexed end column
---@field url string

---@class Ghsigns.Markdown.Removal
---@field start integer 0-indexed position in the input text
---@field count integer number of characters removed

---@class Ghsigns.Markdown
local Markdown = {}

--- Adjust highlight and link positions after character removals
---@param highlights Ghsigns.Markdown.Highlight[]
---@param links Ghsigns.Markdown.Link[]
---@param removals Ghsigns.Markdown.Removal[]
---@param hl_count integer number of highlights to adjust (from the beginning)
---@param link_count integer number of links to adjust (from the beginning)
local function adjust_positions(highlights, links, removals, hl_count, link_count)
  if #removals == 0 then
    return
  end
  local function adjust(pos)
    local shift = 0
    for _, r in ipairs(removals) do
      if pos >= r.start + r.count then
        shift = shift + r.count
      elseif pos > r.start then
        shift = shift + (pos - r.start)
      end
    end
    return pos - shift
  end
  for i = 1, hl_count do
    highlights[i].col = adjust(highlights[i].col)
    highlights[i].end_col = adjust(highlights[i].end_col)
  end
  for i = 1, link_count do
    links[i].col_start = adjust(links[i].col_start)
    links[i].col_end = adjust(links[i].col_end)
  end
end

--- Process paired markers (bold, strikethrough) by removing markers and adding highlights
---@param text string The input text
---@param pattern string The Lua pattern to match (e.g., "%*%*([^*]+)%*%*")
---@param hl_group string The highlight group to apply
---@param marker_len integer The length of each marker (e.g., 2 for ** or ~~)
---@param highlights Ghsigns.Markdown.Highlight[] Existing highlights to adjust
---@param links Ghsigns.Markdown.Link[] Existing links to adjust
---@return string processed The text with markers removed
local function process_paired_markers(text, pattern, hl_group, marker_len, highlights, links)
  local pre_hl_count = #highlights
  local pre_link_count = #links
  local removals = {}
  local processed = ""
  local i = 1
  while i <= #text do
    local s, e = text:find(pattern, i)
    if s == i then
      local content = text:match(pattern, i)
      table.insert(removals, { start = s - 1, count = marker_len })
      table.insert(removals, { start = s - 1 + marker_len + #content, count = marker_len })
      local start_col = #processed
      processed = processed .. content
      table.insert(highlights, { col = start_col, end_col = start_col + #content, hl = hl_group })
      i = e + 1
    else
      processed = processed .. text:sub(i, i)
      i = i + 1
    end
  end
  adjust_positions(highlights, links, removals, pre_hl_count, pre_link_count)
  return processed
end

--- Process code markers (backticks) by removing them and adding highlights
---@param text string The input text
---@param hl_group string The highlight group to apply
---@param highlights Ghsigns.Markdown.Highlight[] Existing highlights to adjust
---@param links Ghsigns.Markdown.Link[] Existing links to adjust
---@return string processed The text with backticks removed
local function process_code_markers(text, hl_group, highlights, links)
  local pre_hl_count = #highlights
  local pre_link_count = #links
  local removals = {}
  local processed = ""
  local i = 1
  while i <= #text do
    if text:sub(i, i) == "`" then
      local e = text:find("`", i + 1)
      if e then
        table.insert(removals, { start = i - 1, count = 1 })
        table.insert(removals, { start = e - 1, count = 1 })
        local content = text:sub(i + 1, e - 1)
        local start_col = #processed
        processed = processed .. content
        table.insert(highlights, { col = start_col, end_col = start_col + #content, hl = hl_group })
        i = e + 1
      else
        processed = processed .. text:sub(i, i)
        i = i + 1
      end
    else
      processed = processed .. text:sub(i, i)
      i = i + 1
    end
  end
  adjust_positions(highlights, links, removals, pre_hl_count, pre_link_count)
  return processed
end

--- Render markdown text to plain text with highlight and link metadata
---@param text string The markdown text to render
---@param repo_base_url? string Optional repository base URL for issue/PR references
---@return string rendered_text The rendered plain text
---@return Ghsigns.Markdown.Highlight[] highlights
---@return Ghsigns.Markdown.Link[] links
---@return string? special_type Special type like "heading" if applicable
Markdown.render = function(text, repo_base_url)
  local rendered_text = text
  local highlights = {}
  local links = {}

  -- Remove CR characters
  rendered_text = rendered_text:gsub("\r", "")

  -- Heading (# ## ###) - remove prefix
  local heading_content = rendered_text:match "^#+%s+(.+)$"
  if heading_content then
    rendered_text = heading_content
    table.insert(highlights, { col = 0, end_col = #rendered_text, hl = "Title" })
    return rendered_text, highlights, links, "heading"
  end

  -- Blockquote (> ) - replace prefix with visual bar
  local quote_prefix = ""
  local is_blockquote = false
  while rendered_text:match "^>%s?" do
    rendered_text = rendered_text:gsub("^>%s?", "", 1)
    quote_prefix = quote_prefix .. "│ "
    is_blockquote = true
  end

  -- List items (- * 1.) - keep the marker
  local list_marker, list_content = rendered_text:match "^(%s*[-*]%s)(.*)$"
  if not list_marker then
    list_marker, list_content = rendered_text:match "^(%s*%d+%.%s)(.*)$"
  end

  -- Process inline markdown elements
  local processed = ""

  -- Links [text](url) - show only text, make it clickable (process first to avoid conflicts)
  local i = 1
  while i <= #rendered_text do
    local s, e = rendered_text:find("%[([^%]]+)%]%([^%)]+%)", i)
    if s == i then
      local link_text = rendered_text:match("%[([^%]]+)%]%([^%)]+%)", i)
      local url = rendered_text:match("%[[^%]]+%]%(([^%)]+)%)", i)
      local start_col = #processed
      processed = processed .. link_text
      table.insert(highlights, { col = start_col, end_col = start_col + #link_text, hl = "Underlined" })
      table.insert(links, {
        col_start = start_col,
        col_end = start_col + #link_text,
        url = url,
      })
      i = e + 1
    else
      processed = processed .. rendered_text:sub(i, i)
      i = i + 1
    end
  end
  rendered_text = processed

  -- Issue/PR references #123 - make them clickable (but not inside backticks)
  if repo_base_url then
    processed = ""
    i = 1
    local in_backtick = false
    while i <= #rendered_text do
      -- Track backticks to avoid processing #123 inside code
      if rendered_text:sub(i, i) == "`" then
        in_backtick = not in_backtick
        processed = processed .. "`"
        i = i + 1
      else
        local s, e = rendered_text:find("#%d+", i)
        if s == i and not in_backtick then
          local issue_num = rendered_text:match("#(%d+)", i)
          local issue_text = "#" .. issue_num
          local url = repo_base_url .. "/issues/" .. issue_num
          local start_col = #processed
          processed = processed .. issue_text
          table.insert(highlights, { col = start_col, end_col = start_col + #issue_text, hl = "Underlined" })
          table.insert(links, {
            col_start = start_col,
            col_end = start_col + #issue_text,
            url = url,
          })
          i = e + 1
        else
          processed = processed .. rendered_text:sub(i, i)
          i = i + 1
        end
      end
    end
    rendered_text = processed
  end

  -- Bold **text** - remove markers
  rendered_text = process_paired_markers(rendered_text, "%*%*([^*]+)%*%*", "Bold", 2, highlights, links)

  -- Strikethrough ~~text~~ - remove markers
  rendered_text = process_paired_markers(rendered_text, "~~([^~]+)~~", "DiagnosticDeprecated", 2, highlights, links)

  -- Code `text` - remove backticks
  rendered_text = process_code_markers(rendered_text, "String", highlights, links)

  -- Add list marker highlight if present
  if list_marker then
    table.insert(highlights, 1, { col = 0, end_col = #list_marker, hl = "Special" })
  end

  -- Prepend blockquote prefix and shift all positions
  if is_blockquote then
    local offset = #quote_prefix
    rendered_text = quote_prefix .. rendered_text
    table.insert(highlights, 1, { col = 0, end_col = offset, hl = "FloatBorder" })
    for idx = 2, #highlights do
      highlights[idx].col = highlights[idx].col + offset
      highlights[idx].end_col = highlights[idx].end_col + offset
    end
    for _, link in ipairs(links) do
      link.col_start = link.col_start + offset
      link.col_end = link.col_end + offset
    end
    return rendered_text, highlights, links, "blockquote"
  end

  return rendered_text, highlights, links, nil
end

return Markdown
