-- 変換セッションの状態機械(COMPOSING / CONVERTING)。
-- ローマ字バッファを真実とし、preedit は都度 romaji.to_kana で導出する。
-- anthy への依存はインターフェース(convert/resize/commit/close)越し(DIP)。テストは fake を注入する。
local romaji = require("vime.romaji")

local M = {}

local Session = {}
Session.__index = Session

-- anthy_module: setup 済みの anthy(.new_session() を持つ)。テストでは fake を渡す。
function M.new(anthy_module)
  return setmetatable({
    _anthy = anthy_module, -- anthy セッションを生成するモジュール
    anthy = nil,           -- 生成した anthy セッション(変換中に再利用)
    _state = "composing",
    romaji = "",
    _segments = nil,
    seg_index = 1,
    choices = {},
  }, Session)
end

function Session:state()
  return self._state
end

function Session:preedit()
  return romaji.to_kana(self.romaji)
end

-- composing 状態へ戻す(確定/取消後)。
local function reset_composing(self)
  self._state = "composing"
  self.romaji = ""
  self._segments = nil
  self.seg_index = 1
  self.choices = {}
end

-- 1文字入力。converting 中は現変換を自動確定し、確定文字列を返す。
function Session:input(ch)
  if self._state == "converting" then
    local confirmed = self:commit()
    self.romaji = ch
    return confirmed
  end
  self.romaji = self.romaji .. ch
  return ""
end

-- UTF-8 文字数を数える(継続バイト 0x80-0xBF を除外)。
local function uchars(s)
  local n = 0
  for i = 1, #s do
    local b = s:byte(i)
    if b < 0x80 or b >= 0xC0 then
      n = n + 1
    end
  end
  return n
end

-- かな単位で1文字削除する。ローマ字を末尾から削り、
-- 「未完成の英字で終わらず」かつ「かな数が1減った」ところまで戻す。
function Session:backspace()
  if self._state ~= "composing" then
    return
  end
  local before = uchars(romaji.to_kana(self.romaji))
  while #self.romaji > 0 do
    self.romaji = self.romaji:sub(1, #self.romaji - 1)
    local kana = romaji.to_kana(self.romaji)
    if not kana:match("[A-Za-z]$") and uchars(kana) < before then
      break
    end
  end
end

-- composing(非空) → converting。空なら何もしない。
function Session:start_conversion()
  if self._state ~= "composing" then
    return
  end
  local yomi = self:preedit()
  if yomi == "" then
    return
  end
  if not self.anthy then
    self.anthy = self._anthy.new_session()
  end
  self._segments = self.anthy:convert(yomi)
  self.seg_index = 1
  self.choices = {}
  for i = 1, #self._segments do
    self.choices[i] = 1
  end
  self._state = "converting"
end

-- converting の表示用ビュー: { list = {各文節の選択テキスト}, current = 注目index }
function Session:segments()
  local list = {}
  for i, seg in ipairs(self._segments) do
    list[i] = seg.candidates[self.choices[i]]
  end
  return { list = list, current = self.seg_index }
end

-- 注目文節の全候補リストを返す(popup 表示用)。
function Session:candidates()
  if self._state ~= "converting" then
    return {}
  end
  return self._segments[self.seg_index].candidates
end

-- 注目文節の候補を idx(1-based)で選択する。
function Session:select(idx)
  if self._state ~= "converting" then
    return
  end
  local n = #self._segments[self.seg_index].candidates
  self.choices[self.seg_index] = math.max(1, math.min(idx, n))
end

function Session:next_candidate()
  if self._state ~= "converting" then
    return
  end
  local i = self.seg_index
  local n = #self._segments[i].candidates
  self.choices[i] = (self.choices[i] % n) + 1
end

function Session:next_segment()
  if self._state ~= "converting" then
    return
  end
  self.seg_index = math.min(self.seg_index + 1, #self._segments)
end

function Session:prev_segment()
  if self._state ~= "converting" then
    return
  end
  self.seg_index = math.max(self.seg_index - 1, 1)
end

-- 注目文節を delta(+1伸長/-1短縮)して再構成する。
local function resize(self, delta)
  if self._state ~= "converting" then
    return
  end
  self._segments = self.anthy:resize(self.seg_index, delta)
  self.choices = {}
  for i = 1, #self._segments do
    self.choices[i] = 1
  end
  self.seg_index = math.min(self.seg_index, #self._segments)
end

function Session:expand()
  resize(self, 1)
end

function Session:shrink()
  resize(self, -1)
end

-- 確定する。converting なら全文節 commit(学習)し確定文字列を返す。
-- composing なら未確定かなをそのまま確定する。確定後は composing(空)。
function Session:commit()
  if self._state == "converting" then
    local text = table.concat(self:segments().list)
    self.anthy:commit(self.choices)
    reset_composing(self)
    return text
  end
  local text = self:preedit()
  reset_composing(self)
  return text
end

-- 未確定・変換中を完全に破棄して空の composing に戻す。
function Session:clear()
  reset_composing(self)
end

-- 取消。converting なら変換前のかな(composing)へ戻す。composing なら未確定を破棄。
function Session:cancel()
  if self._state == "converting" then
    self._state = "composing"
    self._segments = nil
    self.seg_index = 1
    self.choices = {}
  else
    self.romaji = ""
  end
end

return M
