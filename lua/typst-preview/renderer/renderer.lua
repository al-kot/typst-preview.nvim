local codes = require("typst-preview.renderer.codes")

local M = {}

local uv = vim.uv
if not uv then uv = vim.loop end

local is_tmux = vim.env.TMUX ~= nil

local stdout = vim.loop.new_tty(1, false)
if not stdout then
    print("could not open stdout")
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

---@param data string
---@param win_offset number
---@param img_rows number
---@param img_cols number
function M.render(data, win_offset, img_rows, img_cols, win_height)
    write_graphics({
        action = codes.action.transmit,
        transmit_format = codes.transmit_format.png,
        transmit_medium = codes.transmit_medium.file,
        display_cursor_policy = codes.display_cursor_policy.do_not_move,
        quiet = 2,
        image_id = 1,
    }, data)
    move_cursor(win_offset, math.floor((win_height - img_rows) / 2))

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
    if image_id then
        write_graphics({
            action = codes.action.delete,
            display_delete = "i",
            image_id = 1,
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

return M
