-- ~/.config/nvim/lua/plugins/lualine.lua
-- Highlight setup for git statusline that adapts to the current colorscheme
local function setup_gitstatus_highlights()
  local set_hl = vim.api.nvim_set_hl

  -- link to generic groups that Catppuccin (or any theme) will recolor
  set_hl(0, "GitStatusIcon",     { link = "Special" })     -- icon color
  set_hl(0, "GitStatusRepo",     { link = "Directory" })   -- repo name
  set_hl(0, "GitStatusUpstream", { link = "Identifier" })  -- upstream branch

  set_hl(0, "GitStatusAhead",    { link = "DiffAdd" })     -- ↑ ahead
  set_hl(0, "GitStatusBehind",   { link = "DiffDelete" })  -- ↓ behind

  set_hl(0, "GitStatusAdded",    { link = "DiffAdd" })     -- +N
  set_hl(0, "GitStatusModified", { link = "DiffChange" })  -- ~N
  set_hl(0, "GitStatusRemoved",  { link = "DiffDelete" })  -- -N
end

-- Re-apply links whenever the colorscheme changes (Catppuccin flavour switch)
local gitstatus_group = vim.api.nvim_create_augroup("GitStatusHighlights", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = gitstatus_group,
  callback = setup_gitstatus_highlights,
})

-- Also run once on startup
setup_gitstatus_highlights()

local function colored(text, hl)
  return "%#" .. hl .. "#" .. text .. "%#Normal#"
end

local function git_statusline()
  -- Are we in a git repo?
  local root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
  if not root or root == "" then
    return ""
  end

  local repo = vim.fn.fnamemodify(root, ":t")

  -- Branch & upstream
  local branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD 2>/dev/null")[1] or ""
  local upstream = vim.fn.systemlist("git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null")[1] or ""

  -- Ahead / behind
  local ahead, behind = "", ""
  if upstream ~= "" then
    local counts = vim.fn.systemlist("git rev-list --left-right --count HEAD..." .. upstream .. " 2>/dev/null")[1]
    if counts and counts ~= "" then
      local a, b = counts:match("(%d+)%s+(%d+)")
      if a and tonumber(a) > 0 then ahead = colored("↑" .. a, "GitStatusAhead") end
      if b and tonumber(b) > 0 then behind = colored("↓" .. b, "GitStatusBehind") end
    end
  end

  -- Working tree file changes (added / modified / removed / untracked)
  local status_lines = vim.fn.systemlist("git status --porcelain 2>/dev/null")
  local added, modified, removed = 0, 0, 0

  for _, line in ipairs(status_lines) do
    -- format: "XY path"
    local x = line:sub(1, 1)
    local y = line:sub(2, 2)
    local code = x ~= " " and x or y

    if code == "A" or code == "R" or code == "C" or code == "?" then
      added = added + 1
    elseif code == "M" then
      modified = modified + 1
    elseif code == "D" then
      removed = removed + 1
    end
  end

  local parts = {}

  -- icon + repo
  table.insert(parts, colored(" ", "GitStatusIcon") .. colored(repo, "GitStatusRepo"))

  -- remote branch (or local if no upstream)
  if upstream ~= "" then
    table.insert(parts, colored(upstream, "GitStatusUpstream"))
  elseif branch ~= "" then
    table.insert(parts, colored(branch, "GitStatusUpstream"))
  end

  -- ahead/behind
  local ab = {}
  if ahead ~= "" then table.insert(ab, ahead) end
  if behind ~= "" then table.insert(ab, behind) end
  if #ab > 0 then
    table.insert(parts, table.concat(ab, " "))
  end

  -- file changes
  local changes = {}
  if added > 0 then table.insert(changes, colored("+" .. added, "GitStatusAdded")) end
  if modified > 0 then table.insert(changes, colored("~" .. modified, "GitStatusModified")) end
  if removed > 0 then table.insert(changes, colored("-" .. removed, "GitStatusRemoved")) end
  if #changes > 0 then
    table.insert(parts, table.concat(changes, " "))
  end

  return table.concat(parts, "  ")
end

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
      section_separators = { left = "", right = "" },
      component_separators = { left = " ", right = " " },
      disabled_filetypes = { "neo-tree", "NvimTree", "lazy" },
      refresh = {
        statusline = 200,
        winbar = 200,
      },
    })

    opts.winbar = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = {},
      lualine_x = {
        {
          git_statusline,
          --color = { fg = "#89b4fa" },  -- optional: catppuccin blue
          cond = function()
            -- only show if we're in a git repo
            return vim.fn.system("git rev-parse --is-inside-work-tree 2>/dev/null") == "true\n"
          end,
        },
        {
          "diff",
          colored = true,
          symbols = {
            added    = "+",
            modified = "~",
            removed  = "-",
          },
          padding = { left = 1, right = 0 },
        },
      },
      lualine_y = {},
      lualine_z = {},
    }

    opts.inactive_winbar = {
      lualine_a = { "filename" },
      lualine_z = {},
    }

    opts.sections = {
      -- LEFT
      lualine_a = { "mode" },
      lualine_b = {},

      -- CENTER
      lualine_c = {
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
        {
          "filetype",
          icon_only = true,
          separator = "",
          padding = { left = 1, right = 1 },
        },
      },
      lualine_y = {},
      lualine_z = {}
      --lualine_y = { "progress" }, -- e.g. 41%
      --lualine_z = { "location" }, -- line:col
    }

    return opts
  end,
}

