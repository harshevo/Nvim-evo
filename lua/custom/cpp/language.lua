local M = {}

local function database(root)
  local selected = require('custom.cpp.project').selected(root)
  if selected and vim.uv.fs_stat(selected.build_dir .. '/compile_commands.json') then
    return selected.build_dir
  end
  for _, dir in ipairs {
    '',
    'out/Debug',
    'out/Release',
    'out/RelWithDebInfo',
    'build',
    'cmake-build-debug',
    'cmake-build-release',
    'build/Debug',
    'build/Release',
  } do
    local path = root .. (dir ~= '' and '/' .. dir or '')
    if vim.uv.fs_stat(path .. '/compile_commands.json') then
      return path
    end
  end
end

local function standalone_command(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  file = vim.uv.fs_realpath(file) or file
  if file == '' or not vim.tbl_contains({ 'c', 'cpp' }, vim.bo[bufnr].filetype) then
    return
  end
  if vim.fs.root(file, { '.clangd', 'compile_commands.json', 'compile_flags.txt', 'CMakeLists.txt', 'Makefile', 'makefile' }) then
    return
  end
  local is_c = vim.bo[bufnr].filetype == 'c'
  return file,
    {
      workingDirectory = vim.fs.dirname(file),
      compilationCommand = { is_c and 'clang' or 'clang++', '-x', is_c and 'c' or 'c++', is_c and '-std=c17' or '-std=c++20', '-Wall', '-Wextra', file },
    }
end

function M.configure(params, config)
  local options = vim.deepcopy(config.init_options or {})
  options.compilationDatabasePath = database(config.root_dir or vim.fn.getcwd())
  options.compilationDatabaseChanges = vim.empty_dict()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local file, command = standalone_command(buf)
      if file and not options.compilationDatabasePath then
        options.compilationDatabaseChanges[file] = command
      end
    end
  end
  config.init_options = options
  params.initializationOptions = options
end

function M.attach(bufnr)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'clangd' })[1]
  local file, command = standalone_command(bufnr)
  if file and client and not client.config.init_options.compilationDatabasePath then
    client:notify('workspace/didChangeConfiguration', { settings = { compilationDatabaseChanges = { [file] = command } } })
  end
  local function map(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = desc })
  end
  map('<leader>ch', function()
    client:request('textDocument/switchSourceHeader', { uri = vim.uri_from_bufnr(bufnr) }, function(err, uri)
      if err or not uri or uri == '' then
        vim.notify 'No matching source/header found'
        return
      end
      vim.cmd.edit(vim.fn.fnameescape(vim.uri_to_fname(uri)))
    end, bufnr)
  end, 'Switch source/header')
  map('<leader>ci', function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = bufnr }, { bufnr = bufnr })
  end, 'Toggle parameter/type hints')
  map('<leader>cw', function()
    require('telescope.builtin').lsp_dynamic_workspace_symbols()
  end, 'Search project symbols')
  map('<leader>cI', vim.lsp.buf.incoming_calls, 'Show callers')
  map('<leader>cO', vim.lsp.buf.outgoing_calls, 'Show callees')
  map('gi', vim.lsp.buf.implementation, 'Go to implementation')
  map('<leader>cs', function()
    require('telescope.builtin').lsp_document_symbols()
  end, 'Search file symbols')
end

function M.setup_buffer(bufnr)
  if vim.b[bufnr].large_file then
    return
  end
  local function map(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buffer = bufnr, desc = desc })
  end
  map('K', function()
    require('custom.cpp.docs').hover()
  end, 'Function signature and documentation')
  map('<leader>cm', function()
    require('custom.cpp.docs').manual()
  end, 'System manual for symbol')
  map('<leader>cR', function()
    require('custom.cpp.docs').reference()
  end, 'Search cppreference')
  map('<leader>cf', function()
    require('conform').format { async = true, lsp_format = 'never' }
  end, 'Format with Allman braces')
end

function M.restart()
  vim.lsp.enable('clangd', false)
  vim.defer_fn(function()
    vim.lsp.enable 'clangd'
    if vim.v.vim_did_enter == 0 then
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' then
          vim.api.nvim_exec_autocmds('FileType', { group = 'nvim.lsp.enable', buffer = buf })
        end
      end
    end
  end, 100)
end

return M
