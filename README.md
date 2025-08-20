# typst-preview.nvim

Live preview of [Typst](https://typst.app/) documents directly inside neovim.

https://github.com/user-attachments/assets/31418a36-2a10-40f5-9a19-fc810bd6436b

---

# ⚡️ Requirements

- [`typst`](https://github.com/typst/typst#installation)
- `pdfinfo`
- terminal that supports kitty graphics protocol:
    - kitty
    - wezterm (performance and image quality are worse than with kitty)
    - ~~ghostty~~ (work needed, the rendering is buggy)

note for tmux users: you will need to set these options

```tmux
set -gq allow-passthrough on
set -g visual-activity off
set-option -g focus-events on
```

but sometimes the image still stays when you switch windows and sessions (to fix)

# 📦 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "al-kot/typst-preview.nvim",
    opts = {
        -- your config here
    }
}
```

Using [vim.pack](https://neovim.io/doc/user/pack.html#vim.pack) (nightly):

```lua
vim.pack.add({
    "https://github.com/al-kot/typst-preview.nvim.git",
})

require('typst-preview').setup({
    -- your config here
})
```

---

# ⚙️ Default configuration

```lua
require("typst-preview").setup({
    preview = {
        max_width = 80, -- Maximum width of the preview window (columns)
        ppi = 144, -- The PPI (pixels per inch) to use for PNG export (high value will affect the performance)
        position = "right", -- The position of the preview window relative to the code window
    },
    statusline = {
        enabled = true, -- Show statusline
        compile = { -- Last compilation status
            ok = { icon = "", color = "#b8bb26" },
            ko = { icon = "", color = "#fb4943" },
        },
        page_count = { -- Page count
            color = "#d5c4e1",
        },
    },
})
```

---

# 🚀 Usage

```lua
local preview = require("typst-preview")

-- Setup
preview.setup(opts)

-- Start/stop preview
preview.start()
preview.stop()

-- Page navigation
preview.goto_page(5) -- go to page 5

preview.next_page()
preview.next_page(5) -- go 5 pages forward

preview.prev_page()
preview.prev_page(5) -- go 5 pages backward

preview.first_page()
preview.last_page()

-- Refresh preview
preview.refresh() -- in case the image shifts or the page number is wrong
```

## Commands

| Command | Action |
| -------------- | --------------- |
| TypstPreviewOpen | Opens the preview |
| TypstPreviewClose | Closes the preview |
| TypstPreviewGoTo n| Go to page n |
| TypstPreviewLogs | Show logs (will contain the compilation errors if any) |


## Open on startup

If you want to open the preview whenever you open a typst file, put this in your `nvim/ftplugin/typst.lua`
```lua
require("typst-preview").start()
```

---

# 📖 Example Keymaps

```lua
vim.keymap.set("n", "<leader>ts", function()
  require("typst-preview").start()
end, { desc = "Start Typst preview" })

vim.keymap.set("n", "<leader>tq", function()
  require("typst-preview").stop()
end, { desc = "Stop Typst preview" })

vim.keymap.set("n", "<leader>tn", function()
  require("typst-preview").next_page()
end, { desc = "Next page" })

vim.keymap.set("n", "<leader>tp", function()
  require("typst-preview").prev_page()
end, { desc = "Previous page" })

vim.keymap.set("n", "<leader>tr", function()
  require("typst-preview").refresh()
end, { desc = "Refresh preview" })

vim.keymap.set("n", "<leader>tgg", function()
  require("typst-preview").first_page()
end, { desc = "First page" })

vim.keymap.set("n", "<leader>tG", function()
  require("typst-preview").last_page()
end, { desc = "Last page" })
```

# 💻 Contribution

Feel free to contribute, especially if you find a way to improve the performance. I am pretty new to typst and can miss some important use cases so feature requests are welcome. Before submitting a bug report make sure to run `:checkhealth typst-preview`

# Credits

Big thanks to the author of [image.nvim](https://github.com/3rd/image.nvim), the image rendering is almost entirely "inspired" by their work.

This plugin is basically a slightly more sophisticated version of `typst watch`, if you need more advanced features (low-latency, cursor follow, etc.) you should definitely checkout a great plugin by [chomosuke](https://github.com/chomosuke/typst-preview.nvim) and the [tinymist](https://myriad-dreamin.github.io/tinymist/feature/preview.html) language server.
