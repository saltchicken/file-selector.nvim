vim.api.nvim_create_user_command("FileSelector", function()
  require("file-selector").create_file_selector()
end, {})
