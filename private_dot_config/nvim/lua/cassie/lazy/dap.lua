-- lua/plugins/dap.lua
return {
	{
		"mfussenegger/nvim-dap",
        -- consider nvim-dap-ui
		keys = {
            {
                "<leader>dd",
                function ()
                   require("dap").toggle_breakpoint() 
                end,
                desc = "DAP toggle breakpoint"
            },
            {
                "<leader>dn",
                function ()
                   require("dap").new() 
                end,
                desc = "DAP new debug session"
            },
			{
				"<leader>dc",
				function()
					require("dap").continue()
				end,
				desc = "DAP continue",
			},
			{
				"<leader>dh",
				function()
					require("dap").step_out()
				end,
				desc = "DAP step out",
			},
			{
				"<leader>dj",
				function()
					require("dap").step_over()
				end,
				desc = "DAP step over",
			},
			{
				"<leader>dj",
				function()
					require("dap").restart_frame()
				end,
				desc = "DAP restart frame",
			},
			{
				"<leader>dj",
				function()
					require("dap").step_into()
				end,
				desc = "DAP step into",
			},
		},
	},
}

