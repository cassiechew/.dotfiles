-- lua/plugins/neotest.lua
return {
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-neotest/nvim-nio",
			"nvim-treesitter/nvim-treesitter",
			"nvim-neotest/neotest-plenary",
			"nvim-neotest/neotest-go",
			"jfpedroza/neotest-elixir",
			"nvim-neotest/neotest-jest",
		},
		keys = {
			{
				"<leader>tn",
				function()
					require("neotest").run.run()
				end,
				desc = "Test: nearest",
			},
			{
				"<leader>tf",
				function()
					require("neotest").run.run(vim.fn.expand("%"))
				end,
				desc = "Test: file",
			},
			{
				"<leader>ts",
				function()
					require("neotest").summary.toggle()
				end,
				desc = "Test: summary",
			},
		},
		opts = {},
		config = function()
			require("neotest").setup({
				adapters = {
					require("neotest-go")({
						experimental = {
							test_table = true,
						},
						args = { "-count=1", "-timeout=60s" },
					}),
					require("neotest-jest")({
						jestCommand = "npm test --",
						jestArguments = function(defaultArguments, context)
							return defaultArguments
						end,
						jestConfigFile = "custom.jest.config.ts",
						env = { CI = true },
						cwd = function(path)
							return vim.fn.getcwd()
						end,
						isTestFile = require("neotest-jest.jest-util").defaultIsTestFile,
					}),
				},
			})
		end,
	},
}
