local config = require('typst-preview.config').opts
local M = {}

---Get the dimensions of a terminal cell in pixels
---@return number, number
function M.get_cell_dimensions()
    local ffi = require("ffi")
    ffi.cdef([[
        typedef struct {
          unsigned short row;
          unsigned short col;
          unsigned short xpixel;
          unsigned short ypixel;
        } winsize;
        int ioctl(int, int, ...);
    ]])

    local TIOCGWINSZ = nil
    if vim.fn.has("linux") == 1 then
        TIOCGWINSZ = 0x5413
    elseif vim.fn.has("mac") == 1 then
        TIOCGWINSZ = 0x40087468
    elseif vim.fn.has("bsd") == 1 then
        TIOCGWINSZ = 0x40087468
    end

    ---@type { row: number, col: number, xpixel: number, ypixel: number }
    local sz = ffi.new("winsize")
    assert(ffi.C.ioctl(1, TIOCGWINSZ, sz) == 0, "Failed to get terminal size")

    local cell_height = sz.ypixel / sz.row
    local cell_width = sz.xpixel / sz.col
    return cell_width, cell_height
end

---@param s string bytes to be converted
function M.bytes_to_number(s)
    local b1, b2, b3, b4 = s:byte(1, 4)
    return b1 * math.pow(2, 24) + b2 * math.pow(2, 16) + b3 * math.pow(2, 8) + b4
end

---@param buf number
---@return string
function M.get_buf_content(buf)
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
end

---@param opts { data: string, format: string, pages: number?, output: string?, ppi: number? }
---@return string
function M.typst_compile_cmd(opts)
    local echo = 'echo \'' .. opts.data .. '\''
    local compile = 'typst compile -f ' .. opts.format .. ' --ppi ' .. (opts.ppi or config.preview.ppi)
    if opts.pages then
        compile = compile .. ' --pages ' .. opts.pages
    end
    compile = compile .. ' - ' -- read the typst file contents from stdin
    if opts.output then
        compile = compile .. opts.output
    else
        compile = compile .. '-' -- write the image data to stdout
    end
    return echo .. ' | ' .. compile
end

---@param typst_data string typst file contents
function M.get_image_dimensions(typst_data)
    local cmd = M.typst_compile_cmd({
        data = typst_data,
        format = 'png',
        pages = 1
    })
    local res = vim.system({ vim.o.shell, vim.o.shellcmdflag, cmd }):wait()
    local data = res.stdout

    if not data then
        print('failed to compile (img dimentsions)', res.stderr)
        return 0, 0
    end

    local w = M.bytes_to_number(data:sub(17, 20))
    local h = M.bytes_to_number(data:sub(21, 24))
    return h, w
end

---@param cmds { no_ft: boolean?, event: string[] | string, callback: function }[]
function M.create_autocmds(cmds)
    for _, v in pairs(cmds) do
        local cmd = {
            pattern = { '*.typ' },
            group = 'TypstPreview',
            callback = v.callback
        }
        -- HACK: in nvim v0.12 VimSuspend is not triggered if pattern is present
        if v.no_ft then
            cmd = {
                group = 'TypstPreview',
                callback = v.callback
            }
        end
        vim.api.nvim_create_autocmd(v.event, cmd)
    end
end

return M
