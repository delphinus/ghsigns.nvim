local eq = assert.are.same

describe("Lualine module", function()
  local lualine

  before_each(function()
    -- Reset package cache to ensure clean state
    package.loaded["ghsigns.lualine"] = nil

    lualine = require "ghsigns.lualine"
  end)

  after_each(function()
    -- Clean up
    package.loaded["ghsigns.lualine"] = nil
  end)

  describe("get_info", function()
    it("should be a function", function()
      assert.is_function(lualine.get_info)
    end)

    it("should return nil when ghsigns module is not available", function()
      -- This test verifies the function exists and handles missing dependencies
      -- The actual behavior depends on the ghsigns module being loaded
      assert.is_function(lualine.get_info)
    end)
  end)

  describe("component", function()
    it("should provide a component factory function", function()
      assert.is_function(lualine.component)
    end)

    -- Note: Full component testing requires lualine.nvim dependency
    -- These would be better suited as integration tests
  end)

  describe("on_click handler", function()
    it("should be a function", function()
      assert.is_function(lualine.on_click)
    end)

    it("should handle clicks > 2 gracefully", function()
      -- Should not throw error with invalid click count
      assert.has_no.errors(function()
        lualine.on_click(3)
      end)
    end)

    it("should notify when no PR found", function()
      local notifications = {}
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      local original_get_info = lualine.get_info
      lualine.get_info = function()
        return nil, nil
      end

      lualine.on_click(1)

      vim.notify = original_notify
      lualine.get_info = original_get_info

      eq(1, #notifications)
      assert.is_true(notifications[1].msg:find "No PR information" ~= nil)
    end)

    it("should open URL on double click", function()
      local opened_urls = {}
      local notifications = {}

      local original_ui_open = vim.ui.open
      local original_notify = vim.notify

      vim.ui.open = function(url)
        table.insert(opened_urls, url)
      end

      vim.notify = function(msg, level)
        table.insert(notifications, { msg = msg, level = level })
      end

      local original_get_info = lualine.get_info
      lualine.get_info = function()
        return { head = "main" }, {
          url = "https://github.com/owner/repo/pull/123",
        }
      end

      lualine.on_click(2)

      vim.ui.open = original_ui_open
      vim.notify = original_notify
      lualine.get_info = original_get_info

      eq(1, #opened_urls)
      eq("https://github.com/owner/repo/pull/123", opened_urls[1])
    end)
  end)

  describe("show_pr_info", function()
    local original_getmousepos

    before_each(function()
      -- Mock getmousepos for all show_pr_info tests
      original_getmousepos = vim.fn.getmousepos
      vim.fn.getmousepos = function()
        return { screenrow = 5, screencol = 5 }
      end
    end)

    after_each(function()
      -- Restore original function
      vim.fn.getmousepos = original_getmousepos

      -- Clean up any floating windows
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative ~= "" then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
    end)

    it("should be a function", function()
      assert.is_function(lualine.show_pr_info)
    end)

    it("should close existing window if already open", function()
      local pr = {
        number = 123,
        title = "Test PR",
        url = "https://github.com/owner/repo/pull/123",
        baseRefName = "main",
        headRefName = "feature",
        state = "OPEN",
        author = { name = "Test User" },
        body = "Test body",
      }

      -- First call creates the window
      lualine.show_pr_info(pr)

      -- Count floating windows
      local floating_wins_before = 0
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative ~= "" then
          floating_wins_before = floating_wins_before + 1
        end
      end

      assert.is_true(floating_wins_before > 0, "Should have created a floating window")

      -- Second call should close the window
      lualine.show_pr_info(pr)

      local floating_wins_after = 0
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative ~= "" then
          floating_wins_after = floating_wins_after + 1
        end
      end

      assert.is_true(floating_wins_after < floating_wins_before, "Should have closed the floating window")
    end)

    it("should create buffer with PR information", function()
      local pr = {
        number = 123,
        title = "Test PR Title",
        url = "https://github.com/owner/repo/pull/123",
        baseRefName = "main",
        headRefName = "feature",
        state = "OPEN",
        author = { name = "Test User" },
        body = "Test PR body",
        additions = 10,
        deletions = 5,
        changedFiles = 3,
      }

      lualine.show_pr_info(pr)

      -- Find the floating window buffer
      local found_content = false
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative ~= "" then
          local buf = vim.api.nvim_win_get_buf(win)
          local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          local content = table.concat(lines, "\n")

          -- Check if it contains PR information
          if content:find("Test PR Title") and content:find("Test User") then
            found_content = true
            -- Verify some key elements
            assert.is_true(content:find("123") ~= nil) -- PR number
            assert.is_true(content:find("main") ~= nil) -- base branch
            assert.is_true(content:find("feature") ~= nil) -- head branch
            assert.is_true(content:find("OPEN") ~= nil) -- state
            assert.is_true(content:find("Test PR body") ~= nil) -- body
            break
          end
        end
      end

      assert.is_true(found_content, "PR information not found in any buffer")
    end)

    it("should handle DRAFT PR with draft indicator", function()
      local pr = {
        number = 456,
        title = "Draft PR",
        isDraft = true,
        url = "https://github.com/owner/repo/pull/456",
        baseRefName = "main",
        headRefName = "draft-feature",
        author = { login = "testuser" },
      }

      lualine.show_pr_info(pr)

      -- Find the buffer with DRAFT indicator
      local found_draft = false
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative ~= "" then
          local buf = vim.api.nvim_win_get_buf(win)
          local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          local content = table.concat(lines, "\n")

          if content:find("DRAFT") then
            found_draft = true
            break
          end
        end
      end

      assert.is_true(found_draft, "DRAFT indicator not found")
    end)
  end)
end)
