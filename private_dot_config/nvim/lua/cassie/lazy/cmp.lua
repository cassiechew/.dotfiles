return {
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",
			"hrsh7th/cmp-buffer",
		},
		opts = function(_, opts)
			local cmp = require("cmp")

			-- ":" command-line completion
			cmp.setup.cmdline(":", {
				mapping = cmp.mapping.preset.cmdline(),
				sources = {
					{ name = "path" },
					{ name = "cmdline" },
				},
			})

			-- "/", "?" search completion
			cmp.setup.cmdline({ "/", "?" }, {
				mapping = cmp.mapping.preset.cmdline(),
				sources = {
					{ name = "buffer" },
				},
			})
            
			vim.api.nvim_set_hl(0, "Pmenu", { link = "Comment" })
			opts.window = {
				completion = {
					winhighlight = "Normal:Pmenu,FloatBorder:FloatBorder,CursorLine:PmenuSel",
				},
				documentation = cmp.config.window.bordered({
					border = "rounded",
					winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
				}),
			}

			return opts
		end,
	},
}
