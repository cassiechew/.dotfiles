-- lua/plugins/surround.lua
-- Keybinds are hard
-- https://github.com/kylechui/nvim-surround?tab=readme-ov-file#rocket-usage

return {
	{
		"kylechui/nvim-surround",
		version = "*",
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup({})
		end,
	},
}
