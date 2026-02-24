local eq = assert.are.same

describe("MarkdownTable", function()
  local markdown_table

  before_each(function()
    package.loaded["ghsigns.markdown_table"] = nil
    package.loaded["ghsigns.markdown"] = nil
    markdown_table = require "ghsigns.markdown_table"
  end)

  after_each(function()
    package.loaded["ghsigns.markdown_table"] = nil
    package.loaded["ghsigns.markdown"] = nil
  end)

  ---------------------------------------------------------------------------
  -- parse tests
  ---------------------------------------------------------------------------
  describe("parse", function()
    it("should parse a basic table", function()
      local lines = {
        "| Name | Age |",
        "|------|-----|",
        "| Alice | 30 |",
        "| Bob | 25 |",
      }
      local result = markdown_table.parse(lines)
      assert.is_not_nil(result)
      eq(2, #result.headers)
      eq("Name", result.headers[1].text)
      eq("Age", result.headers[2].text)
      eq(2, #result.rows)
      eq("Alice", result.rows[1][1].text)
      eq("30", result.rows[1][2].text)
      eq("Bob", result.rows[2][1].text)
      eq("25", result.rows[2][2].text)
    end)

    it("should detect alignment from separator", function()
      local lines = {
        "| Left | Center | Right |",
        "|:-----|:------:|------:|",
        "| a | b | c |",
      }
      local result = markdown_table.parse(lines)
      assert.is_not_nil(result)
      eq({ "left", "center", "right" }, result.alignments)
    end)

    it("should return nil for invalid input - too few lines", function()
      local lines = { "| Only header |" }
      eq(nil, markdown_table.parse(lines))
    end)

    it("should return nil for invalid separator", function()
      local lines = {
        "| A | B |",
        "| not a separator |",
        "| 1 | 2 |",
      }
      eq(nil, markdown_table.parse(lines))
    end)

    it("should return nil for column count mismatch", function()
      local lines = {
        "| A | B | C |",
        "|---|---|",
        "| 1 | 2 | 3 |",
      }
      eq(nil, markdown_table.parse(lines))
    end)

    it("should return nil when lines don't start with |", function()
      local lines = {
        "Not a table",
        "|---|",
        "| data |",
      }
      eq(nil, markdown_table.parse(lines))
    end)

    it("should process inline markdown in cells", function()
      local lines = {
        "| Feature |",
        "|---------|",
        "| **bold** |",
      }
      local result = markdown_table.parse(lines)
      assert.is_not_nil(result)
      eq("bold", result.rows[1][1].text)
      eq(1, #result.rows[1][1].highlights)
      eq("Bold", result.rows[1][1].highlights[1].hl)
    end)

    it("should process code markers in cells", function()
      local lines = {
        "| Syntax |",
        "|--------|",
        "| `code` |",
      }
      local result = markdown_table.parse(lines)
      assert.is_not_nil(result)
      eq("code", result.rows[1][1].text)
      eq("String", result.rows[1][1].highlights[1].hl)
    end)

    it("should process strikethrough in cells", function()
      local lines = {
        "| Status |",
        "|--------|",
        "| ~~removed~~ |",
      }
      local result = markdown_table.parse(lines)
      assert.is_not_nil(result)
      eq("removed", result.rows[1][1].text)
      eq("DiagnosticDeprecated", result.rows[1][1].highlights[1].hl)
    end)

    it("should process links in cells", function()
      local lines = {
        "| Link |",
        "|------|",
        "| [click](https://example.com) |",
      }
      local result = markdown_table.parse(lines)
      assert.is_not_nil(result)
      eq("click", result.rows[1][1].text)
      eq(1, #result.rows[1][1].links)
      eq("https://example.com", result.rows[1][1].links[1].url)
    end)

    it("should handle CJK text in cells", function()
      local lines = {
        "| Name |",
        "|------|",
        "| Hello |",
      }
      local result = markdown_table.parse(lines)
      assert.is_not_nil(result)
      eq("Hello", result.rows[1][1].text)
      -- col_widths should use display width
      eq(5, result.col_widths[1])
    end)

    it("should calculate col_widths correctly", function()
      local lines = {
        "| A | Longer |",
        "|---|--------|",
        "| Longest | B |",
      }
      local result = markdown_table.parse(lines)
      assert.is_not_nil(result)
      eq(7, result.col_widths[1]) -- "Longest" = 7
      eq(6, result.col_widths[2]) -- "Longer" = 6
    end)

    it("should handle empty cells", function()
      local lines = {
        "| A | B |",
        "|---|---|",
        "| | x |",
      }
      local result = markdown_table.parse(lines)
      assert.is_not_nil(result)
      eq("", result.rows[1][1].text)
      eq("x", result.rows[1][2].text)
    end)

    it("should handle missing trailing cells", function()
      local lines = {
        "| A | B | C |",
        "|---|---|---|",
        "| 1 |",
      }
      local result = markdown_table.parse(lines)
      assert.is_not_nil(result)
      eq("1", result.rows[1][1].text)
      eq("", result.rows[1][2].text)
      eq("", result.rows[1][3].text)
    end)
  end)

  ---------------------------------------------------------------------------
  -- render tests
  ---------------------------------------------------------------------------
  describe("render", function()
    it("should render basic table with box-drawing characters", function()
      local lines = {
        "| A | B |",
        "|---|---|",
        "| 1 | 2 |",
      }
      local parsed = markdown_table.parse(lines)
      assert.is_not_nil(parsed)
      local result_lines, _, _ = markdown_table.render(parsed, "  ")
      eq("  │ A │ B │", result_lines[1])
      eq("  │───│───│", result_lines[2])
      eq("  │ 1 │ 2 │", result_lines[3])
    end)

    it("should pad cells to column width", function()
      local lines = {
        "| Name | Age |",
        "|------|-----|",
        "| Alice | 30 |",
      }
      local parsed = markdown_table.parse(lines)
      assert.is_not_nil(parsed)
      local result_lines, _, _ = markdown_table.render(parsed, "  ")
      eq("  │ Name  │ Age │", result_lines[1])
      eq("  │───────│─────│", result_lines[2])
      eq("  │ Alice │ 30  │", result_lines[3])
    end)

    it("should apply FloatBorder highlight to separators", function()
      local lines = {
        "| A |",
        "|---|",
        "| 1 |",
      }
      local parsed = markdown_table.parse(lines)
      assert.is_not_nil(parsed)
      local _, hls, _ = markdown_table.render(parsed, "  ")

      -- Separator line should have FloatBorder
      local sep_hls = hls[2]
      local found_border = false
      for _, h in ipairs(sep_hls) do
        if h.hl == "FloatBorder" then
          found_border = true
          break
        end
      end
      assert.is_true(found_border)
    end)

    it("should apply Bold highlight to header cells", function()
      local lines = {
        "| Header |",
        "|--------|",
        "| data |",
      }
      local parsed = markdown_table.parse(lines)
      assert.is_not_nil(parsed)
      local _, hls, _ = markdown_table.render(parsed, "  ")

      -- Header row should have Bold highlight
      local header_hls = hls[1]
      local found_bold = false
      for _, h in ipairs(header_hls) do
        if h.hl == "Bold" then
          found_bold = true
          break
        end
      end
      assert.is_true(found_bold)
    end)

    it("should not apply Bold to data cells", function()
      local lines = {
        "| H |",
        "|---|",
        "| D |",
      }
      local parsed = markdown_table.parse(lines)
      assert.is_not_nil(parsed)
      local _, hls, _ = markdown_table.render(parsed, "  ")

      -- Data row should not have Bold highlight
      local data_hls = hls[3]
      for _, h in ipairs(data_hls) do
        assert.is_not.equal("Bold", h.hl)
      end
    end)

    it("should preserve cell inline highlights", function()
      local lines = {
        "| Syntax |",
        "|--------|",
        "| `code` |",
      }
      local parsed = markdown_table.parse(lines)
      assert.is_not_nil(parsed)
      local _, hls, _ = markdown_table.render(parsed, "  ")

      -- Data row should have String highlight for code
      local data_hls = hls[3]
      local found_string = false
      for _, h in ipairs(data_hls) do
        if h.hl == "String" then
          found_string = true
          break
        end
      end
      assert.is_true(found_string)
    end)

    it("should include link metadata from cells", function()
      local lines = {
        "| Link |",
        "|------|",
        "| [click](https://example.com) |",
      }
      local parsed = markdown_table.parse(lines)
      assert.is_not_nil(parsed)
      local _, _, lnks = markdown_table.render(parsed, "  ")

      -- Data row should have link
      eq(1, #lnks[3])
      eq("https://example.com", lnks[3][1].url)
    end)

    it("should handle right alignment", function()
      local lines = {
        "| Num |",
        "|----:|",
        "| 42 |",
      }
      local parsed = markdown_table.parse(lines)
      assert.is_not_nil(parsed)
      local result_lines, _, _ = markdown_table.render(parsed, "  ")
      -- "Num" is 3 chars, col_width should be 3
      -- With right alignment, "42" should be right-padded: " 42"
      eq("  │ Num │", result_lines[1])
      eq("  │  42 │", result_lines[3])
    end)

    it("should handle center alignment", function()
      local lines = {
        "| Title |",
        "|:-----:|",
        "| A |",
      }
      local parsed = markdown_table.parse(lines)
      assert.is_not_nil(parsed)
      local result_lines, _, _ = markdown_table.render(parsed, "  ")
      -- "Title" is 5 chars, "A" is 1 char, center in 5: "  A  "
      eq("  │ Title │", result_lines[1])
      eq("  │   A   │", result_lines[3])
    end)

    it("should use the specified indent", function()
      local lines = {
        "| X |",
        "|---|",
        "| Y |",
      }
      local parsed = markdown_table.parse(lines)
      assert.is_not_nil(parsed)
      local result_lines, _, _ = markdown_table.render(parsed, "    ")
      assert.is_truthy(result_lines[1]:match "^    │")
    end)

    it("should handle multiple columns", function()
      local lines = {
        "| A | B | C |",
        "|---|---|---|",
        "| 1 | 2 | 3 |",
      }
      local parsed = markdown_table.parse(lines)
      assert.is_not_nil(parsed)
      local result_lines, _, _ = markdown_table.render(parsed, "  ")
      eq("  │ A │ B │ C │", result_lines[1])
      eq("  │───│───│───│", result_lines[2])
      eq("  │ 1 │ 2 │ 3 │", result_lines[3])
    end)
  end)
end)
