vim.api.nvim_create_user_command('TypstPreviewStart', function() require('typst-preview').start() end, {})
vim.api.nvim_create_user_command('TypstPreviewStop', function() require('typst-preview').stop() end, {})
