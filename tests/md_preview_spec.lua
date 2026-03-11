local eq = assert.are.same

describe("Markdown Preview content rendering", function()
  local md_preview

  before_each(function()
    package.loaded["ghsigns.md_preview"] = nil
    package.loaded["ghsigns.content_builder"] = nil
    package.loaded["ghsigns.display_utils"] = nil
    package.loaded["ghsigns.float_win"] = nil
    md_preview = require "ghsigns.md_preview"
  end)

  after_each(function()
    package.loaded["ghsigns.md_preview"] = nil
    package.loaded["ghsigns.content_builder"] = nil
    package.loaded["ghsigns.display_utils"] = nil
    package.loaded["ghsigns.float_win"] = nil
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
    it("should render heading with Title highlight", function()
      local c = md_preview.build_content { "## My Heading" }
      eq("  My Heading", c.lines[1])
      eq({
        { col = 2, end_col = 12, hl = "Title" },
      }, hl_for_line(c, 0))
    end)

    it("should render h1 heading", function()
      local c = md_preview.build_content { "# Top Level" }
      eq("  Top Level", c.lines[1])
      eq({
        { col = 2, end_col = 11, hl = "Title" },
      }, hl_for_line(c, 0))
    end)

    it("should auto-insert blank line before headings", function()
      local c = md_preview.build_content {
        "Some text",
        "## Heading",
      }
      eq("  Some text", c.lines[1])
      eq("  ", c.lines[2])
      eq("  Heading", c.lines[3])
    end)

    it("should skip blank lines immediately after headings", function()
      local c = md_preview.build_content {
        "## Heading",
        "",
        "Paragraph",
      }
      eq("  Heading", c.lines[1])
      eq("  Paragraph", c.lines[2])
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

      eq("  Title", c.lines[1])
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
  end)
end)
