local renderer = require('typst-preview.renderer.renderer')
local utils = require('typst-preview.utils')
local config = require('typst-preview.config').opts.preview
local statusline = require('typst-preview.statusline')

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
    statusline.update(state)
end

function M.update_preview_size()
    local cell_width, cell_height = utils.get_cell_dimensions()
    local img_height, img_width = utils.get_image_dimensions(utils.get_buf_content(state.code.buf))
    local window_height = vim.api.nvim_win_get_height(state.code.win)

    local rows = window_height
    local cols = math.ceil((cell_height * rows * img_width) / (img_height * cell_width))
    if cols > config.max_width then
        cols = config.max_width
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
        split = config.position,
        win = 0,
        focusable = false,
        vertical = true,
        style = 'minimal',
    })
    state.preview.buf = vim.api.nvim_create_buf(false, true)

    M.update_preview_size()
    vim.api.nvim_win_set_buf(state.preview.win, state.preview.buf)
    state.preview.win_offset = vim.fn.win_screenpos(state.preview.win)[2]

    if config.position == 'left' then
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
    statusline.update(state)
end

function M.next_page() M.change_page(1) end

function M.prev_page() M.change_page(-1) end

function M.first_page() M.change_page(-state.pages.current + 1) end

function M.last_page() M.change_page(state.pages.total - state.pages.current) end

function M.open_preview()
    setup_preview_win()
    update_total_page_number()
    M.compile_and_render()
end

function M.close_preview()
    M.clear_preview()
    vim.api.nvim_win_close(state.preview.win, true)
end

return M
