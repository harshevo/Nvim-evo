-- ===== RunNow: reuse a single terminal buffer (no split) and send commands =====
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
_G.RunNowState = _G.RunNowState or { buf = nil, chan = nil }

-- ---------- create / reuse terminal ----------
local function create_terminal()
  vim.cmd 'enew' -- new empty buffer in current window
  local bufnr = vim.api.nvim_get_current_buf()
  local shell_cmd = vim.o.shell or 'bash'
  local chan = vim.fn.termopen(shell_cmd, { cwd = vim.fn.getcwd() })

  pcall(vim.api.nvim_buf_set_name, bufnr, 'RunNow Terminal')
  pcall(vim.api.nvim_buf_set_option, bufnr, 'buflisted', false)
  pcall(vim.api.nvim_buf_set_option, bufnr, 'swapfile', false)
  -- keep 'hide' here; we’ll explicitly wipe in autocmds (more reliable across cases)
  pcall(vim.api.nvim_buf_set_option, bufnr, 'bufhidden', 'hide')

  -- one augroup per buffer to avoid duplicate autocmds
  local aug = vim.api.nvim_create_augroup('RunNow_' .. bufnr, { clear = true })

  -- 1) When you leave this buffer in ANY window, schedule a wipe (after switch completes)
  vim.api.nvim_create_autocmd('BufLeave', {
    group = aug,
    buffer = bufnr,
    callback = function()
      local target = bufnr
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(target) then
          -- if it's still current for some reason, defer a tick
          if vim.api.nvim_get_current_buf() == target then
            vim.defer_fn(function()
              if vim.api.nvim_buf_is_valid(target) then
                pcall(vim.cmd, 'bwipeout! ' .. target)
              end
            end, 10)
          else
            pcall(vim.cmd, 'bwipeout! ' .. target)
          end
        end
      end)
    end,
  })

  -- 2) If it becomes hidden anywhere (no window shows it), wipe as a safety net
  vim.api.nvim_create_autocmd('BufHidden', {
    group = aug,
    buffer = bufnr,
    once = true,
    callback = function()
      local target = bufnr
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(target) then
          pcall(vim.cmd, 'bwipeout! ' .. target)
        end
      end)
    end,
  })

  -- 3) When wiped, clear global state so next run recreates a clean terminal
  vim.api.nvim_create_autocmd('BufWipeout', {
    group = aug,
    buffer = bufnr,
    callback = function()
      if _G.RunNowState.buf == bufnr then
        _G.RunNowState.buf, _G.RunNowState.chan = nil, nil
      end
    end,
  })

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
