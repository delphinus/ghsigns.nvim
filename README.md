# ghsigns.nvim

[日本語版はこちら](#日本語)

A Neovim plugin that integrates [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) with GitHub CLI to automatically display Pull Request information in your statusline and show diffs against the PR's base branch.

> [!WARNING]
> This plugin is under active development. The API, configuration options, and setup methods may change frequently. Breaking changes may occur without prior notice. Please check the documentation regularly for updates.

## Features

- Automatically fetches PR information for the current branch using GitHub CLI
- Displays branch name and PR number in Lualine with colorful highlights
- Double-click the Lualine component to open the PR in your browser
- Automatically changes the diff base to the PR's base branch (using gitsigns' `change_base` feature)
- Caches PR information for better performance
- Asynchronous PR fetching to avoid blocking the editor

## Screenshots

![Lualine showing PR information](assets/lualine-screenshot.png)

The Lualine component displays the current branch (`dev/pack-newline`), base branch (`master`), and PR number (`#37782`) with colorful syntax highlighting.

## Requirements

- [Neovim](https://neovim.io/) >= 0.9.0
- [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) (required)
- [GitHub CLI (`gh`)](https://cli.github.com/) (required)
- [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) (optional, for statusline integration)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "delphinus/ghsigns.nvim",
  dependencies = {
    "lewis6991/gitsigns.nvim",
  },
  config = function()
    require("ghsigns").setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "delphinus/ghsigns.nvim",
  requires = {
    "lewis6991/gitsigns.nvim",
  },
  config = function()
    require("ghsigns").setup()
  end,
}
```

## Configuration

### Basic Setup

```lua
require("ghsigns").setup()
```

### Custom Configuration

```lua
require("ghsigns").setup({
  -- Path to the gh binary (default: "gh")
  bin = "gh",

  -- Custom colors for the Lualine component
  colors = {
    icon = { fg = "#dddde7" },  -- Git branch icon
    head = { fg = "#d087e8" },  -- Current branch name
    arrow = { fg = "#e7a06a" }, -- Arrow symbol
    base = { fg = "#73a3f3" },  -- Base branch name and PR number
  },
})
```

### Lualine Integration

Add the ghsigns component to your Lualine configuration:

```lua
require("lualine").setup({
  sections = {
    lualine_a = { "mode" },
    lualine_b = {
      require("ghsigns.lualine").component(),
    },
    -- ... other sections
  },
})
```

The Lualine component displays:
- `  main` - When on a branch without a PR
- `  feature-branch ← main #123` - When on a branch with PR #123 targeting main

Double-click the component to open the PR in your browser.

## How It Works

1. ghsigns listens to the `GitSignsUpdate` event from gitsigns.nvim
2. When triggered, it fetches PR information for the current branch using `gh pr view`
3. If a PR is found, it automatically changes the diff base to the PR's base branch
4. PR information is cached by repository root and branch name to minimize API calls
5. The Lualine component displays the current branch, base branch, and PR number

## TODO / Roadmap

- [ ] Support for remote repositories other than `origin`
- [ ] Display PR information in a floating window on click
- [ ] Customizable statusline display items
- [ ] Support for statusline plugins other than Lualine

Contributions and feature requests are welcome!

## License

MIT

---

# 日本語

[gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) と GitHub CLI を統合し、ステータスラインに Pull Request 情報を自動表示し、PR のベースブランチとの差分を表示する Neovim プラグインです。

> [!WARNING]
> このプラグインは活発に開発中です。API、設定オプション、セットアップ方法は頻繁に変更される可能性があります。予告なく破壊的変更が入ることがあります。定期的にドキュメントを確認してください。

## 機能

- GitHub CLI を使用して現在のブランチの PR 情報を自動取得
- Lualine にブランチ名と PR 番号をカラフルに表示
- Lualine コンポーネントをダブルクリックすると、ブラウザで PR を開く
- PR のベースブランチに対する差分を自動表示（gitsigns の `change_base` 機能を使用）
- PR 情報をキャッシュしてパフォーマンスを向上
- 非同期 PR 取得でエディタをブロックしない

## スクリーンショット

![Lualine に PR 情報を表示](assets/lualine-screenshot.png)

Lualine コンポーネントは、現在のブランチ（`dev/pack-newline`）、ベースブランチ（`master`）、PR 番号（`#37782`）をカラフルに表示します。

## 必要要件

- [Neovim](https://neovim.io/) >= 0.9.0
- [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)（必須）
- [GitHub CLI (`gh`)](https://cli.github.com/)（必須）
- [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)（オプション、ステータスライン統合用）

## インストール

### [lazy.nvim](https://github.com/folke/lazy.nvim) を使用

```lua
{
  "delphinus/ghsigns.nvim",
  dependencies = {
    "lewis6991/gitsigns.nvim",
  },
  config = function()
    require("ghsigns").setup()
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim) を使用

```lua
use {
  "delphinus/ghsigns.nvim",
  requires = {
    "lewis6991/gitsigns.nvim",
  },
  config = function()
    require("ghsigns").setup()
  end,
}
```

## 設定

### 基本設定

```lua
require("ghsigns").setup()
```

### カスタム設定

```lua
require("ghsigns").setup({
  -- gh コマンドのパス（デフォルト: "gh"）
  bin = "gh",

  -- Lualine コンポーネントのカスタムカラー
  colors = {
    icon = { fg = "#dddde7" },  -- Git ブランチアイコン
    head = { fg = "#d087e8" },  -- 現在のブランチ名
    arrow = { fg = "#e7a06a" }, -- 矢印記号
    base = { fg = "#73a3f3" },  -- ベースブランチ名と PR 番号
  },
})
```

### Lualine 統合

Lualine の設定に ghsigns コンポーネントを追加します：

```lua
require("lualine").setup({
  sections = {
    lualine_a = { "mode" },
    lualine_b = {
      require("ghsigns.lualine").component(),
    },
    -- ... その他のセクション
  },
})
```

Lualine コンポーネントの表示：
- `  main` - PR がないブランチの場合
- `  feature-branch ← main #123` - main をターゲットとする PR #123 があるブランチの場合

コンポーネントをダブルクリックすると、ブラウザで PR を開きます。

## 動作の仕組み

1. ghsigns は gitsigns.nvim の `GitSignsUpdate` イベントをリッスン
2. トリガーされると、`gh pr view` を使用して現在のブランチの PR 情報を取得
3. PR が見つかると、差分ベースを PR のベースブランチに自動変更
4. PR 情報はリポジトリルートとブランチ名でキャッシュされ、API 呼び出しを最小化
5. Lualine コンポーネントに現在のブランチ、ベースブランチ、PR 番号を表示

## TODO / ロードマップ

- [ ] `origin` 以外のリモートリポジトリへの対応
- [ ] クリック時に PR 情報を Floating Window で表示
- [ ] ステータスラインの表示項目をカスタマイズ可能に
- [ ] Lualine 以外のステータスラインプラグインへの対応

コントリビューションや機能リクエストを歓迎します！

## ライセンス

MIT
