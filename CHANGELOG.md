# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.0.0] - 2026-03-13

### Changed

- extract markdown rendering into md-render.nvim

## [1.18.0] - 2026-03-12

### Added

- add kinsoku (JIS X 4051) line-breaking for Japanese text wrapping

### Documentation

- update CHANGELOG and help for v1.18.0

## [1.17.1] - 2026-03-12

### Documentation

- update CHANGELOG and help for v1.17.1

### Fixed

- renumber ordered lists per CommonMark and fix blockquote prefix extraction

## [1.17.0] - 2026-03-11

### Added

- support reference links, image links, and setext headings

### Documentation

- update CHANGELOG and help for v1.17.0

## [1.16.1] - 2026-03-11

### Fixed

- remove unused PR fields to eliminate read:project scope requirement

## [1.16.0] - 2026-03-11

### Added

- level-specific heading icons and improved blank line control

### Documentation

- update CHANGELOG and help for v1.16.0

## [1.15.0] - 2026-03-11

### Documentation

- update CHANGELOG for v1.15.0

### Fixed

- truncate long frontmatter values and fix list item highlight offset

## [1.14.0] - 2026-03-11

### Added

- click-to-expand truncated code blocks and tables

### Documentation

- update help and CHANGELOG for v1.14.0

## [1.13.0] - 2026-03-11

### Added

- support foldable callouts and code blocks inside callouts

### Documentation

- update help and CHANGELOG for v1.13.0

## [1.12.0] - 2026-03-11

### Added

- support ==highlight== marker syntax
- support %%comment%% syntax for Obsidian
- render YAML frontmatter as Properties section
- extend callout types and support custom titles
- support [[wikilink]] syntax for Obsidian
- support ![[embed]] syntax for Obsidian

### Documentation

- update help and CHANGELOG for v1.12.0

## [1.11.0] - 2026-03-04

### Added

- add Markdown Preview floating window for .md files

### Documentation

- update help and CHANGELOG for v1.11.0

## [1.10.0] - 2026-03-04

### Added

- render GitHub Alerts with icons, colored borders, and tinted backgrounds

### Documentation

- update help and CHANGELOG for v1.10.0

## [1.9.0] - 2026-03-03

### Added

- show full PR description by default instead of truncating

### Changed

- update tests for full PR body display

### Documentation

- update help and CHANGELOG for v1.9.0

## [1.8.0] - 2026-02-26

### Added

- truncate long code block lines instead of wrapping

### Documentation

- update CHANGELOG.md for v1.8.0

## [1.7.0] - 2026-02-25

### Added

- add autolink references support for JIRA/external ticket linking

### Documentation

- update CHANGELOG.md for v1.7.0

## [1.6.0] - 2026-02-25

### Added

- display dates in local timezone instead of UTC

### Documentation

- update CHANGELOG.md for v1.6.0

## [1.5.0] - 2026-02-25

### Added

- truncate bare URLs while preserving clickable links

### Documentation

- update CHANGELOG.md for v1.5.0

## [1.4.1] - 2026-02-24

### Documentation

- update CHANGELOG.md for v1.4.1

### Fixed

- shrink wide tables to fit within max display width

## [1.4.0] - 2026-02-24

### Added

- add markdown table rendering in floating window

### Documentation

- update CHANGELOG.md for v1.4.0

## [1.3.6] - 2026-02-24

### Documentation

- update CHANGELOG.md for v1.3.6

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

[2.0.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.18.0...v2.0.0
[1.18.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.17.1...v1.18.0
[1.17.1]: https://github.com/delphinus/ghsigns.nvim/compare/v1.17.0...v1.17.1
[1.17.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.16.1...v1.17.0
[1.16.1]: https://github.com/delphinus/ghsigns.nvim/compare/v1.16.0...v1.16.1
[1.16.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.15.0...v1.16.0
[1.15.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.14.0...v1.15.0
[1.14.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.13.0...v1.14.0
[1.13.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.12.0...v1.13.0
[1.12.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/delphinus/ghsigns.nvim/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/delphinus/ghsigns.nvim/compare/v1.3.6...v1.4.0
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

