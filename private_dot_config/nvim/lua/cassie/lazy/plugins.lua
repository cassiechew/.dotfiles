return {
	{
		'lambdalisue/vim-nerdfont',
		lazy = false,  -- load immediately if needed
	},

	{
		'nvim-tree/nvim-web-devicons',
		lazy = false,  -- needed by many UI plugins
	},

	{
		'ryanoasis/vim-devicons',
		lazy = false,  -- also icon related
	},

	{
		'nixprime/cpsm',
		lazy = true,  -- unless required immediately by another plugin
	},
	{
		'romgrk/fzy-lua-native',
		build = 'make',
		lazy = true, -- or false if you want it loaded immediately
	}
}
