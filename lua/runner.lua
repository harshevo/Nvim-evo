-- ===== RunNow: reuse a single terminal buffer (split) and Shift-H closes it =====
local RUNNER_CMD_NAME = 'RunNow'

-- ---------- build command for current file ----------
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

local function ensure_terminal()
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

vim.keymap.set('n', '<F5>', function()
  vim.cmd(RUNNER_CMD_NAME)
end, { noremap = true, silent = true })
