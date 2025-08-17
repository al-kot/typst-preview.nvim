local renderer = require('typst-preview/renderer/renderer')
local utils = require('typst-preview/utils')
local config = require('typst-preview/config').opts

local M = {}

local uv = vim.uv

---@class State
---@field code { win: number, buf: number }
---@field preview { win?: number, buf: number, width: number, height: number, win_offset: number }
---@field pages { total: number, current: number }
local state = {
    code = {},
    preview = {},
    pages = {
        total = 1,
        current = 1,
    },
}

local preview_dir = vim.fn.stdpath('cache') .. '/typst_preview/'
if not uv.fs_stat(preview_dir) then
    uv.fs_mkdir(preview_dir, 493)
end
local preview_png = preview_dir .. vim.fn.expand('%:t:r') .. '.png'

function M.render()
    renderer.render(preview_png, state.preview.win_offset, state.preview.height, state.preview.width)
end

function M.clear_preview()
    print('clear called')
    renderer.clear()
end

---@type uv.uv_process_t?
local current_job
function M.compile_and_render()
    if current_job and not current_job:is_closing() then
        current_job:close()
        current_job = nil
    end

    local cmd = utils.typst_compile_cmd({
        data = utils.get_buf_content(state.code.buf),
        format = 'png',
        pages = state.pages.current,
        output = preview_png
    })
    current_job = uv.spawn('sh', { args = { '-c', cmd } }, function(code, _)
        current_job = nil
        if code == 0 then
            M.render()
        end
    end)
end

function M.update_statusline()
    vim.api.nvim_set_option_value("statusline",
        '%#StatusLineTypstPreview#%=' .. state.pages.current .. '/' .. state.pages.total .. ' ',
        { win = state.preview.win })
    vim.cmd("redrawstatus")
end

local function update_total_page_number()
    local target_pdf = preview_dir .. 'preview.pdf'
    local cmd = utils.typst_compile_cmd({
        data = utils.get_buf_content(state.code.buf),
        format = 'pdf',
        output = target_pdf
    })
    cmd = cmd .. ' ;' .. 'pdfinfo ' .. target_pdf .. ' | grep Pages | awk \'{print $2}\''
    local res = vim.system({ vim.o.shell, vim.o.shellcmdflag, cmd }):wait()
    local new_page_number = tonumber(res.stdout)
    if not new_page_number then
        print('failed to get page number: (' .. res.stdout .. ')')
        return
    end
    state.pages.total = new_page_number
end

---@return number, number
local function get_image_dimensions()
    local cmd = utils.typst_compile_cmd({
        data = utils.get_buf_content(state.code.buf),
        format = 'png',
        pages = 1
    })
    local res = vim.system({ vim.o.shell, vim.o.shellcmdflag, cmd }):wait()
    local data = res.stdout

    if not data then
        print('failed to compile (img dimentsions)', res.stderr)
        return 0, 0
    end

    local w = utils.bytes_to_number(data:sub(17, 20))
    local h = utils.bytes_to_number(data:sub(21, 24))
    return h, w
end

function M.update_preview_size()
    local cell_width, cell_height = utils.get_cell_dimensions()
    local img_height, img_width = get_image_dimensions()
    local window_height = vim.api.nvim_win_get_height(state.code.win)

    local rows = window_height
    local cols = math.ceil((cell_height * rows * img_width) / (img_height * cell_width))
    if cols > config.preview.max_width then
        cols = config.preview.max_width
        rows = math.ceil((cell_width * cols * img_height) / (img_width * cell_height))
    end
    state.preview.height = rows
    state.preview.width = cols
    vim.api.nvim_win_set_width(state.preview.win, state.preview.width)
    state.preview.win_offset = vim.fn.win_screenpos(state.preview.win)[2]
end

local function setup_preview_win()
    state.code.win = vim.api.nvim_get_current_win()
    state.code.buf = vim.api.nvim_get_current_buf()

    state.preview.win = vim.api.nvim_open_win(0, false, {
        split = config.preview.position,
        win = 0,
        focusable = false,
        vertical = true,
        style = 'minimal',
    })
    state.preview.buf = vim.api.nvim_create_buf(false, true)

    M.update_preview_size()
    vim.api.nvim_win_set_buf(state.preview.win, state.preview.buf)
    state.preview.win_offset = vim.fn.win_screenpos(state.preview.win)[2]

    if config.preview.position == 'left' then
        vim.schedule(function() vim.api.nvim_set_current_win(state.code.win) end)
    end
end

---@param n number
function M.change_page(n)
    local new_page = state.pages.current + n
    update_total_page_number()
    if new_page > state.pages.total then
        new_page = state.pages.total
    elseif new_page < 1 then
        new_page = 1
    end

    if new_page == state.pages.current then
        return
    end

    state.pages.current = new_page
    M.compile_and_render()
    M.update_statusline()
end

function M.next_page() M.change_page(1) end

function M.prev_page() M.change_page(-1) end

function M.first_page() M.change_page(-state.pages.current + 1) end

function M.last_page() M.change_page(state.pages.total - state.pages.current) end

function M.open_preview()
    if not state.preview.win then
        setup_preview_win()
        update_total_page_number()
        if uv.fs_stat(preview_png) then
            M.render()
        else
            M.compile_and_render()
        end
    end
end

function M.close_preview()
    M.clear_preview()
    vim.api.nvim_win_close(state.preview.win, true)
    state.preview = nil
end


-- utils.add_keybinds({
--     { 'n', '<leader>tn',  function() change_page(1) end },
--     { 'n', '<leader>te',  function() change_page(-1) end },
--     { 'n', '<leader>tgg', function() change_page(-cur_page + 1) end },
--     { 'n', '<leader>tG',  function() change_page(page_number - cur_page) end },
--     { 'n', '<leader>tr',  compile_and_render },
--     { 'n', '<leader>tc',  clear_preview },
--     { 'n', '<leader>td', function()
--         vim.api.nvim_clear_autocmds({ group = 'TypstPreview' })
--         close_preview()
--     end },
--     { 'n', '<leader>to', function()
--         open_preview()
--         setup_autocmds()
--     end },
-- })

return M
