local eq = assert.are.same

describe("PR content rendering", function()
  local lualine

  before_each(function()
    package.loaded["ghsigns.lualine"] = nil
    lualine = require "ghsigns.lualine"
  end)

  after_each(function()
    package.loaded["ghsigns.lualine"] = nil
  end)

  -- Helper to build content with a body using minimal PR fields
  local function build_with_body(body, url)
    return lualine.build_pr_content {
      number = 1,
      title = "T",
      body = body,
      url = url,
    }
  end

  -- Helper to find highlight groups for a specific line index
  local function hl_for_line(content, line_idx)
    for _, hl in ipairs(content.highlights) do
      if hl.line == line_idx then
        return hl.groups
      end
    end
    return nil
  end

  -- The minimal header (no body) always produces these lines:
  -- [0] "#1 T"
  -- [1] ""
  -- [2] "Changes: +0 -0 (0 files, 0 commits)"
  -- [3] ""
  -- [4] ""
  -- [5] close button
  -- Body content lines start at index 6 when body is present (after Description: at 5)

  ---------------------------------------------------------------------------
  -- Group 1: Header section (no body)
  ---------------------------------------------------------------------------
  describe("Header section", function()
    it("should format title line with Number and GhsignsPrTitle highlights", function()
      local c = lualine.build_pr_content { number = 42, title = "Test PR" }
      eq("#42 Test PR", c.lines[1])
      eq(0, c.title_line)
      eq("#42 Test PR", c.title_text)
      eq({
        { col = 0, end_col = 3, hl = "Number" },
        { col = 4, end_col = -1, hl = "GhsignsPrTitle" },
      }, hl_for_line(c, 0))
    end)

    it("should show [DRAFT] indicator with WarningMsg highlight", function()
      local c = lualine.build_pr_content {
        number = 99,
        title = "Draft Feature",
        isDraft = true,
      }
      eq("#99 [DRAFT] Draft Feature", c.lines[1])
      eq({
        { col = 0, end_col = 3, hl = "Number" },
        { col = 4, end_col = 11, hl = "WarningMsg" },
        { col = 12, end_col = -1, hl = "GhsignsPrTitle" },
      }, hl_for_line(c, 0))
    end)

    it("should show branch info with correct highlights", function()
      local c = lualine.build_pr_content {
        number = 1,
        title = "T",
        baseRefName = "main",
        headRefName = "feature",
      }
      eq("main ← feature", c.lines[2])
      eq({
        { col = 0, end_col = 4, hl = "String" },
        { col = 5, end_col = 7, hl = "Operator" },
        { col = 8, end_col = -1, hl = "Identifier" },
      }, hl_for_line(c, 1))
    end)

    it("should show Author with String highlight", function()
      local c = lualine.build_pr_content {
        number = 1,
        title = "T",
        author = { name = "Author" },
      }
      -- Author line is after empty line (line index 2 when no branches)
      local author_line = nil
      for i, l in ipairs(c.lines) do
        if l:match "^Author:" then
          author_line = i
          break
        end
      end
      assert.is_not_nil(author_line)
      eq("Author: Author", c.lines[author_line])
      eq({
        { col = 0, end_col = 6, hl = "Comment" },
        { col = 8, end_col = 14, hl = "String" },
      }, hl_for_line(c, author_line - 1))
    end)

    it("should fall back to login when author name is empty", function()
      local c = lualine.build_pr_content {
        number = 1,
        title = "T",
        author = { login = "user123", name = "" },
      }
      local found = false
      for _, l in ipairs(c.lines) do
        if l == "Author: user123" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("should show State with DiagnosticOk for OPEN", function()
      local c = lualine.build_pr_content {
        number = 1,
        title = "T",
        state = "OPEN",
      }
      local state_line = nil
      for i, l in ipairs(c.lines) do
        if l:match "^State:" then
          state_line = i
          break
        end
      end
      assert.is_not_nil(state_line)
      eq("State: OPEN", c.lines[state_line])
      eq({
        { col = 0, end_col = 5, hl = "Comment" },
        { col = 7, end_col = 11, hl = "DiagnosticOk" },
      }, hl_for_line(c, state_line - 1))
    end)

    it("should show State with DiagnosticError for MERGED", function()
      local c = lualine.build_pr_content {
        number = 1,
        title = "T",
        state = "MERGED",
      }
      local state_line = nil
      for i, l in ipairs(c.lines) do
        if l:match "^State:" then
          state_line = i
          break
        end
      end
      assert.is_not_nil(state_line)
      eq({
        { col = 0, end_col = 5, hl = "Comment" },
        { col = 7, end_col = 13, hl = "DiagnosticError" },
      }, hl_for_line(c, state_line - 1))
    end)

    it("should show Changes with DiffAdd and DiffDelete highlights", function()
      local c = lualine.build_pr_content {
        number = 1,
        title = "T",
        additions = 10,
        deletions = 5,
        changedFiles = 3,
        commits = { nodes = { {}, {} } },
      }
      local changes_line = nil
      for i, l in ipairs(c.lines) do
        if l:match "^Changes:" then
          changes_line = i
          break
        end
      end
      assert.is_not_nil(changes_line)
      eq("Changes: +10 -5 (3 files, 2 commits)", c.lines[changes_line])
      eq({
        { col = 0, end_col = 8, hl = "Comment" },
        { col = 9, end_col = 12, hl = "DiffAdd" },
        { col = 13, end_col = 15, hl = "DiffDelete" },
        { col = 16, end_col = -1, hl = "Comment" },
      }, hl_for_line(c, changes_line - 1))
    end)

    it("should show date lines", function()
      local c = lualine.build_pr_content {
        number = 1,
        title = "T",
        createdAt = "2024-01-01T00:00:00Z",
        updatedAt = "2024-01-02T00:00:00Z",
        mergedAt = "2024-01-03T00:00:00Z",
      }
      local found_created, found_updated, found_merged = false, false, false
      for _, l in ipairs(c.lines) do
        if l == "Created: 2024-01-01T00:00:00Z" then
          found_created = true
        end
        if l == "Updated: 2024-01-02T00:00:00Z" then
          found_updated = true
        end
        if l == "Merged: 2024-01-03T00:00:00Z" then
          found_merged = true
        end
      end
      assert.is_true(found_created)
      assert.is_true(found_updated)
      assert.is_true(found_merged)
    end)

    it("should show Labels with Tag highlight", function()
      local c = lualine.build_pr_content {
        number = 1,
        title = "T",
        labels = { nodes = { { name = "bug" }, { name = "enhancement" } } },
      }
      local labels_line = nil
      for i, l in ipairs(c.lines) do
        if l:match "^Labels:" then
          labels_line = i
          break
        end
      end
      assert.is_not_nil(labels_line)
      eq("Labels: bug, enhancement", c.lines[labels_line])
      eq({
        { col = 0, end_col = 6, hl = "Comment" },
        { col = 8, end_col = 24, hl = "Tag" },
      }, hl_for_line(c, labels_line - 1))
    end)

    it("should show Review Decision with correct highlights", function()
      local c = lualine.build_pr_content {
        number = 1,
        title = "T",
        reviewDecision = "APPROVED",
      }
      local review_line = nil
      for i, l in ipairs(c.lines) do
        if l:match "^Review:" then
          review_line = i
          break
        end
      end
      assert.is_not_nil(review_line)
      eq("Review: APPROVED", c.lines[review_line])
      eq({
        { col = 0, end_col = 6, hl = "Comment" },
        { col = 8, end_col = 16, hl = "DiagnosticOk" },
      }, hl_for_line(c, review_line - 1))
    end)

    it("should show full header with all fields", function()
      local c = lualine.build_pr_content {
        number = 99,
        title = "Draft Feature",
        isDraft = true,
        baseRefName = "main",
        headRefName = "feature",
        state = "OPEN",
        author = { name = "Author" },
        additions = 10,
        deletions = 5,
        changedFiles = 3,
        commits = { nodes = { {}, {} } },
        createdAt = "2024-01-01T00:00:00Z",
        updatedAt = "2024-01-02T00:00:00Z",
        reviewDecision = "APPROVED",
        labels = { nodes = { { name = "bug" }, { name = "enhancement" } } },
        mergeable = "MERGEABLE",
      }
      eq({
        "#99 [DRAFT] Draft Feature",
        "main ← feature",
        "",
        "Author: Author",
        "State: OPEN",
        "Review: APPROVED",
        "Mergeable: MERGEABLE",
        "Changes: +10 -5 (3 files, 2 commits)",
        "Labels: bug, enhancement",
        "",
        "Created: 2024-01-01T00:00:00Z",
        "Updated: 2024-01-02T00:00:00Z",
        "",
        "✕ Click here to close (or press q/Esc/Enter)",
      }, c.lines)
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 2: Body rendering (individual Markdown features)
  ---------------------------------------------------------------------------
  describe("Body rendering", function()
    it("should render plain text with 2-space indent", function()
      local c = build_with_body "Hello world"
      eq("  Hello world", c.lines[7])
    end)

    it("should render headings with Title highlight", function()
      local c = build_with_body "## Section Title"
      eq("  Section Title", c.lines[7])
      eq({
        { col = 2, end_col = 15, hl = "Title" },
      }, hl_for_line(c, 6))
    end)

    it("should render **bold** with Bold highlight", function()
      local c = build_with_body "This is **bold** text"
      eq("  This is bold text", c.lines[7])
      eq({
        { col = 10, end_col = 14, hl = "Bold" },
      }, hl_for_line(c, 6))
    end)

    it("should render `inline code` with String highlight", function()
      local c = build_with_body "Use `code` here"
      eq("  Use code here", c.lines[7])
      eq({
        { col = 6, end_col = 10, hl = "String" },
      }, hl_for_line(c, 6))
    end)

    it("should render [links](url) with Underlined highlight and link_metadata", function()
      local c = build_with_body "[click here](https://example.com)"
      eq("  click here", c.lines[7])
      eq({
        { col = 2, end_col = 12, hl = "Underlined" },
      }, hl_for_line(c, 6))
      eq(1, #c.link_metadata)
      eq({
        line = 6,
        col_start = 2,
        col_end = 12,
        url = "https://example.com",
      }, c.link_metadata[1])
    end)

    it("should render ~~strikethrough~~ with DiagnosticDeprecated highlight", function()
      local c = build_with_body "This is ~~removed~~ text"
      eq("  This is removed text", c.lines[7])
      eq({
        { col = 10, end_col = 17, hl = "DiagnosticDeprecated" },
      }, hl_for_line(c, 6))
    end)

    it("should render dash list items with Special highlight", function()
      local c = build_with_body "- Item one"
      eq("  - Item one", c.lines[7])
      eq({
        { col = 2, end_col = 4, hl = "Special" },
      }, hl_for_line(c, 6))
    end)

    it("should render numbered list items with Special highlight", function()
      local c = build_with_body "1. First item"
      eq("  1. First item", c.lines[7])
      eq({
        { col = 2, end_col = 5, hl = "Special" },
      }, hl_for_line(c, 6))
    end)

    it("should render code blocks with Comment/String highlights", function()
      local c = build_with_body "```lua\nlocal x = 1\n```"
      eq("  ```lua", c.lines[7])
      eq("  local x = 1", c.lines[8])
      eq("  ```", c.lines[9])
      -- Code block delimiters get Comment highlight
      eq({ { col = 0, end_col = -1, hl = "Comment" } }, hl_for_line(c, 6))
      -- Code block content gets String highlight
      eq({ { col = 0, end_col = -1, hl = "String" } }, hl_for_line(c, 7))
      -- Closing delimiter gets Comment highlight
      eq({ { col = 0, end_col = -1, hl = "Comment" } }, hl_for_line(c, 8))
    end)

    it("should render blockquote with FloatBorder highlight", function()
      local c = build_with_body "> Quoted text"
      eq("  │ Quoted text", c.lines[7])
      eq({
        { col = 2, end_col = 6, hl = "FloatBorder" },
      }, hl_for_line(c, 6))
    end)

    it("should render nested blockquotes", function()
      local c = build_with_body ">> Nested quote"
      eq("  │ │ Nested quote", c.lines[7])
      eq({
        { col = 2, end_col = 10, hl = "FloatBorder" },
      }, hl_for_line(c, 6))
    end)

    it("should render inline markdown inside blockquotes", function()
      local c = build_with_body "> This has **bold** and `code`"
      eq("  │ This has bold and code", c.lines[7])
      local groups = hl_for_line(c, 6)
      assert.is_not_nil(groups)
      eq({ col = 2, end_col = 6, hl = "FloatBorder" }, groups[1])
      eq({ col = 15, end_col = 19, hl = "Bold" }, groups[2])
      eq({ col = 24, end_col = 28, hl = "String" }, groups[3])
    end)

    it("should make issue references clickable with link_metadata", function()
      local c = build_with_body("See #123 for details", "https://github.com/owner/repo/pull/1")
      eq("  See #123 for details", c.lines[7])
      eq({
        { col = 6, end_col = 10, hl = "Underlined" },
      }, hl_for_line(c, 6))
      eq(1, #c.link_metadata)
      eq({
        line = 6,
        col_start = 6,
        col_end = 10,
        url = "https://github.com/owner/repo/issues/123",
      }, c.link_metadata[1])
    end)

    it("should remove HTML comments", function()
      local c = build_with_body "Before<!-- comment -->After"
      eq("  BeforeAfter", c.lines[7])
    end)

    it("should remove HTML tags", function()
      local c = build_with_body "Before<br>After"
      eq("  BeforeAfter", c.lines[7])
    end)

    it("should compress consecutive blank lines", function()
      local c = build_with_body "Line 1\n\n\n\nLine 2"
      eq("  Line 1", c.lines[7])
      eq("  ", c.lines[8])
      eq("  Line 2", c.lines[9])
      -- Should not have extra blank lines between
      eq(11, #c.lines) -- header(6) + 3 body lines + empty + close
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 3: Line wrapping
  ---------------------------------------------------------------------------
  describe("Line wrapping", function()
    it("should wrap lines exceeding 80 characters", function()
      local long = "This is a very long line that should be wrapped because it exceeds the maximum width of eighty characters in the display window"
      local c = build_with_body(long)
      eq("  This is a very long line that should be wrapped because it exceeds the maximum", c.lines[7])
      eq("  width of eighty characters in the display window", c.lines[8])
    end)

    it("should preserve highlight positions after wrapping", function()
      -- Bold text that spans across a wrap boundary
      local long = "This is a very long line with **bold text** that should be wrapped because it exceeds the maximum width limit"
      local c = build_with_body(long)
      -- The bold text "bold text" should be highlighted correctly
      local found_bold = false
      for _, hl in ipairs(c.highlights) do
        for _, g in ipairs(hl.groups) do
          if g.hl == "Bold" then
            -- Verify the bold highlight exists on a valid line
            local line_text = c.lines[hl.line + 1]
            assert.is_not_nil(line_text)
            found_bold = true
          end
        end
      end
      assert.is_true(found_bold, "Bold highlight should exist after wrapping")
    end)

    it("should preserve link_metadata positions after wrapping", function()
      local long = "Check out this very important and rather long description before the [documentation link](https://example.com/docs)"
      local c = build_with_body(long)
      -- The link should be in link_metadata with correct positions
      eq(1, #c.link_metadata)
      local link = c.link_metadata[1]
      -- Verify the link text is at the reported position
      local line_text = c.lines[link.line + 1]
      eq("documentation link", line_text:sub(link.col_start + 1, link.col_end))
    end)

    it("should maintain blockquote prefix on wrapped lines", function()
      local long_quote = "> This is a very long blockquote line that should be wrapped because it exceeds the maximum width of eighty characters"
      local c = build_with_body(long_quote)
      eq(
        "  │ This is a very long blockquote line that should be wrapped because it exceeds",
        c.lines[7]
      )
      eq("  │ the maximum width of eighty characters", c.lines[8])
      -- First line gets FloatBorder from markdown.render
      eq({ { col = 2, end_col = 6, hl = "FloatBorder" } }, hl_for_line(c, 6))
      -- Continuation line gets FloatBorder for the prefix
      eq({ { col = 2, end_col = 6, hl = "FloatBorder" } }, hl_for_line(c, 7))
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 4: Truncation
  ---------------------------------------------------------------------------
  describe("Truncation", function()
    it("should show truncation message after 15 body lines", function()
      local body_lines = {}
      for i = 1, 20 do
        body_lines[i] = "Line " .. i
      end
      local c = build_with_body(table.concat(body_lines, "\n"))
      -- Should show 15 body lines then truncation
      eq("  Line 15", c.lines[21])
      eq("  ... (truncated)", c.lines[22])
      -- Truncation line has Comment highlight
      eq({ { col = 0, end_col = -1, hl = "Comment" } }, hl_for_line(c, 21))
      -- Line 16 and beyond should not be present
      assert.is_nil(c.lines[23]:match "Line 16")
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 5: PR #4 full rendering (integration test)
  ---------------------------------------------------------------------------
  describe("PR #4 full rendering", function()
    local pr4_content

    before_each(function()
      -- stylua: ignore start
      local body = "## Summary\n\nThis PR adds two enhancements to **ghsigns.nvim**:\n\n- Add `~~strikethrough~~` rendering support to the markdown module\n- Introduce cache utility methods (`clear`, `invalidate`, `size`) for better cache lifecycle management\n\n## Motivation\n\n> Currently, the markdown renderer handles **bold**, `inline code`, [links](https://example.com), and headings \xE2\x80\x94 but ~~it does not support strikethrough~~. GitHub-flavored Markdown uses `~~text~~` extensively in PR descriptions, so this is a useful addition.\n>\n> Additionally, the `Cache` class only supported `get` and `set`. There was no way to:\n> 1. Clear the entire cache\n> 2. Invalidate a specific entry\n> 3. Query how many entries are cached\n\n## Changes\n\n### 1. Markdown: Strikethrough support\n\nAdded `~~text~~` parsing in `lua/ghsigns/markdown.lua`:\n\n```lua\n-- Strikethrough ~~text~~ - remove markers\nlocal s, e = rendered_text:find(\"~~([^~]+)~~\", i)\nif s == i then\n  local content = rendered_text:match(\"~~([^~]+)~~\", i)\n  -- Apply DiagnosticDeprecated highlight (renders as strikethrough)\nend\n```\n\n| Feature | Syntax | Rendered as | Highlight Group |\n|---------|--------|-------------|-----------------|\n| Bold | `**text**` | **text** | `Bold` |\n| Code | `` `text` `` | `text` | `String` |\n| ~~Strikethrough~~ | `~~text~~` | ~~text~~ | `DiagnosticDeprecated` |\n| Link | `[text](url)` | [text](url) | `Underlined` |\n\n### 2. Cache: Management methods\n\nThree new methods added to `lua/ghsigns/cache.lua`:\n\n- **`Cache:clear()`** \xE2\x80\x94 Wipe all cached PR data\n- **`Cache:invalidate(git_info)`** \xE2\x80\x94 Remove a *specific* entry\n- **`Cache:size()`** \xE2\x80\x94 Return the number of cached entries\n\n### 3. Tests\n\nNew test cases in `tests/markdown_spec.lua`:\n\n- [x] Single strikethrough segment: `~~removed~~`\n- [x] Multiple strikethrough segments: `~~first~~ and ~~second~~`\n- [x] Correct highlight group assignment (`DiagnosticDeprecated`)\n- [x] Correct text extraction after marker removal\n\n## How to test\n\n```bash\n# Run all tests\nmake test\n\n# Run markdown tests only\nmake test-markdown\n```\n\n<details>\n<summary>Test output (click to expand)</summary>\n\nAll 21 tests pass:\n- Headings: 3 tests\n- Links: 2 tests\n- Bold text: 2 tests\n- Code: 2 tests\n- Issue references: 3 tests\n- List items: 3 tests\n- **Strikethrough: 2 tests** \xE2\x86\x90 NEW\n- Combined markdown: 2 tests\n- CR character handling: 2 tests\n\n</details>\n\n---\n\n> [!NOTE]\n> The `DiagnosticDeprecated` highlight group is built into Neovim (>= 0.9.0) and typically renders as strikethrough text, which makes it a natural fit for `~~text~~`.\n\n## Related\n\n- Closes #0 *(demo \xE2\x80\x94 no real issue)*\n- See also: [GitHub Flavored Markdown Spec \xE2\x80\x94 Strikethrough](https://github.github.com/gfm/#strikethrough-extension-)\n\n\xF0\x9F\xA4\x96 Generated with [Claude Code](https://claude.com/claude-code)\n"
      -- stylua: ignore end

      pr4_content = lualine.build_pr_content {
        additions = 280,
        author = { login = "delphinus", name = "JINNOUCHI Yasushi" },
        baseRefName = "main",
        changedFiles = 4,
        deletions = 39,
        headRefName = "demo/markdown-rendering-test",
        isDraft = false,
        mergedAt = "2026-02-21T01:58:30Z",
        number = 4,
        state = "MERGED",
        title = "feat: add strikethrough support and cache management",
        url = "https://github.com/delphinus/ghsigns.nvim/pull/4",
        createdAt = "2026-02-19T02:32:57Z",
        updatedAt = "2026-02-21T01:58:30Z",
        reviewDecision = "",
        labels = { nodes = {} },
        body = body,
      }
    end)

    it("should produce the expected lines", function()
      eq({
        "#4 feat: add strikethrough support and cache management",
        "main ← demo/markdown-rendering-test",
        "",
        "Author: JINNOUCHI Yasushi",
        "State: MERGED",
        "Changes: +280 -39 (4 files, 0 commits)",
        "",
        "Created: 2026-02-19T02:32:57Z",
        "Updated: 2026-02-21T01:58:30Z",
        "Merged: 2026-02-21T01:58:30Z",
        "",
        "Description:",
        "  Summary",
        "  ",
        "  This PR adds two enhancements to ghsigns.nvim:",
        "  ",
        "  - Add strikethrough rendering support to the markdown module",
        "  - Introduce cache utility methods (clear, invalidate, size) for better cache",
        "  lifecycle management",
        "  ",
        "  Motivation",
        "  ",
        "  │ Currently, the markdown renderer handles bold, inline code, links, and",
        "  │ headings — but it does not support strikethrough. GitHub-flavored Markdown",
        "  │ uses text extensively in PR descriptions, so this is a useful addition.",
        "  │ ",
        "  │ Additionally, the Cache class only supported get and set. There was no way to:",
        "  ... (truncated)",
        "",
        "✕ Click here to close (or press q/Esc/Enter)",
      }, pr4_content.lines)
    end)

    it("should have correct title highlights", function()
      eq({
        { col = 0, end_col = 2, hl = "Number" },
        { col = 3, end_col = -1, hl = "GhsignsPrTitle" },
      }, hl_for_line(pr4_content, 0))
    end)

    it("should have correct branch highlights", function()
      eq({
        { col = 0, end_col = 4, hl = "String" },
        { col = 5, end_col = 7, hl = "Operator" },
        { col = 8, end_col = -1, hl = "Identifier" },
      }, hl_for_line(pr4_content, 1))
    end)

    it("should have correct metadata highlights", function()
      -- Author
      eq({
        { col = 0, end_col = 6, hl = "Comment" },
        { col = 8, end_col = 25, hl = "String" },
      }, hl_for_line(pr4_content, 3))
      -- State (MERGED = DiagnosticError)
      eq({
        { col = 0, end_col = 5, hl = "Comment" },
        { col = 7, end_col = 13, hl = "DiagnosticError" },
      }, hl_for_line(pr4_content, 4))
      -- Changes
      eq({
        { col = 0, end_col = 8, hl = "Comment" },
        { col = 9, end_col = 13, hl = "DiffAdd" },
        { col = 14, end_col = 17, hl = "DiffDelete" },
        { col = 18, end_col = -1, hl = "Comment" },
      }, hl_for_line(pr4_content, 5))
      -- Merged date
      eq({
        { col = 0, end_col = 6, hl = "Comment" },
        { col = 8, end_col = 28, hl = "DiagnosticOk" },
      }, hl_for_line(pr4_content, 9))
    end)

    it("should have correct body highlights", function()
      -- "Summary" heading
      eq({ { col = 2, end_col = 9, hl = "Title" } }, hl_for_line(pr4_content, 12))
      -- Bold "ghsigns.nvim" in line 14
      eq({ { col = 35, end_col = 47, hl = "Bold" } }, hl_for_line(pr4_content, 14))
      -- "Motivation" heading
      eq({ { col = 2, end_col = 12, hl = "Title" } }, hl_for_line(pr4_content, 20))
      -- Blockquote on line 22 (first wrapped blockquote line)
      local bq_hl = hl_for_line(pr4_content, 22)
      assert.is_not_nil(bq_hl)
      eq({ col = 2, end_col = 6, hl = "FloatBorder" }, bq_hl[1])
    end)

    it("should have link_metadata for the example.com link", function()
      eq(1, #pr4_content.link_metadata)
      eq("https://example.com", pr4_content.link_metadata[1].url)
      eq(22, pr4_content.link_metadata[1].line)
    end)

    it("should have correct meta values", function()
      eq(0, pr4_content.title_line)
      eq(29, pr4_content.close_line_idx)
      eq("#4 feat: add strikethrough support and cache management", pr4_content.title_text)
    end)
  end)

  ---------------------------------------------------------------------------
  -- Group 6: Edge cases
  ---------------------------------------------------------------------------
  describe("Edge cases", function()
    it("should handle nil body", function()
      local c = lualine.build_pr_content { number = 1, title = "T" }
      eq({
        "#1 T",
        "",
        "Changes: +0 -0 (0 files, 0 commits)",
        "",
        "",
        "✕ Click here to close (or press q/Esc/Enter)",
      }, c.lines)
      -- No Description: line
      for _, l in ipairs(c.lines) do
        assert.is_not.equal("Description:", l)
      end
    end)

    it("should handle empty body", function()
      local c = build_with_body ""
      eq({
        "#1 T",
        "",
        "Changes: +0 -0 (0 files, 0 commits)",
        "",
        "",
        "✕ Click here to close (or press q/Esc/Enter)",
      }, c.lines)
    end)

    it("should handle HTML-comment-only body", function()
      local c = build_with_body "<!-- just a comment -->"
      -- HTML comment is removed, leaving only whitespace
      eq("Description:", c.lines[6])
      eq("  ", c.lines[7])
    end)

    it("should have close button as last line", function()
      local c = lualine.build_pr_content { number = 1, title = "T" }
      local last_line = c.lines[#c.lines]
      eq("✕ Click here to close (or press q/Esc/Enter)", last_line)
      eq(#c.lines - 1, c.close_line_idx)
    end)

    it("should have ErrorMsg and Comment highlights on close button", function()
      local c = lualine.build_pr_content { number = 1, title = "T" }
      local close_hl = hl_for_line(c, c.close_line_idx)
      assert.is_not_nil(close_hl)
      eq({ col = 0, end_col = 1, hl = "ErrorMsg" }, close_hl[1])
      eq({ col = 2, end_col = 46, hl = "Comment" }, close_hl[2])
    end)
  end)
end)
