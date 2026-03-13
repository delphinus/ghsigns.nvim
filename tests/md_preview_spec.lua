local eq = assert.are.same

describe("Markdown Preview content rendering", function()
  local md_preview

  before_each(function()
    package.loaded["ghsigns.md_preview"] = nil
    package.loaded["md-render.preview"] = nil
    package.loaded["md-render.content_builder"] = nil
    package.loaded["md-render.display_utils"] = nil
    package.loaded["md-render.float_win"] = nil
    package.loaded["md-render"] = nil
    md_preview = require "ghsigns.md_preview"
  end)

  after_each(function()
    package.loaded["ghsigns.md_preview"] = nil
    package.loaded["md-render.preview"] = nil
    package.loaded["md-render.content_builder"] = nil
    package.loaded["md-render.display_utils"] = nil
    package.loaded["md-render.float_win"] = nil
    package.loaded["md-render"] = nil
  end)

  -- Helper to find highlight groups for a specific line index
  local function hl_for_line(content, line_idx)
    for _, hl in ipairs(content.highlights) do
      if hl.line == line_idx then
        return hl.groups
      end
    end
    return nil
  end

  ---------------------------------------------------------------------------
  -- Group 1: Headings
  ---------------------------------------------------------------------------
  describe("Headings", function()
    it("should render h2 heading with icon and MdRenderH2 highlight", function()
      local c = md_preview.build_content { "## My Heading" }
      eq("  ○ My Heading", c.lines[1])
      local hls = hl_for_line(c, 0)
      eq("MdRenderH2", hls[1].hl)
    end)

    it("should render h1 heading with icon and MdRenderH1 highlight", function()
      local c = md_preview.build_content { "# Top Level" }
      eq("  ◉ Top Level", c.lines[1])
      local hls = hl_for_line(c, 0)
      eq("MdRenderH1", hls[1].hl)
    end)

    it("should auto-insert blank line before headings", function()
      local c = md_preview.build_content {
        "Some text",
        "## Heading",
      }
      eq("  Some text", c.lines[1])
      eq("  ", c.lines[2])
      eq("  ○ Heading", c.lines[3])
    end)

    it("should skip blank lines immediately after headings", function()
      local c = md_preview.build_content {
        "## Heading",
        "",
        "Paragraph",
      }
      eq("  ○ Heading", c.lines[1])
      eq("  Paragraph", c.lines[2])
    end)

    it("should insert blank lines between consecutive headings", function()
      local c = md_preview.build_content {
        "# hoge1",
        "## hoge2",
        "### hoge3",
        "content",
      }
      eq("  ◉ hoge1", c.lines[1])
      eq("  ", c.lines[2])
      eq("  ○ hoge2", c.lines[3])
      eq("  ", c.lines[4])
      eq("  ◆ hoge3", c.lines[5])
      eq("  content", c.lines[6])
    end)

    it("should insert blank lines between consecutive headings with blank lines in source", function()
      local c = md_preview.build_content {
        "# hoge1",
        "",
        "## hoge2",
        "",
        "### hoge3",
        "content",
      }
      eq("  ◉ hoge1", c.lines[1])
      eq("  ", c.lines[2])
      eq("  ○ hoge2", c.lines[3])
      eq("  ", c.lines[4])
      eq("  ◆ hoge3", c.lines[5])
      eq("  content", c.lines[6])
    end)

    it("should collapse multiple blank lines before headings to one", function()
      local c = md_preview.build_content {
        "content",
        "",
        "",
        "",
        "## Heading",
      }
      eq("  content", c.lines[1])
      eq("  ", c.lines[2])
      eq("  ○ Heading", c.lines[3])
      eq(3, #c.lines)
    end)
  end)

  describe("Setext headings", function()
    it("should render setext h1 with === underline", function()
      local c = md_preview.build_content {
        "Top Level",
        "=========",
      }
      eq("  ◉ Top Level", c.lines[1])
      eq(1, #c.lines)
      local hls = hl_for_line(c, 0)
      eq("MdRenderH1", hls[1].hl)
    end)

    it("should render setext h2 with --- underline", function()
      local c = md_preview.build_content {
        "License",
        "-------",
      }
      eq("  ○ License", c.lines[1])
      eq(1, #c.lines)
      local hls = hl_for_line(c, 0)
      eq("MdRenderH2", hls[1].hl)
    end)

    it("should handle setext headings with surrounding content", function()
      local c = md_preview.build_content {
        "Some text",
        "",
        "Features",
        "--------",
        "",
        "More text",
      }
      -- Blank lines adjacent to headings are skipped, but one is auto-inserted before
      eq("  Some text", c.lines[1])
      eq("  ", c.lines[2]) -- auto-inserted blank before heading
      eq("  ○ Features", c.lines[3])
      -- Blank line after heading is skipped
      eq("  More text", c.lines[4])
      eq(4, #c.lines)
    end)
  end)

  describe("Reference links", function()
    it("should resolve reference links and hide definitions", function()
      local c = md_preview.build_content {
        "See [advanced UIs] for details.",
        "",
        "[advanced UIs]: https://example.com/gui",
      }
      -- Reference link definition should be hidden
      eq(2, #c.lines) -- text + blank line (no definition line)
      assert.is_truthy(c.lines[1]:match "advanced UIs")
      -- Should have link metadata
      eq(1, #c.link_metadata)
      eq("https://example.com/gui", c.link_metadata[1].url)
    end)

    it("should resolve [text][ref] reference links", function()
      local c = md_preview.build_content {
        "See [help][my-ref] here.",
        "",
        "[my-ref]: https://example.com",
      }
      assert.is_truthy(c.lines[1]:match "help")
      eq(1, #c.link_metadata)
      eq("https://example.com", c.link_metadata[1].url)
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 2: Bold text
  ---------------------------------------------------------------------------
  describe("Bold text", function()
    it("should render bold with Bold highlight", function()
      local c = md_preview.build_content { "This is **bold** text" }
      eq("  This is bold text", c.lines[1])
      local hls = hl_for_line(c, 0)
      local found = false
      for _, hl in ipairs(hls) do
        if hl.hl == "Bold" then
          found = true
          eq(2 + 8, hl.col) -- "  This is " = 10
          eq(2 + 12, hl.end_col) -- "bold" = 4
        end
      end
      assert.is_true(found, "Expected Bold highlight")
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 3: Code blocks
  ---------------------------------------------------------------------------
  describe("Code blocks", function()
    it("should render code block lines with String highlight", function()
      local c = md_preview.build_content {
        "```",
        "hello world",
        "```",
      }
      eq("  hello world", c.lines[1])
      eq({
        { col = 0, end_col = -1, hl = "String" },
      }, hl_for_line(c, 0))
    end)

    it("should track code blocks with language for treesitter", function()
      local c = md_preview.build_content {
        "```lua",
        "local x = 1",
        "return x",
        "```",
      }
      eq("  local x = 1", c.lines[1])
      eq("  return x", c.lines[2])
      eq(1, #c.code_blocks)
      eq("lua", c.code_blocks[1].language)
      eq(0, c.code_blocks[1].start_line)
      eq(1, c.code_blocks[1].end_line)
    end)

    it("should truncate long code lines with ellipsis", function()
      local long_line = string.rep("a", 100)
      local c = md_preview.build_content {
        "```",
        long_line,
        "```",
      }
      -- "  " + 100 chars = 102, exceeds default max_width 80
      local line = c.lines[1]
      -- Line should be truncated (shorter than original) and end with ellipsis
      assert.is_not_nil(line:find "…")
      assert.is_true(#line < #("  " .. long_line), "Expected truncated line to be shorter than original")
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 4: Tables
  ---------------------------------------------------------------------------
  describe("Tables", function()
    it("should render table with borders", function()
      local c = md_preview.build_content {
        "| A | B |",
        "|---|---|",
        "| 1 | 2 |",
      }
      -- Tables are rendered with box-drawing borders (5 lines: top, header, mid, data, bottom)
      assert.is_true(#c.lines >= 3)
      -- Some line should contain box-drawing border characters
      local found_border = false
      for _, line in ipairs(c.lines) do
        if line:find "─" then
          found_border = true
          break
        end
      end
      assert.is_true(found_border, "Expected box-drawing border in table")
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 5: Lists
  ---------------------------------------------------------------------------
  describe("Lists", function()
    it("should render unordered list items with Special highlight", function()
      local c = md_preview.build_content {
        "- Item one",
        "- Item two",
      }
      eq("  - Item one", c.lines[1])
      eq("  - Item two", c.lines[2])
      local hls = hl_for_line(c, 0)
      local found = false
      for _, hl in ipairs(hls) do
        if hl.hl == "Special" then
          found = true
        end
      end
      assert.is_true(found, "Expected Special highlight for list marker")
    end)

    it("should render ordered list items", function()
      local c = md_preview.build_content {
        "1. First",
        "2. Second",
      }
      eq("  1. First", c.lines[1])
      eq("  2. Second", c.lines[2])
    end)

    it("should renumber all-1 ordered list items sequentially", function()
      local c = md_preview.build_content {
        "1. First",
        "1. Second",
        "1. Third",
      }
      eq("  1. First", c.lines[1])
      eq("  2. Second", c.lines[2])
      eq("  3. Third", c.lines[3])
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 6: Blockquotes
  ---------------------------------------------------------------------------
  describe("Blockquotes", function()
    it("should render blockquotes with FloatBorder prefix", function()
      local c = md_preview.build_content { "> Quote text" }
      eq("  │ Quote text", c.lines[1])
      local hls = hl_for_line(c, 0)
      local found = false
      for _, hl in ipairs(hls) do
        if hl.hl == "FloatBorder" then
          found = true
        end
      end
      assert.is_true(found, "Expected FloatBorder highlight for blockquote prefix")
    end)

    it("should render nested blockquotes", function()
      local c = md_preview.build_content { ">> Nested" }
      eq("  │ │ Nested", c.lines[1])
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 7: Links
  ---------------------------------------------------------------------------
  describe("Links", function()
    it("should render links with Underlined highlight and link metadata", function()
      local c = md_preview.build_content { "[Neovim](https://neovim.io)" }
      eq("  Neovim", c.lines[1])
      eq(1, #c.link_metadata)
      eq("https://neovim.io", c.link_metadata[1].url)
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 8: Strikethrough
  ---------------------------------------------------------------------------
  describe("Strikethrough", function()
    it("should render strikethrough with DiagnosticDeprecated highlight", function()
      local c = md_preview.build_content { "~~removed~~" }
      eq("  removed", c.lines[1])
      local hls = hl_for_line(c, 0)
      local found = false
      for _, hl in ipairs(hls) do
        if hl.hl == "DiagnosticDeprecated" then
          found = true
        end
      end
      assert.is_true(found, "Expected DiagnosticDeprecated highlight")
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 9: Inline code
  ---------------------------------------------------------------------------
  describe("Inline code", function()
    it("should render inline code with String highlight", function()
      local c = md_preview.build_content { "Use `vim.api` here" }
      eq("  Use vim.api here", c.lines[1])
      local hls = hl_for_line(c, 0)
      local found = false
      for _, hl in ipairs(hls) do
        if hl.hl == "String" then
          found = true
        end
      end
      assert.is_true(found, "Expected String highlight for inline code")
    end)

    it("should not overlap inline code highlight with list marker on wrapped lines", function()
      -- Long list item with inline code that triggers wrapping
      local c = md_preview.build_content({
        "- `> [!note]- Title` and `> [!note]+ Title` are not recognized because the pattern does not include them",
      }, { max_width = 60 })
      -- Should have at least 2 lines (wrapped)
      assert.is_true(#c.lines >= 2, "Expected wrapped output, got " .. #c.lines .. " lines")
      -- Line 1 should have Special highlight for "- " at correct position
      local hls = hl_for_line(c, 0)
      local special_hl = nil
      local string_hl = nil
      for _, hl in ipairs(hls) do
        if hl.hl == "Special" then
          special_hl = hl
        end
        if hl.hl == "String" and not string_hl then
          string_hl = hl
        end
      end
      assert.is_not_nil(special_hl, "Expected Special highlight for list marker")
      assert.is_not_nil(string_hl, "Expected String highlight for inline code")
      -- Special and String highlights should NOT overlap
      assert.is_true(
        string_hl.col >= special_hl.end_col,
        "String highlight (col=" .. string_hl.col .. ") should not overlap with Special (end_col=" .. special_hl.end_col .. ")"
      )
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 10: No truncation
  ---------------------------------------------------------------------------
  describe("No truncation", function()
    it("should not truncate content regardless of length", function()
      local lines = {}
      for i = 1, 50 do
        table.insert(lines, "Line " .. i)
      end
      local c = md_preview.build_content(lines)
      eq(50, #c.lines)
      -- No "... (truncated)" line
      for _, line in ipairs(c.lines) do
        assert.is_not.truthy(line:match "truncated")
      end
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 11: Empty input
  ---------------------------------------------------------------------------
  describe("Empty input", function()
    it("should handle empty input", function()
      local c = md_preview.build_content {}
      eq(0, #c.lines)
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 12: Mixed content
  ---------------------------------------------------------------------------
  describe("Mixed content", function()
    it("should render mixed markdown correctly", function()
      local c = md_preview.build_content {
        "## Title",
        "",
        "A paragraph with **bold** and `code`.",
        "",
        "- List item",
        "",
        "```lua",
        "local x = 1",
        "```",
        "",
        "> A quote",
      }

      eq("  ○ Title", c.lines[1])
      -- paragraph
      assert.is_truthy(c.lines[2]:match "A paragraph")
      -- list
      local found_list = false
      for _, line in ipairs(c.lines) do
        if line:match "- List item" then
          found_list = true
        end
      end
      assert.is_true(found_list, "Expected list item")
      -- code block
      eq(1, #c.code_blocks)
      eq("lua", c.code_blocks[1].language)
      -- blockquote
      local found_quote = false
      for _, line in ipairs(c.lines) do
        if line:match "│ A quote" then
          found_quote = true
        end
      end
      assert.is_true(found_quote, "Expected blockquote")
    end)
  end)

  describe("Block comments", function()
    it("should skip block comment lines", function()
      local c = md_preview.build_content {
        "visible line",
        "%%",
        "hidden line 1",
        "hidden line 2",
        "%%",
        "visible again",
      }
      local all_text = table.concat(c.lines, "\n")
      assert.is_truthy(all_text:match "visible line")
      assert.is_truthy(all_text:match "visible again")
      assert.is_falsy(all_text:match "hidden line")
    end)

    it("should hide everything after unclosed block comment", function()
      local c = md_preview.build_content {
        "visible line",
        "%%",
        "hidden to the end",
      }
      local all_text = table.concat(c.lines, "\n")
      assert.is_truthy(all_text:match "visible line")
      assert.is_falsy(all_text:match "hidden to the end")
    end)

    it("should not treat %% inside code blocks as comments", function()
      local c = md_preview.build_content {
        "```",
        "%%",
        "code line",
        "%%",
        "```",
        "visible after code",
      }
      local all_text = table.concat(c.lines, "\n")
      assert.is_truthy(all_text:match "code line")
      assert.is_truthy(all_text:match "visible after code")
    end)
  end)

  describe("Frontmatter", function()
    it("should render frontmatter as Properties section", function()
      local c = md_preview.build_content {
        "---",
        "title: My Document",
        "date: 2026-03-04",
        "---",
        "# Hello",
      }
      eq("  Properties", c.lines[1])
      assert.is_truthy(c.lines[2]:match "title")
      assert.is_truthy(c.lines[2]:match "My Document")
      assert.is_truthy(c.lines[3]:match "date")
      assert.is_truthy(c.lines[3]:match "2026%-03%-04")
      eq("", c.lines[4])
      assert.is_truthy(c.lines[5]:match "Hello")
    end)

    it("should render list values as comma-separated", function()
      local c = md_preview.build_content {
        "---",
        "tags:",
        "  - foo",
        "  - bar",
        "  - baz",
        "---",
        "Body text",
      }
      assert.is_truthy(c.lines[2]:match "foo, bar, baz")
    end)

    it("should skip empty frontmatter", function()
      local c = md_preview.build_content {
        "---",
        "---",
        "Body text",
      }
      assert.is_truthy(c.lines[1]:match "Body text")
    end)

    it("should handle no frontmatter", function()
      local c = md_preview.build_content {
        "# No frontmatter",
        "Just text",
      }
      assert.is_truthy(c.lines[1]:match "No frontmatter")
    end)

    it("should not treat --- in body as frontmatter", function()
      local c = md_preview.build_content {
        "# Title",
        "---",
        "Body text",
      }
      assert.is_truthy(c.lines[1]:match "Title")
    end)

    it("should have Title highlight on Properties heading", function()
      local c = md_preview.build_content {
        "---",
        "key: value",
        "---",
      }
      local groups = hl_for_line(c, 0)
      assert.is_not_nil(groups)
      local found = false
      for _, g in ipairs(groups) do
        if g.hl == "Title" then
          found = true
        end
      end
      assert.is_true(found, "Expected Title highlight on Properties line")
    end)

    it("should handle unclosed frontmatter as regular content", function()
      local c = md_preview.build_content {
        "---",
        "key: value",
        "some text",
      }
      assert.is_falsy(c.lines[1]:match "Properties")
    end)

    it("should truncate long frontmatter values", function()
      local long_value = string.rep("a", 100)
      local c = md_preview.build_content({
        "---",
        "aliases: " .. long_value,
        "---",
        "Body text",
      }, { max_width = 40 })
      -- Properties header + aliases line + blank + body
      local aliases_line = c.lines[2]
      assert.is_truthy(aliases_line:match "aliases")
      assert.is_truthy(aliases_line:match "…$", "Expected truncation ellipsis")
      local display_width = vim.fn.strdisplaywidth(aliases_line)
      assert.is_true(display_width <= 40, "Expected truncated line width <= 40, got " .. display_width)
    end)

    it("should not truncate short frontmatter values", function()
      local c = md_preview.build_content({
        "---",
        "title: Short",
        "---",
        "Body text",
      }, { max_width = 80 })
      local title_line = c.lines[2]
      assert.is_truthy(title_line:match "Short")
      assert.is_falsy(title_line:match "…")
    end)
  end)
end)
