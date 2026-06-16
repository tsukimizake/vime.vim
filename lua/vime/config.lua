-- 設定。デフォルトとユーザー設定をマージし、anthy ライブラリのパスを解決する。
local M = {}

M.defaults = {
  anthy = {
    lib = nil, -- 未指定なら既知パスを探索
  },
  keymaps = {
    toggle = "<C-j>",
    convert = "<Space>",
    commit = "<CR>",
    cancel = "<C-g>",
    next_segment = "<C-f>",
    prev_segment = "<C-b>",
    expand = "<C-o>",
    shrink = "<C-i>",
  },
  popup = {
    threshold = 3, -- Space を N 回で候補一覧
    labels = "asdfghjkl",
  },
}

-- anthy ライブラリの既知パス候補。
M.lib_candidates = {
  "/nix/store/m2z37mlz9rsh2azv9pny1860rpycic54-anthy-9100h/lib/libanthy.dylib",
  "/opt/homebrew/lib/libanthy.dylib",
  "/usr/local/lib/libanthy.dylib",
  "/usr/lib/libanthy.so",
}

-- defaults へ user を再帰マージした新しいテーブルを返す。
function M.merge(user)
  local function deep(base, over)
    local out = {}
    for k, v in pairs(base) do
      out[k] = v
    end
    if over then
      for k, v in pairs(over) do
        if type(v) == "table" and type(out[k]) == "table" then
          out[k] = deep(out[k], v)
        else
          out[k] = v
        end
      end
    end
    return out
  end
  return deep(M.defaults, user)
end

-- candidates(省略時は既知パス)のうち最初に存在するパスを返す。無ければ nil。
function M.find_anthy_lib(candidates)
  candidates = candidates or M.lib_candidates
  for _, path in ipairs(candidates) do
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end
  return nil
end

return M
