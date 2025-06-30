return {
  vim.keymap.set('v', '<leader>p', function()
    vim.cmd 'normal! "vy'
    local text = vim.fn.getreg 'v'

    if text == '' then
      vim.notify('No text selected.', vim.log.levels.WARN)
      return
    end

    -- Trim trailing newlines from selection
    text = text:gsub('[\r\n]+$', '')

    -- Find Python pane
    local handle = io.popen 'wezterm cli list --format json'
    if not handle then
      vim.notify('Failed to run wezterm cli.', vim.log.levels.ERROR)
      return
    end

    local result = handle:read '*a'
    handle:close()

    local ok, panes = pcall(vim.fn.json_decode, result)
    if not ok or type(panes) ~= 'table' then
      vim.notify('Failed to parse wezterm pane list.', vim.log.levels.ERROR)
      return
    end

    local python_pane_id = nil
    for _, pane in ipairs(panes) do
      local title = (pane.title or ''):lower()
      if title:match 'python' then
        python_pane_id = pane.pane_id
        break
      end
    end

    if not python_pane_id then
      vim.notify("Couldn't find a wezterm pane running Python.", vim.log.levels.ERROR)
      return
    end

    -- Add extra newline only if it's a block
    local needs_block_close = false
    for _, line in ipairs(vim.split(text, '\n', { plain = true })) do
      if line:match '^%s*[%w_]+.*:%s*$' then
        needs_block_close = true
        break
      end
    end

    local to_send = text .. '\n'
    if needs_block_close then
      to_send = to_send .. '\n'
    end

    vim.fn.jobstart({
      'wezterm',
      'cli',
      'send-text',
      '--pane-id',
      tostring(python_pane_id),
      '--no-paste',
      '--',
      to_send,
    }, {
      detach = true,
      on_stderr = function(_, data)
        -- Ignore empty stderr
        local err = table.concat(data or {}, '\n')
        if err:match '%S' then
          vim.notify('Error sending to REPL:\n' .. err, vim.log.levels.ERROR)
        end
      end,
    })
  end, { desc = 'Send visual block to Python REPL', silent = true }),
}
