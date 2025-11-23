local function is_daytime()
	-- 24h format, local time
	local hour = tonumber(os.date("%H"))
	-- adjust these if you want different "sun up/down" times
	return hour >= 7 and hour < 18
end

return {
	-- {
	-- 	"scottmckendry/cyberdream.nvim",
	-- 	lazy = false,
	-- 	priority = 1000,
	-- },
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		config = function()
			vim.opt.termguicolors = true

			local day = is_daytime()
			local flavour = day and "latte" or "frappe"
			local bg = day and "light" or "dark"

			vim.o.background = bg

			require("catppuccin").setup({
				flavour = flavour,
				background = {
					light = "latte",
					dark = "frappe",
				},

				transparent_background = false,

				integrations = {
                    noice = true,
					overseer = true,
					cmp = true,
					gitsigns = true,
					nvimtree = true,
					telescope = true,
                    notify = true,
					fidget = true,
					mini = {
						enabled = true,
						indentscope_color = "",
					},
					treesitter = true,
					lsp_trouble = true,
					which_key = true,
					illuminate = false,
					native_lsp = {
						enabled = true,
						underlines = {
							errors = { "underline" },
							hints = { "underline" },
							warnings = { "underline" },
							information = { "underline" },
						},
					},
				},

				custom_highlights = function(colors)
					return {
						-- NormalFloat = { bg = "NONE" },
						-- FloatBorder = { bg = "NONE" },
					}
				end,
			})

			vim.cmd.colorscheme("catppuccin")
			vim.api.nvim_set_hl(0, "Cursor", { bg = "#FF0066", fg = "#FFFFFF" })
			vim.api.nvim_set_hl(0, "Cursor2", { bg = "#FF0066", fg = "#1e1e1e" })
			vim.o.guicursor = "n-v-c:block-Cursor,i-ci-ve:ver25-Cursor2"
		end,
	},
}
