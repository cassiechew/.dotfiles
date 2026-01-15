return {
	"neovim/nvim-lspconfig",
	dependencies = {
		"stevearc/conform.nvim",
		"williamboman/mason.nvim",
		"williamboman/mason-lspconfig.nvim",
        "WhoIsSethDaniel/mason-tool-installer.nvim",
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-buffer",
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-cmdline",
		"hrsh7th/nvim-cmp",
		"L3MON4D3/LuaSnip",
		"saadparwaiz1/cmp_luasnip",
		"j-hui/fidget.nvim",
		"onsails/lspkind.nvim",
		"RRethy/vim-illuminate",
	},
	opts = {
		setup = {
			["*"] = function(server_opts)
				local original_on_attach = server_opts.on_attach

				server_opts.on_attach = function(client, bufnr)
					-- Call LazyVim's original on_attach (important!)
					if original_on_attach then
						original_on_attach(client, bufnr)
					end
					vim.keymap.set("n", "gd", vim.lsp.buf.definition)
					vim.keymap.set("n", "K", vim.lsp.buf.hover)
					vim.keymap.set("n", "<leader>vws", vim.lsp.buf.workspace_symbol)
					vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float)
					vim.keymap.set("n", "[d", vim.diagnostic.goto_next)
					vim.keymap.set("n", "]d", vim.diagnostic.goto_prev)
					vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action)
					vim.keymap.set("n", "<leader>vrr", vim.lsp.buf.references)
					vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename)
				end
				return true
			end,
		},
	},
	config = function()
		require("conform").setup({
			formatters_by_ft = {
				go = { "gofumpt", "goimports" },
				elixir = { "mix" },
				eelixir = { "mix" },
				heex = { "mix" },
				surface = { "mix" },
				lua = { "stylua" },
                graphql = { "prettier"},
                typescript = { "prettier" },
			},
		})

		vim.keymap.set({ "n", "v" }, "<leader>fm", function()
			require("conform").format()
		end, { desc = "Format code" })

		local cmp = require("cmp")
		local cmp_lsp = require("cmp_nvim_lsp")
		local capabilities = vim.tbl_deep_extend(
			"force",
			{},
			vim.lsp.protocol.make_client_capabilities(),
			cmp_lsp.default_capabilities()
		)

		require("fidget").setup({
			progress = {
				display = {
					done_icon = "✓", -- icon for completed tasks
				},
			},
			notification = {
				window = {
					normal_hl = "Comment",
					winblend = 0,
					--- border = "rounded",
				},
			},
			view = {
				stack_upwards = true, -- Display notification items from bottom to top
				align = "message", -- Indent messages longer than a single line
				reflow = false, -- Reflow (wrap) messages wider than notification window
				icon_separator = " ", -- Separator between group name and icon
				group_separator = "---", -- Separator between notification groups
				-- Highlight group used for group separator
				group_separator_hl = "Comment",
				line_margin = 1, -- Spaces to pad both sides of each non-empty line
				-- How to render notification messages
				render_message = function(msg, cnt)
					return cnt == 1 and msg or string.format("(%dx) %s", cnt, msg)
				end,
			},
		})

		require("mason").setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		require("mason-lspconfig").setup({
			ensure_installed = {
				"lua_ls",
				"rust_analyzer",
				"gopls",
				"elixirls",
                "vtsls",
			},
			handlers = {
				function(server_name) -- default handler (optional)
					require("lspconfig")[server_name].setup({
						capabilities = capabilities,
					})
				end,

				lua_ls = function()
					local lspconfig = require("lspconfig")
					require("neodev").setup()
					lspconfig.lua_ls.setup({

						capabilities = capabilities,
						settings = {
							Lua = {
								runtime = {
									version = "LuaJIT",
								},
								diagnostics = {
									globals = {
										"vim",
										"require",
									},
								},
								format = {
									enable = true,
									-- Put format options here
									-- NOTE: the value should be STRING!!
									defaultConfig = {
										indent_style = "space",
										indent_size = "2",
									},
								},
							},
						},
					})
				end,
			},
		})

        require('mason-tool-installer').setup {
            ensure_installed = {

                { 'golangci-lint', condition = function() return vim.fn.executable('go') == 1  end },
                { 'gofumpt', condition = function() return vim.fn.executable('go') == 1  end },
                { 'goimports', condition = function() return vim.fn.executable('go') == 1  end },
                { 'stylua', condition = function() return vim.fn.executable('lua') == 1  end },
            }
        }

		local cmp_select = { behavior = cmp.SelectBehavior.Select }
		cmp.setup({
			experimental = {
				ghost_text = true,
			},
			snippet = {
				expand = function(args)
					require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
				end,
			},
			mapping = cmp.mapping.preset.insert({
				["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
				["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
				["<Tab>"] = cmp.mapping.select_next_item(cmp_select),
				["<S-Tab>"] = cmp.mapping.select_prev_item(cmp_select),
				["<CR>"] = function(fallback)
					if cmp.visible() then
						cmp.confirm({ select = true })
						vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
					else
						fallback()
					end
				end,
				["<C-Space>"] = cmp.mapping.complete(),
                ["<Right>"] = function(fallback)
					if cmp.visible() then
						cmp.confirm({ select = true })
					else
						fallback()
					end
				end,
                ["<S-CR>"] = function(fallback)
					if cmp.visible() then
						cmp.confirm({ select = true })
					else
						fallback()
					end
				end,
			}),
			sources = cmp.config.sources({
				{ name = "copilot", group_index = 2 },
				{ name = "nvim_lsp" },
				{ name = "path" },
				{ name = "luasnip" }, -- For luasnip users.
			}, {
				{ name = "buffer" },
			}),
			-- formatting = {
			--     format = lspkind.cmp_format({
			--         mode = "symbol_text",
			--         maxwidth = 50,
			--         ellipsis_char = "…"
			--     })
			-- }
		})

		vim.diagnostic.config({
			-- update_in_insert = true,
			float = {
				focusable = false,
				style = "minimal",
				border = "rounded",
				source = "always",
				header = "",
				prefix = "",
			},
		})
	end,
}
