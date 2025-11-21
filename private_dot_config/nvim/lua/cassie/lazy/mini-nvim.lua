return {
	"nvim-mini/mini.nvim",
	version = false,
	config = function()
        require("mini.icons").setup({})
		local mini_files = require("mini.files")
		mini_files.setup({
			options = {
				use_as_default_explorer = false,
			},
		})

		vim.keymap.set("n", "<leader>e", function()
			if mini_files.get_explorer_state() then
				mini_files.close()
			else
				local file = vim.api.nvim_buf_get_name(0)
                mini_files.open(file, false)
			end
		end, { desc = "MiniFiles (current file)" })

		vim.keymap.set("n", "<leader>E", function()
			mini_files.open(vim.loop.cwd())
		end, { desc = "MiniFiles (cwd)" })

		vim.api.nvim_create_autocmd("User", {
			pattern = "MiniFilesBufferCreate",
			callback = function(args)
				local buf = args.data.buf_id

				vim.keymap.set("n", "<CR>", function()
					if mini_files.get_explorer_state() ~= nil then
						mini_files.synchronize()
						mini_files.go_in()
						mini_files.close()
					end
				end, { buffer = buf, nowait = true, silent = true })
			end,
		})
	end,
}
