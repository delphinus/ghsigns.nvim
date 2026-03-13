--- Thin wrapper that delegates to md_render.preview.
--- Kept for backward compatibility so existing users can still call
--- require("ghsigns.md_preview").show()
local md_render = require "md-render"

local MdPreview = {}

MdPreview.build_content = md_render.preview.build_content

MdPreview.show = md_render.preview.show

return MdPreview
