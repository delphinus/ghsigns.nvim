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

  describe("Bare URLs", function()
    it("should keep short URLs as-is with highlight and link", function()
      local text, highlights, links = markdown.render("See https://example.com here")
      eq("See https://example.com here", text)
      local url_hl = nil
      for _, hl in ipairs(highlights) do
        if hl.hl == "Underlined" then
          url_hl = hl
          break
        end
      end
      assert.is_not_nil(url_hl)
      eq("https://example.com", text:sub(url_hl.col + 1, url_hl.end_col))
      eq(1, #links)
      eq("https://example.com", links[1].url)
    end)

    it("should truncate long URLs with ellipsis", function()
      local long_url = "https://github.com/very/long/path/to/some/resource/that/exceeds/width"
      local text, highlights, links = markdown.render("See " .. long_url)
      -- URL should be truncated
      assert.is_truthy(text:match "…")
      -- Link should have full URL
      eq(1, #links)
      eq(long_url, links[1].url)
      -- Truncated display should be at most 50 display cols
      local url_hl = nil
      for _, hl in ipairs(highlights) do
        if hl.hl == "Underlined" then
          url_hl = hl
          break
        end
      end
      assert.is_not_nil(url_hl)
      local display_url = text:sub(url_hl.col + 1, url_hl.end_col)
      assert.is_true(vim.fn.strdisplaywidth(display_url) <= 50)
    end)

    it("should not process URLs inside backticks", function()
      local text, highlights, links = markdown.render("Use `https://example.com` as example")
      -- After code marker processing, backticks are removed but URL should not be a link
      eq(0, #links)
    end)

    it("should strip trailing punctuation from URLs", function()
      local text, highlights, links = markdown.render("Visit https://example.com.")
      eq("Visit https://example.com.", text)
      eq(1, #links)
      eq("https://example.com", links[1].url)
      local url_hl = nil
      for _, hl in ipairs(highlights) do
        if hl.hl == "Underlined" then
          url_hl = hl
          break
        end
      end
      assert.is_not_nil(url_hl)
      eq("https://example.com", text:sub(url_hl.col + 1, url_hl.end_col))
    end)

    it("should handle multiple bare URLs", function()
      local text, highlights, links = markdown.render("See https://a.com and https://b.com")
      eq("See https://a.com and https://b.com", text)
      eq(2, #links)
      eq("https://a.com", links[1].url)
      eq("https://b.com", links[2].url)
    end)

    it("should correctly adjust prior link positions after truncation", function()
      local long_url = "https://github.com/very/long/path/to/some/resource/that/exceeds/width"
      local text, highlights, links = markdown.render("[click](https://a.com) and " .. long_url)
      -- "click" link from process_links, then bare URL
      eq(2, #links)
      eq("https://a.com", links[1].url)
      eq(long_url, links[2].url)
      -- Verify "click" position is correct in the output text
      eq("click", text:sub(links[1].col_start + 1, links[1].col_end))
    end)

    it("should handle http URLs", function()
      local text, highlights, links = markdown.render("See http://example.com here")
      eq("See http://example.com here", text)
      eq(1, #links)
      eq("http://example.com", links[1].url)
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

    it("should correctly highlight inline code after multiple consecutive spaces", function()
      local text, highlights = markdown.render("one of  `edit`, `tabedit`")
      -- Multiple spaces should be collapsed to one
      eq("one of edit, tabedit", text)
      local code_hls = {}
      for _, hl in ipairs(highlights) do
        if hl.hl == "String" then
          table.insert(code_hls, hl)
        end
      end
      eq(2, #code_hls)
      eq("edit", text:sub(code_hls[1].col + 1, code_hls[1].end_col))
      eq("tabedit", text:sub(code_hls[2].col + 1, code_hls[2].end_col))
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

  describe("Strikethrough", function()
    it("should remove ~~ markers from strikethrough text", function()
      local text, highlights = markdown.render("This is ~~removed~~ text")
      eq("This is removed text", text)
      local strike_hl = nil
      for _, hl in ipairs(highlights) do
        if hl.hl == "DiagnosticDeprecated" then
          strike_hl = hl
          break
        end
      end
      assert.is_not_nil(strike_hl)
      eq("removed", text:sub(strike_hl.col + 1, strike_hl.end_col))
    end)

    it("should handle multiple strikethrough segments", function()
      local text = markdown.render("~~first~~ and ~~second~~")
      eq("first and second", text)
    end)
  end)

  describe("Highlight markers", function()
    it("should remove == markers and add GhsignsHighlight", function()
      local text, highlights = markdown.render("This is ==highlighted== text")
      eq("This is highlighted text", text)
      local hl = nil
      for _, h in ipairs(highlights) do
        if h.hl == "GhsignsHighlight" then
          hl = h
          break
        end
      end
      assert.is_not_nil(hl)
      eq("highlighted", text:sub(hl.col + 1, hl.end_col))
    end)

    it("should handle multiple highlights in one line", function()
      local text, highlights = markdown.render("==foo== and ==bar==")
      eq("foo and bar", text)
      local hl_count = 0
      for _, h in ipairs(highlights) do
        if h.hl == "GhsignsHighlight" then
          hl_count = hl_count + 1
        end
      end
      eq(2, hl_count)
    end)

    it("should not match single = signs", function()
      local text, highlights = markdown.render("a = b = c")
      eq("a = b = c", text)
      local hl_count = 0
      for _, h in ipairs(highlights) do
        if h.hl == "GhsignsHighlight" then
          hl_count = hl_count + 1
        end
      end
      eq(0, hl_count)
    end)

    it("should work combined with bold", function()
      local text = markdown.render("**bold** and ==highlight==")
      eq("bold and highlight", text)
    end)
  end)

  describe("Inline comments", function()
    it("should remove inline comments", function()
      local text = markdown.render("visible %%hidden%% text")
      eq("visible  text", text)
    end)

    it("should handle %% without closing pair", function()
      local text = markdown.render("this has %% but no close")
      eq("this has %% but no close", text)
    end)

    it("should remove multiple inline comments", function()
      local text = markdown.render("a %%b%% c %%d%% e")
      eq("a  c  e", text)
    end)

    it("should not affect single %", function()
      local text = markdown.render("100% done")
      eq("100% done", text)
    end)
  end)

  describe("Wikilinks", function()
    it("should render simple wikilink", function()
      local text, highlights, links = markdown.render("See [[my page]]")
      eq("See my page", text)
      local hl = nil
      for _, h in ipairs(highlights) do
        if h.hl == "Underlined" then
          hl = h
          break
        end
      end
      assert.is_not_nil(hl)
      eq("my page", text:sub(hl.col + 1, hl.end_col))
      eq(1, #links)
      eq("obsidian://open?file=my page", links[1].url)
    end)

    it("should render wikilink with display text", function()
      local text = markdown.render("See [[target|shown text]]")
      eq("See shown text", text)
    end)

    it("should render wikilink with heading", function()
      local text = markdown.render("See [[page#section]]")
      eq("See page > section", text)
    end)

    it("should render wikilink with heading and display text", function()
      local text = markdown.render("See [[page#section|custom]]")
      eq("See custom", text)
    end)

    it("should render same-file heading link", function()
      local text = markdown.render("See [[#heading]]")
      eq("See heading", text)
    end)

    it("should not match single brackets", function()
      local text = markdown.render("array[0] and list[1]")
      eq("array[0] and list[1]", text)
    end)

    it("should handle unclosed wikilink", function()
      local text = markdown.render("See [[unclosed")
      eq("See [[unclosed", text)
    end)

    it("should handle multiple wikilinks", function()
      local text, _, links = markdown.render("See [[page1]] and [[page2]]")
      eq("See page1 and page2", text)
      eq(2, #links)
    end)
  end)

  describe("Embeds", function()
    it("should render note embed as link", function()
      local text, highlights, links = markdown.render("![[my-note]]")
      eq("📎 my-note", text)
      eq(1, #links)
      eq("obsidian://open?file=my-note", links[1].url)
    end)

    it("should render image embed with image icon", function()
      local text = markdown.render("![[photo.png]]")
      eq("🖼 photo.png", text)
    end)

    it("should render various image extensions", function()
      for _, ext in ipairs { "jpg", "jpeg", "gif", "svg", "webp", "bmp" } do
        local text = markdown.render("![[img." .. ext .. "]]")
        assert.is_truthy(text:match "🖼", "Expected image icon for ." .. ext)
      end
    end)

    it("should distinguish embed from standard image syntax", function()
      local text1 = markdown.render("![[embed]]")
      local text2 = markdown.render("![alt](url)")
      assert.not_equals(text1, text2)
    end)

    it("should handle unclosed embed", function()
      local text = markdown.render("![[unclosed")
      eq("![[unclosed", text)
    end)

    it("should handle embed with heading reference", function()
      local text = markdown.render("![[note#section]]")
      eq("📎 note", text)
    end)

    it("should handle embed with pipe display text", function()
      local text = markdown.render("![[note|custom display]]")
      eq("📎 note", text)
    end)
  end)

  describe("Blockquote", function()
    it("should replace > prefix with visual bar", function()
      local text, highlights, links, special_type = markdown.render("> Quoted text")
      eq("│ Quoted text", text)
      eq("blockquote", special_type)
      eq({ col = 0, end_col = #"│ ", hl = "FloatBorder" }, highlights[1])
    end)

    it("should handle nested blockquotes", function()
      local text, highlights, links, special_type = markdown.render(">> Nested quote")
      eq("│ │ Nested quote", text)
      eq("blockquote", special_type)
      eq({ col = 0, end_col = #"│ │ ", hl = "FloatBorder" }, highlights[1])
    end)

    it("should process inline markdown inside blockquotes", function()
      local text, highlights = markdown.render("> This is **bold** text")
      eq("│ This is bold text", text)
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

    it("should handle empty blockquote lines", function()
      local text, highlights, links, special_type = markdown.render(">")
      eq("│ ", text)
      eq("blockquote", special_type)
    end)
  end)

  describe("GitHub Alerts", function()
    it("should convert > [!NOTE] to icon + label", function()
      local text, highlights, links, special_type, list_marker, alert_type = markdown.render("> [!NOTE]")
      eq("│ 󰋽 Note", text)
      eq("blockquote", special_type)
      eq("NOTE", alert_type)
      eq({ col = 0, end_col = #"│ ", hl = "FloatBorder" }, highlights[1])
    end)

    it("should return correct alert_type for all 5 types", function()
      local types = {
        { input = "> [!NOTE]", label = "󰋽 Note", alert = "NOTE" },
        { input = "> [!TIP]", label = "󰌶 Tip", alert = "TIP" },
        { input = "> [!IMPORTANT]", label = "󰅾 Important", alert = "IMPORTANT" },
        { input = "> [!WARNING]", label = "󰀪 Warning", alert = "WARNING" },
        { input = "> [!CAUTION]", label = "󰳦 Caution", alert = "CAUTION" },
      }
      for _, t in ipairs(types) do
        local text, _, _, _, _, alert_type = markdown.render(t.input)
        eq("│ " .. t.label, text)
        eq(t.alert, alert_type)
      end
    end)

    it("should treat > [!UNKNOWN] as normal blockquote", function()
      local text, highlights, links, special_type, _, alert_type = markdown.render("> [!UNKNOWN]")
      eq("│ [!UNKNOWN]", text)
      eq("blockquote", special_type)
      assert.is_nil(alert_type)
    end)

    it("should render callout with custom title", function()
      local text, highlights, links, special_type, _, alert_type = markdown.render("> [!NOTE] My Custom Title")
      eq("│ 󰋽 My Custom Title", text)
      eq("blockquote", special_type)
      eq("NOTE", alert_type)
    end)

    it("should render Obsidian-specific alert types", function()
      local obsidian_types = {
        { input = "> [!BUG]", label = "󱈰 Bug", alert = "BUG" },
        { input = "> [!EXAMPLE]", label = "󰆹 Example", alert = "EXAMPLE" },
        { input = "> [!QUOTE]", label = "󱗝 Quote", alert = "QUOTE" },
        { input = "> [!TODO]", label = "󰄬 Todo", alert = "TODO" },
        { input = "> [!SUCCESS]", label = "󰄬 Success", alert = "SUCCESS" },
        { input = "> [!QUESTION]", label = "󱈅 Question", alert = "QUESTION" },
        { input = "> [!FAILURE]", label = "󰅙 Failure", alert = "FAILURE" },
        { input = "> [!DANGER]", label = "󱐌 Danger", alert = "DANGER" },
        { input = "> [!ABSTRACT]", label = "󱉫 Abstract", alert = "ABSTRACT" },
      }
      for _, t in ipairs(obsidian_types) do
        local text, _, _, _, _, alert_type = markdown.render(t.input)
        eq("│ " .. t.label, text)
        eq(t.alert, alert_type)
      end
    end)

    it("should resolve alias types to parent style", function()
      local aliases = {
        { input = "> [!TLDR]", label = "󱉫 TL;DR", style = "ABSTRACT" },
        { input = "> [!INFO]", label = "󰋽 Info", style = "NOTE" },
        { input = "> [!DONE]", label = "󰄬 Done", style = "SUCCESS" },
        { input = "> [!HELP]", label = "󱈅 Help", style = "QUESTION" },
        { input = "> [!FAIL]", label = "󰅙 Fail", style = "FAILURE" },
        { input = "> [!ERROR]", label = "󱐌 Error", style = "DANGER" },
        { input = "> [!CITE]", label = "󱗝 Cite", style = "QUOTE" },
      }
      for _, t in ipairs(aliases) do
        local text, _, _, _, _, alert_type = markdown.render(t.input)
        eq("│ " .. t.label, text)
        eq(t.style, alert_type)
      end
    end)

    it("should match case-insensitively", function()
      local text, _, _, _, _, alert_type = markdown.render("> [!note]")
      eq("│ 󰋽 Note", text)
      eq("NOTE", alert_type)
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

    it("should correctly position link highlight after bold and code markers are removed", function()
      local text, highlights, links =
        markdown.render("**bold**, `inline code`, [links](https://example.com), and headings")
      eq("bold, inline code, links, and headings", text)

      -- Find the Underlined highlight for "links"
      local link_hl = nil
      for _, hl in ipairs(highlights) do
        if hl.hl == "Underlined" then
          link_hl = hl
          break
        end
      end
      assert.is_not_nil(link_hl)
      eq("links", text:sub(link_hl.col + 1, link_hl.end_col))

      -- Also verify link metadata position matches
      eq(1, #links)
      eq("links", text:sub(links[1].col_start + 1, links[1].col_end))
    end)
  end)

  describe("Autolink references", function()
    local autolinks = {
      { key_prefix = "JIRA-", url_template = "https://jira.example.com/browse/JIRA-<num>" },
    }

    it("should make JIRA-123 clickable when autolinks are provided", function()
      local text, highlights, links = markdown.render("See JIRA-123 for details", nil, autolinks)
      eq("See JIRA-123 for details", text)
      eq(1, #links)
      eq({
        col_start = 4,
        col_end = 12,
        url = "https://jira.example.com/browse/JIRA-123",
      }, links[1])
    end)

    it("should not make JIRA-123 clickable inside backticks", function()
      local text, highlights, links = markdown.render("Use `JIRA-123` as example", nil, autolinks)
      eq("Use JIRA-123 as example", text)
      eq(0, #links)
    end)

    it("should handle multiple autolink matches", function()
      local text, highlights, links = markdown.render("See JIRA-123 and JIRA-456", nil, autolinks)
      eq("See JIRA-123 and JIRA-456", text)
      eq(2, #links)
      eq("https://jira.example.com/browse/JIRA-123", links[1].url)
      eq("https://jira.example.com/browse/JIRA-456", links[2].url)
    end)

    it("should handle multiple autolink patterns", function()
      local multi_autolinks = {
        { key_prefix = "JIRA-", url_template = "https://jira.example.com/browse/JIRA-<num>" },
        { key_prefix = "GH-", url_template = "https://github.example.com/issues/GH-<num>" },
      }
      local text, highlights, links = markdown.render("See JIRA-123 and GH-456", nil, multi_autolinks)
      eq("See JIRA-123 and GH-456", text)
      eq(2, #links)
      eq("https://jira.example.com/browse/JIRA-123", links[1].url)
      eq("https://github.example.com/issues/GH-456", links[2].url)
    end)

    it("should handle is_alphanumeric flag", function()
      local alpha_autolinks = {
        { key_prefix = "TICKET-", url_template = "https://example.com/ticket/TICKET-<num>", is_alphanumeric = true },
      }
      local text, highlights, links = markdown.render("See TICKET-abc123 here", nil, alpha_autolinks)
      eq("See TICKET-abc123 here", text)
      eq(1, #links)
      eq("https://example.com/ticket/TICKET-abc123", links[1].url)
    end)

    it("should match only digits when is_alphanumeric is false", function()
      local digit_autolinks = {
        { key_prefix = "BUG-", url_template = "https://example.com/bug/BUG-<num>" },
      }
      local text, highlights, links = markdown.render("See BUG-123abc here", nil, digit_autolinks)
      eq("See BUG-123abc here", text)
      eq(1, #links)
      -- Should only match the digits portion
      eq("https://example.com/bug/BUG-123", links[1].url)
      eq("BUG-123", text:sub(links[1].col_start + 1, links[1].col_end))
    end)

    it("should not break when autolinks is nil", function()
      local text, highlights, links = markdown.render("See JIRA-123 here", nil, nil)
      eq("See JIRA-123 here", text)
      eq(0, #links)
    end)

    it("should not break when autolinks is empty", function()
      local text, highlights, links = markdown.render("See JIRA-123 here", nil, {})
      eq("See JIRA-123 here", text)
      eq(0, #links)
    end)

    it("should add Underlined highlight for autolink matches", function()
      local text, highlights, links = markdown.render("Fix JIRA-42", nil, autolinks)
      eq("Fix JIRA-42", text)
      local underlined_hl = nil
      for _, hl in ipairs(highlights) do
        if hl.hl == "Underlined" then
          underlined_hl = hl
          break
        end
      end
      assert.is_not_nil(underlined_hl)
      eq("JIRA-42", text:sub(underlined_hl.col + 1, underlined_hl.end_col))
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
