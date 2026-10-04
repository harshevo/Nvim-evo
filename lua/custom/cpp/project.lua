local M = {}
local selections = {}

function M.root(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr or 0)
  if vim.bo[bufnr or 0].buftype ~= '' or file == '' then
    local source = _G.RunNowState and _G.RunNowState.source_buf
    file = source and vim.api.nvim_buf_is_valid(source) and vim.api.nvim_buf_get_name(source) or vim.fn.getcwd()
  end
  local root = vim.fs.root(
    file,
    { { 'CMakePresets.json', 'CMakeUserPresets.json', 'CMakeLists.txt', 'Makefile', 'makefile', 'compile_commands.json' }, '.git' }
  ) or (vim.uv.fs_stat(file) and vim.uv.fs_stat(file).type == 'directory' and file or vim.fs.dirname(file))
  return vim.uv.fs_realpath(root) or root
end

function M.read(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return
  end
  local valid, value = pcall(vim.json.decode, table.concat(lines, '\n'))
  if valid then
    return value
  end
end

function M.state_path(root)
  local dir = vim.fn.stdpath 'state' .. '/cpp-ide/projects'
  vim.fn.mkdir(dir, 'p')
  return dir .. '/' .. vim.fn.sha256(root) .. '.json'
end

function M.selected(root)
  root = vim.uv.fs_realpath(root) or root
  if selections[root] == nil then
    selections[root] = M.read(M.state_path(root)) or false
  end
  return selections[root] or nil
end

function M.remember(root, value)
  root = vim.uv.fs_realpath(root) or root
  selections[root] = value
  vim.fn.writefile({ vim.json.encode(value) }, M.state_path(root))
end

function M.build_dir(root)
  local selected = M.selected(root)
  if selected and selected.build_dir then
    return selected.build_dir
  end
  for _, dir in ipairs { 'out/Debug', 'out/Release', 'out/RelWithDebInfo', 'build', 'cmake-build-debug', 'cmake-build-release' } do
    if vim.uv.fs_stat(root .. '/' .. dir .. '/CMakeCache.txt') then
      return root .. '/' .. dir
    end
  end
  return root .. '/build'
end

function M.configure_command(root, dir)
  local selected = M.selected(root)
  if selected and selected.preset then
    return 'cmake --preset ' .. vim.fn.shellescape(selected.preset) .. ' -DCMAKE_EXPORT_COMPILE_COMMANDS=ON'
  end
  local args = { 'cmake', '-S', root, '-B', dir, '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' }
  if not vim.uv.fs_stat(dir .. '/CMakeCache.txt') then
    vim.list_extend(args, { '-DCMAKE_BUILD_TYPE=Debug' })
    if vim.fn.executable 'ninja' == 1 then
      vim.list_extend(args, { '-G', 'Ninja' })
    end
  end
  local cache = M.read(root .. '/.nvim-run.json') or {}
  if vim.fn.executable 'ccache' == 1 and cache.ccache ~= false then
    vim.list_extend(args, { '-DCMAKE_C_COMPILER_LAUNCHER=ccache', '-DCMAKE_CXX_COMPILER_LAUNCHER=ccache' })
  end
  for i, value in ipairs(args) do
    args[i] = vim.fn.shellescape(value)
  end
  return table.concat(args, ' ')
end

function M.index_config(root)
  root = root or M.root()
  local path = root .. '/.clangd'
  local lines = vim.uv.fs_stat(path) and vim.fn.readfile(path) or {}
  for _, line in ipairs(lines) do
    if line == '# nvim-generated-index-exclusions' then
      return
    end
  end
  if #lines > 0 then
    lines[#lines + 1] = '---'
  end
  vim.list_extend(
    lines,
    { '# nvim-generated-index-exclusions', 'If:', "  PathMatch: '(^|.*/)(build|out|cmake-build-[^/]+|[.]git)/.*'", 'Index:', '  Background: Skip' }
  )
  vim.fn.writefile(lines, path)
end

function M.init_presets(root)
  root = root or M.root()
  if not vim.uv.fs_stat(root .. '/CMakeLists.txt') then
    vim.notify('Open a CMake project to create build presets', vim.log.levels.WARN)
    return false
  end
  local path = root .. '/CMakeUserPresets.json'
  local data = M.read(path)
  if type(data) ~= 'table' then
    data = nil
  end
  if vim.uv.fs_stat(path) and not data then
    vim.notify('Invalid CMakeUserPresets.json; preserved existing file', vim.log.levels.ERROR)
    return false
  end
  data = data or { version = 3 }
  data.version = math.max(3, tonumber(data.version) or 3)
  data.configurePresets = data.configurePresets or {}
  data.buildPresets = data.buildPresets or {}
  data.testPresets = data.testPresets or {}
  local function add(list, value)
    for _, entry in ipairs(list) do
      if entry.name == value.name then
        return
      end
    end
    list[#list + 1] = value
  end
  for _, entry in ipairs {
    { name = 'nvim-debug', type = 'Debug' },
    { name = 'nvim-release', type = 'Release' },
    { name = 'nvim-asan', type = 'Debug', flags = '-fsanitize=address -fno-omit-frame-pointer' },
    { name = 'nvim-ubsan', type = 'Debug', flags = '-fsanitize=undefined -fno-omit-frame-pointer' },
  } do
    local variables = { CMAKE_BUILD_TYPE = entry.type, CMAKE_EXPORT_COMPILE_COMMANDS = true }
    if vim.fn.executable 'ccache' == 1 then
      variables.CMAKE_C_COMPILER_LAUNCHER = 'ccache'
      variables.CMAKE_CXX_COMPILER_LAUNCHER = 'ccache'
    end
    if entry.flags then
      variables.CMAKE_C_FLAGS = entry.flags
      variables.CMAKE_CXX_FLAGS = entry.flags
      variables.CMAKE_EXE_LINKER_FLAGS = entry.flags
      variables.CMAKE_SHARED_LINKER_FLAGS = entry.flags
    end
    add(data.configurePresets, {
      name = entry.name,
      displayName = entry.name:gsub('nvim%-', '') .. ' (Neovim)',
      generator = vim.fn.executable 'ninja' == 1 and 'Ninja' or 'Unix Makefiles',
      binaryDir = '${sourceDir}/build/' .. entry.name,
      cacheVariables = variables,
    })
    add(data.buildPresets, { name = entry.name, configurePreset = entry.name, jobs = 4 })
    add(
      data.testPresets,
      { name = entry.name, configurePreset = entry.name, output = { outputOnFailure = true }, execution = { jobs = 4, noTestsAction = 'error' } }
    )
  end
  -- Generated user presets stay local; project-owned presets are preserved.
  vim.fn.writefile(vim.split(vim.json.encode(data), '\n'), path)
  M.index_config(root)
  vim.notify 'Added Debug, Release, ASan and UBSan user presets'
  return true
end

function M.choose(name, done)
  local root = M.root()
  if not require('runner').save_sources() then
    return
  end
  require('runner').stop_build()
  if not vim.uv.fs_stat(root .. '/CMakeLists.txt') then
    vim.notify('Presets require a CMake project', vim.log.levels.WARN)
    return
  end
  if not vim.uv.fs_stat(root .. '/CMakePresets.json') and not vim.uv.fs_stat(root .. '/CMakeUserPresets.json') then
    if not M.init_presets(root) then
      return
    end
  end
  vim.system({ 'cmake', '--list-presets=configure' }, { cwd = root, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify(result.stderr, vim.log.levels.ERROR)
        return
      end
      local presets = {}
      for line in result.stdout:gmatch '[^\n]+' do
        local value = line:match '^%s+"([^"]+)"'
        if value then
          presets[#presets + 1] = value
        end
      end
      local function configure(preset)
        if not preset then
          return
        end
        if not vim.tbl_contains(presets, preset) then
          vim.notify('Unknown configure preset: ' .. preset, vim.log.levels.ERROR)
          return
        end
        require('custom.cpp.tasks').run('configure', { 'cmake', '--preset', preset, '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' }, root, {
          title = 'Configure ' .. preset,
          open = true,
          on_exit = function(output)
            if output.code ~= 0 then
              if done then
                done(false)
              end
              return
            end
            local dir = output.stdout:match 'Build files have been written to:%s*([^\r\n]+)'
            if not dir then
              vim.notify('CMake did not report its build directory', vim.log.levels.ERROR)
              if done then
                done(false)
              end
              return
            end
            dir = vim.uv.fs_realpath(dir) or dir
            local query = dir .. '/.cmake/api/v1/query/codemodel-v2'
            vim.fn.mkdir(vim.fs.dirname(query), 'p')
            vim.fn.writefile({}, query)
            -- Request executable metadata before switching the active configuration.
            require('custom.cpp.tasks').run('configure', { 'cmake', '--preset', preset, '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' }, root, {
              title = 'Activate ' .. preset,
              on_exit = function(second)
                if second.code == 0 then
                  local previous = M.selected(root) or {}
                  M.remember(root, { preset = preset, build_dir = dir, launch_target = previous.launch_target })
                  require('custom.cpp.language').restart()
                end
                if done then
                  done(second.code == 0, M.selected(root))
                end
              end,
            })
          end,
        })
      end
      if name and name ~= '' then
        configure(name)
      else
        vim.ui.select(presets, { prompt = 'CMake configure preset:' }, configure)
      end
    end)
  end)
end

return M
