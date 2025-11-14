-- ~/.config/nvim/lua/plugins/lualine.lua
local function lsp_name()
  local buf_ft = vim.bo.filetype
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if not clients or #clients == 0 then
    return ""
  end
  for _, client in ipairs(clients) do
    local supported = client.config.filetypes
    if supported and vim.tbl_contains(supported, buf_ft) then
      return client.name
    end
  end
  return ""
end

local function task_status()
  return "overseer"
end

return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = function(_, opts)
    opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
      theme = "catppuccin",       -- works if you have catppuccin plugin loaded
      globalstatus = true,
      icons_enabled = true,
      section_separators = { left = "", right = "" },
      component_separators = { left = "│", right = "│" },
      disabled_filetypes = { "neo-tree", "NvimTree", "lazy" },
    })

    opts.sections = {
      -- LEFT
      lualine_a = { "mode" },

      lualine_b = {
        {
          "filename",
          path = 1, -- 0 = just name, 1 = relative, 2 = absolute
          symbols = { modified = " ●", readonly = " " },
        },
        {
          lsp_name,
          icon = "",
          cond = function()
            return lsp_name() ~= ""
          end,
        },
      },

      -- CENTER
      lualine_c = {
        {
          --task_status,
          "overseer",
          colored = true,
        },
      },

      -- RIGHT
      lualine_x = {
        {
          "diff",
          colored = true,
          symbols = {
            added = " ",      -- Catppuccin-colored icon for insertions
            modified = " ",   -- changes
            removed = " ",    -- deletions
          },
          padding = 1,
        },
        {
          "diagnostics",
          sources = { "nvim_diagnostic" },
          sections = { "error", "warn", "info", "hint" },
          symbols = {
            error = " ",
            warn = " ",
            info = " ",
            hint = " ",
          },
          colored = true,
          update_in_insert = false,
        },
      },
      --lualine_y = { "progress" }, -- e.g. 41%
      --lualine_z = { "location" }, -- line:col
    }

    return opts
  end,
}

