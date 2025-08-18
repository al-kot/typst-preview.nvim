local M = {}
local running = false

---@param opts ConfigOpts?
function M.setup(opts)
    require('typst-preview.config').setup(opts)
end

local function setup_autocmds()
    local preview = require('typst-preview.preview')
    vim.api.nvim_create_augroup('TypstPreview', {})
    require('typst-preview.utils').create_autocmds({
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
            event = 'FocusGained',
            callback = function()
                preview.render()
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
    require('typst-preview.preview').open_preview()
    setup_autocmds()
    running = true
end

function M.stop()
    if not running then
        return
    end
    require('typst-preview.preview').close_preview()
    vim.api.nvim_clear_autocmds({ group = 'TypstPreview' })
    running = false
end

---@param n number
function M.change_page(n)
    require('typst-preview.preview').change_page(n)
end

function M.first_page()
    require('typst-preview.preview').first_page()
end

function M.last_page()
    require('typst-preview.preview').last_page()
end

function M.next_page()
    require('typst-preview.preview').next_page()
end

function M.prev_page()
    require('typst-preview.preview').prev_page()
end

return M
