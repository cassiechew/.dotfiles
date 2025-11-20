vim.g.mapleader = " "
--vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

vim.keymap.set("n", "<leader><leader>", function()
	vim.cmd("so")
end, { desc = "source current file" })

-- lsp keymaps

vim.keymap.set("n", "gd", vim.lsp.buf.definition, {desc = "-> definition"})
vim.keymap.set("n", "K", vim.lsp.buf.hover, {desc = "hover"})
vim.keymap.set("n", "<leader>vws", vim.lsp.buf.workspace_symbol, {desc = "view workspace symbol"})
vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float, {desc = "open diagnostics"})
vim.keymap.set("n", "[d", vim.diagnostic.goto_next, {desc = "next diagnostics"})
vim.keymap.set("n", "]d", vim.diagnostic.goto_prev, {desc = "prev diagnostics"})
vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action, {desc = "code action"})
vim.keymap.set("n", "<leader>vrr", vim.lsp.buf.references, {desc = "view reference"})
vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename, {desc = "rename symbol"})

-- vim split
--
vim.keymap.set("n", "<C-J>", "<C-W><C-J>")
vim.keymap.set("n", "<C-K>", "<C-W><C-K>")
vim.keymap.set("n", "<C-L>", "<C-W><C-L>")
vim.keymap.set("n", "<C-H>", "<C-W><C-H>")
-- vv to generate new vertical split
--nnore map <silent> vv <C-w>v
vim.keymap.set("n", "vv", "<C-w>v", { noremap = true, silent = true, desc = "New split pane" })
