vim.api.nvim_create_user_command("TypstPreviewStart", function()
    require("typst-preview").start()
end, {})

vim.api.nvim_create_user_command("TypstPreviewStop", function()
    require("typst-preview").stop()
end, {})

vim.api.nvim_create_user_command("TypstPreviewGoTo", function(opts)
    local n = tonumber(opts.args)
    if n then require("typst-preview").goto_page(n) end
end, { nargs = 1 })
