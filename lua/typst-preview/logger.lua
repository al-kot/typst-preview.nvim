local M = {}

local log_dir = vim.fn.stdpath('log') .. '/typst-preview/'
if not vim.uv.fs_stat(log_dir) then vim.uv.fs_mkdir(log_dir, 493) end
local log_file = log_dir .. 'logs.txt'

function M.show_logs()
    vim.cmd('tabnew +view ' .. log_file)
    vim.cmd('normal! G')
end

local function write_log(level, msg)
    local time = os.date('%H:%M:%S')
    local file = io.open(log_file, 'a')
    if not file then return end
    file:write('[' .. level .. ']' .. '[' ..time .. '] ' .. msg)
    file:close()
end

function M.info(msg)
    write_log('INFO', msg)
end

function M.warn(msg)
    write_log('WARN', msg)
end

function M.error(msg)
    write_log('ERROR', msg)
end

function M.debug(msg)
    write_log('DEBUG', msg)
end

return M
