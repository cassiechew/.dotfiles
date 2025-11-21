return {
	"tpope/vim-fugitive",
	config = function()
		local map = vim.keymap.set
		local opts = { silent = true }

		-- Fugitive status
		map("n", "<leader>gs", function()
			vim.cmd.Git()
		end, { desc = "Fugitive: Status" })

		-- Stage file
		map("n", "<leader>ga", function()
			vim.cmd.Gwrite()
		end, { desc = "Fugitive: Stage file" })

		-- Unstage file
		map("n", "<leader>gA", function()
			vim.cmd("Git restore --staged " .. vim.fn.expand("%"))
		end, { desc = "Fugitive: Unstage file" })

		-- Blame
		map("n", "<leader>gb", function()
			vim.cmd.Git("blame")
		end, { desc = "Fugitive: Blame" })

		-- Commit
		map("n", "<leader>gc", function()
			vim.cmd.Git("commit")
		end, { desc = "Fugitive: Commit" })

		-- Push / Pull
		map("n", "<leader>gp", function()
			vim.cmd.Git("push")
		end, { desc = "Fugitive: Push" })

		map("n", "<leader>gP", function()
			vim.cmd.Git("pull")
		end, { desc = "Fugitive: Pull" })
	end,
}
