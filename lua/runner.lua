-- ===== Multi-language Code Runner (Neovim + Lua) =====
-- Supports: Python (.py), C (.c via gcc), C++ (.cpp/.cc/.cxx via g++),
--           x86 Assembly (.asm/.s via nasm -f elf32 + ld -m elf_i386)
-- Creates a :RunNow command (rename if you like) and <F5> keybinding.

-- Change this if you want a different command name
local RUNNER_CMD_NAME = 'RunNow'

local function shellescape(s)
  return vim.fn.shellescape(s)
end

local function build_cmd_for_current_file()
  local file_abs = vim.fn.expand '%:p'
  local ext = vim.fn.expand '%:e'
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
    -- Requires: nasm (32-bit output) and 32-bit linker support
    -- On many distros you may need: sudo apt-get install gcc-multilib
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

local function run_current_file()
  -- Save first
  vim.cmd 'w'

  local cmd, err = build_cmd_for_current_file()
  if not cmd then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- Optional: prompt for program args (passed after the executable/script)
  local args = vim.fn.input 'Args? '
  if args ~= nil and args ~= '' then
    cmd = cmd .. ' ' .. args
  end

  -- Use bash -lc so we can use && and PATH expansions
  local term_cmd = 'term://bash -lc ' .. shellescape(cmd)

  -- Open a split terminal and run
  vim.cmd('split ' .. term_cmd)
  -- Tip: change to "vsplit " .. term_cmd if you prefer vertical splits
end

-- User command (rename RUNNER_CMD_NAME to any name you like)
vim.api.nvim_create_user_command(RUNNER_CMD_NAME, run_current_file, {})
