local M = {}

local function configuration()
  vim.health.start("Configuration")
  local confmod = require("transforms.config")

  if vim.deep_equal(confmod.config, confmod.default_config) then
    vim.health.ok("using default configuration")
  else
    vim.health.info("Custom configuration:\n" .. vim.inspect(confmod.config))
  end

end

local function keymaps()
  vim.health.start("Keymaps")
  local found = false
  local maps = vim.deepcopy(vim.api.nvim_get_keymap("n"))
  vim.list_extend(maps, vim.api.nvim_get_keymap("i"))
  for _, map in ipairs(maps) do
    if map.rhs and string.match(map.rhs, "Transforms") then
      vim.health.ok(("%s %s %s"):format(map.mode, map.lhs, map.rhs))
      found = true
    end
  end
  if not found then
    vim.health.info("No custom keymaps found")
  end
end

M.check = function()
  configuration()
  keymaps()
end

return M
