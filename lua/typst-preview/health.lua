local M = {}

local health = vim.health or require("vim.health")

local function check_bin(bin)
    if vim.fn.executable(bin) == 1 then
        health.ok(bin .. " is installed")
    else
        health.error(bin .. " is not installed")
    end
end

local function check_tmux_options()
    local opts = {
        {
            opt = 'allow-passthrough',
            must = true,
            value = 'on'
        },
        {
            opt = 'focus-events',
            must = true,
            value = 'on'
        },
        {
            opt = 'visual-activity',
            must = false,
            value = 'off'
        },
    }
    for _, opt in pairs(opts) do
        local result = vim.fn.systemlist({ "tmux", "show-option", "-gqv", opt.opt })
        if vim.v.shell_error ~= 0 or #result == 0 or result[1] ~= opt.value then
            if opt.must then
                health.error("Inside tmux the option " .. opt.opt .. " must be set to " .. opt.value)
            else
                health.warn("Inside tmux it is recommended to set the option " .. opt.opt .. " to " .. opt.value)
            end
        else
            health.ok('Tmux option ' .. opt.opt .. ' is set correctly')
        end
    end
end

function M.check()
    health.start("MyPlugin: checking dependencies")

    check_bin("typst")
    check_bin("pdfinfo")
    if vim.env.TMUX then check_tmux_options() end
end

return M
