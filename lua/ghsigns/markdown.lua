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

local MAX_URL_DISPLAY_WIDTH = 50

--- GitHub Flavored Markdown + Obsidian alert/callout types
local ALERT_TYPES = {
  -- GitHub Alerts
  NOTE = { icon = "󰋽", label = "Note" },
  TIP = { icon = "󰌶", label = "Tip" },
  IMPORTANT = { icon = "󰅾", label = "Important" },
  WARNING = { icon = "󰀪", label = "Warning" },
  CAUTION = { icon = "󰳦", label = "Caution" },
  -- Obsidian additional types
  ABSTRACT = { icon = "󱉫", label = "Abstract" },
  SUMMARY = { icon = "󱉫", label = "Summary", style = "ABSTRACT" },
  TLDR = { icon = "󱉫", label = "TL;DR", style = "ABSTRACT" },
  INFO = { icon = "󰋽", label = "Info", style = "NOTE" },
  TODO = { icon = "󰄬", label = "Todo" },
  SUCCESS = { icon = "󰄬", label = "Success" },
  CHECK = { icon = "󰄬", label = "Check", style = "SUCCESS" },
  DONE = { icon = "󰄬", label = "Done", style = "SUCCESS" },
  QUESTION = { icon = "󱈅", label = "Question" },
  HELP = { icon = "󱈅", label = "Help", style = "QUESTION" },
  FAQ = { icon = "󱈅", label = "FAQ", style = "QUESTION" },
  FAILURE = { icon = "󰅙", label = "Failure" },
  FAIL = { icon = "󰅙", label = "Fail", style = "FAILURE" },
  MISSING = { icon = "󰅙", label = "Missing", style = "FAILURE" },
  DANGER = { icon = "󱐌", label = "Danger" },
  ERROR = { icon = "󱐌", label = "Error", style = "DANGER" },
  BUG = { icon = "󱈰", label = "Bug" },
  EXAMPLE = { icon = "󰆹", label = "Example" },
  QUOTE = { icon = "󱗝", label = "Quote" },
  CITE = { icon = "󱗝", label = "Cite", style = "QUOTE" },
}

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

--- Process [[wikilinks]]: display as link text with highlight
---@param text string
---@param highlights Ghsigns.Markdown.Highlight[]
---@param links Ghsigns.Markdown.Link[]
---@return string processed
local function process_wikilinks(text, highlights, links)
  local processed = ""
  local i = 1

  while i <= #text do
    if text:sub(i, i + 1) == "[[" then
      local close = text:find("]]", i + 2, true)
      if close then
        local inner = text:sub(i + 2, close - 1)
        local display, target

        local pipe_pos = inner:find("|", 1, true)
        if pipe_pos then
          target = inner:sub(1, pipe_pos - 1)
          display = inner:sub(pipe_pos + 1)
        else
          target = inner
          local heading = inner:match "^#(.+)$"
          if heading then
            display = heading
          else
            local page, h = inner:match "^(.+)#(.+)$"
            if page and h then
              display = page .. " > " .. h
            else
              display = inner
            end
          end
        end

        local start_col = #processed
        processed = processed .. display
        table.insert(highlights, { col = start_col, end_col = start_col + #display, hl = "Underlined" })
        table.insert(links, {
          col_start = start_col,
          col_end = start_col + #display,
          url = "obsidian://open?file=" .. target,
        })
        i = close + 2
      else
        processed = processed .. text:sub(i, i)
        i = i + 1
      end
    else
      processed = processed .. text:sub(i, i)
      i = i + 1
    end
  end

  return processed
end

--- Process [text](url) links: remove markers and produce highlight/link entries
---@param text string
---@param highlights Ghsigns.Markdown.Highlight[]
---@param links Ghsigns.Markdown.Link[]
---@return string processed
local function process_links(text, highlights, links)
  local processed = ""
  local i = 1
  while i <= #text do
    local s, e = text:find("%[([^%]]+)%]%([^%)]+%)", i)
    if s == i then
      local link_text = text:match("%[([^%]]+)%]%([^%)]+%)", i)
      local url = text:match("%[[^%]]+%]%(([^%)]+)%)", i)
      local start_col = #processed
      processed = processed .. link_text
      table.insert(highlights, { col = start_col, end_col = start_col + #link_text, hl = "Underlined" })
      table.insert(links, { col_start = start_col, col_end = start_col + #link_text, url = url })
      i = e + 1
    else
      processed = processed .. text:sub(i, i)
      i = i + 1
    end
  end
  return processed
end

--- Process bare URLs: detect standalone URLs, truncate for display, add link metadata with full URL
---@param text string
---@param max_url_width integer
---@param highlights Ghsigns.Markdown.Highlight[]
---@param links Ghsigns.Markdown.Link[]
---@return string processed
local function process_bare_urls(text, max_url_width, highlights, links)
  local pre_hl_count = #highlights
  local pre_link_count = #links
  local processed = ""
  local i = 1
  local in_backtick = false
  local adjustments = {}

  while i <= #text do
    if text:sub(i, i) == "`" then
      in_backtick = not in_backtick
      processed = processed .. "`"
      i = i + 1
    elseif not in_backtick then
      local s, e = text:find("https?://[^%s%)<>]+", i)
      if s == i then
        local url_match = text:sub(s, e)
        -- Strip trailing punctuation (including markdown markers)
        local url = url_match:gsub("[.,;:!?*~]+$", "")
        local start_col = #processed
        local display_url

        if vim.fn.strdisplaywidth(url) > max_url_width then
          local target = max_url_width - 1
          local current_width = 0
          local byte_pos = 0
          for char in url:gmatch "[%z\1-\127\194-\253][\128-\191]*" do
            local char_width = vim.fn.strdisplaywidth(char)
            if current_width + char_width > target then
              break
            end
            current_width = current_width + char_width
            byte_pos = byte_pos + #char
          end
          display_url = url:sub(1, byte_pos) .. "…"
          table.insert(adjustments, {
            input_pos = i - 1 + byte_pos,
            delta = #url - byte_pos - #"…",
          })
        else
          display_url = url
        end

        processed = processed .. display_url
        table.insert(highlights, { col = start_col, end_col = start_col + #display_url, hl = "Underlined" })
        table.insert(links, { col_start = start_col, col_end = start_col + #display_url, url = url })
        i = i + #url
      else
        processed = processed .. text:sub(i, i)
        i = i + 1
      end
    else
      processed = processed .. text:sub(i, i)
      i = i + 1
    end
  end

  if #adjustments > 0 then
    local function adjust(pos)
      local total_delta = 0
      for _, adj in ipairs(adjustments) do
        if pos > adj.input_pos then
          total_delta = total_delta + adj.delta
        end
      end
      return pos - total_delta
    end
    for idx = 1, pre_hl_count do
      highlights[idx].col = adjust(highlights[idx].col)
      highlights[idx].end_col = adjust(highlights[idx].end_col)
    end
    for idx = 1, pre_link_count do
      links[idx].col_start = adjust(links[idx].col_start)
      links[idx].col_end = adjust(links[idx].col_end)
    end
  end

  return processed
end

--- Process #123 issue/PR references: make them clickable (skip inside backticks)
---@param text string
---@param repo_base_url string
---@param highlights Ghsigns.Markdown.Highlight[]
---@param links Ghsigns.Markdown.Link[]
---@return string processed
local function process_issue_refs(text, repo_base_url, highlights, links)
  local processed = ""
  local i = 1
  local in_backtick = false
  while i <= #text do
    if text:sub(i, i) == "`" then
      in_backtick = not in_backtick
      processed = processed .. "`"
      i = i + 1
    else
      local s, e = text:find("#%d+", i)
      if s == i and not in_backtick then
        local issue_num = text:match("#(%d+)", i)
        local issue_text = "#" .. issue_num
        local url = repo_base_url .. "/issues/" .. issue_num
        local start_col = #processed
        processed = processed .. issue_text
        table.insert(highlights, { col = start_col, end_col = start_col + #issue_text, hl = "Underlined" })
        table.insert(links, { col_start = start_col, col_end = start_col + #issue_text, url = url })
        i = e + 1
      else
        processed = processed .. text:sub(i, i)
        i = i + 1
      end
    end
  end
  return processed
end

--- Process autolink references: make key_prefix matches clickable (skip inside backticks)
---@param text string
---@param autolinks Ghsigns.Autolink[]
---@param highlights Ghsigns.Markdown.Highlight[]
---@param links Ghsigns.Markdown.Link[]
---@return string processed
local function process_autolink_refs(text, autolinks, highlights, links)
  local processed = ""
  local i = 1
  local in_backtick = false
  while i <= #text do
    if text:sub(i, i) == "`" then
      in_backtick = not in_backtick
      processed = processed .. "`"
      i = i + 1
    elseif not in_backtick then
      local matched = false
      for _, autolink in ipairs(autolinks) do
        local prefix = autolink.key_prefix
        if text:sub(i, i + #prefix - 1) == prefix then
          -- Try to match the value after the prefix
          local rest = text:sub(i + #prefix)
          local value
          if autolink.is_alphanumeric then
            value = rest:match "^([%w]+)"
          else
            value = rest:match "^(%d+)"
          end
          if value and #value > 0 then
            local ref_text = prefix .. value
            local url = autolink.url_template:gsub("<num>", value)
            local start_col = #processed
            processed = processed .. ref_text
            table.insert(highlights, { col = start_col, end_col = start_col + #ref_text, hl = "Underlined" })
            table.insert(links, { col_start = start_col, col_end = start_col + #ref_text, url = url })
            i = i + #ref_text
            matched = true
            break
          end
        end
      end
      if not matched then
        processed = processed .. text:sub(i, i)
        i = i + 1
      end
    else
      processed = processed .. text:sub(i, i)
      i = i + 1
    end
  end
  return processed
end

--- Prepend blockquote visual prefix and shift all highlight/link positions
---@param text string
---@param quote_prefix string
---@param highlights Ghsigns.Markdown.Highlight[]
---@param links Ghsigns.Markdown.Link[]
---@return string
local function apply_blockquote_prefix(text, quote_prefix, highlights, links)
  local offset = #quote_prefix
  text = quote_prefix .. text
  table.insert(highlights, 1, { col = 0, end_col = offset, hl = "FloatBorder" })
  for idx = 2, #highlights do
    highlights[idx].col = highlights[idx].col + offset
    highlights[idx].end_col = highlights[idx].end_col + offset
  end
  for _, link in ipairs(links) do
    link.col_start = link.col_start + offset
    link.col_end = link.col_end + offset
  end
  return text
end

--- Render markdown text to plain text with highlight and link metadata
---@param text string The markdown text to render
---@param repo_base_url? string Optional repository base URL for issue/PR references
---@param autolinks? Ghsigns.Autolink[] Optional autolink definitions
---@return string rendered_text The rendered plain text
---@return Ghsigns.Markdown.Highlight[] highlights
---@return Ghsigns.Markdown.Link[] links
---@return string? special_type Special type like "heading" if applicable
---@return string? list_marker List marker if applicable
---@return string? alert_type Alert type (NOTE, TIP, etc.) if applicable
Markdown.render = function(text, repo_base_url, autolinks)
  local rendered_text = text:gsub("\r", "")
  -- Collapse multiple consecutive spaces (preserve leading whitespace)
  local leading_ws = rendered_text:match "^(%s*)" or ""
  rendered_text = leading_ws .. rendered_text:sub(#leading_ws + 1):gsub("  +", " ")
  local highlights = {}
  local links = {}

  -- Heading (# ## ###) - early return
  local heading_content = rendered_text:match "^#+%s+(.+)$"
  if heading_content then
    rendered_text = heading_content
    table.insert(highlights, { col = 0, end_col = #rendered_text, hl = "Title" })
    return rendered_text, highlights, links, "heading"
  end

  -- Blockquote (> ) - extract prefix
  local quote_prefix = ""
  local is_blockquote = false
  while rendered_text:match "^>%s?" do
    rendered_text = rendered_text:gsub("^>%s?", "", 1)
    quote_prefix = quote_prefix .. "│ "
    is_blockquote = true
  end

  -- Detect alert/callout syntax [!TYPE] or [!TYPE] Custom Title in blockquotes
  if is_blockquote then
    local alert_key, custom_title = rendered_text:match "^%[!(%a+)%]%s+(.+)$"
    if not alert_key then
      alert_key = rendered_text:match "^%[!(%a+)%]$"
    end
    if alert_key then
      alert_key = alert_key:upper()
      local alert = ALERT_TYPES[alert_key]
      if alert then
        local style_key = alert.style or alert_key
        if custom_title then
          rendered_text = alert.icon .. " " .. custom_title
        else
          rendered_text = alert.icon .. " " .. alert.label
        end
        rendered_text = apply_blockquote_prefix(rendered_text, quote_prefix, highlights, links)
        return rendered_text, highlights, links, "blockquote", nil, style_key
      end
    end
  end

  -- List items (- * 1.) - detect marker
  local list_marker = rendered_text:match "^(%s*[-*]%s)"
    or rendered_text:match "^(%s*%d+%.%s)"

  -- Remove Obsidian inline comments (%%...%%)
  rendered_text = rendered_text:gsub("%%%%(.-)%%%%", "")

  -- Process inline elements (wikilinks before standard links)
  rendered_text = process_wikilinks(rendered_text, highlights, links)
  rendered_text = process_links(rendered_text, highlights, links)
  rendered_text = process_bare_urls(rendered_text, MAX_URL_DISPLAY_WIDTH, highlights, links)
  if repo_base_url then
    rendered_text = process_issue_refs(rendered_text, repo_base_url, highlights, links)
  end
  if autolinks and #autolinks > 0 then
    rendered_text = process_autolink_refs(rendered_text, autolinks, highlights, links)
  end
  rendered_text = process_paired_markers(rendered_text, "%*%*([^*]+)%*%*", "Bold", 2, highlights, links)
  rendered_text = process_paired_markers(rendered_text, "~~([^~]+)~~", "DiagnosticDeprecated", 2, highlights, links)
  rendered_text = process_paired_markers(rendered_text, "==([^=]+)==", "GhsignsHighlight", 2, highlights, links)
  rendered_text = process_code_markers(rendered_text, "String", highlights, links)

  -- Add list marker highlight
  if list_marker then
    table.insert(highlights, 1, { col = 0, end_col = #list_marker, hl = "Special" })
  end

  -- Prepend blockquote prefix
  if is_blockquote then
    rendered_text = apply_blockquote_prefix(rendered_text, quote_prefix, highlights, links)
    return rendered_text, highlights, links, "blockquote", list_marker
  end

  return rendered_text, highlights, links, nil, list_marker
end

return Markdown
