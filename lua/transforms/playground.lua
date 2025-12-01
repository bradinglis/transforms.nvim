local M = {}
local ns = vim.api.nvim_create_namespace("transforms")
local augroup = vim.api.nvim_create_augroup("transforms", {})

local function show_error(msg)
  vim.notify("transforms: " .. msg, vim.log.levels.ERROR, {})
end

local function input_args(input)

  if type(input) == "number" and vim.api.nvim_buf_is_valid(input) then
    return vim.api.nvim_buf_get_lines(input, 0, -1, false)
  end

  show_error("invalid input: " .. input)
end

local function run_query(cmd, input, query_buf, output_buf)
  local cli_args = vim.deepcopy(cmd)

  local filter_lines = vim.api.nvim_buf_get_lines(query_buf, 0, -1, false)
  local filter = table.concat(filter_lines, "\n")
  table.insert(cli_args, filter)

  local stdin = input_args(input)

  local on_exit = function(result)
    vim.schedule(function()
      local out = result.code == 0 and result.stdout or result.stderr
      local lines = vim.split(out, "\n", { plain = true })
      vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, lines)
    end)
  end

  local ok, _ = pcall(vim.system, cli_args, { stdin = stdin }, on_exit)
end

local function resolve_winsize(num, max)
  if num == nil or (1 <= num and num <= max) then
    return num
  elseif 0 < num and num < 1 then
    return math.floor(num * max)
  else
    show_error(string.format("incorrect winsize, received %s of max %s", num, max))
  end
end

local function create_split_buf(opts, before_filetype_callback)
  local buf = vim.fn.bufnr(opts.name)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(true, opts.scratch)

    -- Execute callback before setting filetype to ensure buffer variables are
    -- available to ftplugin scripts and FileType autocmds that get triggered
    if vim.is_callable(before_filetype_callback) then
      before_filetype_callback(buf)
    end

    vim.bo[buf].filetype = opts.filetype
    vim.api.nvim_buf_set_name(buf, opts.name)
  end

  local height = resolve_winsize(opts.height, vim.api.nvim_win_get_height(0))
  local width = resolve_winsize(opts.width, vim.api.nvim_win_get_width(0))

  local winid = vim.api.nvim_open_win(buf, true, {
    split = opts.split_direction,
    width = width,
    height = height,
  })

  return buf, winid
end

local function virt_text_hint(buf, hint)
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_text = { { hint, "Conceal" } },
  })

  -- Delete hint about running the query as soon as the user does something
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertEnter" }, {
    once = true,
    group = augroup,
    buffer = buf,
    callback = function()
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end,
  })
end

function M.init_playground(in_filename, transform_filename, opts)
  local cfg = require('transforms.config').config

  if in_filename then
    vim.cmd('e ' .. in_filename)
  end

  local curbuf = vim.api.nvim_get_current_buf()
  local match_args = in_filename and { filename = in_filename } or { buf = curbuf }

  local query_lang = vim.filetype.match({ filename = transform_filename })
  cfg.output_window.filetype = vim.filetype.match(match_args)

  cfg.cmd = opts.command or { "bash", "-c" }

  vim.bo[curbuf].filetype = opts.input_lang
  cfg.output_window.filetype = opts.output_lang or opts.input_lang
  cfg.query_window.filetype = opts.query_lang or query_lang

  -- Create output buffer first
  local output_buf, _ = create_split_buf(cfg.output_window)
  vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, {})

  -- And then query buffer
  local query_buf, _ = create_split_buf(cfg.query_window, function(new_buf)
    vim.b[new_buf].transforms_inputbuf = curbuf
  end)

  if transform_filename then
    vim.cmd('e ' .. transform_filename)
    query_buf = vim.api.nvim_get_current_buf()
  else
    virt_text_hint(query_buf, "Run your query with <CR>.")
  end

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup,
    buffer = query_buf,
    callback = function()
      run_query(cfg.cmd, curbuf, query_buf, output_buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = augroup,
    buffer = curbuf,
    callback = function()
      run_query(cfg.cmd, curbuf, query_buf, output_buf)
    end,
  })

  vim.keymap.set({ "n", "i" }, "<Plug>(TransformRun)", function()
    run_query(cfg.cmd, curbuf, query_buf, output_buf)
  end, {
    buffer = query_buf,
    silent = true,
    desc = "Transform Run",
  })
  run_query(cfg.cmd, curbuf, query_buf, output_buf)

  -- To have a sensible default. Does not require user to define one
  if not cfg.disable_default_keymap then
    vim.keymap.set({ "n" }, "<CR>", "<Plug>(TransformRun)", {
      desc = "Default for Transforms",
    })
  end
end

return M
