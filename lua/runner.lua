local run_command_in_terminal
local run_build_to_quickfix
local close_terminal_split
local run_cmake_target
local state = { buf = nil, chan = nil, prev_win = nil, source_buf = nil, build = nil, generation = 0, cmake_targets = {}, writes = {}, write_sequence = 0 }
_G.RunNowState = state

local function source_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype ~= '' then
    bufnr = state.source_buf
  end
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_buf_get_name(bufnr) == '' then
    vim.notify('Open a named source file before building or running', vim.log.levels.ERROR)
    return nil
  end
  return bufnr
end

local function with_source(callback)
  local bufnr = source_buffer()
  if bufnr then
    state.source_buf = bufnr
    local wins = vim.fn.win_findbuf(bufnr)
    if #wins > 0 then
      vim.api.nvim_set_current_win(wins[1])
    else
      local win = state.prev_win
      if not win or not vim.api.nvim_win_is_valid(win) or vim.wo[win].winfixbuf then
        win = nil
        for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not vim.wo[candidate].winfixbuf and vim.bo[vim.api.nvim_win_get_buf(candidate)].buftype == '' then
            win = candidate
            break
          end
        end
      end
      if win then
        vim.api.nvim_set_current_win(win)
      else
        vim.cmd 'topleft new'
      end
      vim.api.nvim_set_current_buf(bufnr)
    end
    return callback()
  end
end

local function save_sources()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == '' and vim.bo[bufnr].modified then
      if vim.api.nvim_buf_get_name(bufnr) == '' then
        vim.notify('Save unnamed modified buffers before building or running', vim.log.levels.ERROR)
        return false
      end
      local ok, err = pcall(vim.api.nvim_buf_call, bufnr, function()
        vim.cmd 'silent update'
      end)
      if not ok then
        vim.notify('Save failed: ' .. tostring(err), vim.log.levels.ERROR)
        return false
      end
    end
  end
  return true
end

local function cancel_build()
  state.generation = state.generation + 1
  if state.on_build_cancel then
    local callback = state.on_build_cancel
    state.on_build_cancel = nil
    callback 'Build canceled by another run/build'
  end
  if state.build then
    local process = state.build
    state.build = nil
    if process.pid then
      pcall(vim.uv.kill, -process.pid, 15)
    end
    process:kill(15)
  end
end

local function output_path(file_abs)
  local dir = vim.fn.stdpath 'cache' .. '/runner/' .. vim.fn.sha256(file_abs):sub(1, 24)
  vim.fn.mkdir(dir, 'p', 448)
  return dir .. '/program'
end

local function current_extension()
  local ext = vim.fn.expand '%:e'
  return ext == 'C' and 'cpp' or ext:lower()
end

local function compile_command(file_abs, ext)
  if ext ~= 'c' and ext ~= 'cpp' and ext ~= 'cc' and ext ~= 'cxx' then
    return nil, 'Open a C/C++ source file to compile (headers are built through a project)'
  end
  local candidates = ext == 'c' and { 'clang', 'gcc', 'cc' } or { 'clang++', 'g++', 'c++' }
  local compiler
  for _, name in ipairs(candidates) do
    if vim.fn.executable(name) == 1 then
      compiler = name
      break
    end
  end
  if not compiler then
    return nil, 'No C/C++ compiler found in PATH'
  end
  local out_bin = output_path(file_abs)
  file_abs = vim.uv.fs_realpath(file_abs) or file_abs
  local standard = ext == 'c' and '-std=c17' or '-std=c++23'
  local flags = standard .. ' -O0 -g -pipe -Wall -Wextra'
  local cmd
  if vim.fn.executable 'ccache' == 1 then
    local object = out_bin .. '.o'
    cmd = ('ccache %s %s -c %s -o %s && %s -g %s -o %s'):format(
      compiler,
      flags,
      vim.fn.shellescape(file_abs),
      vim.fn.shellescape(object),
      compiler,
      vim.fn.shellescape(object),
      vim.fn.shellescape(out_bin)
    )
  else
    cmd = ('%s %s %s -o %s'):format(compiler, flags, vim.fn.shellescape(file_abs), vim.fn.shellescape(out_bin))
  end
  return cmd, out_bin
end

-- ---------- build command for current file ----------
local function shellescape(s)
  return vim.fn.shellescape(s)
end

local function build_cmd_for_current_file()
  local file_abs = vim.fn.expand '%:p'
  local ext = current_extension()
  if file_abs == '' then
    return nil, 'No file open'
  end
  if ext == 'c' or ext == 'cpp' or ext == 'cc' or ext == 'cxx' then
    local cmd, out_bin = compile_command(file_abs, ext)
    if not cmd then
      return nil, out_bin
    end
    return cmd .. ' && exec ' .. shellescape(out_bin)
  elseif ext == 'py' then
    local env = require 'custom.python.environment'
    local root = env.root(0)
    return table.concat({
      'exec',
      shellescape(env.python(root)),
      '-u',
      shellescape(vim.fn.stdpath 'config' .. '/scripts/python_run.py'),
      shellescape(root),
      'file',
      shellescape(file_abs),
    }, ' ')
  elseif ext == 'js' then
    return 'exec node ' .. shellescape(file_abs)
  elseif ext == 'go' then
    return 'exec go run ' .. shellescape(file_abs)
  elseif ext == 'ts' or ext == 'tsx' then
    return 'exec npx --no-install tsx ' .. shellescape(file_abs)
  elseif ext == 'asm' or ext == 's' then
    if vim.uv.os_uname().sysname ~= 'Linux' then
      return nil, 'The NASM ELF32 runner requires Linux; use a project Makefile for assembly on macOS'
    end
    local out_bin = output_path(file_abs)
    local obj_file = out_bin .. '.o'
    return ('nasm -f elf32 %s -o %s && ld -m elf_i386 %s -o %s && exec %s'):format(
      shellescape(file_abs),
      shellescape(obj_file),
      shellescape(obj_file),
      shellescape(out_bin),
      shellescape(out_bin)
    )
  end
  return nil, ('Unsupported extension: %s'):format(ext)
end

local function find_root(markers)
  return vim.fs.root(0, markers) or vim.fn.expand '%:p:h'
end

local function file_exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function is_cpp_file(ext)
  return ext == 'c' or ext == 'cpp' or ext == 'cc' or ext == 'cxx' or ext == 'h' or ext == 'hpp' or ext == 'hh' or ext == 'hxx'
end

local function executable(name)
  return vim.fn.executable(name) == 1
end

local function project_root()
  local ext = current_extension()
  local markers
  if is_cpp_file(ext) or vim.bo.filetype == 'cmake' then
    markers = { { 'CMakeLists.txt', 'Makefile', 'makefile' }, '.git' }
  elseif ext == 'py' then
    return require('custom.python.environment').root(0)
  elseif ext == 'go' then
    markers = { 'go.mod', '.git' }
  else
    markers = { { 'package.json', 'tsconfig.json', 'Makefile', 'makefile' }, '.git' }
  end
  return find_root(markers)
end

local function make_changed_flags(root)
  local paths, writes = {}, {}
  for path, sequence in pairs(state.writes) do
    if path:sub(1, #root + 1) == root .. '/' then
      paths[#paths + 1] = path
      writes[path] = sequence
    end
  end
  table.sort(paths)
  local flags = {}
  for _, path in ipairs(paths) do
    flags[#flags + 1] = '-W ' .. shellescape(path)
    flags[#flags + 1] = '-W ' .. shellescape(path:sub(#root + 2))
  end
  return table.concat(flags, ' '), writes
end

local function read_json(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end

  local ok_json, decoded = pcall(vim.json.decode, table.concat(lines, '\n'))
  if ok_json and type(decoded) == 'table' then
    return decoded
  end

  return nil
end

local function cmake_target_details(build_dir)
  local reply_dir = build_dir .. '/.cmake/api/v1/reply/'
  local indexes = vim.fn.glob(reply_dir .. 'index-*.json', false, true)
  table.sort(indexes)
  local index = read_json(indexes[#indexes] or '')
  local model
  for _, object in ipairs(index and index.objects or {}) do
    if object.kind == 'codemodel' then
      model = read_json(reply_dir .. object.jsonFile)
      break
    end
  end
  local config = model and model.configurations and model.configurations[1]
  local targets = {}
  for _, target in ipairs(config and config.targets or {}) do
    local details = read_json(reply_dir .. target.jsonFile)
    if details then
      targets[#targets + 1] = details
    end
  end
  return targets
end

local function invalidate_changed_objects(build_dir, writes)
  build_dir = vim.uv.fs_realpath(build_dir) or build_dir
  local commands = read_json(build_dir .. '/compile_commands.json')
  if not commands or #commands == 0 then
    return false
  end
  local affected, removed = {}, false
  for _, entry in ipairs(commands) do
    local object = entry.output
    if not object and entry.arguments then
      for i, arg in ipairs(entry.arguments) do
        if arg == '-o' then
          object = entry.arguments[i + 1]
          break
        end
      end
    end
    if not object and entry.command then
      object = entry.command:match '%s%-o%s+"([^"]+)"' or entry.command:match "%s%-o%s+'([^']+)'" or entry.command:match '%s%-o%s+(%S+)'
    end
    if object then
      object = vim.fs.normalize(object:sub(1, 1) == '/' and object or entry.directory .. '/' .. object)
      if object:sub(1, #build_dir + 1) == build_dir .. '/' and object:match '%.o[bj]*$' then
        local dependencies = ''
        local ok, lines = pcall(vim.fn.readfile, object .. '.d')
        if ok then
          dependencies = table.concat(lines, '\n'):gsub('\\\n', ''):gsub('\\ ', ' ')
        end
        for path in pairs(writes) do
          local real_path = vim.uv.fs_realpath(path) or path
          if
            real_path == entry.file
            or path == entry.file
            or dependencies:find(real_path, 1, true)
            or dependencies:find(path, 1, true)
            or dependencies == ''
          then
            -- Make can miss sub-second saves. Remove only affected generated objects.
            vim.fn.delete(object)
            local name = object:match '/CMakeFiles/(.-)%.dir/'
            if not name then
              return false
            end
            affected[name] = true
            removed = true
            break
          end
        end
      end
    end
  end
  if removed then
    local targets = cmake_target_details(build_dir)
    if #targets == 0 then
      return false
    end
    for _, target in ipairs(targets) do
      if affected[target.name] then
        affected[target.id] = true
      end
    end
    local changed = true
    while changed do
      changed = false
      for _, target in ipairs(targets) do
        if not affected[target.id] then
          for _, dependency in ipairs(target.dependencies or {}) do
            if affected[dependency.id] then
              affected[target.id] = true
              changed = true
              break
            end
          end
        end
      end
    end
    for _, target in ipairs(targets) do
      if affected[target.id] then
        for _, artifact in ipairs(target.artifacts or {}) do
          local path = vim.fs.normalize(artifact.path:sub(1, 1) == '/' and artifact.path or build_dir .. '/' .. artifact.path)
          if path:sub(1, #build_dir + 1) ~= build_dir .. '/' then
            return false
          end
          vim.fn.delete(path)
        end
      end
    end
  end
  return true
end

local function run_config_path(root)
  return root .. '/.nvim-run.json'
end

local function read_run_config(root)
  return read_json(run_config_path(root)) or {}
end

local function project_language(ext, root)
  if is_cpp_file(ext) or vim.bo.filetype == 'cmake' then
    return 'cpp'
  end
  if ext == 'go' then
    return 'go'
  end
  if ext == 'py' then
    return 'python'
  end
  if ext == 'ts' or ext == 'tsx' then
    return 'typescript'
  end
  if ext == 'js' or ext == 'jsx' then
    return 'javascript'
  end
  if file_exists(root .. '/go.mod') then
    return 'go'
  end
  if file_exists(root .. '/pyproject.toml') then
    return 'python'
  end
  if file_exists(root .. '/tsconfig.json') then
    return 'typescript'
  end
  if file_exists(root .. '/package.json') then
    return 'javascript'
  end
end

local function package_script(root, preferred)
  local package = read_json(root .. '/package.json')
  local scripts = package and package.scripts or {}
  if type(scripts) ~= 'table' then
    return nil
  end

  for _, script in ipairs(preferred) do
    if scripts[script] then
      return 'npm run ' .. script
    end
  end

  return nil
end

local function get_project_run_cmd(root, language, default_cmd)
  local config = read_run_config(root)
  config.run = type(config.run) == 'table' and config.run or {}

  local stored = config.run[language]
  if stored == false then
    return default_cmd
  end
  if type(stored) == 'string' and stored ~= '' then
    return stored
  end

  return default_cmd
end

local function has_make_target(root, target)
  local makefile = file_exists(root .. '/Makefile') and root .. '/Makefile' or root .. '/makefile'
  if not file_exists(makefile) then
    return false
  end

  local ok, lines = pcall(vim.fn.readfile, makefile)
  if not ok then
    return false
  end

  for _, line in ipairs(lines) do
    if line:match('^' .. vim.pesc(target) .. '%s*:') then
      return true
    end
  end

  return false
end

local function has_project_file(root, pattern)
  local handle = vim.uv.fs_scandir(root)
  if not handle then
    return false
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end

    if type == 'file' and name:match(pattern) then
      return true
    end
  end

  return false
end

local function init_cmake_project()
  local root = find_root { '.git', 'compile_commands.json' }
  local cmake_file = root .. '/CMakeLists.txt'

  if file_exists(cmake_file) then
    vim.notify('CMakeLists.txt already exists', vim.log.levels.WARN)
    return
  end

  local project_name = vim.fn.fnamemodify(root, ':t')
  if project_name == '' then
    project_name = 'app'
  end

  local ext = current_extension()
  local has_cpp = ext ~= 'c'
    or has_project_file(root, '%.cxx?$')
    or has_project_file(root, '%.cc$')
    or has_project_file(root, '%.hpp$')
    or has_project_file(root, '%.hxx$')
  local language = has_cpp and 'C CXX' or 'C'
  local project_id = project_name:gsub('[^%w_]', '_')

  local lines = {
    'cmake_minimum_required(VERSION 3.20)',
    '',
    ('project(%s VERSION 0.1.0 LANGUAGES %s)'):format(project_id, language),
    '',
    'set(CMAKE_EXPORT_COMPILE_COMMANDS ON)',
    '',
    'set(CMAKE_C_STANDARD 17)',
    'set(CMAKE_C_STANDARD_REQUIRED ON)',
    'set(CMAKE_C_EXTENSIONS OFF)',
    '',
    'set(CMAKE_CXX_STANDARD 20)',
    'set(CMAKE_CXX_STANDARD_REQUIRED ON)',
    'set(CMAKE_CXX_EXTENSIONS OFF)',
    '',
    'option(ENABLE_WARNINGS "Enable compiler warnings" ON)',
    'option(ENABLE_ASAN "Enable address sanitizer in Debug builds" OFF)',
    '',
    '# Output directories. Change these if you want executables/libs elsewhere.',
    'set(PROJECT_OUTPUT_DIR "${CMAKE_BINARY_DIR}/bin" CACHE PATH "Output directory for built executables and libraries")',
    'set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_OUTPUT_DIR}")',
    'set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_OUTPUT_DIR}")',
    'set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_OUTPUT_DIR}/lib")',
    '',
    'foreach(config Debug Release RelWithDebInfo MinSizeRel)',
    '  string(TOUPPER "${config}" config_upper)',
    '  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${config_upper} "${PROJECT_OUTPUT_DIR}/${config}")',
    '  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_${config_upper} "${PROJECT_OUTPUT_DIR}/${config}")',
    '  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${config_upper} "${PROJECT_OUTPUT_DIR}/${config}/lib")',
    'endforeach()',
    '',
    '# Collect all C/C++ source and header files in this project.',
    '# CONFIGURE_DEPENDS asks CMake to re-scan when files are added or removed.',
    'file(GLOB_RECURSE PROJECT_SOURCES CONFIGURE_DEPENDS',
    '  "${CMAKE_CURRENT_SOURCE_DIR}/*.c"',
    '  "${CMAKE_CURRENT_SOURCE_DIR}/*.cc"',
    '  "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp"',
    '  "${CMAKE_CURRENT_SOURCE_DIR}/*.cxx"',
    ')',
    '',
    'file(GLOB_RECURSE PROJECT_HEADERS CONFIGURE_DEPENDS',
    '  "${CMAKE_CURRENT_SOURCE_DIR}/*.h"',
    '  "${CMAKE_CURRENT_SOURCE_DIR}/*.hh"',
    '  "${CMAKE_CURRENT_SOURCE_DIR}/*.hpp"',
    '  "${CMAKE_CURRENT_SOURCE_DIR}/*.hxx"',
    ')',
    '',
    '# Keep generated/build/vendor files out of the target.',
    'foreach(path IN LISTS PROJECT_SOURCES PROJECT_HEADERS)',
    '  if(path MATCHES "/(build|out|cmake-build-[^/]+|\\.git|node_modules|vendor|external|third_party)/")',
    '    list(REMOVE_ITEM PROJECT_SOURCES "${path}")',
    '    list(REMOVE_ITEM PROJECT_HEADERS "${path}")',
    '  endif()',
    'endforeach()',
    '',
    'if(NOT PROJECT_SOURCES)',
    '  message(FATAL_ERROR "No C/C++ source files found. Add a .c/.cpp file or edit PROJECT_SOURCES manually.")',
    'endif()',
    '',
    'add_executable(${PROJECT_NAME}',
    '  ${PROJECT_SOURCES}',
    '  ${PROJECT_HEADERS}',
    ')',
    '',
    '# Common include directories. Add/remove paths for your project.',
    'set(PROJECT_INCLUDE_DIRS',
    '  "${CMAKE_CURRENT_SOURCE_DIR}"',
    '  "${CMAKE_CURRENT_SOURCE_DIR}/include"',
    '  "${CMAKE_CURRENT_SOURCE_DIR}/src"',
    ')',
    '',
    'foreach(dir IN LISTS PROJECT_INCLUDE_DIRS)',
    '  if(EXISTS "${dir}")',
    '    target_include_directories(${PROJECT_NAME} PRIVATE "${dir}")',
    '  endif()',
    'endforeach()',
    '',
    '# Package examples. Uncomment and adapt the packages your project uses.',
    '# find_package(fmt CONFIG REQUIRED)',
    '# find_package(SDL2 CONFIG REQUIRED)',
    '# find_package(OpenGL REQUIRED)',
    '',
    '# Library examples. Put imported targets or raw library names here.',
    'set(PROJECT_LIBRARIES',
    '  # fmt::fmt',
    '  # SDL2::SDL2',
    '  # OpenGL::GL',
    '  # m',
    ')',
    '',
    'if(PROJECT_LIBRARIES)',
    '  target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_LIBRARIES})',
    'endif()',
    '',
    'if(ENABLE_WARNINGS)',
    '  target_compile_options(${PROJECT_NAME} PRIVATE',
    '    $<$<C_COMPILER_ID:Clang,AppleClang,GNU>:-Wall -Wextra -Wpedantic>',
    '    $<$<CXX_COMPILER_ID:Clang,AppleClang,GNU>:-Wall -Wextra -Wpedantic>',
    '    $<$<C_COMPILER_ID:MSVC>:/W4>',
    '    $<$<CXX_COMPILER_ID:MSVC>:/W4>',
    '  )',
    'endif()',
    '',
    'if(ENABLE_ASAN AND CMAKE_BUILD_TYPE STREQUAL "Debug")',
    '  target_compile_options(${PROJECT_NAME} PRIVATE -fsanitize=address -fno-omit-frame-pointer)',
    '  target_link_options(${PROJECT_NAME} PRIVATE -fsanitize=address)',
    'endif()',
  }

  vim.fn.writefile(lines, cmake_file)
  vim.cmd.edit(cmake_file)
  vim.notify('Created CMakeLists.txt starter', vim.log.levels.INFO)
end

local function project_build_cmd(check_only)
  local file_abs = vim.fn.expand '%:p'
  local ext = current_extension()
  local root = project_root()

  if is_cpp_file(ext) or vim.bo.filetype == 'cmake' then
    if file_exists(root .. '/CMakeLists.txt') then
      local project = require 'custom.cpp.project'
      local build_dir = project.build_dir(root)
      local dir = build_dir
      local query = build_dir .. '/.cmake/api/v1/query/codemodel-v2'
      if not file_exists(query) then
        vim.fn.mkdir(vim.fn.fnamemodify(query, ':h'), 'p')
        vim.fn.writefile({}, query)
      end
      local configure = ''
      if #vim.fn.glob(build_dir .. '/.cmake/api/v1/reply/codemodel-v2-*.json', false, true) == 0 or not file_exists(build_dir .. '/compile_commands.json') then
        configure = project.configure_command(root, build_dir) .. ' && '
      end
      local flags, writes = make_changed_flags(root)
      for path in pairs(writes) do
        if vim.fn.fnamemodify(path, ':t') == 'CMakeLists.txt' or path:match '%.cmake$' then
          configure = project.configure_command(root, build_dir) .. ' && '
          break
        end
      end
      local force = ''
      if file_exists(build_dir .. '/Makefile') and flags ~= '' then
        if not invalidate_changed_objects(build_dir, writes) then
          force = ' --clean-first'
        end
      end
      local refresh = ''
      if file_exists(build_dir .. '/build.ninja') and flags ~= '' then
        local args = { 'python3', shellescape(vim.fn.stdpath 'config' .. '/scripts/refresh_ninja.py'), shellescape(build_dir) }
        local paths = vim.tbl_keys(writes)
        table.sort(paths)
        for _, path in ipairs(paths) do
          args[#args + 1] = shellescape(path)
        end
        refresh = table.concat(args, ' ') .. ' && '
      end
      return configure .. refresh .. ('cmake --build %s --parallel 4'):format(shellescape(dir)) .. force,
        root,
        { run_cmake = true, build_dir = build_dir, writes = writes }
    end

    if file_exists(root .. '/Makefile') or file_exists(root .. '/makefile') then
      local metadata = {}
      if has_make_target(root, 'run') then
        metadata.run_cmd = 'make run'
      end
      local flags, writes = make_changed_flags(root)
      metadata.writes = writes
      return 'make -j4 ' .. flags, root, metadata
    end

    if check_only then
      local is_c = vim.bo.filetype == 'c'
      local compiler = is_c and 'clang' or 'clang++'
      local standard = is_c and 'c17' or 'c++20'
      local language = is_c and 'c' or 'c++'
      return ('%s -x %s -std=%s -Wall -Wextra -fsyntax-only %s'):format(compiler, language, standard, shellescape(file_abs)), vim.fn.expand '%:p:h', {}
    end
    local compile_cmd, out_bin = compile_command(file_abs, ext)
    if compile_cmd then
      return compile_cmd, vim.fn.expand '%:p:h', { run_cmd = 'exec ' .. shellescape(out_bin), executable = out_bin }
    end
    vim.notify(out_bin, vim.log.levels.ERROR)
    return nil, root
  end

  if ext == 'go' then
    if file_exists(root .. '/go.mod') then
      return 'go test ./...', root
    end

    return ('go test %s'):format(shellescape(file_abs)), vim.fn.expand '%:p:h'
  end

  if ext == 'py' then
    local python = shellescape(require('custom.python.environment').python(root))
    if file_exists(root .. '/pyproject.toml') or file_exists(root .. '/setup.py') or file_exists(root .. '/setup.cfg') then
      return python .. ' -m compileall -q -x ' .. shellescape '(^|/)([.]venv|venv|env|[.]git|build|dist)(/|$)' .. ' .', root
    end

    return ('%s -m py_compile %s'):format(python, shellescape(file_abs)), root
  end

  if file_exists(root .. '/package.json') then
    local package = read_json(root .. '/package.json')
    local scripts = package and package.scripts or {}

    if ext == 'ts' or ext == 'tsx' or file_exists(root .. '/tsconfig.json') then
      return 'npx tsc --noEmit --pretty false', root
    end

    if scripts and scripts.build then
      return 'npm run build', root
    end
  end

  if file_exists(root .. '/Makefile') or file_exists(root .. '/makefile') then
    return 'make', root
  end

  if ext == 'js' or ext == 'jsx' then
    return ('node --check %s'):format(shellescape(file_abs)), root
  end

  return nil, root
end

local function build_errorformat()
  return table.concat({
    '%f:%l:%c: %trror: %m',
    '%f:%l:%c: %tarning: %m',
    '%f:%l:%c: %m',
    '%f:%l: %trror: %m',
    '%f:%l: %tarning: %m',
    '%f:%l: %m',
    '%EFile "%f"\\, line %l%.%#',
    '%Z%m',
    '%A%f(%l\\,%c): %trror %m',
    '%A%f(%l\\,%c): %tarning %m',
    '%A%f(%l\\,%c): %m',
    '%-G%.%#',
  }, ',')
end

local function set_build_quickfix(lines, cmd, cwd, panel)
  local old_cwd = vim.fn.getcwd()
  vim.fn.chdir(cwd)

  vim.fn.setqflist({}, ' ', {
    title = 'BuildNow: ' .. cmd,
    lines = lines,
    efm = build_errorformat(),
  })

  vim.fn.chdir(old_cwd)

  if panel then
    return
  end
  if vim.fn.getqflist({ size = 0 }).size > 0 then
    vim.cmd 'botright copen 12'
  else
    vim.cmd 'cclose'
  end
end

local function quickfix_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    if vim.bo[bufnr].filetype == 'qf' then
      return win
    end
  end

  return nil
end

run_build_to_quickfix = function(opts, run_after)
  if not save_sources() then
    return false
  end

  cancel_build()
  local cmd, cwd, metadata
  if opts and opts.args and opts.args ~= '' then
    cmd, cwd = opts.args, vim.fn.getcwd()
  else
    cmd, cwd, metadata = project_build_cmd(opts and opts.check)
  end
  if not cmd then
    vim.notify('No build/check command found for this file or project', vim.log.levels.ERROR)
    return false
  end
  if run_after and not (metadata and (metadata.run_cmd or metadata.run_cmake)) then
    vim.notify('This project needs a run command in .nvim-run.json or a Makefile run target', vim.log.levels.ERROR)
    return false
  end

  local generation = state.generation
  vim.fn.setqflist({}, 'r', { title = 'Checking: ' .. vim.fn.fnamemodify(cwd, ':t'), items = opts and opts.panel and vim.fn.getqflist() or {} })
  if not (opts and opts.panel) then
    vim.notify('Building project...', vim.log.levels.INFO)
  end
  local ok, process = pcall(vim.system, { vim.o.shell, vim.o.shellcmdflag, cmd }, { cwd = cwd, text = true, detach = true }, function(result)
    vim.schedule(function()
      if generation ~= state.generation then
        return false
      end
      state.build = nil
      local lines = {}
      for _, stream in ipairs { result.stdout or '', result.stderr or '' } do
        for line in vim.gsplit(stream, '\n', { plain = true, trimempty = true }) do
          table.insert(lines, line)
        end
      end
      set_build_quickfix(lines, cmd, cwd, opts and opts.panel)
      local count = vim.fn.getqflist({ size = 0 }).size
      if result.code ~= 0 or result.signal ~= 0 then
        if count == 0 then
          vim.fn.setqflist({}, 'r', {
            title = 'Build failed: ' .. cmd,
            items = { { text = table.concat(lines, ' ') ~= '' and table.concat(lines, ' ') or ('Exit code ' .. result.code) } },
          })
          if not (opts and opts.panel) then
            vim.cmd 'botright copen 12'
          end
        end
        vim.fn.setqflist({}, 'a', { title = 'Check failed: ' .. cmd })
        if not (opts and opts.panel) then
          vim.notify('Build failed; executable was not run', vim.log.levels.ERROR)
        end
        if opts and opts.on_failure then
          opts.on_failure(result)
        end
      else
        for path, sequence in pairs(metadata and metadata.writes or {}) do
          if state.writes[path] == sequence then
            state.writes[path] = nil
          end
        end
        if opts and opts.on_success then
          opts.on_success(metadata or {}, cwd, generation)
        elseif run_after and metadata.run_cmake then
          run_cmake_target(metadata, cwd, generation)
        elseif run_after then
          run_command_in_terminal(metadata.run_cmd, cwd)
        else
          vim.fn.setqflist({}, 'a', { title = count == 0 and 'Check complete: no errors' or 'Check complete: warnings' })
          if not (opts and opts.panel) then
            vim.notify('Build succeeded', vim.log.levels.INFO)
          end
        end
      end
    end)
  end)
  if ok then
    state.build = process
  else
    vim.notify('Unable to start build: ' .. tostring(process), vim.log.levels.ERROR)
    return false
  end
  return true
end

run_cmake_target = function(metadata, root, generation, on_target)
  local targets = {}
  for _, details in ipairs(cmake_target_details(metadata.build_dir)) do
    if details.type == 'EXECUTABLE' and details.artifacts and details.artifacts[1] then
      local path = details.artifacts[1].path
      targets[#targets + 1] = {
        name = details.name,
        path = path:sub(1, 1) == '/' and path or metadata.build_dir .. '/' .. path,
      }
    end
  end
  if #targets == 0 then
    vim.notify('CMake build has no executable target', vim.log.levels.ERROR)
    if on_target then
      on_target(nil, root)
    end
    return
  end
  local function launch(target)
    if generation ~= state.generation then
      return
    end
    if not target then
      if on_target then
        on_target(nil, root)
      end
      return
    end
    state.cmake_targets[root] = target.name
    if on_target then
      on_target(target.path, root)
    else
      run_command_in_terminal('exec ' .. shellescape(target.path), root)
    end
  end
  local run_config = read_run_config(root)
  local selected = run_config.cmake_target or state.cmake_targets[root]
  local cmake = package.loaded['cmake-tools']
  if not selected and cmake and cmake.is_cmake_project() then
    selected = cmake.get_launch_target()
  end
  for _, target in ipairs(targets) do
    if not metadata.pick_target and (target.name == selected or #targets == 1) then
      launch(target)
      return
    end
  end
  vim.ui.select(targets, {
    prompt = 'CMake executable:',
    format_item = function(target)
      return target.name
    end,
  }, launch)
end

local function check_signature(bufnr)
  local parts = { vim.api.nvim_buf_get_name(bufnr) }
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' then
      parts[#parts + 1] = buf .. ':' .. vim.api.nvim_buf_get_changedtick(buf)
    end
  end
  return table.concat(parts, '|')
end

local function toggle_build_quickfix()
  if quickfix_win() then
    vim.cmd 'cclose'
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local key = check_signature(bufnr)
  if state.check_key ~= key and not state.build then
    local diagnostics = vim.diagnostic.get(bufnr)
    vim.fn.setqflist({}, 'r', { title = 'C/C++ diagnostics; checking...', items = vim.diagnostic.toqflist(diagnostics) })
  end
  vim.cmd 'botright copen 12'
  if state.build or state.check_pending then
    return
  end
  if state.check_key == key and state.check_time and vim.uv.hrtime() - state.check_time < 2e9 then
    return
  end
  local generation = state.generation
  state.check_pending = true
  vim.defer_fn(function()
    state.check_pending = false
    if generation ~= state.generation or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    vim.api.nvim_buf_call(bufnr, function()
      run_build_to_quickfix { panel = true, check = true }
      state.check_key = check_signature(bufnr)
      state.check_time = vim.uv.hrtime()
    end)
  end, 20)
end

local function run_built_target()
  if not save_sources() then
    return
  end
  cancel_build()
  close_terminal_split(false)
  local file_abs = vim.fn.expand '%:p'
  local ext = current_extension()
  local root = project_root()
  local language = project_language(ext, root)

  if is_cpp_file(ext) or vim.bo.filetype == 'cmake' then
    local config = read_run_config(root)
    local custom = type(config.run) == 'table' and config.run.cpp
    if type(custom) == 'string' and custom ~= '' then
      local cmd, cwd = project_build_cmd()
      if cmd then
        run_command_in_terminal(cmd .. ' && ' .. custom, cwd)
      end
    else
      run_build_to_quickfix({}, true)
    end
    return
  end

  local default_cmd
  if language == 'go' then
    default_cmd = file_exists(root .. '/go.mod') and 'go run .' or ('go run %s'):format(shellescape(file_abs))
  elseif language == 'python' then
    local python = require('custom.python.environment').python(root)
    default_cmd = table.concat(
      { 'exec', shellescape(python), '-u', shellescape(vim.fn.stdpath 'config' .. '/scripts/python_run.py'), shellescape(root), 'file', shellescape(file_abs) },
      ' '
    )
  elseif language == 'typescript' then
    default_cmd = package_script(root, { 'start', 'dev' }) or ('npx --no-install tsx %s'):format(shellescape(file_abs))
  elseif language == 'javascript' then
    default_cmd = package_script(root, { 'start', 'dev' }) or ('node %s'):format(shellescape(file_abs))
  end
  if default_cmd then
    cancel_build()
    run_command_in_terminal(get_project_run_cmd(root, language, default_cmd), root)
    return
  end
  local cmd, err = build_cmd_for_current_file()
  if cmd then
    cancel_build()
    run_command_in_terminal(cmd, root)
  else
    vim.notify(err, vim.log.levels.ERROR)
  end
end

local function stop_terminal_job()
  if state.chan then
    pcall(vim.fn.jobstop, state.chan)
    state.chan = nil
  end
end

close_terminal_split = function(restore_focus)
  local prev_win, bufnr = state.prev_win, state.buf
  stop_terminal_job()
  state.buf = nil
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
  if restore_focus ~= false and prev_win and vim.api.nvim_win_is_valid(prev_win) then
    vim.api.nvim_set_current_win(prev_win)
  end
end

run_command_in_terminal = function(cmd, cwd)
  local prev_win = vim.api.nvim_get_current_win()
  local old_buf = state.buf
  local wins = old_buf and vim.api.nvim_buf_is_valid(old_buf) and vim.fn.win_findbuf(old_buf) or {}
  stop_terminal_job()
  state.buf = nil
  if #wins > 0 then
    if prev_win ~= wins[1] then
      state.prev_win = prev_win
    end
    vim.api.nvim_set_current_win(wins[1])
  else
    state.prev_win = prev_win
    vim.cmd 'botright 15split'
  end
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, bufnr)
  state.buf = bufnr
  if old_buf and vim.api.nvim_buf_is_valid(old_buf) then
    pcall(vim.api.nvim_buf_delete, old_buf, { force = true })
  end
  vim.bo[bufnr].bufhidden = 'wipe'
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].buflisted = false
  vim.api.nvim_buf_set_name(bufnr, 'RunNow Output')
  local ok, chan = pcall(vim.fn.jobstart, { vim.o.shell, vim.o.shellcmdflag, cmd }, {
    cwd = cwd,
    term = true,
    on_exit = function(_, code)
      vim.schedule(function()
        if state.buf == bufnr then
          state.chan = nil
          if code ~= 0 then
            vim.notify(('Run exited with code %d'):format(code), vim.log.levels.ERROR)
          end
        end
      end)
    end,
  })
  if not ok or chan <= 0 then
    vim.notify('Unable to start command: ' .. tostring(chan), vim.log.levels.ERROR)
    return
  end
  state.chan = chan
  local group = vim.api.nvim_create_augroup('RunNowTerminal', { clear = true })
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    buffer = bufnr,
    callback = function()
      if state.buf == bufnr then
        stop_terminal_job()
        state.buf = nil
      end
    end,
  })
  vim.keymap.set('n', 'H', close_terminal_split, { buffer = bufnr, silent = true, desc = 'Close run output' })
  vim.keymap.set('n', 'K', close_terminal_split, { buffer = bufnr, silent = true, desc = 'Close run output' })
  vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', { buffer = bufnr, silent = true, desc = 'Leave terminal input' })
  vim.keymap.set('n', '<leader>R', function()
    with_source(function()
      vim.cmd 'RunNow'
    end)
  end, { buffer = bufnr, silent = true, desc = 'Rerun source file' })
  vim.keymap.set('n', '<leader>r', function()
    with_source(run_built_target)
  end, { buffer = bufnr, silent = true, desc = 'Rebuild and run project' })
  if state.source_buf and vim.bo[state.source_buf].filetype == 'python' then
    require('custom.core.python_ide').map(bufnr)
  end
  vim.cmd 'startinsert'
end

local function run_current_file(opts)
  if not save_sources() then
    return
  end
  local cmd, err = build_cmd_for_current_file()
  if not cmd then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  if opts.args ~= '' then
    cmd = cmd .. ' ' .. opts.args
  end
  cancel_build()
  run_command_in_terminal(cmd, vim.fn.expand '%:p:h')
end

vim.api.nvim_create_user_command('RunNow', function(opts)
  with_source(function()
    run_current_file(opts)
  end)
end, { nargs = '*', complete = 'file', desc = 'Save, compile and run current file; optional shell arguments' })
vim.api.nvim_create_user_command('BuildNow', function(opts)
  with_source(function()
    if vim.bo.filetype == 'python' and opts.args == '' then
      require('custom.python.check').explicit 'project'
    else
      run_build_to_quickfix(opts)
    end
  end)
end, { nargs = '*', complete = 'shellcmd', desc = 'Save and build project asynchronously' })
vim.api.nvim_create_user_command('BuildToggle', function()
  with_source(function()
    if vim.bo.filetype == 'python' then
      require('custom.python.check').toggle()
    else
      toggle_build_quickfix()
    end
  end)
end, {})
vim.api.nvim_create_user_command('RunBuild', function()
  with_source(run_built_target)
end, { desc = 'Save, rebuild and run project' })
vim.api.nvim_create_user_command('RunStop', function()
  cancel_build()
  close_terminal_split()
end, { desc = 'Stop active runner build and close run output' })
vim.api.nvim_create_user_command('CMakeInit', init_cmake_project, {})
vim.api.nvim_create_autocmd('BufWritePost', {
  group = vim.api.nvim_create_augroup('RunnerSavedSources', { clear = true }),
  callback = function(event)
    local path = vim.api.nvim_buf_get_name(event.buf)
    local ext = vim.fn.fnamemodify(path, ':e'):lower()
    if vim.bo[event.buf].buftype == '' and (is_cpp_file(ext) or vim.bo[event.buf].filetype == 'cmake') then
      state.write_sequence = state.write_sequence + 1
      state.writes[path] = state.write_sequence
    end
  end,
})

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = vim.api.nvim_create_augroup('RunNowCleanup', { clear = true }),
  callback = function()
    cancel_build()
    stop_terminal_job()
  end,
})

vim.keymap.set('n', '<leader>R', '<cmd>RunNow<CR>', { silent = true, desc = 'Save, compile and run file' })
vim.keymap.set('n', '<leader>b', '<cmd>BuildToggle<CR>', { silent = true, nowait = true, desc = 'Toggle error pane and check in background' })
vim.keymap.set('n', '<leader>r', '<cmd>RunBuild<CR>', { silent = true, desc = 'Rebuild and run project' })
vim.keymap.set('n', '<leader>B', '<cmd>BuildNow<CR>', { silent = true, desc = 'Force full project build/check' })
vim.keymap.set('n', '<leader>co', '<cmd>copen<CR>', { silent = true, desc = 'Open quickfix' })
vim.keymap.set('n', '<leader>cn', '<cmd>cnext<CR>', { silent = true, desc = 'Next quickfix item' })
vim.keymap.set('n', '<leader>cp', '<cmd>cprev<CR>', { silent = true, desc = 'Previous quickfix item' })

local function build_executable(on_ready, on_failure)
  return with_source(function()
    local function fail(message)
      state.on_build_cancel = nil
      if on_failure then
        on_failure(message)
      end
    end
    local started = run_build_to_quickfix {
      panel = true,
      on_success = function(metadata, cwd, generation)
        local function ready(path)
          if generation ~= state.generation then
            return
          end
          state.on_build_cancel = nil
          if path then
            on_ready(path, cwd, metadata)
          else
            fail 'No executable selected or available'
          end
        end
        if metadata.run_cmake then
          run_cmake_target(metadata, cwd, generation, ready)
        elseif metadata.executable then
          ready(metadata.executable)
        else
          vim.ui.input({ prompt = 'Executable to inspect: ', default = cwd .. '/', completion = 'file' }, function(path)
            if generation ~= state.generation then
              return
            end
            if path and vim.fn.executable(path) == 1 then
              ready(path)
            else
              fail 'No executable selected'
            end
          end)
        end
      end,
      on_failure = function()
        fail 'Build failed; open compiler errors with Space b'
      end,
    }
    if started then
      state.on_build_cancel = fail
    else
      fail 'Unable to save/build this source'
    end
    return started
  end)
end

return {
  build_executable = build_executable,
  run_terminal = function(command, cwd, buf)
    state.source_buf = buf or source_buffer()
    cancel_build()
    run_command_in_terminal(command, cwd)
  end,
  save_sources = save_sources,
  source_buffer = source_buffer,
  stop_build = cancel_build,
  build = function(callback)
    return with_source(function()
      return run_build_to_quickfix {
        on_success = function(metadata, cwd, generation)
          callback(true, cwd, generation, metadata)
        end,
        on_failure = function(result)
          callback(false, nil, nil, nil, result)
        end,
      }
    end)
  end,
  select_target = function()
    with_source(function()
      run_build_to_quickfix {
        on_success = function(metadata, cwd, generation)
          if not metadata.run_cmake then
            vim.notify('Executable target selection requires CMake', vim.log.levels.WARN)
            return
          end
          metadata.pick_target = true
          run_cmake_target(metadata, cwd, generation, function() end)
        end,
      }
    end)
  end,
  debug = function()
    with_source(function()
      run_build_to_quickfix {
        on_success = function(metadata, cwd, generation)
          local function launch(path)
            if not path then
              return
            end
            require('dap').run {
              name = 'C/C++ debug',
              type = 'lldb',
              request = 'launch',
              program = path,
              cwd = cwd,
              stopOnEntry = false,
              runInTerminal = true,
            }
          end
          if metadata.run_cmake then
            run_cmake_target(metadata, cwd, generation, launch)
          elseif metadata.executable then
            launch(metadata.executable)
          else
            vim.ui.input({ prompt = 'Executable to debug: ', default = cwd .. '/', completion = 'file' }, function(path)
              if path and vim.fn.executable(path) == 1 and generation == state.generation then
                launch(path)
              end
            end)
          end
        end,
      }
    end)
  end,
}
