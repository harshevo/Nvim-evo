local M = {}
local last, cached = {}, {}
local request_generation, build_generation = 0, nil
local project = require 'custom.cpp.project'
local tasks = require 'custom.cpp.tasks'

local function discover(root, dir, done)
  vim.system({ 'ctest', '--test-dir', dir, '--show-only=json-v1' }, { text = true, cwd = root }, function(result)
    vim.schedule(function()
      local ok, data = pcall(vim.json.decode, result.stdout or '')
      if result.code ~= 0 or not ok then
        tasks.run('test', { 'ctest', '--test-dir', dir, '--show-only' }, root, { open = true })
        done(nil)
        return
      end
      cached[dir] = data
      done(data)
    end)
  end)
end

local function source(data, test)
  local graph = data.backtraceGraph or {}
  local node = graph.nodes and graph.nodes[(test.backtrace or -1) + 1]
  if node and node.file and graph.files then
    return { file = graph.files[node.file + 1], line = node.line or 1, col = 1 }
  end
end

local function run(root, dir, choice)
  local cmd = { 'ctest', '--test-dir', dir, '--output-on-failure', '--no-tests=error', '--parallel', '4' }
  if choice == 'failed' then
    cmd[#cmd + 1] = '--rerun-failed'
  elseif choice then
    vim.list_extend(cmd, { '-R', '^' .. choice:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?%{%}%|])', function(c)
      return string.char(92) .. c
    end) .. '$' })
  end
  last[root] = choice or 'all'
  tasks.run('test', cmd, root, {
    title = 'CTest: ' .. (choice or 'all tests'),
    open = true,
    decorate = function(s)
      local data = cached[dir] or {}
      for row, line in ipairs(s.lines) do
        local name = line:match 'Test%s+#%d+:%s+(.-)%s+%.%.%.'
        if name then
          for _, test in ipairs(data.tests or {}) do
            if test.name == name then
              s.locations[row] = source(data, test)
            end
          end
        end
      end
    end,
  })
end

function M.run(choice)
  local root = project.root()
  if not vim.uv.fs_stat(root .. '/CMakeLists.txt') then
    vim.notify('Register project tests with CMake/CTest to use the test runner', vim.log.levels.WARN)
    return
  end
  request_generation = request_generation + 1
  local generation = request_generation
  tasks.stop 'test'
  local s = tasks.states.test
  s.result = nil
  s.lines = { 'CTest', 'Building test project...', '' }
  s.locations = {}
  s.cwd = root
  local started = require('runner').build(function(ok, _, _, metadata)
    if generation ~= request_generation then
      return
    end
    if not ok then
      s.result = { code = 1, signal = 0, stdout = '', stderr = 'Build failed; tests were not run' }
      s.lines = { 'CTest', 'Build failed; tests were not run. See compiler errors.' }
      tasks.refresh 'test'
      return
    end
    local dir = metadata.build_dir or project.build_dir(root)
    discover(root, dir, function(data)
      if generation ~= request_generation then
        return
      end
      if not data then
        return
      end
      if choice == 'select' then
        if #(data.tests or {}) == 0 then
          vim.notify('No CTest tests registered', vim.log.levels.WARN)
          return
        end
        vim.ui.select(data.tests, {
          prompt = 'Run CTest test:',
          format_item = function(item)
            return item.name
          end,
        }, function(test)
          if test and generation == request_generation then
            run(root, dir, test.name)
          end
        end)
      else
        local selected = choice == 'last' and last[root] or choice
        run(root, dir, selected == 'all' and nil or selected)
      end
    end)
  end)
  if not started then
    s.result = { code = 1, signal = 0, stdout = '', stderr = 'Unable to start test build' }
    s.lines = { 'CTest', 'Unable to start test build; check source saves and compiler errors.' }
    tasks.refresh 'test'
    return
  end
  build_generation = RunNowState.generation
  tasks.open 'test'
end

function M.toggle()
  tasks.toggle 'test'
end
function M.stop()
  request_generation = request_generation + 1
  if build_generation == RunNowState.generation and RunNowState.build then
    require('runner').stop_build()
  end
  tasks.stop 'test'
  local s = tasks.states.test
  if s then
    s.lines = { 'CTest', 'Cancelled' }
    tasks.refresh 'test'
  end
end
return M
