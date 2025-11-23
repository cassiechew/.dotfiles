return {
	"MagicDuck/grug-far.nvim",
	config = function()
		require("grug-far").setup({})

		vim.keymap.set("n", "<leader>sr", function()
			require("grug-far").open()
		end, { desc = "Search & Replace (grug-far)" })

		vim.keymap.set("n", "<leader>sw", function()
			require("grug-far").open({ search = vim.fn.expand("<cword>") })
		end, { desc = "Search word under cursor" })

		vim.keymap.set("v", "<leader>sw", function()
			require("grug-far").visual()
		end, { desc = "Search visual selection (grug-far)" })

		vim.keymap.set("n", "<leader>sp", function()
			require("grug-far").open({ cwd = vim.uv.cwd() })
		end, { desc = "Search project (grug-far)" })

		vim.keymap.set("n", "<leader>sf", function()
			require("grug-far").open({ paths = vim.fn.expand("%") })
		end, { desc = "Search in current file" })

		vim.keymap.set("n", "<leader>ss", function()
			require("grug-far").resume()
		end, { desc = "Resume grug-far panel" })

		vim.keymap.set("n", "<leader>sx", function()
			require("grug-far").replace()
		end, { desc = "Replace using last settings" })
	end,
}

