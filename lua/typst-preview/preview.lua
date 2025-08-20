local renderer = require("typst-preview.renderer.renderer")
local utils = require("typst-preview.utils")
local config = require("typst-preview.config").opts.preview
local statusline = require("typst-preview.statusline")
local log = require("typst-preview.logger")

assert(config ~= nil, "config must not be nil")

local M = {}

local uv = vim.uv

---@class State
---@field code { win: number, buf: number, compiled: boolean }
---@field preview { win?: number, buf: number }
---@field pages { total: number, current: number, placements: {
---width: number, height: number, rows: number, cols:number , win_offset: number }[] } width, height -> pixels | rows, cols -> cells
---@field meta { cell_width: number, cell_height: number, win_rows: number, win_cols: number }
local state = {
    code = {},
    preview = {},
    pages = {
        total = 1,
        current = 1,
        placements = {},
    },
    meta = {},
}

local preview_dir = vim.fn.stdpath("cache") .. "/typst_preview/"
if not uv.fs_stat(preview_dir) then uv.fs_mkdir(preview_dir, 493) end
local preview_png = preview_dir .. vim.fn.expand("%:t:r") .. ".png"

function M.render()
    M.update_preview_size()
    local page_placement = state.pages.placements[state.pages.current]
    renderer.render(
        preview_png,
        page_placement.win_offset,
        page_placement.rows,
        page_placement.cols,
        state.meta.win_rows
    )
end

function M.clear_preview()
    renderer.clear()
end

---@type vim.SystemObj?
local current_job
function M.compile_and_render()
    if current_job and not current_job:is_closing() then
        current_job:kill(9)
        current_job = nil
    end

    local cmd = utils.typst_compile_cmd({
        format = "png",
        pages = state.pages.current,
        output = preview_png,
    })

    current_job = vim.system(cmd, { stdin = utils.get_buf_content(state.code.buf) }, function(obj)
        if obj.signal ~= 9 then
            if obj.code == 0 then
                state.code.compiled = true
                M.update_preview_size()
                M.render()
            else
                vim.schedule(function()
                    log.info("(preview) compilation failed:\n" .. obj.stderr)
                end)
                state.code.compiled = false
            end
            vim.schedule(function()
                statusline.update(state)
            end)
        end
    end)
end

local function update_total_page_number()
    local target_pdf = preview_dir .. "preview.pdf"
    local typst_cmd = utils.typst_compile_cmd({
        format = "pdf",
        output = target_pdf,
    })
    local cmd = "echo '" .. utils.get_buf_content(state.code.buf)
    cmd = cmd .. "' | " .. table.concat(typst_cmd, " ") .. " ;" .. "pdfinfo " .. target_pdf
    cmd = cmd .. " | grep Pages | awk '{print $2}'"
    local res = vim.system({ vim.o.shell, vim.o.shellcmdflag, cmd }):wait()
    local new_page_number = tonumber(res.stdout)
    if not new_page_number then
        log.warn(
            "(preview) failed to get page number: stdout = (" .. res.stdout .. "), stderr = (" .. res.stderr .. ")"
        )
        return
    end
    state.pages.total = new_page_number
    statusline.update(state)
end

---@param force boolean?
function M.update_preview_size(force)
    local img_height, img_width = utils.get_page_dimensions(preview_png)
    local page_placement = state.pages.placements[state.pages.current]
    if force or not page_placement or page_placement.width ~= img_width or page_placement.height ~= img_height then
        local rows = state.meta.win_rows
        local cols = math.ceil((state.meta.cell_height * rows * img_width) / (img_height * state.meta.cell_width))
        if cols > config.max_width then
            cols = config.max_width
            rows = math.ceil((state.meta.cell_width * cols * img_height) / (img_width * state.meta.cell_height))
        end
        page_placement = {
            width = img_width,
            height = img_height,
            cols = cols or 0,
            rows = rows,
            win_offset = config.position == "left" and 0 or state.meta.win_cols - cols + 1,
        }
        state.pages.placements[state.pages.current] = page_placement
    end
    vim.schedule(function()
        vim.api.nvim_win_set_width(state.preview.win, page_placement.cols)
    end)
end

function M.update_meta()
    local cell_width, cell_height = utils.get_cell_dimensions()
    state.meta = {
        win_rows = vim.api.nvim_win_get_height(0),
        win_cols = vim.api.nvim_win_get_width(state.code.win) + vim.api.nvim_win_get_width(state.preview.win) + 1,
        cell_height = cell_height,
        cell_width = cell_width,
    }
end

local function setup_preview_win()
    state.code.win = vim.api.nvim_get_current_win()
    state.code.buf = vim.api.nvim_get_current_buf()

    state.preview.win = vim.api.nvim_open_win(0, false, {
        split = config.position,
        win = 0,
        focusable = false,
        vertical = true,
        style = "minimal",
    })
    state.preview.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(state.preview.win, state.preview.buf)

    if config.position == "left" then
        vim.schedule(function()
            vim.api.nvim_set_current_win(state.code.win)
        end)
    end
end

---@param n number
function M.goto_page(n)
    update_total_page_number()
    if n > state.pages.total then
        n = state.pages.total
    elseif n < 1 then
        n = 1
    end

    if n == state.pages.current then return end

    state.pages.current = n
    M.compile_and_render()
    statusline.update(state)
end

---@param n? number
function M.next_page(n)
    if not n then n = 1 end
    M.goto_page(state.pages.current + n)
end

---@param n? number
function M.prev_page(n)
    if not n then n = 1 end
    M.goto_page(state.pages.current - n)
end

function M.first_page()
    M.goto_page(1)
end

function M.last_page()
    M.goto_page(state.pages.total)
end

function M.open_preview()
    setup_preview_win()
    update_total_page_number()
    M.update_meta()
    M.compile_and_render()
end

function M.close_preview()
    M.clear_preview()
    vim.api.nvim_win_close(state.preview.win, true)
end

return M
