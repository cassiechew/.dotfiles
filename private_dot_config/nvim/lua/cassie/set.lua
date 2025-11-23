vim.opt.guicursor = ""

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true
vim.api.nvim_set_hl(0, "Cursor", { fg = "#FF0066", bg = "#FFFFFF" })
vim.api.nvim_set_hl(0, "Cursor2", { fg = "#FF0066", bg = "#1e1e1e" })
vim.o.guicursor = "n-v-c:block-Cursor,i-ci-ve:ver25-Cursor2"

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

vim.opt.colorcolumn = "80"

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.splitbelow = true
vim.opt.splitbelow = true

vim.opt.timeoutlen = 300
vim.opt.ttimeoutlen = 10
