-- RunNow: reuse a single terminal buffer (no split) and send commands to it
local RUNNER_CMD_NAME = 'RunNow'

-- copy/keep your existing build_cmd_for_current_file() here
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

-- global storage so it persists between calls
_G.RunNowState = _G.RunNowState or { buf = nil, chan = nil }

local function create_terminal()
  -- open a new empty buffer in the current window (no split)
  vim.cmd 'enew'

  local bufnr = vim.api.nvim_get_current_buf()
  -- start an interactive shell in this buffer; `termopen` returns a channel/job id
  local shell_cmd = vim.o.shell and vim.o.shell or 'bash'
  local chan = vim.fn.termopen(shell_cmd, { cwd = vim.fn.getcwd() })

  -- friendly name + options
  pcall(vim.api.nvim_buf_set_name, bufnr, 'RunNow Terminal')
  pcall(vim.api.nvim_buf_set_option, bufnr, 'bufhidden', 'hide')
  pcall(vim.api.nvim_buf_set_option, bufnr, 'swapfile', false)

  _G.RunNowState.buf = bufnr
  _G.RunNowState.chan = chan
  return bufnr, chan
end

local function ensure_terminal()
  local s = _G.RunNowState
  if s.buf and vim.api.nvim_buf_is_valid(s.buf) and s.chan then
    return s.buf, s.chan
  end
  return create_terminal()
end

local function run_current_file()
  -- save first
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

  -- show the terminal buffer in the current window (replaces whatever buffer you're on)
  vim.api.nvim_set_current_buf(bufnr)

  -- try to send the command; if it fails (channel died) recreate the terminal and retry
  local ok, send_err = pcall(function()
    vim.api.nvim_chan_send(chan, 'clear\n')
    vim.api.nvim_chan_send(chan, cmd .. '\n')
  end)
  if not ok then
    -- channel might have died: recreate terminal and retry once
    create_terminal()
    bufnr, chan = _G.RunNowState.buf, _G.RunNowState.chan
    vim.api.nvim_set_current_buf(bufnr)
    local ok2, send_err2 = pcall(vim.api.nvim_chan_send, chan, cmd .. '\n')
    if not ok2 then
      vim.notify('Failed to send command to terminal: ' .. tostring(send_err2), vim.log.levels.ERROR)
    end
  end
end

vim.api.nvim_create_user_command(RUNNER_CMD_NAME, run_current_file, {})

-- optional: map F5 to RunNow
vim.keymap.set('n', '<F5>', function()
  vim.cmd(RUNNER_CMD_NAME)
end, { noremap = true, silent = true })
