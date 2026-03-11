# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.16.1] - 2026-03-11

### Fixed

- **Removed unnecessary `read:project` scope requirement**: stripped unused PR fields (`projectCards`, `projectItems`, and 25 others) from `gh pr view` requests, eliminating the need for `gh auth refresh -s read:project`

## [1.16.0] - 2026-03-11

### Added

- **Level-specific heading icons**: headings now display distinct icons per level (◉ ○ ◆ ◇ ▸ ▹ for h1–h6) making heading hierarchy visually clear at a glance
- **Heading highlight groups**: new `GhsignsH1`–`GhsignsH6` highlight groups that inherit colors from treesitter `@markup.heading.N.markdown` groups (fallback to `Title`)
- Updated `show_demo()` with h3 subheadings to showcase heading level differentiation

### Fixed

- **Blank line control around headings**: headings now always have exactly one blank line before them (except at the start of content); blank lines after headings are removed; multiple consecutive blank lines before a heading are collapsed to one

## [1.15.0] - 2026-03-11

### Fixed

- **Frontmatter truncation**: long frontmatter property values in Markdown Preview now truncate at `max_width` with `…` ellipsis, preventing the floating window from becoming too wide
- **Wrapped list item highlight offset**: inline code highlights on wrapped list items were shifted left by the list marker width (e.g. `Title` showing only `Tit` colored), caused by `distribute_highlights` and `distribute_links` not accounting for `list_prefix_len` on the first wrapped line
- **List marker visibility on wrapped lines**: list marker `Special` highlight was being overlapped by `String` highlight on the first line of wrapped list items, making them not appear as bullet points

## [1.14.0] - 2026-03-11

### Added

- **Expandable code blocks and tables**: click the underlined `…` on truncated lines to expand and see full content via horizontal scrolling; click again to collapse
- Updated `show_demo()` with demonstrations for all new features

### Fixed

- Callout fold toggle not working in PR display (local variable scoping bug)

## [1.13.0] - 2026-03-11

### Added

- **Foldable callouts**: Obsidian-compatible `[!TYPE]+` (default expanded) and `[!TYPE]-` (default collapsed) fold modifiers with click-to-toggle
- **Code blocks inside callouts**: code fences inside callout bodies are now detected and rendered with blockquote bar prefix and treesitter syntax highlighting
- **Unknown callout types**: any `[!type]` is now recognized as a callout (rendered with generic ❝ icon and NOTE style)

### Fixed

- Treesitter highlighting on truncated code lines no longer bleeds across truncation boundaries (e.g. heredoc start on a truncated line coloring visible filenames)
- Treesitter parsing now uses original (non-truncated) source lines, preventing truncation from breaking multi-line syntax like heredocs

## [1.12.0] - 2026-03-11

### Added

- **Obsidian compatibility**: extended Markdown rendering with Obsidian-specific syntax support
  - `==highlight==` marker syntax with `GhsignsHighlight` highlight group
  - `%%comment%%` inline comments (hidden in preview) and `%%` block comments
  - YAML frontmatter rendered as a "Properties" section in Markdown Preview
  - 20+ Obsidian callout types (abstract, todo, success, question, failure, danger, bug, example, quote) with aliases
  - Custom callout titles (`> [!NOTE] Custom Title`) and case-insensitive type matching
  - `[[wikilink]]` syntax with display text, heading references, and `obsidian://` URI links
  - `![[embed]]` syntax displayed as link icons (📎 for notes, 🖼 for images)
- 18 new highlight groups for Obsidian callout types (`GhsignsAlert{Type}` and `GhsignsAlert{Type}Bg`)

## [1.11.0] - 2026-03-04

### Added

- **Markdown Preview** (experimental): preview the current `.md` buffer in a floating window with the same rendering engine used for PR descriptions (`:lua require("ghsigns.md_preview").show()`)
- New `display_utils` module extracting shared display utilities (`apply_content_to_buffer`, `open_float_window`, `setup_float_keymaps`, `supports_osc8`) for reuse across PR display and Markdown Preview

### Changed

- Refactored `pr_display` to delegate shared display logic to `display_utils`

## [1.10.0] - 2026-03-04

### Added

- GitHub Alerts (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`) are now rendered with type-specific icons, colored borders, and tinted backgrounds instead of plain blockquotes
- 10 new highlight groups (`GhsignsAlert{Name}` and `GhsignsAlert{Name}Bg`) for alert styling

## [1.9.0] - 2026-03-03

### Changed

- Show the full PR description by default instead of truncating to 15 lines
- The `max_body_lines` option remains available to limit display length if needed

## [1.8.0] - 2026-02-26

### Changed

- Code block lines exceeding the max width are now truncated with "…" instead of wrapped, improving readability in floating windows
- Normal prose continues to wrap at word boundaries as before

### Updated

- `show_demo()` now demonstrates both long prose wrapping and code block truncation

## [1.7.0] - 2026-02-25

### Added

- Autolink references support: ticket IDs (e.g. `JIRA-1234`) in PR descriptions are automatically converted to clickable links
- Hybrid approach: auto-fetches autolink config from GitHub API with `--hostname` support for GitHub Enterprise, falls back to manual `setup({ autolinks = {...} })` configuration
- Support for `is_alphanumeric` flag to match alphanumeric or digit-only patterns
- Autolink references in `show_demo()` for demonstration
- Autolinks work in markdown body text, tables, and all inline contexts

## [1.6.0] - 2026-02-25

### Added

- Display dates (Created, Updated, Merged) in local timezone with abbreviation (e.g. `2024-01-01 09:00:00 JST`) instead of raw UTC format

## [1.5.0] - 2026-02-25

### Added

- Bare URL detection and clickable link support in PR descriptions
- Long URLs (>50 display columns) are truncated with "…" while preserving full URL for clicks
- Short bare URLs are displayed as-is with underline highlight and click support
- Bare URL examples added to `show_demo()`

## [1.4.1] - 2026-02-24

### Fixed

- Wide tables now shrink proportionally to fit within 80-character display width
- Cell content truncated with "…" when columns are narrowed

## [1.4.0] - 2026-02-24

### Added

- Markdown table rendering in floating window using box-drawing characters (`│`, `─`)
- Support for column alignment (left/center/right) and inline markdown in table cells
- New `markdown_table` module with `parse()` and `render()` functions

## [1.3.6] - 2026-02-24

### Fixed

- treesitter highlights in code blocks overridden by fallback String highlight

## [1.3.5] - 2026-02-24

### Documentation

- replace demo video with GIF for inline display
- update CHANGELOG.md for v1.3.5

## [1.3.4] - 2026-02-23

### Documentation

- add demo screencast and update lualine screenshot
- update CHANGELOG.md for v1.3.4

## [1.3.3] - 2026-02-23

### Documentation

- update CHANGELOG.md for v1.3.3

### Fixed

- collapse consecutive spaces in markdown to prevent highlight offset

## [1.3.2] - 2026-02-23

### Documentation

- add release procedure and verify CHANGELOG in workflow
- update CHANGELOG.md for v1.3.2

## [1.3.1] - 2026-02-23

### Changed

- introduce git-cliff for automated CHANGELOG generation

### Fixed

- reorder release workflow to create release before CHANGELOG push

## [1.3.0] - 2026-02-22

### Documentation

- add Neovim help file (vimdoc)

## [1.2.0] - 2026-02-22

### Added

- add show_demo() for markdown rendering verification

## [1.1.0] - 2026-02-22

### Added

- add treesitter syntax highlighting for code blocks in floating window

### Fixed

- improve floating window display (branch order, mergeable, list indent, heading spacing)

## [1.0.1] - 2026-02-22

### Changed

- prepare for v1.0.1 release

### Fixed

- handle CJK line wrapping in floating window

## [1.0.0] - 2026-02-22

### Added

- add .gitignore and StyLua settings
- implement the base features
- enable to open PR on clicking statusline
- show PR number in Lualine section
- print non-critical messages as debug ones
- add single/double click handling for PR component
- implement floating window for PR information display
- add strikethrough support and cache management methods
- add blockquote rendering support

### Changed

- add types
- add debug logging
- fix arrangement
- add Git class skeleton
- add .claude directory to .gitignore
- add comprehensive test suite with plenary.nvim
- add GitHub Actions workflow for running tests
- use more understandable variable names
- fix styles
- gather logic to open/close float win
- fix test for changing messages
- fix by StyLua
- unify click handling via url extmarks
- add PR content rendering tests with build_pr_content extraction
- use [[ ]] long string for PR #4 body in test
- extract process_paired_markers and process_code_markers in markdown.lua
- split show_pr_info into apply_content_to_buffer, open_float_window, setup_float_keymaps
- introduce ContentBuilder and decompose build_pr_content
- decompose add_markdown_line into pure functions and focused methods
- replace generic table annotations with specific type definitions
- decompose Markdown.render, build_header, and build_body
- extract FloatWin class to float_win.lua
- extract ContentBuilder and helpers to content_builder.lua
- extract PR display logic to pr_display.lua
- prepare for v1.0.0 release

### Documentation

- add README
- update README with floating window features
- translate Development/Testing section to Japanese

### Fixed

- detect `origin` remote in default
- detect error messages validly
- use semaphore to access API duplicatedly
- wrap vim.notify with vim.schedule_wrap for async safety
- maintain blockquote prefix on wrapped continuation lines
- correct highlight positions when multiple inline elements coexist
- embed PR #4 body inline instead of reading from /tmp
- prevent duplicate link opening in OSC 8 terminals

[1.11.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.8.0...v1.9.0
[1.3.6]: https://github.com/delphinus/ghsigns.nvim/compare/v1.3.5...v1.3.6
[1.3.5]: https://github.com/delphinus/ghsigns.nvim/compare/v1.3.4...v1.3.5
[1.3.4]: https://github.com/delphinus/ghsigns.nvim/compare/v1.3.3...v1.3.4
[1.3.3]: https://github.com/delphinus/ghsigns.nvim/compare/v1.3.2...v1.3.3
[1.3.2]: https://github.com/delphinus/ghsigns.nvim/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/delphinus/ghsigns.nvim/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/delphinus/ghsigns.nvim/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/delphinus/ghsigns.nvim/releases/tag/v1.0.0

