local M = {}
local running = false

local function setup_autocmds()
    local preview = require("typst-preview.preview")
    vim.api.nvim_create_augroup("TypstPreview", {})
    require("typst-preview.utils").create_autocmds({
        {
            event = { "TextChanged", "TextChangedI" },
            callback = function()
                preview.compile_and_render()
            end,
        },
        {
            event = "BufWritePost",
            callback = function()
                preview.compile_and_render()
            end,
        },
        {
            event = "QuitPre",
            callback = function()
                preview.close_preview()
            end,
        },
        {
            no_ft = true,
            event = "VimSuspend",
            callback = function()
                if vim.bo.filetype == "typst" then preview.clear_preview() end
            end,
        },
        {
            no_ft = true,
            event = "VimResume",
            callback = function()
                if vim.bo.filetype == "typst" then preview.compile_and_render() end
            end,
        },
        {
            event = "FocusLost",
            callback = function()
                preview.clear_preview()
            end,
        },
        {
            event = "FocusGained",
            callback = function()
                preview.render()
            end,
        },
        {
            event = "VimResized",
            callback = function()
                preview.update_meta()
                preview.update_preview_size(true)
                preview.render()
            end,
        },
    })
end

---@param opts? ConfigOpts
function M.setup(opts)
    require("typst-preview.config").setup(opts)
    require("typst-preview.statusline").setup()
end

function M.start()
    if running then return end
    require("typst-preview.preview").open_preview()
    setup_autocmds()
    running = true
end

function M.stop()
    if not running then return end
    require("typst-preview.preview").close_preview()
    vim.api.nvim_clear_autocmds({ group = "TypstPreview" })
    running = false
end

---@param n number
function M.goto_page(n)
    if not running then return end
    require("typst-preview.preview").goto_page(n)
end

function M.first_page()
    if not running then return end
    require("typst-preview.preview").first_page()
end

function M.last_page()
    if not running then return end
    require("typst-preview.preview").last_page()
end

---@param n? number
function M.next_page(n)
    if not running then return end
    require("typst-preview.preview").next_page(n)
end

---@param n? number
function M.prev_page(n)
    if not running then return end
    require("typst-preview.preview").prev_page(n)
end

function M.refresh()
    if not running then return end
    local preview = require("typst-preview.preview")
    preview.update_meta()
    preview.update_preview_size(true)
    preview.render()
end

return M
