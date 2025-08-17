local utils = require('typst-preview/utils')
local config = require('typst-preview/config').opts

local M = {}
local running = false

---@param opts ConfigOpts
function M.setup(opts)
    require('typst-preview/config').setup(opts)
end

local function setup_autocmds(preview)
    vim.api.nvim_create_augroup('TypstPreview', {})
    utils.create_autocmds({
        {
            event = { 'TextChanged', 'TextChangedI' },
            callback = function()
                preview.compile_and_render()
            end
        },
        {
            event = "BufWritePost",
            callback = function()
                preview.compile_and_render()
            end,
        },
        {
            event = 'BufEnter',
            callback = function()
                preview.open_preview()
                preview.update_statusline()
            end
        },
        {
            event = 'QuitPre',
            callback = function()
                preview.close_preview()
            end
        },
        {
            no_ft = true,
            event = 'VimSuspend',
            callback = function()
                if vim.bo.filetype == 'typst' then
                    preview.clear_preview()
                end
            end
        },
        {
            no_ft = true,
            event = 'VimResume',
            callback = function()
                if vim.bo.filetype == 'typst' then
                    preview.compile_and_render()
                end
            end
        },
        {
            event = 'FocusLost',
            callback = function()
                preview.clear_preview()
            end
        },
        {
            event = "VimResized",
            callback = function()
                preview.update_preview_size()
                preview.render()
            end
        },
    })
end

function M.start()
    if running then
        return
    end
    vim.api.nvim_set_hl(0, "StatusLineTypstPreview", { bold = true, fg = config.style.page_count_color, bg = 'none' })
    local preview = require('typst-preview/preview')
    preview.open_preview()
    preview.update_statusline()
    setup_autocmds(preview)
    running = true
end

function M.stop()
    if not running then
        return
    end
    local preview = require('typst-preview/preview')
    preview.close_preview()
    vim.api.nvim_clear_autocmds({ group = 'TypstPreview' })
    running = false
end

---@param n number
function M.change_page(n)
    require('typst-preview/preview').change_page(n)
end

function M.first_page()
    require('typst-preview/preview').first_page()
end

function M.last_page()
    require('typst-preview/preview').last_page()
end

function M.next_page()
    require('typst-preview/preview').next_page()
end

function M.prev_page()
    require('typst-preview/preview').prev_page()
end

return M
