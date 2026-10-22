-- Insert a starter template into a .c or .cpp file with :loadbp.
local templates = {
  cpp = {
    '#include <algorithm>',
    '#include <iostream>',
    '#include <string>',
    '#include <vector>',
    '',
    'using namespace std;',
    '',
    'int main(int argc, char *argv[]) {',
    '  ',
    '  return 0;',
    '}',
  },
  c = {
    '#include <stdbool.h>',
    '#include <stdio.h>',
    '#include <stdlib.h>',
    '#include <string.h>',
    '',
    'int main(int argc, char *argv[]) {',
    '  ',
    '  return 0;',
    '}',
  },
}

local function insert_template()
  local ext = vim.fn.expand '%:e'
  local lang = (ext == 'cpp' or ext == 'c') and ext or nil
  if not lang then
    vim.notify('Template: current file must end in .c or .cpp', vim.log.levels.WARN)
    return
  end

  local lines = templates[lang]
  vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
  -- Park the cursor on the indented blank line inside main().
  vim.api.nvim_win_set_cursor(0, { #lines - 2, 2 })
end

-- User commands must start with a capital letter, so the command is Loadbp.
-- The abbreviation lets you type :loadbp in lowercase.
vim.api.nvim_create_user_command('Loadbp', insert_template, { desc = 'Insert C/C++ template' })
vim.cmd.cnoreabbrev('loadbp', 'Loadbp')
