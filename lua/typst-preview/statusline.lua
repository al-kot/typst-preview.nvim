local config = require('typst-preview.config').opts.statusline

local M = {}

function M.setup()
    vim.api.nvim_set_hl(0, "StatusLineTypstPreview", { bold = true, fg = config.color, bg = 'none' })
end

---@param state State
function M.update(state)
    vim.api.nvim_set_option_value("statusline",
        '%#StatusLineTypstPreview#%=' .. state.pages.current .. '/' .. state.pages.total .. ' ',
        { win = state.preview.win })
    vim.cmd("redrawstatus")
end

return M
