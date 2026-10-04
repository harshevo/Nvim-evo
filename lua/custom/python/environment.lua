local M = { last_buf = nil }
local selected = {}
local markers = { { 'pyproject.toml', 'pyrightconfig.json', 'pytest.ini', 'setup.py', 'setup.cfg', 'Pipfile', 'requirements.txt', '.venv' }, '.git' }

function M.source()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype == '' and vim.bo[buf].filetype == 'python' then
    M.last_buf = buf
    if _G.RunNowState then
      RunNowState.source_buf = buf
    end
  else
    buf = M.last_buf
  end
  if buf and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) ~= '' then
    return buf
  end
  vim.notify('Open a named Python file first', vim.log.levels.WARN)
end

function M.root(buf)
  local current = vim.api.nvim_get_current_buf()
  buf = buf or (vim.bo[current].buftype == '' and vim.bo[current].filetype == 'python' and current) or M.last_buf or 0
  local file = vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) or ''
  local root = file ~= '' and (vim.fs.root(file, markers) or vim.fs.dirname(file)) or vim.fn.getcwd()
  return vim.uv.fs_realpath(root) or root
end

local function state_path(root)
  local dir = vim.fn.stdpath 'state' .. '/python-ide/projects'
  vim.fn.mkdir(dir, 'p')
  return dir .. '/' .. vim.fn.sha256(root) .. '.json'
end

function M.selection(root)
  root = root or M.root()
  root = vim.uv.fs_realpath(root) or root
  if selected[root] == nil then
    local ok, lines = pcall(vim.fn.readfile, state_path(root))
    local parsed, data = false, nil
    if ok then
      parsed, data = pcall(vim.json.decode, table.concat(lines, '\n'))
    end
    selected[root] = parsed and type(data) == 'table' and type(data.python) == 'string' and data.python ~= '' and data.python or false
  end
  return selected[root] or nil
end

function M.python(root)
  root = root or M.root()
  root = vim.uv.fs_realpath(root) or root
  local chosen = M.selection(root)
  if chosen and vim.fn.executable(chosen) == 1 then
    return chosen
  end
  for _, dir in ipairs { root .. '/.venv', root .. '/venv', root .. '/env', vim.env.VIRTUAL_ENV or '', vim.env.CONDA_PREFIX or '' } do
    if dir ~= '' and vim.fn.executable(dir .. '/bin/python') == 1 then
      return dir .. '/bin/python'
    end
  end
  local path = vim.fn.exepath 'python3'
  if path == '' then
    path = vim.fn.exepath 'python'
  end
  return path
end

function M.tool_python()
  return vim.fn.stdpath 'data' .. '/python-tools/bin/python'
end

function M.tool(name, root)
  root = root or M.root()
  local python = M.python(root)
  for _, path in ipairs { vim.fs.dirname(python) .. '/' .. name, vim.fn.stdpath 'data' .. '/python-tools/bin/' .. name, vim.fn.exepath(name) } do
    if path ~= '' and vim.fn.executable(path) == 1 then
      return path
    end
  end
  return name
end

function M.remember(root, path)
  root = vim.uv.fs_realpath(root) or root
  selected[root] = path or false
  vim.fn.writefile({ vim.json.encode { python = path } }, state_path(root))
end

function M.restart()
  for _, client in ipairs(vim.lsp.get_clients { name = 'pyright' }) do
    local path = M.python(client.config.root_dir)
    client.settings.python = vim.tbl_deep_extend('force', client.settings.python or {}, { pythonPath = path })
    client:notify('workspace/didChangeConfiguration', { settings = client.settings })
  end
end

function M.choose(path)
  local buf = M.source()
  if not buf then
    return
  end
  local root = M.root(buf)
  local function activate(value)
    if not value then
      return
    end
    if value == 'auto' then
      M.remember(root, nil)
    else
      value = vim.fn.fnamemodify(vim.fn.expand(value), ':p'):gsub('/$', '')
      if vim.fn.isdirectory(value) == 1 then
        value = value .. '/bin/python'
      end
      if vim.fn.executable(value) ~= 1 then
        vim.notify('Python executable not found: ' .. value, vim.log.levels.ERROR)
        return
      end
      M.remember(root, value)
    end
    M.restart()
    vim.notify('Python: ' .. M.python(root))
  end
  if path then
    activate(path)
    return
  end
  local choices, seen = { 'auto' }, {}
  local function add(value)
    if value and value ~= '' and not seen[value] and vim.fn.executable(value) == 1 then
      seen[value] = true
      choices[#choices + 1] = value
    end
  end
  add(M.python(root))
  for _, dir in ipairs { root .. '/.venv', root .. '/venv', root .. '/env', vim.env.VIRTUAL_ENV or '', vim.env.CONDA_PREFIX or '' } do
    if dir ~= '' then
      add(dir .. '/bin/python')
    end
  end
  add(vim.fn.exepath 'python3')
  choices[#choices + 1] = 'Enter interpreter/environment path...'
  vim.ui.select(choices, { prompt = 'Python environment (' .. vim.fs.basename(root) .. ')' }, function(value)
    if value == 'Enter interpreter/environment path...' then
      vim.ui.input({ prompt = 'Python executable or environment: ', completion = 'file' }, activate)
    else
      activate(value)
    end
  end)
end

function M.info()
  local buf = M.source()
  if buf then
    local root = M.root(buf)
    vim.notify('Project: ' .. root .. '\nPython: ' .. M.python(root) .. '\nRuff: ' .. M.tool('ruff', root))
  end
end
return M
