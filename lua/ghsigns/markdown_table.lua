---@class Ghsigns.MarkdownTable.ParsedCell
---@field text string rendered text (inline markdown processed)
---@field highlights Ghsigns.Markdown.Highlight[] highlights from markdown.render()
---@field links Ghsigns.Markdown.Link[] links from markdown.render()

---@class Ghsigns.MarkdownTable.ParsedTable
---@field headers Ghsigns.MarkdownTable.ParsedCell[]
---@field alignments string[] "left"|"center"|"right" per column
---@field rows Ghsigns.MarkdownTable.ParsedCell[][] each row is an array of cells
---@field col_widths integer[] display width per column

local MarkdownTable = {}

--- Split a table row into cell strings (trim leading/trailing whitespace)
---@param line string
---@return string[]|nil cells or nil if not a valid table row
local function split_row(line)
  -- Strip leading whitespace, then expect |
  local stripped = line:match "^%s*(.*)" or line
  if stripped:sub(1, 1) ~= "|" then
    return nil
  end
  -- Remove leading and trailing |
  local inner = stripped:match "^|(.*)$"
  if not inner then
    return nil
  end
  -- Remove trailing | if present
  if inner:sub(-1) == "|" then
    inner = inner:sub(1, -2)
  end
  local cells = {}
  for cell in (inner .. "|"):gmatch "(.-)|" do
    -- Trim whitespace
    cell = cell:match "^%s*(.-)%s*$"
    table.insert(cells, cell)
  end
  return cells
end

--- Check if a line is a separator row (e.g., |---|:---:|---:|)
---@param line string
---@return string[]|nil alignments array or nil if not a separator
local function parse_separator(line)
  local cells = split_row(line)
  if not cells or #cells == 0 then
    return nil
  end
  local alignments = {}
  for _, cell in ipairs(cells) do
    -- Must match pattern: optional :, one or more -, optional :
    if not cell:match "^:?%-+:?$" then
      return nil
    end
    local left = cell:sub(1, 1) == ":"
    local right = cell:sub(-1) == ":"
    if left and right then
      table.insert(alignments, "center")
    elseif right then
      table.insert(alignments, "right")
    else
      table.insert(alignments, "left")
    end
  end
  return alignments
end

--- Process a cell's text through markdown.render() for inline formatting
---@param text string
---@param repo_base_url? string
---@return Ghsigns.MarkdownTable.ParsedCell
local function process_cell(text, repo_base_url)
  local markdown = require "ghsigns.markdown"
  local rendered, highlights, links = markdown.render(text, repo_base_url)
  return {
    text = rendered,
    highlights = highlights,
    links = links,
  }
end

--- Pad text to a given display width according to alignment
---@param text string
---@param width integer target display width
---@param align string "left"|"center"|"right"
---@return string padded text
---@return integer left_pad number of spaces added on the left
local function pad_cell(text, width, align)
  local text_width = vim.fn.strdisplaywidth(text)
  local total_pad = width - text_width
  if total_pad <= 0 then
    return text, 0
  end
  if align == "right" then
    return string.rep(" ", total_pad) .. text, total_pad
  elseif align == "center" then
    local left = math.floor(total_pad / 2)
    local right = total_pad - left
    return string.rep(" ", left) .. text .. string.rep(" ", right), left
  else
    return text .. string.rep(" ", total_pad), 0
  end
end

--- Parse consecutive lines as a Markdown table
---@param lines string[]
---@param repo_base_url? string
---@return Ghsigns.MarkdownTable.ParsedTable|nil
function MarkdownTable.parse(lines, repo_base_url)
  if #lines < 2 then
    return nil
  end

  -- Line 1: header row
  local header_cells = split_row(lines[1])
  if not header_cells or #header_cells == 0 then
    return nil
  end

  -- Line 2: separator row
  local alignments = parse_separator(lines[2])
  if not alignments then
    return nil
  end

  -- Column count must match
  if #header_cells ~= #alignments then
    return nil
  end

  -- Process header cells
  local headers = {}
  for _, cell_text in ipairs(header_cells) do
    table.insert(headers, process_cell(cell_text, repo_base_url))
  end

  -- Process data rows (line 3+)
  local rows = {}
  for i = 3, #lines do
    local cells = split_row(lines[i])
    if not cells then
      break
    end
    local row = {}
    for col = 1, #alignments do
      local cell_text = cells[col] or ""
      table.insert(row, process_cell(cell_text, repo_base_url))
    end
    table.insert(rows, row)
  end

  -- Calculate column widths (display width)
  local col_widths = {}
  for col = 1, #alignments do
    local w = vim.fn.strdisplaywidth(headers[col].text)
    for _, row in ipairs(rows) do
      if row[col] then
        w = math.max(w, vim.fn.strdisplaywidth(row[col].text))
      end
    end
    col_widths[col] = w
  end

  return {
    headers = headers,
    alignments = alignments,
    rows = rows,
    col_widths = col_widths,
  }
end

--- Render a parsed table into lines with highlights and links
---@param parsed_table Ghsigns.MarkdownTable.ParsedTable
---@param indent string
---@return string[] lines
---@return Ghsigns.Highlight.Group[][] per_line_highlights
---@return {line: integer, col_start: integer, col_end: integer, url: string}[][] per_line_links
function MarkdownTable.render(parsed_table, indent)
  local out_lines = {}
  local out_highlights = {}
  local out_links = {}
  local num_cols = #parsed_table.col_widths

  --- Build a data row line (header or body)
  ---@param cells Ghsigns.MarkdownTable.ParsedCell[]
  ---@param is_header boolean
  ---@return string line
  ---@return Ghsigns.Highlight.Group[] highlights
  ---@return {col_start: integer, col_end: integer, url: string}[] links
  local function build_row(cells, is_header)
    local parts = {}
    local hls = {}
    local lnks = {}
    local byte_pos = #indent

    for col = 1, num_cols do
      local cell = cells[col]
      local padded, left_pad = pad_cell(cell.text, parsed_table.col_widths[col], parsed_table.alignments[col])

      -- "│ " before cell
      local sep = "│ "
      table.insert(hls, { col = byte_pos, end_col = byte_pos + #sep, hl = "FloatBorder" })
      byte_pos = byte_pos + #sep

      local cell_start = byte_pos + left_pad

      -- Add cell highlights (shifted by byte_pos + left_pad)
      for _, hl in ipairs(cell.highlights) do
        table.insert(hls, {
          col = cell_start + hl.col,
          end_col = cell_start + hl.end_col,
          hl = hl.hl,
        })
      end

      -- Add header Bold highlight
      if is_header then
        table.insert(hls, {
          col = cell_start,
          end_col = cell_start + #cell.text,
          hl = "Bold",
        })
      end

      -- Add cell links (shifted)
      for _, link in ipairs(cell.links) do
        table.insert(lnks, {
          col_start = cell_start + link.col_start,
          col_end = cell_start + link.col_end,
          url = link.url,
        })
      end

      byte_pos = byte_pos + #padded
      table.insert(parts, sep .. padded)

      -- " " after cell (before next separator)
      byte_pos = byte_pos + 1
      table.insert(parts, " ")
    end

    -- Trailing "│"
    local trailing = "│"
    table.insert(hls, { col = byte_pos, end_col = byte_pos + #trailing, hl = "FloatBorder" })
    table.insert(parts, trailing)

    return indent .. table.concat(parts), hls, lnks
  end

  --- Build a separator line
  ---@return string line
  ---@return Ghsigns.Highlight.Group[] highlights
  local function build_separator()
    local parts = {}
    local byte_pos = #indent

    for col = 1, num_cols do
      local sep_str = "│" .. string.rep("─", parsed_table.col_widths[col] + 2)
      table.insert(parts, sep_str)
      byte_pos = byte_pos + #sep_str
    end
    table.insert(parts, "│")

    local line = indent .. table.concat(parts)
    local hls = { { col = #indent, end_col = #line, hl = "FloatBorder" } }
    return line, hls
  end

  -- Header row
  local h_line, h_hls, h_links = build_row(parsed_table.headers, true)
  table.insert(out_lines, h_line)
  table.insert(out_highlights, h_hls)
  table.insert(out_links, h_links)

  -- Separator
  local s_line, s_hls = build_separator()
  table.insert(out_lines, s_line)
  table.insert(out_highlights, s_hls)
  table.insert(out_links, {})

  -- Data rows
  for _, row in ipairs(parsed_table.rows) do
    local r_line, r_hls, r_links = build_row(row, false)
    table.insert(out_lines, r_line)
    table.insert(out_highlights, r_hls)
    table.insert(out_links, r_links)
  end

  return out_lines, out_highlights, out_links
end

return MarkdownTable
