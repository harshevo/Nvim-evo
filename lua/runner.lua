-- ===== RunNow: reuse a single terminal buffer (split) and Shift-H closes it =====
local RUNNER_CMD_NAME = 'RunNow'
local BUILD_CMD_NAME = 'BuildNow'
local BUILD_TOGGLE_CMD_NAME = 'BuildToggle'
local RUN_BUILD_CMD_NAME = 'RunBuild'
local CMAKE_INIT_CMD_NAME = 'CMakeInit'
local ensure_terminal

-- ---------- build command for current file ----------
local function shellescape(s)
  return vim.fn.shellescape(s)
end

local function build_cmd_for_current_file()
  local file_abs = vim.fn.expand '%:p'
  local ext = vim.fn.expand('%:e'):lower()
  local base = vim.fn.expand '%:t:r'
  local out_bin = '/tmp/' .. base .. '_run'
  local obj_file = '/tmp/' .. base .. '.o'
  if file_abs == '' then
    return nil, 'No file open'
  end
  if ext == 'py' then
    return ('python3 %s'):format(shellescape(file_abs))
  elseif ext == 'c' then
    return ('gcc -std=c17 -O2 -pipe -Wall -Wextra %s -o %s && %s'):format(shellescape(file_abs), shellescape(out_bin), shellescape(out_bin))
  elseif ext == 'cpp' or ext == 'cc' or ext == 'cxx' then
    return ('g++ -std=c++20 -O2 -pipe -Wall -Wextra %s -o %s && %s'):format(shellescape(file_abs), shellescape(out_bin), shellescape(out_bin))
  elseif ext == 'asm' or ext == 's' then
    return ('nasm -f elf32 %s -o %s && ld -m elf_i386 %s -o %s && %s'):format(
      shellescape(file_abs),
      shellescape(obj_file),
      shellescape(obj_file),
      shellescape(out_bin),
      shellescape(out_bin)
    )
  else
    return nil, ('Unsupported extension: %s'):format(ext)
  end
end

local function find_root(markers)
  return vim.fs.root(0, markers) or vim.fn.getcwd()
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

local function find_cmake_build_dir(root)
  local candidates = {
    'out/Debug',
    'out/Release',
    'out/RelWithDebInfo',
    'build',
    'cmake-build-debug',
    'cmake-build-release',
  }

  for _, dir in ipairs(candidates) do
    local path = root .. '/' .. dir
    if file_exists(path .. '/CMakeCache.txt') then
      return dir
    end
  end

  return nil
end

local function read_json(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end

  local ok_json, decoded = pcall(vim.json.decode, table.concat(lines, '\n'))
  if ok_json then
    return decoded
  end

  return nil
end

local function write_json(path, data)
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    return false
  end

  return pcall(vim.fn.writefile, { encoded }, path)
end

local function run_config_path(root)
  return root .. '/.nvim-run.json'
end

local function read_run_config(root)
  return read_json(run_config_path(root)) or {}
end

local function write_run_config(root, config)
  return write_json(run_config_path(root), config)
end

local function project_language(ext, root)
  if is_cpp_file(ext) then
    return 'cpp'
  end
  if ext == 'go' or file_exists(root .. '/go.mod') then
    return 'go'
  end
  if ext == 'py' or file_exists(root .. '/pyproject.toml') then
    return 'python'
  end
  if ext == 'ts' or ext == 'tsx' or file_exists(root .. '/tsconfig.json') then
    return 'typescript'
  end
  if ext == 'js' or ext == 'jsx' or file_exists(root .. '/package.json') then
    return 'javascript'
  end

  return nil
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
  config.run = config.run or {}

  local stored = config.run[language]
  if stored == false then
    return default_cmd
  end
  if type(stored) == 'string' and stored ~= '' then
    return stored
  end

  local prompt = ('Run command for %s project. Empty = default [%s]: '):format(language, default_cmd)
  local custom = vim.fn.input(prompt)
  if custom and custom ~= '' then
    config.run[language] = custom
    write_run_config(root, config)
    return custom
  end

  config.run[language] = false
  write_run_config(root, config)
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

  local ext = vim.fn.expand('%:e'):lower()
  local has_cpp = ext ~= 'c' or has_project_file(root, '%.cxx?$') or has_project_file(root, '%.cc$') or has_project_file(root, '%.hpp$') or has_project_file(root, '%.hxx$')
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

local function project_build_cmd()
  local file_abs = vim.fn.expand '%:p'
  local ext = vim.fn.expand('%:e'):lower()
  local base = vim.fn.expand '%:t:r'
  local out_bin = '/tmp/' .. base .. '_run'
  local root = find_root {
    'package.json',
    'tsconfig.json',
    'Makefile',
    'makefile',
    'CMakeLists.txt',
    'pyproject.toml',
    'go.mod',
    '.git',
  }

  if is_cpp_file(ext) then
    local cmake_dir = find_cmake_build_dir(root)
    if cmake_dir then
      return ('cmake --build %s -- -j4'):format(shellescape(cmake_dir)), root, { run_cmake = true }
    end

    if file_exists(root .. '/CMakeLists.txt') then
      return 'cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=1 && cmake --build build -- -j4', root, { run_cmake = true }
    end

    if file_exists(root .. '/Makefile') or file_exists(root .. '/makefile') then
      local metadata = {}
      if has_make_target(root, 'run') then
        metadata.run_cmd = 'make run'
      end
      return 'make', root, metadata
    end

    if executable('clangd') then
      local compiler = ext == 'c' and 'clang' or 'clang++'
      local standard = ext == 'c' and '-std=c17' or '-std=c++20'
      local compile_cmd = ('%s %s -Wall -Wextra %s -o %s'):format(compiler, standard, shellescape(file_abs), shellescape(out_bin))
      return (('clangd --check=%s && %s'):format(shellescape(file_abs), compile_cmd)), root, { clangd_check_file = file_abs, run_cmd = shellescape(out_bin) }
    end

    local compiler = ext == 'c' and 'clang' or 'clang++'
    if executable(compiler) then
      local standard = ext == 'c' and '-std=c17' or '-std=c++20'
      local compile_cmd = ('%s %s -Wall -Wextra %s -o %s'):format(compiler, standard, shellescape(file_abs), shellescape(out_bin))
      return compile_cmd, root, { run_cmd = shellescape(out_bin) }
    end
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

  if ext == 'go' or file_exists(root .. '/go.mod') then
    if file_exists(root .. '/go.mod') then
      return 'go test ./...', root
    end

    return ('go test %s'):format(shellescape(file_abs)), vim.fn.expand '%:p:h'
  end

  if ext == 'py' then
    if file_exists(root .. '/pyproject.toml') or file_exists(root .. '/setup.py') or file_exists(root .. '/setup.cfg') then
      return 'python3 -m compileall -q .', root
    end

    return ('python3 -m py_compile %s'):format(shellescape(file_abs)), root
  end

  if ext == 'js' or ext == 'jsx' then
    return ('node --check %s'):format(shellescape(file_abs)), root
  end

  return nil, root
end

local function run_command_in_terminal(cmd, cwd)
  local bufnr, chan = ensure_terminal()
  vim.api.nvim_set_current_buf(bufnr)

  local cd_cmd = cwd and cwd ~= '' and ('cd ' .. shellescape(cwd) .. '\n') or ''
  vim.api.nvim_chan_send(chan, 'clear\n' .. cd_cmd .. cmd .. '\n')
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

local function normalize_build_lines(lines, metadata)
  if not (metadata and metadata.clangd_check_file) then
    return lines
  end

  local normalized = {}
  for _, line in ipairs(lines) do
    local level, lnum, message = line:match '^(%u)%b[]%s+%b[]%s+Line%s+(%d+):%s+(.+)$'
    if level and lnum and message then
      local kind = level == 'E' and 'error' or 'warning'
      table.insert(normalized, ('%s:%s:1: %s: %s'):format(metadata.clangd_check_file, lnum, kind, message))
    else
      table.insert(normalized, line)
    end
  end

  return normalized
end

local function setup_quickfix_mappings()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= 'qf' then
    return
  end

  vim.opt_local.cursorline = true

  local function select_quickfix_item(delta)
    local qf_size = vim.fn.getqflist({ size = 0 }).size
    if qf_size == 0 then
      return
    end

    local row = vim.api.nvim_win_get_cursor(0)[1] + delta
    if row < 1 then
      row = qf_size
    elseif row > qf_size then
      row = 1
    end

    vim.api.nvim_win_set_cursor(0, { row, 0 })
  end

  vim.keymap.set('n', 'j', function()
    select_quickfix_item(1)
  end, { buffer = bufnr, silent = true, desc = 'Select next quickfix item' })

  vim.keymap.set('n', 'k', function()
    select_quickfix_item(-1)
  end, { buffer = bufnr, silent = true, desc = 'Select previous quickfix item' })

  vim.keymap.set('n', '<leader>b', '<cmd>BuildToggle<CR>', { buffer = bufnr, silent = true, desc = 'Close build quickfix' })
end

local function set_build_quickfix(lines, cmd, cwd, metadata)
  local old_cwd = vim.fn.getcwd()
  pcall(vim.cmd.lcd, vim.fn.fnameescape(cwd))

  vim.fn.setqflist({}, ' ', {
    title = 'BuildNow: ' .. cmd,
    lines = normalize_build_lines(lines, metadata),
    efm = build_errorformat(),
  })

  pcall(vim.cmd.lcd, vim.fn.fnameescape(old_cwd))

  if vim.fn.getqflist({ size = 0 }).size > 0 then
    vim.cmd 'botright copen 12'
    setup_quickfix_mappings()
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

local function run_build_to_quickfix(opts)
  vim.cmd 'write'

  local cmd, cwd, metadata
  if opts and opts.args and opts.args ~= '' then
    cmd = opts.args
    cwd = vim.fn.getcwd()
  else
    cmd, cwd, metadata = project_build_cmd()
  end

  if not cmd then
    vim.notify('No build/check command found for this file or project', vim.log.levels.ERROR)
    return
  end

  vim.notify('BuildNow: ' .. cmd, vim.log.levels.INFO)

  vim.system({ vim.o.shell, vim.o.shellcmdflag, cmd }, { cwd = cwd, text = true }, function(result)
    vim.schedule(function()
      local lines = {}
      for _, stream in ipairs { result.stdout or '', result.stderr or '' } do
        for line in vim.gsplit(stream, '\n', { plain = true, trimempty = true }) do
          table.insert(lines, line)
        end
      end

      set_build_quickfix(lines, cmd, cwd, metadata)

      local count = vim.fn.getqflist({ size = 0 }).size
      if result.code == 0 and count == 0 then
        vim.notify('BuildNow: success', vim.log.levels.INFO)
      elseif result.code == 0 and count > 0 then
        vim.notify(('BuildNow: success with %d quickfix item(s)'):format(count), vim.log.levels.WARN)
      elseif count > 0 then
        vim.notify(('BuildNow: %d quickfix item(s)'):format(count), vim.log.levels.WARN)
      else
        vim.notify('BuildNow failed, but no jumpable errors were parsed', vim.log.levels.WARN)
      end
    end)
  end)
end

local function toggle_build_quickfix()
  if quickfix_win() then
    vim.cmd 'cclose'
    return
  end

  run_build_to_quickfix {}
end

local function run_built_target()
  local file_abs = vim.fn.expand '%:p'
  local ext = vim.fn.expand('%:e'):lower()
  local base = vim.fn.expand '%:t:r'
  local out_bin = '/tmp/' .. base .. '_run'
  local root = find_root {
    'package.json',
    'tsconfig.json',
    'Makefile',
    'makefile',
    'CMakeLists.txt',
    'pyproject.toml',
    'go.mod',
    '.git',
  }

  local language = project_language(ext, root)

  if is_cpp_file(ext) then
    if file_exists(root .. '/CMakeLists.txt') then
      local ok, err = pcall(vim.cmd, 'CMakeRun')
      if not ok then
        vim.notify('RunBuild: CMakeRun failed: ' .. tostring(err), vim.log.levels.WARN)
      end
      return
    end

    if file_exists(root .. '/Makefile') or file_exists(root .. '/makefile') then
      if has_make_target(root, 'run') then
        run_command_in_terminal('make run', root)
      else
        vim.notify('RunBuild: Makefile has no run target', vim.log.levels.WARN)
      end
      return
    end

    if file_exists(out_bin) then
      run_command_in_terminal(shellescape(out_bin), root)
    else
      vim.notify('RunBuild: no built executable found. Press <leader>b first.', vim.log.levels.WARN)
    end
    return
  end

  if language == 'go' then
    local default_cmd = file_exists(root .. '/go.mod') and 'go run .' or ('go run %s'):format(shellescape(file_abs))
    run_command_in_terminal(get_project_run_cmd(root, language, default_cmd), root)
    return
  end

  if language == 'python' then
    local default_cmd = ('python3 %s'):format(shellescape(file_abs))
    run_command_in_terminal(get_project_run_cmd(root, language, default_cmd), root)
    return
  end

  if language == 'typescript' then
    local default_cmd = package_script(root, { 'start', 'dev' }) or ('npx tsx %s'):format(shellescape(file_abs))
    run_command_in_terminal(get_project_run_cmd(root, language, default_cmd), root)
    return
  end

  if language == 'javascript' then
    local default_cmd = package_script(root, { 'start', 'dev' }) or ('node %s'):format(shellescape(file_abs))
    run_command_in_terminal(get_project_run_cmd(root, language, default_cmd), root)
    return
  end

  local cmd, err = build_cmd_for_current_file()
  if not cmd then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  run_command_in_terminal(cmd, root)
end

-- ---------- global state ----------
_G.RunNowState = _G.RunNowState or { buf = nil, chan = nil, prev_win = nil }

-- ---------- close terminal split (buffer-local mapping will call this) ----------
local function close_terminal_split()
  local s = _G.RunNowState
  if not (s and s.buf and vim.api.nvim_buf_is_valid(s.buf)) then
    return
  end

  local wins = vim.fn.win_findbuf(s.buf)
  if #wins == 0 then
    -- terminal not visible; just ensure buffer is wiped and state cleared
    pcall(vim.cmd, 'bwipeout! ' .. s.buf)
    s.buf, s.chan, s.prev_win = nil, nil, nil
    return
  end

  -- pick a valid window showing the terminal
  local winid = nil
  for _, w in ipairs(wins) do
    if vim.api.nvim_win_is_valid(w) then
      winid = w
      break
    end
  end
  if not winid then
    return
  end

  -- attempt to return focus to recorded prev_win after wipe
  local prev = s.prev_win
  -- make terminal window current, then wipe the buffer (this closes the window)
  pcall(vim.api.nvim_set_current_win, winid)
  pcall(vim.cmd, 'bwipeout! ' .. s.buf)

  -- restore focus: prefer prev_win if still valid, else try to move up
  if prev and vim.api.nvim_win_is_valid(prev) then
    pcall(vim.api.nvim_set_current_win, prev)
  else
    -- best-effort: move to the window above
    pcall(vim.cmd, 'wincmd k')
  end

  -- clear stored state (BufWipeout autocmd may also handle this, but keep it tidy)
  s.buf, s.chan, s.prev_win = nil, nil, nil
end

-- ---------- create / reuse terminal ----------
local function create_terminal()
  -- record the window we'll return to later
  local prev_win = vim.api.nvim_get_current_win()

  -- force bottom horizontal split, set height, and create a fresh buffer there
  vim.cmd 'botright split'
  vim.cmd 'resize 15'
  vim.cmd 'enew'

  local bufnr = vim.api.nvim_get_current_buf()
  local shell_cmd = vim.o.shell or 'bash'
  local chan = vim.fn.termopen(shell_cmd, { cwd = vim.fn.getcwd() })

  pcall(vim.api.nvim_buf_set_name, bufnr, 'RunNow Terminal')
  pcall(vim.api.nvim_buf_set_option, bufnr, 'buflisted', false)
  pcall(vim.api.nvim_buf_set_option, bufnr, 'swapfile', false)
  pcall(vim.api.nvim_buf_set_option, bufnr, 'bufhidden', 'hide') -- hidden when not displayed

  -- one augroup per buffer to avoid duplicate autocmds
  local aug = vim.api.nvim_create_augroup('RunNow_' .. bufnr, { clear = true })

  -- When wiped, clear global state so next run recreates a clean terminal
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = aug,
    buffer = bufnr,
    callback = function()
      if _G.RunNowState and _G.RunNowState.buf == bufnr then
        _G.RunNowState.buf, _G.RunNowState.chan, _G.RunNowState.prev_win = nil, nil, nil
      end
    end,
  })

  -- buffer-local mappings:
  -- Normal mode: press Shift-H (capital H) to close the terminal and return above
  vim.keymap.set('n', 'K', close_terminal_split, { buffer = bufnr, noremap = true, silent = true })

  -- Terminal mode: pressing Shift-H should first get us to Normal mode, then close.
  vim.keymap.set('t', 'H', function()
    -- exit terminal-mode to Normal mode, then run close routine
    local esc = vim.api.nvim_replace_termcodes('<C-\\><C-n>', true, false, true)
    vim.api.nvim_feedkeys(esc, 'n', true)
    close_terminal_split()
  end, { buffer = bufnr, noremap = true, silent = true })

  _G.RunNowState.buf = bufnr
  _G.RunNowState.chan = chan
  _G.RunNowState.prev_win = prev_win
  return bufnr, chan
end

function ensure_terminal()
  local s = _G.RunNowState
  if s.buf and vim.api.nvim_buf_is_valid(s.buf) and s.chan then
    local wins = vim.fn.win_findbuf(s.buf)
    if #wins == 0 then
      -- terminal exists but is hidden: open it at bottom and set it visible
      s.prev_win = vim.api.nvim_get_current_win()
      vim.cmd 'botright split'
      vim.cmd 'resize 15'
      vim.api.nvim_set_current_buf(s.buf)
    else
      -- if already visible somewhere, just focus it
      pcall(vim.api.nvim_set_current_win, wins[1])
    end
    return s.buf, s.chan
  end
  return create_terminal()
end

-- ---------- run file ----------
local function run_current_file()
  vim.cmd 'write'
  local cmd, err = build_cmd_for_current_file()
  if not cmd then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local args = vim.fn.input 'Args? '
  if args and args ~= '' then
    cmd = cmd .. ' ' .. args
  end

  local bufnr, chan = ensure_terminal()
  -- ensure terminal window is visible and focused
  vim.api.nvim_set_current_buf(bufnr)

  local ok = pcall(function()
    vim.api.nvim_chan_send(chan, 'clear\n')
    vim.api.nvim_chan_send(chan, cmd .. '\n')
  end)
  if not ok then
    bufnr, chan = create_terminal()
    vim.api.nvim_set_current_buf(bufnr)
    local ok2, send_err2 = pcall(vim.api.nvim_chan_send, chan, cmd .. '\n')
    if not ok2 then
      vim.notify('Failed to send command to terminal: ' .. tostring(send_err2), vim.log.levels.ERROR)
      return
    end
  end
end

-- ---------- user commands / mappings ----------
vim.api.nvim_create_user_command(RUNNER_CMD_NAME, run_current_file, {})
vim.api.nvim_create_user_command(BUILD_CMD_NAME, run_build_to_quickfix, {
  nargs = '*',
  complete = 'shellcmd',
})
vim.api.nvim_create_user_command(BUILD_TOGGLE_CMD_NAME, toggle_build_quickfix, {})
vim.api.nvim_create_user_command(RUN_BUILD_CMD_NAME, run_built_target, {})
vim.api.nvim_create_user_command(CMAKE_INIT_CMD_NAME, init_cmake_project, {})

vim.keymap.set('n', '<F5>', function()
  vim.cmd(RUNNER_CMD_NAME)
end, { noremap = true, silent = true })

vim.keymap.set('n', '<leader>b', '<cmd>BuildToggle<CR>', { noremap = true, silent = true, desc = 'Toggle build quickfix' })

vim.keymap.set('n', '<leader>r', function()
  vim.cmd(RUN_BUILD_CMD_NAME)
end, { noremap = true, silent = true, desc = 'Run built target' })

vim.keymap.set('n', '<leader>co', '<cmd>copen<CR>', { silent = true, desc = 'Open quickfix' })
vim.keymap.set('n', '<leader>cn', '<cmd>cnext<CR>', { silent = true, desc = 'Next quickfix item' })
vim.keymap.set('n', '<leader>cp', '<cmd>cprev<CR>', { silent = true, desc = 'Previous quickfix item' })
