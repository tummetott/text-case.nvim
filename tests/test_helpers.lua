local M = {}

M.get_buf_lines = function()
  local result = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
  return result
end

M.execute_keys = function(feedkeys, mode)
  local keys = vim.api.nvim_replace_termcodes(feedkeys, true, false, true)
  vim.api.nvim_feedkeys(keys, mode or "x", false)
end

---@param path string
M.read_file = function(path)
  local fd = vim.loop.fs_open(path, "r", 438)
  local fstat = vim.loop.fs_fstat(fd)
  local contents = vim.loop.fs_read(fd, fstat.size, 0)
  vim.loop.fs_close(fd)
  return contents
end

M.wait_for = function(max_milliseconds, callback)
  local step = 100
  local curr_milliseconds = 0
  local task_finished = false
  while curr_milliseconds < max_milliseconds and not task_finished do
    task_finished = callback()
    vim.wait(step, function() end)
    curr_milliseconds = curr_milliseconds + step
  end
end

-- Wait for the language server to answer a hover request for the fixture symbol.
local function wait_for_hover(expected)
  local ready = false
  M.wait_for(30 * 1000, function()
    if ready then
      return true
    end

    local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
    local clients = get_clients({ bufnr = 0 })
    if #clients == 0 then
      return false
    end

    local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
    vim.lsp.buf_request_all(0, "textDocument/hover", params, function(results)
      for _, response in pairs(results or {}) do
        local contents = response.result and response.result.contents
        local text = type(contents) == "table" and contents.value or contents
        if type(text) == "string" and string.find(text, expected, 1, true) then
          ready = true
        end
      end
    end)
    return false
  end)
  assert(ready, "Language server did not return hover for " .. expected)
end

M.wait_for_language_server_to_start = function()
  M.execute_keys("ww") -- Move to `doSomething`
  wait_for_hover("doSomething")
end

M.wait_for_language_server_to_start_on_destructuring_file = function()
  M.execute_keys("ww") -- Move to `fooVar`
  wait_for_hover("fooVar")
end

return M
