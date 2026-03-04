.PHONY: test test-markdown test-lualine test-rendering test-md-preview

PLENARY_DIR ?= $(HOME)/.local/share/nvim/lazy/plenary.nvim

test:
	@if [ ! -d "$(PLENARY_DIR)" ]; then \
		echo "plenary.nvim not found. Cloning..."; \
		git clone --depth=1 https://github.com/nvim-lua/plenary.nvim /tmp/plenary.nvim; \
		export PLENARY_DIR=/tmp/plenary.nvim; \
	fi
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

test-markdown:
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedFile tests/markdown_spec.lua"

test-lualine:
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedFile tests/lualine_spec.lua"

test-rendering:
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedFile tests/rendering_spec.lua"

test-md-preview:
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedFile tests/md_preview_spec.lua"
