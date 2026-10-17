-- Used by check.sh: exits 0 once every server in $EXPECT (comma-separated) is attached to the
-- current buffer, or exits 1 after 90 seconds.
local expected = vim.split(vim.env.EXPECT, ",")
local deadline = vim.uv.now() + 90000

local function attached()
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
    names[client.name] = true
  end
  for _, name in ipairs(expected) do
    if not names[name] then return false end
  end
  return true
end

local function poll()
  if attached() then
    vim.cmd "qa!"
  elseif vim.uv.now() > deadline then
    vim.cmd "cquit 1"
  else
    vim.defer_fn(poll, 500)
  end
end

poll()
