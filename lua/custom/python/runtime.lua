local M = {}
local env = require 'custom.python.environment'

function M.run(args)
  local buf = env.source()
  if not buf or not require('runner').save_sources() then
    return
  end
  local root = env.root(buf)
  local command = { vim.fn.shellescape(env.python(root)), '-u' }
  for _, arg in ipairs(args) do
    command[#command + 1] = vim.fn.shellescape(arg)
  end
  require('runner').run_terminal(table.concat(command, ' '), root, buf)
end

function M.repl()
  M.run { '-i' }
end

function M.module(args)
  local cmd = { vim.fn.stdpath 'config' .. '/scripts/python_run.py', env.root(), 'module' }
  vim.list_extend(cmd, args)
  M.run(cmd)
end

function M.serve(args)
  local cmd = { vim.fn.stdpath 'config' .. '/scripts/python_run.py', env.root(), 'module', 'uvicorn', args[1] or 'main:app', '--reload' }
  for index = 2, #args do
    cmd[#cmd + 1] = args[index]
  end
  M.run(cmd)
end

function M.venv()
  local buf = env.source()
  if not buf then
    return
  end
  local root = env.root(buf)
  if vim.uv.fs_stat(root .. '/.venv') then
    vim.notify('.venv already exists; use :PyEnv to select it', vim.log.levels.WARN)
    return
  end
  require('custom.cpp.tasks').run('py-env', { 'uv', 'venv', '--python', env.python(root), root .. '/.venv' }, root, {
    open = true,
    title = 'Create project Python environment',
    on_exit = function(result)
      if result.code == 0 then
        env.remember(root, root .. '/.venv/bin/python')
        env.restart()
      end
    end,
  })
end

function M.sync()
  local buf = env.source()
  if not buf then
    return
  end
  local root = env.root(buf)
  if not vim.uv.fs_stat(root .. '/pyproject.toml') then
    vim.notify('uv sync requires a pyproject.toml project', vim.log.levels.WARN)
    return
  end
  require('custom.cpp.tasks').run('py-env', { 'uv', 'sync' }, root, {
    open = true,
    title = 'Synchronize project dependencies with uv',
    on_exit = function(result)
      if result.code == 0 then
        env.remember(root, root .. '/.venv/bin/python')
        env.restart()
      end
    end,
  })
end
return M
