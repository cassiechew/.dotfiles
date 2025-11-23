-- lua/plugins/neotest.lua
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-plenary",
      "nvim-neotest/neotest-go",
      "jfpedroza/neotest-elixir",
    },
    keys = {
      { "<leader>tn", function() require("neotest").run.run() end, desc = "Test: nearest" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Test: file" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Test: summary" },
    },
    opts = {},
  },
}

