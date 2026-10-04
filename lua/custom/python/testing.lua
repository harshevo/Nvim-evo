local M = { generation = 0, last = {} }
local env = require 'custom.python.environment'
local tasks = require 'custom.cpp.tasks'
local helper = vim.fn.stdpath 'config' .. '/scripts/python_pytest.py'

local function read(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  local valid, data = false, nil
  if ok then
    valid, data = pcall(vim.json.decode, table.concat(lines, '\n'))
  end
  vim.fn.delete(path)
  return valid and type(data) == 'table' and data or {}
end

function M.stop()
  M.generation = M.generation + 1
  tasks.stop 'py-collect'
  tasks.stop 'py-test'
end

local function execute(root, args)
  local report = vim.fn.tempname() .. '.json'
  local cmd = { env.python(root), '-u', helper, report, '--color=no', '--tb=short', '-q' }
  vim.list_extend(cmd, args)
  M.last[root] = vim.deepcopy(args)
  tasks.run('py-test', cmd, root, {
    open = true,
    title = 'pytest (' .. vim.fs.basename(root) .. ')',
    decorate = function(s)
      local data = read(report)
      for row, line in ipairs(s.lines) do
        for _, failure in ipairs(data.failures or {}) do
          if line:find('FAILED ' .. failure.id, 1, true) then
            s.locations[row] = { file = failure.file, line = failure.line }
            break
          end
        end
      end
      s.tests = data.tests
      s.failures = data.failures
    end,
  })
end

function M.run(mode)
  local buf = env.source()
  if not buf or not require('runner').save_sources() then
    return
  end
  M.stop()
  local generation, root = M.generation, env.root(buf)
  local file, cursor = vim.api.nvim_buf_get_name(buf), vim.api.nvim_win_get_cursor(vim.fn.win_findbuf(buf)[1] or 0)[1]
  if mode == 'last' then
    execute(root, M.last[root] or {})
  elseif mode == 'failed' then
    execute(root, { '--lf', '--last-failed-no-failures=none' })
  elseif mode == 'file' then
    execute(root, { file })
  elseif mode == 'select' or mode == 'nearest' then
    local report = vim.fn.tempname() .. '.json'
    tasks.run('py-collect', { env.python(root), helper, report, '--collect-only', '--color=no', '-q' }, root, {
      open = true,
      title = 'Discovering pytest tests',
      on_exit = function(result)
        local tests = read(report).tests or {}
        if generation ~= M.generation then
          return
        end
        if result.code ~= 0 or #tests == 0 then
          vim.notify('No tests collected; see discovery output', vim.log.levels.WARN)
          return
        end
        if mode == 'nearest' then
          local line, choices = -1, {}
          for _, test in ipairs(tests) do
            if (vim.uv.fs_realpath(test.file) or test.file) == (vim.uv.fs_realpath(file) or file) and test.line <= cursor then
              if test.line > line then
                line, choices = test.line, {}
              end
              if test.line == line then
                choices[#choices + 1] = test.id
              end
            end
          end
          if #choices == 0 then
            vim.notify('Place the cursor inside a collected test', vim.log.levels.WARN)
          else
            tasks.close 'py-collect'
            execute(root, choices)
          end
        else
          vim.ui.select(tests, {
            prompt = 'pytest test',
            format_item = function(test)
              return test.id
            end,
          }, function(test)
            if test and generation == M.generation then
              tasks.close 'py-collect'
              execute(root, { test.id })
            end
          end)
        end
      end,
    })
  else
    execute(root, {})
  end
end

function M.install()
  local buf = env.source()
  if not buf then
    return
  end
  local root = env.root(buf)
  tasks.run(
    'py-env',
    { 'uv', 'pip', 'install', '--python', env.python(root), 'pytest' },
    root,
    { open = true, title = 'Install pytest in selected Python environment' }
  )
end
return M
