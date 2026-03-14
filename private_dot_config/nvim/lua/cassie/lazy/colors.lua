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

				-- Hot pink accent palette + custom backgrounds
				color_overrides = {
					latte = {
						pink = "#FF0066",
						mauve = "#CC0052",
						base = "#FFF0F5",
						mantle = "#FFE4ED",
						crust = "#FFD6E3",
					},
					frappe = {
						pink = "#F77AB0",
						mauve = "#FF0066",
						text = "#F2F4F8",
						base = "#161616",
						mantle = "#111111",
						crust = "#0D0D0D",
					},
				},

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
						CursorLineNr = { fg = colors.pink, style = { "bold" } },
						MatchParen = { fg = colors.pink, style = { "bold" } },
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
