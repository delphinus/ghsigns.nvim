-- Minimal init.lua for running tests with plenary.nvim

local home = os.getenv("HOME")
local plenary_dir = os.getenv("PLENARY_DIR") or (home .. "/.local/share/nvim/lazy/plenary.nvim")
local ghsigns_dir = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")

vim.opt.rtp:prepend(ghsigns_dir)
vim.opt.rtp:append(plenary_dir)

vim.cmd("runtime plugin/plenary.vim")

-- Make sure ghsigns module is available
package.path = package.path .. ";" .. ghsigns_dir .. "/lua/?.lua"
package.path = package.path .. ";" .. ghsigns_dir .. "/lua/?/init.lua"
