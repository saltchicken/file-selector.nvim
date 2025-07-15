local M = {}

-- Get all files in current directory and subdirectories
local function get_all_files()
  local files = {}
  local handle = io.popen("find . -type f -not -path '*/.*' 2>/dev/null")
  if handle then
    for line in handle:lines() do
      local clean_path = line:gsub("^%./", "")
      table.insert(files, clean_path)
    end
    handle:close()
  end
  table.sort(files)
  return files
end

-- Read previously selected files from a file (if it exists)
local function read_selected_file(filepath)
  local selected = {}
  local f = io.open(filepath, "r")
  if f then
    for line in f:lines() do
      selected[line] = true
    end
    f:close()
  end
  return selected
end

-- Create the file selector buffer
function M.create_file_selector()
  local context_file = vim.api.nvim_buf_get_name(0)
  local all_files = get_all_files()
  local selected = read_selected_file(context_file)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "File Selector")

  vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(buf, "filetype", "file-selector")

  local content_lines = {
    "",
  }

  for _, file in ipairs(all_files) do
    local mark = selected[file] and "[x]" or "[ ]"
    table.insert(content_lines, mark .. " " .. file)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)
  vim.api.nvim_win_set_buf(0, buf)

  local function setup_keymaps()
    vim.api.nvim_buf_set_keymap(buf, "n", "<Space>", "", {
      callback = function()
        local line_num = vim.api.nvim_win_get_cursor(0)[1]
        if line_num <= 1 then
          return
        end
        local line = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]
        local file_index = line_num - 1
        local filename = all_files[file_index]

        if line:match("^%[x%]") then
          local new_line = line:gsub("^%[x%]", "[ ]")
          vim.api.nvim_buf_set_lines(buf, line_num - 1, line_num, false, { new_line })
          selected[filename] = nil
        elseif line:match("^%[ %]") then
          local new_line = line:gsub("^%[ %]", "[x]")
          vim.api.nvim_buf_set_lines(buf, line_num - 1, line_num, false, { new_line })
          selected[filename] = true
        end
      end,
      noremap = true,
      silent = true,
    })

    vim.api.nvim_buf_set_keymap(buf, "n", "<leader>sa", "", {
      callback = function()
        local new_lines = {}
        table.insert(new_lines, vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
        for _, file in ipairs(all_files) do
          table.insert(new_lines, "[x] " .. file)
          selected[file] = true
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
      end,
      noremap = true,
      silent = true,
    })

    vim.api.nvim_buf_set_keymap(buf, "n", "<leader>sc", "", {
      callback = function()
        local new_lines = {}
        table.insert(new_lines, vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
        for _, file in ipairs(all_files) do
          table.insert(new_lines, "[ ] " .. file)
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
        selected = {}
      end,
      noremap = true,
      silent = true,
    })
  end

  setup_keymaps()

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local output_file = context_file
      if output_file == "" then
        vim.notify("No context file available to write to", vim.log.levels.ERROR)
        return
      end

      local file_handle = io.open(output_file, "w")
      if not file_handle then
        vim.notify("Error: Could not write to " .. output_file, vim.log.levels.ERROR)
        return
      end

      for file, _ in pairs(selected) do
        file_handle:write(file .. "\n")
      end
      file_handle:close()
      vim.notify("Selected files saved to " .. output_file, vim.log.levels.INFO)
      vim.api.nvim_buf_set_option(buf, "modified", false)
    end,
  })

  -- for i = 1, 6 do
  --   vim.api.nvim_buf_add_highlight(buf, -1, "Comment", i - 1, 0, -1)
  -- end

  vim.api.nvim_win_set_cursor(0, { 2, 0 })
end

return M