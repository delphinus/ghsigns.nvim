local eq = assert.are.same

describe("Markdown rendering", function()
  local markdown

  before_each(function()
    -- Load the markdown module
    markdown = require "ghsigns.markdown"
  end)

  describe("Headings", function()
    it("should remove # prefix from heading", function()
      local text, highlights, links, special_type = markdown.render("# Heading")
      eq("Heading", text)
      eq("heading", special_type)
      eq(1, #highlights)
      eq({ col = 0, end_col = 7, hl = "Title" }, highlights[1])
    end)

    it("should remove ## prefix from h2", function()
      local text, highlights, links, special_type = markdown.render("## Heading 2")
      eq("Heading 2", text)
      eq("heading", special_type)
    end)

    it("should remove ### prefix from h3", function()
      local text, highlights, links, special_type = markdown.render("### Heading 3")
      eq("Heading 3", text)
      eq("heading", special_type)
    end)
  end)

  describe("Links", function()
    it("should convert [text](url) to text with highlight", function()
      local text, highlights, links = markdown.render("[click here](https://example.com)")
      eq("click here", text)
      eq(1, #highlights)
      eq({ col = 0, end_col = 10, hl = "Underlined" }, highlights[1])
      eq(1, #links)
      eq({
        col_start = 0,
        col_end = 10,
        url = "https://example.com",
      }, links[1])
    end)

    it("should handle multiple links", function()
      local text, highlights, links = markdown.render("Check [link1](url1) and [link2](url2)")
      eq("Check link1 and link2", text)
      eq(2, #links)
    end)
  end)

  describe("Bold text", function()
    it("should remove ** markers from bold text", function()
      local text, highlights = markdown.render("This is **bold** text")
      eq("This is bold text", text)
      -- Should have one highlight for bold
      local bold_hl = nil
      for _, hl in ipairs(highlights) do
        if hl.hl == "Bold" then
          bold_hl = hl
          break
        end
      end
      assert.is_not_nil(bold_hl)
      eq("bold", text:sub(bold_hl.col + 1, bold_hl.end_col))
    end)

    it("should handle multiple bold segments", function()
      local text = markdown.render("**first** and **second**")
      eq("first and second", text)
    end)
  end)

  describe("Code", function()
    it("should remove backticks from inline code", function()
      local text, highlights = markdown.render("Use `code` here")
      eq("Use code here", text)
      -- Should have one highlight for code
      local code_hl = nil
      for _, hl in ipairs(highlights) do
        if hl.hl == "String" then
          code_hl = hl
          break
        end
      end
      assert.is_not_nil(code_hl)
      eq("code", text:sub(code_hl.col + 1, code_hl.end_col))
    end)

    it("should handle multiple code segments", function()
      local text = markdown.render("Run `npm install` then `npm start`")
      eq("Run npm install then npm start", text)
    end)
  end)

  describe("Issue references", function()
    it("should make #123 clickable when repo_base_url is provided", function()
      local text, highlights, links = markdown.render("See #123 for details", "https://github.com/owner/repo")
      eq("See #123 for details", text)
      eq(1, #links)
      eq({
        col_start = 4,
        col_end = 8,
        url = "https://github.com/owner/repo/issues/123",
      }, links[1])
    end)

    it("should not make #123 clickable inside backticks", function()
      local text, highlights, links = markdown.render("Use `#123` as example", "https://github.com/owner/repo")
      eq("Use #123 as example", text)
      -- Should have code highlight but no link
      eq(0, #links)
    end)

    it("should handle multiple issue references", function()
      local text, highlights, links = markdown.render("See #123 and #456", "https://github.com/owner/repo")
      eq("See #123 and #456", text)
      eq(2, #links)
    end)
  end)

  describe("List items", function()
    it("should keep - marker for unordered list", function()
      local text, highlights = markdown.render("- Item one")
      eq("- Item one", text)
      -- First highlight should be for the list marker
      eq({ col = 0, end_col = 2, hl = "Special" }, highlights[1])
    end)

    it("should keep * marker for unordered list", function()
      local text = markdown.render("* Item two")
      eq("* Item two", text)
    end)

    it("should keep numbered markers for ordered list", function()
      local text, highlights = markdown.render("1. First item")
      eq("1. First item", text)
      eq({ col = 0, end_col = 3, hl = "Special" }, highlights[1])
    end)
  end)

  describe("Combined markdown", function()
    it("should handle links and bold together", function()
      local text = markdown.render("**Important**: See [docs](https://example.com)")
      eq("Important: See docs", text)
    end)

    it("should handle code and issue refs together", function()
      local text, highlights, links = markdown.render("Run `npm test` for #123", "https://github.com/owner/repo")
      eq("Run npm test for #123", text)
      eq(1, #links)
    end)
  end)

  describe("CR character handling", function()
    it("should remove CR characters", function()
      local text = markdown.render("Line with\r\nCRLF")
      eq("Line with\nCRLF", text)
    end)

    it("should remove standalone CR", function()
      local text = markdown.render("Line with\rCR")
      eq("Line withCR", text)
    end)
  end)
end)
