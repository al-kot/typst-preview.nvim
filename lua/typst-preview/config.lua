---@class ConfigOpts

---@class PreviewOpts
---@field max_preview_width number
---@field ppi number
---@field preview_position 'left' | 'right'

---@class style
---@field page_count_color string
local default_opts = {
    preview = {
        ppi = 144,
        max_width = 80,
        position = 'right',
    },
    statusline = {
        color = '',
    },
}

local M = {
    opts = default_opts
}

---@param opts ConfigOpts?
function M.setup(opts)
    M.opts = vim.tbl_deep_extend('force', M.opts, opts or {})
end

return M
