local codes = require("typst-preview.renderer.codes")
local log = require('typst-preview.logger')
local utils = require("typst-preview.utils")

local M = {}

local uv = vim.uv
if not uv then uv = vim.loop end

local is_tmux = vim.env.TMUX ~= nil

local backend = "kitty"
local last_sixel_frame
local sixel_render_seq = 0

local stdout = vim.loop.new_tty(1, false)
if not stdout then
    log.error("(renderer) could not open stdout")
    return
end

---@param sequence string
---@return string
local function escape_tmux(sequence)
    return "\27Ptmux;" .. sequence:gsub("\27", "\27\27") .. "\27\\"
end

---@param data string
---@param escape? boolean
local function write(data, escape)
    if data == "" then return end

    local payload = data
    if escape and is_tmux then payload = escape_tmux(data) end
    stdout:write(payload)
end

---@param str string
local get_chunked = function(str)
    local chunks = {}
    for i = 1, #str, 4096 do
        local chunk = str:sub(i, i + 4096 - 1):gsub("%s", "")
        if #chunk > 0 then table.insert(chunks, chunk) end
    end
    return chunks
end

---@param config {}
---@param data? string
local function write_graphics(config, data)
    local control_payload = ""

    for k, v in pairs(config) do
        if v ~= nil then
            local key = codes.keys[k]
            if key then
                if type(v) == "number" then v = string.format("%d", v) end
                control_payload = control_payload .. key .. "=" .. v .. ","
            end
        end
    end
    control_payload = control_payload:sub(0, -2)

    if data then
        data = vim.base64.encode(data):gsub("%-", "/")
        local chunks = get_chunked(data)
        local m = #chunks > 1 and 1 or 0
        control_payload = control_payload .. ",m=" .. m
        for i = 1, #chunks do
            write("\27_G" .. control_payload .. ";" .. chunks[i] .. "\27\\", true)
            if i == #chunks - 1 then
                control_payload = "m=0"
            else
                control_payload = "m=1"
            end
            uv.sleep(1)
        end
    else
        write("\27_G" .. control_payload .. "\27\\", true)
    end
end

---@param x number
---@param y number
local move_cursor = function(x, y)
    write("\27[s")
    write("\27[" .. y .. ";" .. x .. "H")
    uv.sleep(1)
end

local restore_cursor = function()
    write("\27[u")
end

local function clear_sixel_frame()
    if not last_sixel_frame then return end
    write("\27[s")
    for row = 0, last_sixel_frame.rows - 1 do
        write("\27[" .. (last_sixel_frame.y + row) .. ";" .. last_sixel_frame.x .. "H")
        write(string.rep(" ", last_sixel_frame.cols))
    end
    write("\27[u")
    last_sixel_frame = nil
end

---@param y number
---@param x number
---@param len number
local function clear_segment(y, x, len)
    if len <= 0 then return end
    write("\27[" .. y .. ";" .. x .. "H")
    write(string.rep(" ", len))
end

---@param old { x: number, y: number, rows: number, cols: number }
---@param new { x: number, y: number, rows: number, cols: number }
local function clear_sixel_non_overlap(old, new)
    local old_y1 = old.y
    local old_y2 = old.y + old.rows - 1
    local old_x1 = old.x
    local old_x2 = old.x + old.cols - 1

    local new_y1 = new.y
    local new_y2 = new.y + new.rows - 1
    local new_x1 = new.x
    local new_x2 = new.x + new.cols - 1

    write("\27[s")
    for y = old_y1, old_y2 do
        if y < new_y1 or y > new_y2 then
            clear_segment(y, old_x1, old.cols)
        else
            local left_len = math.max(0, math.min(old_x2, new_x1 - 1) - old_x1 + 1)
            local right_start = math.max(old_x1, new_x2 + 1)
            local right_len = math.max(0, old_x2 - right_start + 1)

            clear_segment(y, old_x1, left_len)
            clear_segment(y, right_start, right_len)
        end
    end
    write("\27[u")
end

---@param old { x: number, y: number, rows: number, cols: number }?
---@param new { x: number, y: number, rows: number, cols: number }
---@return boolean
local function same_frame(old, new)
    if not old then return false end
    return old.x == new.x
        and old.y == new.y
        and old.rows == new.rows
        and old.cols == new.cols
end

local function render_sixel(data, win_col, img_rows, img_cols, y)

    local sixel_bin = utils.get_sixel_bin()
    if not sixel_bin then
        log.warn("(renderer) sixel backend selected but no sixel binary found")
        return
    end

    local sixel_cmd
    local bin_name = sixel_bin:lower()
    if bin_name:find("chafa", 1, true) then
        sixel_cmd = { sixel_bin, "-f", "sixels", "--size", string.format("%dx%d", img_cols, img_rows), data }
    else
        sixel_cmd = { sixel_bin, "-w", tostring(img_cols), data }
    end

    sixel_render_seq = sixel_render_seq + 1
    local current_seq = sixel_render_seq

    vim.system(sixel_cmd, {}, function(res)
        if current_seq ~= sixel_render_seq then return end
        if res.code ~= 0 then
            vim.schedule(function()
                log.warn("(renderer) sixel render failed:\n" .. (res.stderr or ""))
            end)
            return
        end

        vim.schedule(function()
            if current_seq ~= sixel_render_seq then return end

            local new_frame = {
                x = win_col,
                y = y,
                rows = img_rows,
                cols = img_cols,
            }

            move_cursor(win_col, y)
            write(res.stdout or "")
            restore_cursor()

            if last_sixel_frame and not same_frame(last_sixel_frame, new_frame) then
                clear_sixel_non_overlap(last_sixel_frame, new_frame)
            end

            last_sixel_frame = new_frame
        end)
    end)
end

---@param data string
---@param win_col number
---@param win_row number
---@param img_rows number
---@param img_cols number
function M.render(data, win_col, win_row, img_rows, img_cols, win_height)
    local y = win_row + math.floor((win_height - img_rows) / 2)
    if y < 1 then y = 1 end

    if backend == "sixel" then
        render_sixel(data, win_col, img_rows, img_cols, y)
        return
    end

    write_graphics({
        action = codes.action.transmit,
        transmit_format = codes.transmit_format.png,
        transmit_medium = codes.transmit_medium.file,
        display_cursor_policy = codes.display_cursor_policy.do_not_move,
        quiet = 2,
        image_id = 1,
    }, data)
    move_cursor(win_col, y)

    write_graphics({
        action = codes.action.display,
        display_columns = img_cols,
        display_rows = img_rows,
        quiet = 2,
        display_zindex = -1,
        display_cursor_policy = codes.display_cursor_policy.do_not_move,
        image_id = 1,
    })
    restore_cursor()
end

---@param image_id? number
function M.clear(image_id)
    if backend == "sixel" then
        sixel_render_seq = sixel_render_seq + 1
        clear_sixel_frame()
        return
    end

    if image_id then
        write_graphics({
            action = codes.action.delete,
            display_delete = "i",
            image_id = image_id,
            quiet = 2,
        })
        return
    end

    write_graphics({
        action = codes.action.delete,
        display_delete = "a",
        quiet = 2,
    })
end

---@param value 'kitty' | 'sixel'
function M.set_backend(value)
    backend = value
end

---@return 'kitty' | 'sixel'
function M.get_backend()
    return backend
end

return M
