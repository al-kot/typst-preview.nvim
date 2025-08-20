local config = require("typst-preview.config").opts.statusline

local M = {}

function M.setup()
    vim.api.nvim_set_hl(0, "StatusLineTypstPreviewCompOk", { bold = true, fg = config.compile.ok.color, bg = "none" })
    vim.api.nvim_set_hl(0, "StatusLineTypstPreviewCompKo", { bold = true, fg = config.compile.ko.color, bg = "none" })
    vim.api.nvim_set_hl(0, "StatusLineTypstPreviewPages", { bold = true, fg = config.page_count.color, bg = "none" })
end

local function get_compilation_state(compiled)
    if compiled then
        return "%#StatusLineTypstPreviewCompOk#" .. config.compile.ok.icon
    else
        return "%#StatusLineTypstPreviewCompKo#" .. config.compile.ko.icon
    end
end

local function get_page_count(current, total)
    return "%#StatusLineTypstPreviewPages#" .. current .. "/" .. total
end

---@param state State
function M.update(state)
    if not config.enabled then return end
    local line = {
        get_compilation_state(state.code.compiled),
        "%=",
        get_page_count(state.pages.current, state.pages.total),
        " ",
    }
    vim.api.nvim_set_option_value("statusline", table.concat(line), { win = state.preview.win })
    vim.cmd("redrawstatus")
end

return M
