return {
	"nvim-telescope/telescope.nvim",

	tag = "v0.1.9",

	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		"nvim-telescope/telescope-file-browser.nvim",
	},

	config = function()
		local telescope = require("telescope")
		local builtin = require("telescope.builtin")
		telescope.setup({
			defaults = {
				layout_strategy = "center",
				layout_config = {
					anchor = "S",
					height = 0.40,
					width = 0.99,
					preview_cutoff = 1,
				},
			},
			extensions = {
				fzf = {
					fuzzy = true,
					override_generic_sorter = true,
					override_file_sorter = true,
					case_mode = "smart_case",
				},
				file_browser = {
					--                    sorting_strategy = "ascending",
					initial_mode = "normal",
					preview = false,
					hijack_netrw = true,
					hidden = true,
					grouped = true,
					respect_gitignore = true,
				},
			},
		})

		telescope.load_extension("fzf")
		telescope.load_extension("file_browser")

		vim.keymap.set("n", "<leader>pf", builtin.find_files, { desc = "Telescope find files" })
		vim.keymap.set("n", "<C-p>", builtin.git_files, { desc = "Telescope find git files" })
		vim.keymap.set("n", "<leader>ps", function()
			builtin.grep_string({ search = vim.fn.input("Grep > ") })
		end, { desc = "Grep for string" })
		vim.keymap.set("n", "<leader>pps", builtin.live_grep, { desc = "Live Grep" })

		vim.keymap.set("n", "<leader>pv", function()
			local dir = vim.fn.expand("%:p:h") -- open at current file’s directory
			telescope.extensions.file_browser.file_browser({
				path = dir,
				cwd = dir,
				select_buffer = true,
				hidden = true,
				grouped = true,
			})
		end, { desc = "Telescope File Browser" })

		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				local arg = vim.fn.argv(0)
				if vim.fn.isdirectory(arg) == 1 then
					telescope.extensions.file_browser.file_browser({
						path = arg,
						cwd = arg,
						hidden = true,
						respect_gitignore = true,
					})
				end
			end,
		})
	end,
}
