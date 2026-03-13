-- Minimal init.lua for running tests with plenary.nvim

local home = os.getenv("HOME")
local plenary_dir = os.getenv("PLENARY_DIR") or (home .. "/.local/share/nvim/lazy/plenary.nvim")
local ghsigns_dir = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
local md_render_dir = os.getenv("MD_RENDER_DIR") or (home .. "/.local/share/nvim/lazy/md-render.nvim")

vim.opt.rtp:prepend(ghsigns_dir)
vim.opt.rtp:append(plenary_dir)
vim.opt.rtp:append(md_render_dir)

vim.cmd("runtime plugin/plenary.vim")

-- Make sure ghsigns and md_render modules are available
package.path = package.path .. ";" .. ghsigns_dir .. "/lua/?.lua"
package.path = package.path .. ";" .. ghsigns_dir .. "/lua/?/init.lua"
package.path = package.path .. ";" .. md_render_dir .. "/lua/?.lua"
package.path = package.path .. ";" .. md_render_dir .. "/lua/?/init.lua"
