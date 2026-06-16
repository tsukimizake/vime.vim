-- テスト用 最小 init: plenary とプラグイン本体を runtimepath に追加する
local data = vim.fn.stdpath("data")
local plenary = data .. "/lazy/plenary.nvim"

vim.opt.runtimepath:append(vim.fn.getcwd())
vim.opt.runtimepath:append(plenary)

-- テストヘルパ(tests/ 配下)を require できるようにする
package.path = package.path .. ";" .. vim.fn.getcwd() .. "/?.lua"

-- 実 HOME のうちに libanthy を解決して VIME_ANTHY_LIB に固定する。
-- この後 HOME を temp 化すると ~ 展開先が変わり ~/.local/lib 等を見失うため、先に確定させる。
local lib = require("vime.config").find_anthy_lib()
if lib then
  vim.env.VIME_ANTHY_LIB = lib
end

-- anthy の学習をテストごとに隔離して決定的にする(spec ファイル単位で別 nvim=別 tmp)。
-- 原 anthy(9100h)は $HOME/.anthy、anthy-unicode は $XDG_CONFIG_HOME/anthy に保存する
-- (anthy-unicode の HOME は getpwuid 由来で env では変えられないため XDG の隔離が必須)。両方を一時化する。
local tmp_home = vim.fn.tempname()
vim.fn.mkdir(tmp_home, "p")
vim.env.HOME = tmp_home
vim.env.XDG_CONFIG_HOME = tmp_home .. "/.config"

vim.cmd("runtime plugin/plenary.vim")
