-- 辞書取込 CLI: nvim -l <vime>/lua/vime/import.lua <SKK-JISYO.*.json> [<...>]
--
-- SKK 辞書(JISYO 形式 JSON)の okuri_nasi を anthy の私的辞書へ名詞として取り込む。
-- per-entry の anthy API は遅い(L で数分)ため、私的辞書テキスト private_words_default を
-- 直接生成する。既存語を保持しつつ全体を読みでソート(texttrie の要件)・重複排除して書き戻す。
-- 編集中の Vim とは別プロセスの一回作業として実行する。
local here = debug.getinfo(1, "S").source:sub(2) -- .../lua/vime/import.lua
local root = vim.fn.fnamemodify(here, ":h:h:h") -- プラグインルート
vim.opt.runtimepath:append(root)

local config = require("vime.config")
local anthy = require("vime.anthy")
local skk = require("vime.skk")

local files = arg or {}
if #files == 0 then
  io.stderr:write("usage: nvim -l lua/vime/import.lua <SKK-JISYO.*.json> [<...>]\n")
  os.exit(2)
end

local lib = config.find_anthy_lib()
if not (lib and anthy.setup(lib)) then
  io.stderr:write(
    "vime: libanthy が見つからないか初期化に失敗しました ($VIME_ANTHY_LIB で指定可)\n"
  )
  os.exit(1)
end

local dic_path = anthy.private_dic_path()
if not dic_path then
  io.stderr:write("vime: anthy 私的辞書のパスを解決できませんでした\n")
  os.exit(1)
end
vim.fn.mkdir(vim.fn.fnamemodify(dic_path, ":h"), "p") -- 辞書ディレクトリが無ければ作る

-- 既存の私的辞書(他ツールで登録した語など)を保持する
local all = {}
local existing = io.open(dic_path, "r")
if existing then
  for line in existing:lines() do
    if line ~= "" then
      all[#all + 1] = line
    end
  end
  existing:close()
end

local added, skipped = 0, 0
for _, path in ipairs(files) do
  local fd = io.open(path, "r")
  if not fd then
    io.stderr:write("スキップ(開けない): " .. path .. "\n")
  else
    local decoded = skk.decode(fd:read("*a"))
    fd:close()
    if not decoded then
      io.stderr:write("スキップ(不正な JSON): " .. path .. "\n")
    else
      local lines, sk = skk.to_lines(skk.entries(decoded))
      for _, l in ipairs(lines) do
        all[#all + 1] = l
      end
      added = added + #lines
      skipped = skipped + sk
      print(string.format("取り込み: %d 語 (skip %d) <- %s", #lines, sk, path))
    end
  end
end

-- texttrie は読みのソート済みを要求する。重複排除＋ソートして書き戻す。
local sorted = skk.sort_unique(all)
local fp = io.open(dic_path, "w")
if not fp then
  io.stderr:write("vime: 書き込めません: " .. dic_path .. "\n")
  os.exit(1)
end
fp:write(table.concat(sorted, "\n"))
fp:write("\n")
fp:close()
print(string.format("完了: %s に %d 語 (今回 +%d, skip %d)", dic_path, #sorted, added, skipped))
