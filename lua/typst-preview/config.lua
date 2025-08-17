---@class ConfigOpts
---@field max_preview_width number
---@field ppi number
---@field preview_position 'left' | 'right'
local default_opts = {
    max_preview_width = 80,
    ppi = 144,
    preview_position = 'right',
}

local M = {
    opts = default_opts
}

function M.setup(opts)
    M.opts = vim.tbl_deep_extend('force', M.opts, opts or {})
end

return M
