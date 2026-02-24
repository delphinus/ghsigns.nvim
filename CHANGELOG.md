# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.3.5] - 2026-02-24

### Documentation

- replace demo video with GIF for inline display

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

