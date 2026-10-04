local group = vim.api.nvim_create_augroup('LargeFilePerformance', { clear = true })
local limit = 1024 * 1024

vim.api.nvim_create_autocmd('BufReadPre', {
  group = group,
  callback = function(event)
    local stat = vim.uv.fs_stat(event.file)
    vim.b[event.buf].large_file = stat ~= nil and stat.size >= limit
  end,
})

vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWinEnter', 'FileType' }, {
  group = group,
  callback = function(event)
    if vim.api.nvim_buf_line_count(event.buf) >= 20000 then
      vim.b[event.buf].large_file = true
    end
    if vim.b[event.buf].large_file then
      vim.bo[event.buf].syntax = ''
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(event.buf) and vim.b[event.buf].large_file then
          vim.bo[event.buf].syntax = ''
          pcall(vim.treesitter.stop, event.buf)
        end
      end)
      vim.bo[event.buf].synmaxcol = 200
      vim.bo[event.buf].swapfile = false
      vim.diagnostic.enable(false, { bufnr = event.buf })
    end
  end,
})
