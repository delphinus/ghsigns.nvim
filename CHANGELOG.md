# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.1] - 2026-02-22

### Fixed

- Fix CJK (Japanese, Chinese, Korean) text causing floating window to expand
  horizontally instead of wrapping properly. Added segment-based text splitting
  that treats each CJK/fullwidth character as an individual wrapping unit.

## [1.0.0] - 2026-02-22

### Added

- Core plugin that integrates gitsigns.nvim with GitHub CLI
- Automatic PR information fetching for the current branch via `gh pr view`
- Automatic diff base change to the PR's base branch using gitsigns' `change_base`
- PR information caching by repository root and branch name
- Asynchronous PR fetching to avoid blocking the editor
- Lualine statusline component displaying branch name, base branch, and PR number
- Interactive mouse click handling on the Lualine component:
  - Single-click: Show detailed PR information in a floating window
  - Double-click: Open the PR in the browser
- Rich floating window for PR information display:
  - PR title, draft status, author, state, review decision, mergeable status
  - Branch information, labels, dates (created, updated, merged)
  - Line changes (+/-), file count, and commit count
  - Markdown-rendered PR description with syntax highlighting
  - Clickable links (`[text](url)` format and `#123` issue/PR references)
  - Close button, keyboard shortcuts (q/Esc/Enter), and click-outside-to-close
- Markdown rendering engine supporting:
  - Headings (h1-h3)
  - Bold, strikethrough, inline code
  - Links and issue/PR references
  - Ordered and unordered lists
  - Code blocks with language labels
  - Blockquotes (including nested)
  - HTML comment/tag stripping
  - Long line wrapping with highlight preservation
- OSC 8 terminal detection to prevent duplicate link opening behavior
  - Supports iTerm2, WezTerm, kitty, foot, contour, rio, alacritty, ghostty
  - Supports VTE-based terminals (GNOME Terminal, etc.) and Windows Terminal
- Customizable colors for the Lualine component (icon, head, arrow, base)
- Comprehensive test suite (89 tests) covering markdown rendering, PR content
  rendering, lualine component, and OSC 8 detection
- CI pipeline with GitHub Actions

[1.0.1]: https://github.com/delphinus/ghsigns.nvim/releases/tag/v1.0.1
[1.0.0]: https://github.com/delphinus/ghsigns.nvim/releases/tag/v1.0.0
