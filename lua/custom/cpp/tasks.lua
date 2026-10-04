local M = { states = {} }

local function state(kind)
  if not M.states[kind] then
    M.states[kind] = { generation = 0, lines = {} }
  end
  return M.states[kind]
end

local function render(s)
  if not s.buf or not vim.api.nvim_buf_is_valid(s.buf) then
    return
  end
  vim.bo[s.buf].modifiable = true
  vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, s.lines)
  vim.bo[s.buf].modifiable = false
end

function M.refresh(kind)
  render(state(kind))
end

function M.close(kind)
  local s = state(kind)
  if s.buf then
    for _, win in ipairs(vim.fn.win_findbuf(s.buf)) do
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

function M.open(kind, opts)
  local s = state(kind)
  opts = opts or {}
  s.layout = opts.layout or s.layout
  s.width = opts.width or s.width
  if not s.buf or not vim.api.nvim_buf_is_valid(s.buf) then
    s.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[s.buf].bufhidden = 'hide'
    vim.bo[s.buf].swapfile = false
    vim.api.nvim_buf_set_name(s.buf, (kind:match '^py%-' and 'python-ide://' or 'cpp-ide://') .. kind)
    vim.bo[s.buf].filetype = kind:match '^py%-' and 'python_task' or 'cpp_task'
    for _, lhs in ipairs { 'q', '<Esc>' } do
      vim.keymap.set('n', lhs, function()
        M.close(kind)
      end, { buffer = s.buf, nowait = true, desc = 'Hide task output' })
    end
    vim.keymap.set('n', '<CR>', function()
      M.jump(kind)
    end, { buffer = s.buf, desc = 'Jump to result' })
    vim.keymap.set('n', 'o', function()
      M.jump(kind)
    end, { buffer = s.buf, desc = 'Jump to result' })
    vim.keymap.set('n', '<leader>to', function()
      M.toggle(kind:match '^py%-' and 'py-test' or 'test')
    end, { buffer = s.buf, nowait = true, desc = 'Toggle test output' })
    vim.keymap.set('n', '<leader>ao', function()
      M.toggle(kind:match '^py%-' and 'py-analysis' or 'analysis')
    end, { buffer = s.buf, nowait = true, desc = 'Toggle analysis output' })
    if kind:match '^py%-' then
      require('custom.core.python_ide').map(s.buf)
      vim.keymap.set('n', '<leader>b', '<cmd>PyCheckToggle<CR>', { buffer = s.buf, nowait = true, desc = 'Toggle Python errors' })
    end
  end
  local win = vim.fn.win_findbuf(s.buf)[1]
  if win then
    vim.api.nvim_set_current_win(win)
    return
  end
  if s.layout == 'right' then
    vim.cmd('botright ' .. math.max(30, math.min(s.width or 64, math.floor(vim.o.columns * 0.48))) .. 'vsplit')
  else
    vim.cmd 'botright 12split'
  end
  vim.api.nvim_win_set_buf(0, s.buf)
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.wrap = false
  vim.wo.winfixbuf = s.layout == 'right'
  render(s)
end

function M.toggle(kind, opts)
  local s = state(kind)
  if s.buf and #vim.fn.win_findbuf(s.buf) > 0 then
    M.close(kind)
  else
    M.open(kind, opts)
  end
end

function M.stop(kind)
  local s = state(kind)
  s.generation = s.generation + 1
  if s.process then
    if s.process.pid then
      pcall(vim.uv.kill, -s.process.pid, 15)
    end
    s.process:kill(15)
    s.process = nil
    s.lines = { 'Cancelled', 'Task process stopped' }
    render(s)
  end
end

function M.jump(kind)
  local s = state(kind)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = s.lines[row] or ''
  local file, number, col = line:match '^%s*(.-):(%d+):(%d+):'
  if not file then
    file, number = line:match '^%s*(.-):(%d+):'
  end
  local location = file and { file = file, line = tonumber(number), col = tonumber(col) or 1 }
  if not location and s.locations then
    location = s.locations[row]
  end
  if not location then
    return
  end
  local path = location.file:sub(1, 1) == '/' and location.file or s.cwd .. '/' .. location.file
  if not vim.uv.fs_stat(path) then
    return
  end
  local target
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not vim.wo[win].winfixbuf and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == '' then
      target = win
      break
    end
  end
  if target then
    vim.api.nvim_set_current_win(target)
  else
    vim.cmd 'topleft new'
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  vim.api.nvim_win_set_cursor(0, { math.min(location.line or 1, vim.api.nvim_buf_line_count(0)), math.max(0, (location.col or 1) - 1) })
end

function M.run(kind, cmd, cwd, opts)
  opts = opts or {}
  M.stop(kind)
  local s = state(kind)
  local generation = s.generation
  s.layout = opts.layout or s.layout
  s.width = opts.width or s.width
  s.cwd = cwd
  s.locations = {}
  s.result = nil
  s.lines = { opts.title or kind, 'Running...', '' }
  if opts.open then
    M.open(kind)
  end
  render(s)
  local ok, process = pcall(vim.system, cmd, { cwd = cwd, text = true, detach = true, env = opts.env }, function(result)
    vim.schedule(function()
      if generation ~= s.generation then
        return
      end
      s.process = nil
      s.result = result
      s.lines = { opts.title or kind, 'Exit status: ' .. result.code .. (result.signal ~= 0 and ' (signal ' .. result.signal .. ')' or ''), '' }
      for _, stream in ipairs { result.stdout or '', result.stderr or '' } do
        for line in vim.gsplit(stream, '\n', { plain = true, trimempty = true }) do
          s.lines[#s.lines + 1] = line
        end
      end
      if opts.decorate then
        opts.decorate(s, result)
      end
      render(s)
      if opts.on_exit then
        opts.on_exit(result, s)
      end
    end)
  end)
  if ok then
    s.process = process
  else
    s.result = { code = 127, signal = 0, stdout = '', stderr = tostring(process) }
    s.lines = { opts.title or kind, 'Unable to start command', tostring(process) }
    render(s)
    if opts.on_exit then
      opts.on_exit(s.result, s)
    end
  end
  return s
end

vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    for kind in pairs(M.states) do
      M.stop(kind)
    end
  end,
})
return M
