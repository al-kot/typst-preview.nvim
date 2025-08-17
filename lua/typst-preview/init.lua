local utils = require('typst-preview/utils')

local M = {}

---@param opts ConfigOpts
function M.setup(opts)
    require('typst-preview/config').setup(opts)
end

vim.api.nvim_set_hl(0, "StatusLineTypstPreview", { bold = true, fg = '#83a598', bg = 'none' })
vim.api.nvim_create_augroup('TypstPreview', {})
utils.create_autocmds({
    {
        event = { 'TextChanged', 'TextChangedI' },
        callback = function()
            require('typst-preview/preview').compile_and_render()
        end
    },
    {
        event = "BufWritePost",
        callback = function()
            require('typst-preview/preview').compile_and_render()
        end,
    },
    {
        event = 'BufEnter',
        callback = function()
            require('typst-preview/preview').open_preview()
            require('typst-preview/preview').update_statusline()
        end
    },
    {
        event = 'QuitPre',
        callback = function()
            require('typst-preview/preview').close_preview()
        end
    },
    {
        no_ft = true,
        event = 'VimSuspend',
        callback = function()
            if vim.bo.filetype == 'typst' then
                require('typst-preview/preview').clear_preview()
            end
        end
    },
    {
        no_ft = true,
        event = 'VimResume',
        callback = function()
            if vim.bo.filetype == 'typst' then
                require('typst-preview/preview').compile_and_render()
            end
        end
    },
    {
        event = 'FocusLost',
        callback = function()
            require('typst-preview/preview').clear_preview()
        end
    },
    {
        event = "VimResized",
        callback = function()
            local preview = require('typst-preview/preview')
            preview.update_preview_size()
            preview.render()
        end
    },
})

function M.open_preview()
    require('typst-preview/preview').open_preview()
end

function M.close_preview()
    require('typst-preview/preview').close_preview()
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
