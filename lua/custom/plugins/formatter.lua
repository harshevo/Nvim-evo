--formatter
return {
  'stevearc/conform.nvim',
  event = 'BufWritePre',
  cmd = { 'ConformInfo', 'KickstartFormatToggle' },
  keys = { '<leader>mp' },
  config = function()
    local conform = require 'conform'

    conform.setup {
      formatters = {
        ['clang-format'] = {
          prepend_args = { '--style=file:' .. vim.fn.stdpath 'config' .. '/clang-format.yaml' },
        },
      },
      formatters_by_ft = {
        javascript = { 'prettier' },
        typescript = { 'prettier' },
        javascriptreact = { 'prettier' },
        typescriptreact = { 'prettier' },
        svelte = { 'prettier' },
        css = { 'prettier' },
        json = { 'prettier' },
        yaml = { 'prettier' },
        markdown = { 'prettier' },
        go = { 'goimports', 'gofmt' },
        lua = { 'stylua' },
        python = { 'isort', 'black' },
        c = { 'clang-format' },
        cpp = { 'clang-format' },
      },
      format_on_save = function(bufnr)
        if vim.g.autoformat == false or vim.b[bufnr].large_file or vim.bo[bufnr].buftype ~= '' then
          return
        end
        return { lsp_format = 'fallback', timeout_ms = 500, quiet = true }
      end,
    }

    vim.api.nvim_create_user_command('KickstartFormatToggle', function()
      vim.g.autoformat = vim.g.autoformat == false
      vim.notify('Autoformat: ' .. tostring(vim.g.autoformat))
    end, {})

    vim.keymap.set({ 'n', 'v' }, '<leader>mp', function()
      conform.format {
        lsp_format = 'fallback',
        async = false,
        timeout_ms = 1000,
      }
    end, { desc = 'Format file or range (in visual mode)' })
  end,
}
