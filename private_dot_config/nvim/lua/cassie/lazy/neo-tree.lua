return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
		},
		lazy = false,
		---@module 'neo-tree'
		---@type neotree.Config
		opts = {
			enable_git_status = true,
			enable_diagnostics = true,
		},
		keys = {
			-- Reveal current file
			{ "<leader>f", "<cmd>Neotree reveal<CR>", desc = "Neo-tree: Reveal" },

			-- Toggle tree
			{ "<leader>F", "<cmd>Neotree toggle<CR>", desc = "Neo-tree: Toggle" },
		},
	},
}

