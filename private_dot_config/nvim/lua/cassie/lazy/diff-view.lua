return {
	"sindrets/diffview.nvim",
	config = function()
		require("diffview").setup({
			enhanced_diff_hl = true,
			use_iconns = true,
			view = {
				default = {
					layout = "diff2_horizontal", -- side-by-side (good for wide monitors)
				},
				merge_tool = {
					layout = "diff3_horizontal", -- 3-way merge layout preference
				},
			},
			keymaps = {
				view = {
					["q"] = "<cmd>DiffviewClose<CR>",
					["<leader>e"] = "<cmd>DiffviewToggleFiles<CR>",
					["<tab>"] = "<cmd>DiffviewToggleFiles<CR>",
					["gf"] = "<cmd>DiffviewFocusFiles<CR>",
					["<C-n>"] = "select_next_entry",
					["<C-p>"] = "select_prev_entry",
				},
				file_panel = {
					["q"] = "<cmd>DiffviewClose<CR>",
					["<cr>"] = "select_entry",
					["<tab>"] = "toggle_stage_entry",
					["s"] = "stage_all",
					["u"] = "unstage_all",
					["j"] = "next_entry",
					["k"] = "prev_entry",
				},
			},
		})

		local map = vim.keymap.set

		-- Open diff vs HEAD
		map("n", "<leader>gd", "<cmd>DiffviewOpen<CR>", { desc = "Diffview: HEAD" })

		-- Diff against current branch’s upstream
		map("n", "<leader>gu", "<cmd>DiffviewOpen @{upstream}<CR>", { desc = "Diffview: upstream" })

		-- View file history for current file
		map("n", "<leader>gh", function()
			vim.cmd("DiffviewFileHistory " .. vim.fn.expand("%"))
		end, { desc = "Diffview: file history" })

		-- Toggle files panel when already in diffview
		map("n", "<leader>gf", "<cmd>DiffviewToggleFiles<CR>", { desc = "Diffview: toggle files panel" })
	end,
}
