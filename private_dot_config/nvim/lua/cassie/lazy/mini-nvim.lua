return {
	"nvim-mini/mini.nvim",
	version = false,
	config = function()
		local builtin = require("mini.files")
		builtin.setup({
            options = {
                use_as_default_explorer = false,
            }
        })

		vim.keymap.set("n", "<leader>e", function()
			builtin.open()
		end, { desc = "MiniFiles (current file)" })

		vim.keymap.set("n", "<leader>E", function()
			builtin.open(vim.loop.cwd())
		end, { desc = "MiniFiles (cwd)" })

		vim.api.nvim_create_autocmd("User", {
			pattern = "MiniFilesBufferCreate",
			callback = function(args)
				local buf = args.data.buf_id

				vim.keymap.set("n", "<CR>", function()
					if builtin.get_explorer_state() ~= nil then
						builtin.synchronize()
						builtin.go_in()
						builtin.close()
					end
				end, { buffer = buf, nowait = true, silent = true })
			end,
		})
	end,
}
