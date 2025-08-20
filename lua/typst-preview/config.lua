---@class PreviewOpts
---@field max_width? number
---@field ppi? number
---@field position? 'left' | 'right'

---@class StatusLineOpts
---@field enabled? boolean
---@field compile? { ok?: { icon?: string, color?: string }, ko?: { icon?: string, color?: string }}
---@field page_count? { color?: string }

---@class ConfigOpts
---@field preview? PreviewOpts
---@field statusline? StatusLineOpts
local default_opts = {
    preview = {
        max_width = 80,
        ppi = 144,
        position = "right",
    },
    statusline = {
        enabled = true,
        compile = {
            ok = { icon = "", color = "#b8bb26" },
            ko = { icon = "", color = "#fb4943" },
        },
        page_count = {
            color = "#d5c4e1",
        },
    },
}

local M = {
    opts = default_opts,
}

---@param opts? ConfigOpts
function M.setup(opts)
    M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
end

return M
