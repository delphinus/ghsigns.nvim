---@class Ghsigns.Markdown
local Markdown = {}

--- Render markdown text to plain text with highlight and link metadata
---@param text string The markdown text to render
---@param repo_base_url? string Optional repository base URL for issue/PR references
---@return string rendered_text The rendered plain text
---@return table highlights Array of highlight metadata {col, end_col, hl}
---@return table links Array of link metadata {col_start, col_end, url}
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
  processed = ""
  i = 1
  while i <= #rendered_text do
    local s, e = rendered_text:find("%*%*([^*]+)%*%*", i)
    if s == i then
      local content = rendered_text:match("%*%*([^*]+)%*%*", i)
      local start_col = #processed
      processed = processed .. content
      table.insert(highlights, { col = start_col, end_col = start_col + #content, hl = "Bold" })
      i = e + 1
    else
      processed = processed .. rendered_text:sub(i, i)
      i = i + 1
    end
  end
  rendered_text = processed

  -- Strikethrough ~~text~~ - remove markers
  processed = ""
  i = 1
  while i <= #rendered_text do
    local s, e = rendered_text:find("~~([^~]+)~~", i)
    if s == i then
      local content = rendered_text:match("~~([^~]+)~~", i)
      local start_col = #processed
      processed = processed .. content
      table.insert(highlights, { col = start_col, end_col = start_col + #content, hl = "DiagnosticDeprecated" })
      i = e + 1
    else
      processed = processed .. rendered_text:sub(i, i)
      i = i + 1
    end
  end
  rendered_text = processed

  -- Code `text` - remove backticks
  processed = ""
  i = 1
  while i <= #rendered_text do
    if rendered_text:sub(i, i) == "`" then
      local e = rendered_text:find("`", i + 1)
      if e then
        local content = rendered_text:sub(i + 1, e - 1)
        local start_col = #processed
        processed = processed .. content
        table.insert(highlights, { col = start_col, end_col = start_col + #content, hl = "String" })
        i = e + 1
      else
        processed = processed .. rendered_text:sub(i, i)
        i = i + 1
      end
    else
      processed = processed .. rendered_text:sub(i, i)
      i = i + 1
    end
  end
  rendered_text = processed

  -- Add list marker highlight if present
  if list_marker then
    table.insert(highlights, 1, { col = 0, end_col = #list_marker, hl = "Special" })
  end

  return rendered_text, highlights, links, nil
end

return Markdown
