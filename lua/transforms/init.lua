local M = {}

function M.setup(opts)
  local confmod = require("transforms.config")

  confmod.config = vim.tbl_deep_extend("force", confmod.default_config, opts or {})

end

return M
