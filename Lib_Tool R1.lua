-- ============================================================
-- Lib_Tool —— GameGuardian 静态基址获取工具
-- 作者 TG: @xsnbyyds
-- 版本 R1 —— 支持中英双语界面
-- 许可: PolyForm Noncommercial 1.0.0（仅限非商业使用，禁止商用）
--       协议全文见仓库 LICENSE 或
--       https://polyformproject.org/licenses/noncommercial/1.0.0
-- ============================================================

-- ------------------------------------------------------------
-- 多语言（i18n）
-- 语言状态保存在 LANG（"zh" / "en"），由配置项 lang 记忆，
-- 主菜单「Language / 语言」可随时切换，切换后立即生效。
-- 所有面向用户的文案都必须走 t()，禁止再写死字符串。
-- ------------------------------------------------------------

local VERSION = "R1"
local LANG    = "zh"

local STR = {}

STR.zh = {
  app_title     = "Lib Tool " .. VERSION .. "\nTG: @xsnbyyds",
  menu_flow     = "获取静态基址",
  menu_lang     = "Language / 语言",
  menu_exit     = "退出脚本",
  lang_switched = "语言已切换为 %s",

  no_session    = "未检测到内存段\n\n请先选择要修改的游戏进程，再运行本脚本。",
  script_err    = "脚本出错:\n%s",

  cfg_broken    = "配置已损坏，已恢复默认",
  cfg_save_fail = "配置保存失败（本次会话不记忆配置）",

  pick_none     = "请先在保存列表勾选需要取址的数值\n\n（GG 主界面搜索结果 → 勾选左侧方框 → 保存）",
  pick_nonstatic = "勾选项中包含非静态地址\n\n非静态地址每次重启都会变化，无法生成本脚本。",

  filter_title  = "筛选用哪个 so",
  filter_all    = "全部模块（不筛选）",
  filter_empty  = "筛完之后没有剩余项",

  sel_all       = "全选（共 %d 项）",
  sel_title     = "选择要取静态基址的项",

  fz_title      = "冻结方式",
  fz_all        = "全部冻结",
  fz_none       = "全部不冻结",
  fz_each       = "逐项勾选",
  fz_empty      = "没有选中任何项",
  fz_title2     = "逐项冻结（勾选的项会被冻结）",

  ev_mono       = "单调值（勾选后统一改成这个值）",
  ev_use_mono   = "采用单调值",

  fmt_title     = "选择输出格式（可多选，一起输出）",
  fmt_all       = "全部输出（lua + json + csv）",
  fmt_need      = "请至少选择一种输出格式",
  fmt_lua       = "Lua 脚本 (.lua)",
  fmt_json      = "JSON (.json)",
  fmt_csv       = "CSV (.csv)",

  out_path      = "输出文件路径（多格式自动换后缀）",
  out_remember  = "记住本次格式选择",
  out_empty     = "输出路径为空",

  verify_bad    = "检测到 %d 个偏移可能已失效\n（模块可能已卸载或地址已变）\n\n继续写出剩余 %d 项？",
  verify_ok     = "继续",
  verify_cancel = "取消",
  all_bad       = "所有偏移都无法通过有效性校验",
  no_rows       = "没有生成任何静态基址",

  bad_path      = "输出路径不合法:\n%s",
  write_fail    = "无法写入文件:\n%s\n\n已依次尝试脚本目录、/sdcard、/storage/emulated/0 均失败。\n最后错误: %s",
  done          = "写出完成（%d 项，%d 个格式）",
  moved         = "（部分原路径被占用/不可写，已改存到上面列出的路径）",
  err_head      = "以下格式写出失败：",
  err_fmt       = "%s：%s",

  desc          = "%s，类型：%s，地址：%s",
  unknown       = "?",
}

STR.en = {
  app_title     = "Lib Tool " .. VERSION .. "\nTG: @xsnbyyds",
  menu_flow     = "Extract static base",
  menu_lang     = "Language / 语言",
  menu_exit     = "Exit script",
  lang_switched = "Language switched to %s",

  no_session    = "No memory ranges detected.\n\nSelect the target game process in GameGuardian before running this script.",
  script_err    = "Script error:\n%s",

  cfg_broken    = "Config corrupted — defaults restored",
  cfg_save_fail = "Failed to save config (settings will not persist this session)",

  pick_none     = "Tick the values you want in the saved list first.\n\n(GG results → tick the box on the left → Save)",
  pick_nonstatic = "The selection contains non-static addresses.\n\nNon-static addresses change on every restart, so no script can be generated from them.",

  filter_title  = "Filter by module",
  filter_all    = "All modules (no filter)",
  filter_empty  = "Nothing left after filtering",

  sel_all       = "Select all (%d items)",
  sel_title     = "Choose the items to convert",

  fz_title      = "Freeze mode",
  fz_all        = "Freeze all",
  fz_none       = "Freeze none",
  fz_each       = "Pick per item",
  fz_empty      = "Nothing selected",
  fz_title2     = "Per-item freeze (ticked items get frozen)",

  ev_mono       = "Single value (applied to every item when ticked)",
  ev_use_mono   = "Use single value",

  fmt_title     = "Output formats (multi-select)",
  fmt_all       = "All formats (lua + json + csv)",
  fmt_need      = "Pick at least one format",
  fmt_lua       = "Lua script (.lua)",
  fmt_json      = "JSON (.json)",
  fmt_csv       = "CSV (.csv)",

  out_path      = "Output path (extension auto-adjusted)",
  out_remember  = "Remember this format choice",
  out_empty     = "Output path is empty",

  verify_bad    = "%d offset(s) may be stale\n(module unloaded or addresses moved)\n\nWrite the remaining %d item(s)?",
  verify_ok     = "Continue",
  verify_cancel = "Cancel",
  all_bad       = "No offset passed the validity check",
  no_rows       = "No static base address was generated",

  bad_path      = "Invalid output path:\n%s",
  write_fail    = "Cannot write file:\n%s\n\nTried the script folder, /sdcard and /storage/emulated/0 — all failed.\nLast error: %s",
  done          = "Done — %d items, %d format(s)",
  moved         = "(Some paths were busy or read-only; files were written to the paths above.)",
  err_head      = "Failed formats:",
  err_fmt       = "%s: %s",

  desc          = "%s, type: %s, address: %s",
  unknown       = "?",
}

-- 取文案：t("key") 或 t("key", arg1, arg2…)
-- 缺失 key 时回落到中文，再缺失则原样返回 key，避免整条流程因缺词而中断
local function t(k, ...)
  local pack = STR[LANG] or STR.zh
  local s = pack[k]
  if s == nil then s = STR.zh[k] end
  if s == nil then return tostring(k) end
  if select("#", ...) > 0 then
    local ok, out = pcall(string.format, s, ...)
    if ok then return out end
  end
  return s
end


local SCRIPT_DIR = (gg.getFile() or ""):gsub("[^/]*$", "")
SCRIPT_DIR = SCRIPT_DIR:gsub("^file://", ""):gsub("^document://", "")
if SCRIPT_DIR:sub(1, 1) ~= "/" then SCRIPT_DIR = "/storage/emulated/0/" end
if SCRIPT_DIR:sub(-1) ~= "/" then SCRIPT_DIR = SCRIPT_DIR .. "/" end

-- 默认输出路径与配置槽位名
local DEFAULT_OUT    = SCRIPT_DIR .. "已输出的基址.lua"
local Data_Save_file = "Lib_Tool.R1.cfg"
-- 文件写入校验参数：分区存储下新建文件可能延迟可见
local RETRY_SLEEP    = 120
local VERIFY_TRIES   = 3
local HISTORY_MAX    = 1

-- 静态内存段 state 白名单
local STATIC_STATES = { Xa = true, Cb = true, Cd = true, Ps = true }

-- 数值类型标签：GG flags -> 可读名称
local TYPE_MAP = {
  [127] = "Auto[127]", [16] = "Float[16]", [1] = "Byte[1]", [2] = "Word[2]",
  [32]  = "Qword[32]", [4]  = "Dword[4]",  [64] = "Double[64]", [8] = "Xor[8]",
}

-- 静态段数组 [{start, end, state, internalName}]
-- internalName -> 该模块最小 start
local static_list, static_module = {}, {}

-- 空值判定：nil 或空串都算空
local function has_text(v) return v ~= nil and v ~= "" end
-- 首尾去空白
local function trim(v) return v == nil and "" or (tostring(v):gsub("^%s+", ""):gsub("%s+$", "")) end
-- 取路径最后一段：/a/b/libc.so -> libc.so
local function basename(p) return (tostring(p):gsub("^.*/", "")) end
-- 取路径所在目录，带结尾 /：/a/b/c.lua -> /a/b/
local function dirname(p) local d = tostring(p):gsub("[^/]*$", ""); return d ~= "" and d or "/" end
-- 返回值是否为「成功」（os.rename / os.remove 的 true 判定）
local function is_true(v) return v ~= nil and v ~= false end

-- 拆出主干与扩展名：out.lua -> "out","lua"；.lua -> "out","lua"；out -> "out",nil
local function split_name(name)
  local ext  = name:match("%.([%w]+)$")
  local stem = ext and name:sub(1, #name - #ext - 1) or name
  if not has_text(stem) then stem = "out" end
  return stem, ext
end

-- 路径归一化：剥掉 content:// 等协议前缀，统一成 / 开头的裸路径
-- 兼容文件选择器（SAF）返回的 tree / document 形态
-- 百分号转义只还原会改变路径语义的四个字符，其它 %XX 原样保留，
-- 避免把 UTF-8 文件名的多字节序列拆坏
local function norm_path(p)
  local s = trim(p)
  if s == "" then return "" end

  s = s:gsub("^content://[^/]*", ""):gsub("^file://", "")
       :gsub("^document://", ""):gsub("^%a+://", "")

  s = s:gsub("%%(%x%x)", function(h)
    local c = tonumber(h, 16)
    if c == 0x25 then return "%" end
    if c == 0x2F then return "/" end
    if c == 0x3A then return ":" end
    if c == 0x20 then return " " end
    return "%" .. h
  end)

  local tree, doc = s:match("^/tree/(.-)/document/(.*)$")
  if tree then
    if doc:sub(1, #tree) == tree then doc = doc:sub(#tree + 1) end
    s = "/" .. tree .. "/" .. doc:gsub("^/", "")
  end

  s = s:gsub("^/tree/", "/"):gsub("^tree/", ""):gsub("^/document/", "/"):gsub("^document/", "")
  s = s:gsub("^/primary:", "/storage/emulated/0/"):gsub("^primary:", "/storage/emulated/0/")
  s = s:gsub("\\", "/")
  if s:sub(1, 1) ~= "/" then return "" end
  return s
end

-- 判断路径长度是否可用作文件名
local function path_ok(p)
  return type(p) == "string" and #p < 240 and p:sub(1, 1) == "/"
end

-- ------------------------------------------------------------
-- 文件后端
--
-- 目标文件被外部删除后，Android 11+ 的 FUSE 缓存可能仍是旧 dentry，
-- 同进程再创建同名路径会失败。写「临时新名 → rename 覆盖」可绕开这一路径。
-- ------------------------------------------------------------

-- 临时后缀的自增序号
local _seq = 0

-- 生成唯一临时后缀：时间 + 自增 + 随机，保证每次都不一样
local function uniq_suffix()
  _seq = _seq + 1
  local t, r = 0, 0
  local ok, v = pcall(os.time)
  if ok and type(v) == "number" then t = v end
  ok, v = pcall(math.random, 100000, 999999)
  if ok and type(v) == "number" then r = v end
  return string.format("%d_%d_%d", t, _seq, r)
end

-- 直接写 path（不删不改名）。成功 true；失败 false, err
-- GG 的 io 在不同 ROM 模式支持不一致，逐个尝试
local function raw_write(path, blob)
  local last = "open failed"
  local modes = { "wb", "w", "w+b", "w+" }
  for i = 1, #modes do
    local ok, f, err = pcall(io.open, path, modes[i])
    if not ok then
      last = tostring(f)
    elseif f then
      local okw, wres, werr = pcall(function() return f:write(blob) end)
      local wrote = okw and is_true(wres)
      pcall(function() f:flush() end)
      pcall(function() f:close() end)
      if wrote then return true end
      last = okw and tostring(werr) or tostring(wres)
    else
      last = tostring(err)
    end
  end
  return false, last
end

-- 删除：任何错误都吞掉（GG 的 os 在部分 ROM 会抛）
local function safe_remove(path)
  if not has_text(path) then return false end
  local ok, res = pcall(os.remove, path)
  return ok and is_true(res)
end

-- 可读性探测：能打开读即算存在
-- 只作旁证，不能当写成功的唯一判据 —— 分区存储下常见「写成功但立刻读不到」
local function probe_readable(path, tries)
  tries = tries or VERIFY_TRIES
  for i = 1, tries do
    local ok, f = pcall(io.open, path, "rb")
    if ok and f then pcall(function() f:close() end) return true end
    if i < tries then pcall(gg.sleep, RETRY_SLEEP) end
  end
  return false
end

-- 清理临时文件：删不掉就改名成 .bak 后缀，避免污染目录
local function drop_tmp(tmp)
  if not has_text(tmp) then return end
  if safe_remove(tmp) then return end
  pcall(os.rename, tmp, tmp:gsub("%.tmp$", "") .. ".bak")
end

-- 稳健写文件，返回 ok, saved_path, err
-- saved_path 可能与传入 path 不同：目标路径的 FUSE 缓存彻底坏死时，
-- 会改用「原名 + 时间戳」的新文件名交付
-- 判据优先级：写/关闭的返回值 = 主判据；读回探测 = 旁证
local function try_write(path, blob)
  if type(blob) ~= "string" then return false, nil, "blob not string" end
  if not path_ok(path) then return false, nil, "bad path" end

  local dir, name = dirname(path), basename(path)
  if not has_text(name) then return false, nil, "bad name" end

  local tmp = dir .. "." .. name .. ".lt" .. uniq_suffix() .. ".tmp"
  local okw, werr = raw_write(tmp, blob)

  if okw then

    local rok, rres = pcall(os.rename, tmp, path)
    if rok and is_true(rres) then return true, path end

    safe_remove(path)
    rok, rres = pcall(os.rename, tmp, path)
    if rok and is_true(rres) then return true, path end

    safe_remove(path)
    if raw_write(path, blob) then drop_tmp(tmp) return true, path end

    local stem, ext = split_name(name)
    local alt = dir .. stem .. "_" .. uniq_suffix() .. (ext and ("." .. ext) or "")
    rok, rres = pcall(os.rename, tmp, alt)
    if rok and is_true(rres) then return true, alt end
    if raw_write(alt, blob) then drop_tmp(tmp) return true, alt end

    if probe_readable(tmp) then return true, tmp end
    drop_tmp(tmp)
    return false, nil, "target path blocked by stale FUSE cache"
  end

  safe_remove(path)
  local ok4, err4 = raw_write(path, blob)
  if ok4 then return true, path end
  if probe_readable(path) then return true, path end
  drop_tmp(tmp)
  return false, nil, err4 or werr or "write failed"
end

-- 校正输出路径，确保落在可写位置
--   原路径合法   -> 原样返回
--   原路径不合法 -> 脚本目录 + 同名文件
-- 不做预探测：可写性由调用方 try_write 实际写入时判定，避免产生多余文件
local function resolve_out_path(p)
  local norm = norm_path(p)
  if norm == "" then norm = tostring(p or "") end
  if not has_text(norm) or norm:sub(-1) == "/" then return nil end
  if path_ok(norm) then return norm end
  local name = basename(norm)
  if not has_text(name) then return nil end
  return SCRIPT_DIR .. name
end

-- 解析用户输入的数值
-- 支持 0x 十六进制 / 千位逗号 / A~B 区间取上限 / 负数 / 小数 / 科学计数 / 空白
local function parse_num(v)
  local s = trim(v):gsub(",", "")
  if s == "" then return nil end

  local tilde = s:find("~", 1, true)
  if tilde then s = trim(s:sub(tilde + 1)) end

  local neg = s:sub(1, 1) == "-"
  if neg then s = s:sub(2) end

  local n
  if s:sub(1, 2):lower() == "0x" then
    local hex = s:sub(3)
    n = tonumber(hex, 16)

    if n ~= nil and n < 0 and hex:match("^%x+$") then
      local acc = 0.0
      for i = 1, #hex do acc = acc * 16.0 + tonumber(hex:sub(i, i), 16) end
      n = acc
    end
  else
    n = tonumber(s)
  end
  if n == nil then return nil end
  if n ~= n or n == math.huge or n == -math.huge then return nil end
  return neg and -n or n
end

-- 数字转 Lua 字面量：整数不带小数点，浮点保留小数
local function num_to_literal(n)
  if n == nil then return "0" end
  local s = tostring(n)
  if s:find(".", 1, true) or s:find("e", 1, true)
     or s:find("inf", 1, true) or s:find("nan", 1, true) then
    return s
  end
  return string.format("%d", n)
end

-- 安全十六进制格式化：%X 遇到非整数值会抛错，先归一化
local function hex_addr(v)
  if type(v) ~= "number" then return "?" end
  if v ~= v or v == math.huge or v == -math.huge then return "?" end
  return string.format("0x%X", math.floor(v))
end

-- 单条记录的界面描述文本（随语言变化）
-- 注意：局部变量不能叫 t，会遮蔽全局的 t()
local function describe(item)
  local v = item.value
  if not has_text(v) then v = t("unknown") end
  local ty = item.flags and (TYPE_MAP[tonumber(item.flags)] or item.flags) or t("unknown")
  return t("desc", tostring(v), tostring(ty), hex_addr(item.address))
end

-- ------------------------------------------------------------
-- GG 数据采集（只取数据，不弹窗）
-- ------------------------------------------------------------

-- 抓取静态内存段，建立段表 + 模块名 -> 段基址索引
local function load_ranges()
  static_list, static_module = {}, {}
  local list = gg.getRangesList()
  if type(list) ~= "table" then return end
  for _, r in ipairs(list) do
    if r.state and STATIC_STATES[r.state] then
      static_list[#static_list + 1] = r
      local m = static_module[r.internalName]
      if m == nil or r.start < m then static_module[r.internalName] = r.start end
    end
  end
end

-- 按地址反查所属静态段
local function range_of(addr)
  for i = 1, #static_list do
    local r = static_list[i]
    if addr >= r.start and addr <= r["end"] then return r end
  end
  return nil
end

-- 按地址反查所属模块名（完整路径）
local function module_of(addr)
  local r = range_of(addr)
  return r and r.internalName or nil
end

-- 取保存列表勾选项，按地址去重（同一地址只留第一条）
local function load_selected()
  local raw = gg.getSelectedListItems()
  if type(raw) ~= "table" then return {} end
  local seen, out = {}, {}
  for i = 1, #raw do
    local it = raw[i]
    if it and it.address ~= nil and not seen[it.address] then
      seen[it.address] = true
      out[#out + 1] = it
    end
  end
  return out
end

-- 批量校验选中项是否全部位于静态段（getValuesRange 一次调用）
local function all_static(sel)
  if #sel == 0 then return true end
  local infos = gg.getValuesRange(sel)
  if type(infos) ~= "table" then return false end
  for i = 1, #sel do
    local info  = infos[i]
    local state = type(info) == "table" and info.state or info
    if not STATIC_STATES[state] then return false end
  end
  return true
end

-- 按 chosen 收集选中项，返回紧凑的 labels 与对应的 sel 下标 keys
local function collect_chosen(sel, chosen)
  local labels, keys, k = {}, {}, 0
  for i = 1, #sel do
    if chosen[i] then
      k = k + 1
      labels[k] = describe(sel[i])
      keys[k]  = i
    end
  end
  return labels, keys
end

-- ------------------------------------------------------------
-- 业务逻辑（只算数据，不弹窗）
-- ------------------------------------------------------------

-- 由保存列表项生成静态基址记录，地址不在静态段内返回 nil
-- freeze 随记录一起固化，避免排序后下标错位
local function make_record(item, value, freeze)
  local r = range_of(item.address)
  if not r then return nil end
  local base = static_module[r.internalName] or r.start
  return {
    module     = r.internalName,
    seg_start  = r.start,
    seg_end    = r["end"],
    offset     = hex_addr(item.address - base),
    flags      = item.flags,
    value      = value,
    freeze     = freeze,
    value_addr = hex_addr(item.address),
  }
end

-- 偏移有效性自检：seg_start + offset 必须仍落在某个静态段内
-- 返回 ok_rows, bad_rows
local function verify_rows(rows)
  local ok, bad = {}, {}
  for i = 1, #rows do
    local row = rows[i]
    local off = row.offset and tonumber(row.offset)
    local hit = off and row.seg_start and range_of(row.seg_start + off)
    if hit then ok[#ok + 1] = row else bad[#bad + 1] = row end
  end
  return ok, bad
end

-- 排序：段基址 -> 模块名 -> 偏移，保证输出可复现
-- 偏移按数值比较，不能用字符串比较（"0x1000" < "0x80" 在字典序下为 true）
local function sort_rows(rows)
  table.sort(rows, function(a, b)
    local sa, sb = a.seg_start or 0, b.seg_start or 0
    if sa ~= sb then return sa < sb end
    if a.module ~= b.module then return a.module < b.module end
    local oa, ob = tonumber(a.offset) or 0, tonumber(b.offset) or 0
    if oa ~= ob then return oa < ob end
    return tostring(a.offset) < tostring(b.offset)
  end)
  return rows
end

-- 冻结判定：布尔=整体，表=逐项
local function frozen(freeze, i)
  if type(freeze) == "table" then return freeze[i] == true end
  return freeze == true
end

-- ------------------------------------------------------------
-- 输出格式化
-- FORMATS 的顺序即多格式一起输出时的写出顺序
-- ------------------------------------------------------------

-- 支持的格式集合
local FORMATS = { "lua", "json", "csv" }

-- 格式合法性集合（仅作 membership 判定，显示名走 fmt_label）
local FORMAT_LABEL = { lua = true, json = true, csv = true }

-- 格式的界面显示名，随语言变化
local function fmt_label(f) return t("fmt_" .. tostring(f)) end

-- Lua 冻结脚本头部
local LUA_HEAD = "function setvalue(address,flags,value,freeze) local tt={} tt[1]={} "
              .. "tt[1].address=address tt[1].flags=flags tt[1].value=value tt[1].freeze=freeze  "
              .. "gg.setValues(tt) for i=1,#tt do if tt[i].freeze then gg.addListItems(tt) break end "
              .. "end end--静态冻结配置\n"

-- Lua 冻结脚本
local function fmt_lua(rows)
  local out, cur = { LUA_HEAD }, nil
  for i = 1, #rows do
    local r = rows[i]
    if r.module ~= cur then
      cur = r.module
      out[#out + 1] = 'so=gg.getRangesList("' .. basename(r.module) .. '")[1].start'
    end
    out[#out + 1] = "py=" .. hex_addr(tonumber(r.offset))
                 .. "\nsetvalue(so+py," .. tostring(r.flags) .. "," .. num_to_literal(parse_num(r.value))
                 .. (r.freeze and ",true" or "") .. ")"
  end
  return table.concat(out, "\n")
end

-- JSON 字符串转义表
local JSON_ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
                   ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
-- JSON 字符串转义：转义 \ 与 " 之外的全部控制字符
local function json_q(s)
  s = tostring(s):gsub('[%c"\\]', function(c)
    return JSON_ESC[c] or string.format("\\u%04X", c:byte())
  end)
  return '"' .. s .. '"'
end

-- JSON 数组输出，无尾逗号
local function fmt_json(rows)
  local q = json_q
  local out = { "[" }
  for i = 1, #rows do
    local r = rows[i]
    out[#out + 1] = "  {" .. table.concat({
      '"module":'     .. q(basename(r.module)),
      '"offset":'     .. q(r.offset),
      '"flags":'      .. tostring(r.flags),
      '"value_addr":' .. q(r.value_addr),
      '"value":'      .. q(r.value),
      '"freeze":'     .. tostring(r.freeze == true),
    }, ",") .. "}" .. (i < #rows and "," or "")
  end
  out[#out + 1] = "]"
  return table.concat(out, "\n")
end

-- CSV 字段：含逗号 / 引号 / 换行时用双引号包裹，内部引号翻倍
local function csv_field(s)
  s = tostring(s)
  if s:find('[,"\n\r]') then return '"' .. s:gsub('"', '""') .. '"' end
  return s
end

-- CSV 输出：首行表头，其余每项一行
local function fmt_csv(rows)
  local out = { "module,offset,flags,value_addr,value,freeze" }
  for i = 1, #rows do
    local r = rows[i]
    out[#out + 1] = table.concat({
      csv_field(basename(r.module)), csv_field(r.offset), csv_field(r.flags),
      csv_field(r.value_addr), csv_field(r.value), csv_field(r.freeze and "true" or "false"),
    }, ",")
  end
  return table.concat(out, "\n")
end

-- 后缀 -> formatter 映射表
local FORMATTERS = { lua = fmt_lua, json = fmt_json, csv = fmt_csv }

-- 渲染输出文本（调用前 rows 需已 sort_rows）
local function render(rows, fmt)
  return (FORMATTERS[fmt] or fmt_lua)(rows)
end

-- 把任意来源的格式列表规范化为「已知格式 + 固定顺序 + 去重」
local function normalize_formats(fmts)
  local set = {}
  if type(fmts) == "table" then
    for i = 1, #fmts do
      if FORMAT_LABEL[fmts[i]] then set[fmts[i]] = true end
    end
  end
  local out = {}
  for i = 1, #FORMATS do
    if set[FORMATS[i]] then out[#out + 1] = FORMATS[i] end
  end
  return out
end

-- 解析 cfg 里的 formats 字段（"lua,json" -> {lua,json}），非法项直接丢弃
-- 注意：Lua 5.4+ 的 for 控制变量是只读的，不能直接赋值，必须另起局部变量
local function parse_formats(v)
  local set = {}
  for item in tostring(v or ""):gmatch("[^,]+") do
    local name = trim(item)
    if FORMAT_LABEL[name] then set[name] = true end
  end
  local out = {}
  for i = 1, #FORMATS do
    if set[FORMATS[i]] then out[#out + 1] = FORMATS[i] end
  end
  return out
end

-- 由用户给的路径派生各格式目标路径：目录 + 主干 + .扩展名
-- 例：/sdcard/base.lua + {lua,json} -> /sdcard/base.lua, /sdcard/base.json
local function format_paths(base, fmts)
  local dir, name = dirname(base), basename(base)
  local stem = split_name(name)
  local out = {}
  for i = 1, #fmts do out[i] = dir .. stem .. "." .. fmts[i] end
  return out
end

-- ------------------------------------------------------------
-- 配置读写 / 历史
--
-- 双存储：① 真实文件（优先读）——删掉后走 try_write 的临时名重建流程
--         ② gg.saveVariable 槽位（兜底）——文件系统整体不可用时仍能记忆配置
-- ------------------------------------------------------------

-- cfg 文件候选位置（按优先级）
local CFG_FILES = {}
do
  -- 追加候选路径（去重）
  local function push(p)
    for i = 1, #CFG_FILES do if CFG_FILES[i] == p then return end end
    CFG_FILES[#CFG_FILES + 1] = p
  end
  push(SCRIPT_DIR .. "Lib_Tool.R1.cfg")
  push("/sdcard/Lib_Tool.R1.cfg")
  push("/storage/emulated/0/Lib_Tool.R1.cfg")
end

-- 默认配置
local function default_cfg()
  return {
    out_path = DEFAULT_OUT,
    formats  = { "lua" },
    lang     = LANG,
    history  = {},
  }
end

-- 值里的换行会破坏「一行一个 key=value」的结构，写入前统一替换成空格
local function one_line(s)
  return (tostring(s or ""):gsub("[\r\n]", " "))
end

-- 序列化：固定字段顺序，_loaded 等内部标记不落盘
-- lang 必须写在 history_count 之前：解析端在 history_count 处 break
local function serialize(cfg)
  local h = cfg.history or {}
  local head = "out_path=" .. one_line(cfg.out_path)
             .. "\nformats=" .. table.concat(normalize_formats(cfg.formats), ",")
             .. "\nlang=" .. one_line(STR[cfg.lang or ""] and cfg.lang or LANG)
             .. "\nhistory_count=" .. #h
  if #h == 0 then return head end
  local hs = {}
  for i = 1, #h do hs[i] = one_line(h[i]):gsub("\x1F", " ") end
  return head .. "\n" .. table.concat(hs, "\x1F")
end

-- 反序列化：按 key 解析，history_count 之后的一行是 history
-- 容错：CRLF、尾部空行、history 计数不符、超量条目，都不整体判废
local function deserialize(text)
  if type(text) ~= "string" or text == "" then return nil end

  text = text:gsub("\r\n", "\n"):gsub("\r", "\n")

  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
  while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
  if #lines < 3 then return nil end

  local cfg, cnt, cnt_line = default_cfg(), nil, nil
  for i = 1, #lines do
    local k, v = lines[i]:match("^%s*([^=]+)=(.*)$")
    if k == "out_path" then
      cfg.out_path = v
    elseif k == "formats" then
      local fmts = parse_formats(v)
      if #fmts > 0 then cfg.formats = fmts end
    elseif k == "lang" then
      local lg = trim(v)
      if STR[lg] then cfg.lang = lg end
    elseif k == "history_count" then
      cnt = tonumber(v)
      if not cnt or cnt < 0 then return nil end
      cnt_line = i
      break
    end
  end

  if not cnt_line then return nil end
  if cnt > HISTORY_MAX then cnt = HISTORY_MAX end

  cfg.history = {}
  local hl = lines[cnt_line + 1]
  if cnt > 0 and hl and hl ~= "" then
    for p in (hl .. "\x1F"):gmatch("(.-)\x1F") do
      if #cfg.history >= cnt then break end
      if p ~= "" then cfg.history[#cfg.history + 1] = p end
    end
  end
  return cfg
end

-- 从文件读 cfg blob
local function cfg_blob_from_file(path)
  local ok, f = pcall(io.open, path, "rb")
  if not ok or not f then return nil end
  local okr, txt = pcall(function() return f:read("*a") end)
  pcall(function() f:close() end)
  if okr and type(txt) == "string" and txt ~= "" then return txt end
  return nil
end

-- gg.getVariables 的返回形态在不同 GG 版本不一致，这里兼容多种：
--   {blob} / {cfg = blob} / {[name] = ...} / blob
local function cfg_blob_from(v)
  if type(v) == "string" then return v end
  if type(v) ~= "table" then return nil end
  if type(v[1]) == "string" then return v[1] end
  if type(v.cfg) == "string" then return v.cfg end
  return nil
end

-- 从 GG 变量槽位读 blob（兼容带参 / 不带参两种签名）
local function cfg_blob_from_gg()
  if not gg.getVariables then return nil end

  local ok, v = pcall(gg.getVariables, Data_Save_file)
  if ok then
    local b = cfg_blob_from(v)
    if has_text(b) then return b end
  end

  ok, v = pcall(gg.getVariables)
  if ok and type(v) == "table" then
    local b = cfg_blob_from(v)
    if has_text(b) then return b end
    b = cfg_blob_from(v[Data_Save_file])
    if has_text(b) then return b end
  end
  return nil
end

-- 读取 cfg：文件优先，变量槽位兜底；解析失败回落默认值
-- _loaded 标记是否读到有效存储
local function read_cfg()
  local raw = nil
  for i = 1, #CFG_FILES do
    raw = cfg_blob_from_file(CFG_FILES[i])
    if has_text(raw) then break end
  end
  if not has_text(raw) then raw = cfg_blob_from_gg() end

  local dflt = default_cfg()
  if not has_text(raw) then dflt._loaded = false return dflt end

  local cfg = deserialize(raw)
  if not cfg then
    gg.toast(t("cfg_broken"))
    dflt._loaded = false
    return dflt
  end
  -- 语言以配置为准：读到合法 lang 就立刻生效，后续所有弹窗随之切换
  if STR[cfg.lang or ""] then LANG = cfg.lang end
  cfg._loaded = true
  return cfg
end

-- 写回 cfg：文件 + 变量槽位双写，任一成功即算成功
local function write_cfg(cfg)
  local plain = serialize(cfg)

  local ok_file = false
  for i = 1, #CFG_FILES do
    if try_write(CFG_FILES[i], plain) then ok_file = true break end
  end

  local ok_var = false
  if gg.saveVariable then
    local ok, res = pcall(gg.saveVariable, { cfg = plain }, Data_Save_file)
    if ok and res ~= false then ok_var = true end
  end

  if ok_file or ok_var then return true end
  gg.toast(t("cfg_save_fail"))
  return false
end

-- 记录最近输出路径：只留最新一条，每次写出直接覆盖旧记录
local function history_push(path)
  if not has_text(path) then return end
  local cfg = read_cfg()
  cfg.history = { path }
  write_cfg(cfg)
end

-- 启动时确保配置可用：两处存储都没有就创建
local function ensure_cfg()
  if read_cfg()._loaded then return true end
  return write_cfg(default_cfg())
end

-- ------------------------------------------------------------
-- 界面流程（只弹窗，业务计算在采集/业务段）
-- ------------------------------------------------------------

-- [步骤1] 取保存列表勾选项，带合法性校验
local function step_pick_list()
  local sel = load_selected()
  if #sel == 0 then
    gg.alert(t("pick_none"))
    return nil
  end
  if not all_static(sel) then
    gg.alert(t("pick_nonstatic"))
    return nil
  end
  return sel
end

-- [步骤2] 按模块过滤（模块多于 1 个时才弹窗）
local function step_filter_modules(sel)
  local mods, seen = {}, {}
  for i = 1, #sel do
    local nm = module_of(sel[i].address)
    if nm and not seen[nm] then
      seen[nm] = true
      mods[#mods + 1] = nm
    end
  end
  if #mods <= 1 then return sel end

  local items = { t("filter_all") }
  for i = 1, #mods do items[#items + 1] = basename(mods[i]) end

  local picked = gg.multiChoice(items, nil, t("filter_title"))
  if not picked then return nil end
  if picked[1] then return sel end

  local keep = {}
  for i = 2, #items do
    if picked[i] then keep[mods[i - 1]] = true end
  end
  local out = {}
  for i = 1, #sel do
    local nm = module_of(sel[i].address)
    if nm == nil or keep[nm] then out[#out + 1] = sel[i] end
  end
  if #out == 0 then
    gg.alert(t("filter_empty"))
    return nil
  end
  return out
end

-- [步骤3] 勾选要取址的具体项（多选）
local function step_select_items(sel)
  local items = { t("sel_all", #sel) }
  for i = 1, #sel do items[#items + 1] = describe(sel[i]) end

  local picked = gg.multiChoice(items, nil, t("sel_title"))
  if not picked then return nil end

  local chosen = {}
  if picked[1] then
    for i = 1, #sel do chosen[i] = true end
  else
    for i = 2, #items do
      if picked[i] then chosen[i - 1] = true end
    end
  end
  return chosen
end

-- [步骤4] 冻结方式
-- 返回 true=全部冻结，false=全部不冻结，table=逐项冻结表
local function step_pick_freeze(sel, chosen)
  local mode = gg.choice({ t("fz_all"), t("fz_none"), t("fz_each") }, nil, t("fz_title"))
  if not mode then return nil end
  if mode == 1 then return true end
  if mode == 2 then return false end

  local labels, keys = collect_chosen(sel, chosen)
  if #labels == 0 then
    gg.alert(t("fz_empty"))
    return nil
  end

  local picked = gg.multiChoice(labels, nil, t("fz_title2"))
  if not picked then return nil end

  local map = {}
  for i = 1, #sel do map[i] = false end
  for i = 1, #labels do
    if picked[i] then map[keys[i]] = true end
  end
  return map
end

-- [步骤5] 改值：单调值统一改或逐项改，返回 { [sel_index] = 值 }
local function step_edit_values(sel, chosen)
  local labels, keys = collect_chosen(sel, chosen)

  local defaults, types = { "", false }, { "text", "checkbox" }
  for i = 1, #keys do
    defaults[i + 2] = sel[keys[i]].value
    types[i + 2]    = "text"
  end
  table.insert(labels, 1, t("ev_use_mono"))
  table.insert(labels, 1, t("ev_mono"))

  local res = gg.prompt(labels, defaults, types)
  if not res then return nil end

  local values = {}
  if res[2] == true then
    local mono = res[1]
    if not has_text(mono) then mono = 0 end
    for i = 1, #keys do values[keys[i]] = mono end
  else
    for i = 1, #keys do
      if res[i + 2] ~= nil then values[keys[i]] = res[i + 2] end
    end
  end
  return values
end

-- [步骤6] 输出格式：可只选一种，也可多选一起输出
-- 上次记住的选择会预勾选；返回规范化后的格式列表，未选返回 nil
local function step_pick_formats()
  local remembered = normalize_formats(read_cfg().formats)
  if #remembered == 0 then remembered = { "lua" } end

  local items = { t("fmt_all") }
  for i = 1, #FORMATS do items[#items + 1] = fmt_label(FORMATS[i]) end

  local pre = {}
  for i = 1, #FORMATS do
    for j = 1, #remembered do
      if remembered[j] == FORMATS[i] then pre[i + 1] = true end
    end
  end

  local picked = gg.multiChoice(items, pre, t("fmt_title"))
  if not picked then return nil end

  local fmts = {}
  if picked[1] then
    for i = 1, #FORMATS do fmts[i] = FORMATS[i] end
  else
    for i = 1, #FORMATS do
      if picked[i + 1] then fmts[#fmts + 1] = FORMATS[i] end
    end
  end

  if #fmts == 0 then
    gg.alert(t("fmt_need"))
    return nil
  end
  return fmts
end

-- [步骤7] 输出参数（路径 + 是否记住格式选择）
local function step_output_opts()
  local cfg = read_cfg()

  local def_path = has_text(cfg.out_path) and cfg.out_path or DEFAULT_OUT

  if def_path:sub(-4) == ".tmp" or def_path:sub(1, 1) ~= "/" then def_path = DEFAULT_OUT end

  local res = gg.prompt(
    { t("out_path"), t("out_remember") },
    { def_path, true },
    { "file", "checkbox" })
  if not res then return nil end
  if not has_text(res[1]) then
    gg.alert(t("out_empty"))
    return nil
  end
  return res[1], res[2] == true
end

-- 写出：原路径优先，失败再依次退到脚本目录 /sdcard /storage/emulated/0
local function write_output(want_out, text)
  local name  = basename(want_out)
  local paths = { want_out }
  local seen  = { [want_out] = true }
  for _, dir in ipairs({ SCRIPT_DIR, "/sdcard/", "/storage/emulated/0/" }) do
    if dir ~= "" then
      if dir:sub(-1) ~= "/" then dir = dir .. "/" end
      local p = dir .. name
      if not seen[p] then
        seen[p] = true
        paths[#paths + 1] = p
      end
    end
  end

  local last_err
  for i = 1, #paths do
    local ok, saved, err = try_write(paths[i], text)
    if ok then return saved or paths[i] end
    last_err = err
  end
  return nil, last_err
end

-- 主流程：获取静态基址
local function flow_static_address()
  local sel = step_pick_list()
  if not sel then return end

  sel = step_filter_modules(sel)
  if not sel then return end

  local chosen = step_select_items(sel)
  if not chosen then return end

  local freeze = step_pick_freeze(sel, chosen)
  if freeze == nil then return end

  local values = step_edit_values(sel, chosen)
  if not values then return end

  local rows = {}
  for i = 1, #sel do
    if chosen[i] then
      local row = make_record(sel[i], values[i], frozen(freeze, i))
      if row then rows[#rows + 1] = row end
    end
  end
  if #rows == 0 then
    gg.alert(t("no_rows"))
    return
  end

  local ok_rows, bad_rows = verify_rows(rows)
  if #bad_rows > 0 and gg.alert(t("verify_bad", #bad_rows, #ok_rows),
                                 t("verify_ok"), t("verify_cancel")) ~= 1 then
    return
  end
  if #ok_rows == 0 then
    gg.alert(t("all_bad"))
    return
  end
  rows = ok_rows

  local fmts = step_pick_formats()
  if not fmts then return end

  local out_path, remember = step_output_opts()
  if not out_path then return end

  local base = resolve_out_path(out_path)
  if not base then
    gg.alert(t("bad_path", tostring(out_path)))
    return
  end

  sort_rows(rows)
  local targets = format_paths(base, fmts)
  local written, errors, moved = {}, {}, false
  for i = 1, #fmts do
    local text = render(rows, fmts[i])
    local saved, err = write_output(targets[i], text)
    if saved then
      written[#written + 1] = saved
      if saved ~= targets[i] then moved = true end
    else
      errors[#errors + 1] = t("err_fmt", fmts[i], tostring(err))
    end
  end

  if #written == 0 then
    gg.alert(t("write_fail", tostring(out_path), tostring(errors[1])))
    return
  end

  pcall(gg.sleep, 80)

  local cfg = read_cfg()
  cfg.out_path = written[1]
  if remember then cfg.formats = fmts end
  write_cfg(cfg)
  history_push(written[1])

  local lines = { t("done", #rows, #written) }
  for i = 1, #written do lines[#lines + 1] = written[i] end
  if moved then
    lines[#lines + 1] = ""
    lines[#lines + 1] = t("moved")
  end
  if #errors > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = t("err_head")
    for i = 1, #errors do lines[#lines + 1] = errors[i] end
  end
  gg.alert(table.concat(lines, "\n"))
end

local RUNNING = true

-- 切换界面语言并记忆到配置
-- 注意顺序：read_cfg 会把 LANG 拉回配置里的旧值，所以必须先算出目标语言，
-- 读完配置之后再覆盖 LANG，否则「切换」会变成「还原」
local function toggle_lang()
  local next_lang = (LANG == "zh") and "en" or "zh"
  local cfg = read_cfg()
  LANG = next_lang
  cfg.lang = LANG
  write_cfg(cfg)
  gg.toast(t("lang_switched", LANG == "zh" and "中文" or "English"))
end

-- 主菜单
-- choice == nil 表示点空白处或按返回键，此时不退出，直接 return 等下一次点击
local function main_menu()
  local choice = gg.choice({
    t("menu_flow"),
    t("menu_lang"),
    t("menu_exit"),
  }, nil, t("app_title"))

  if choice == nil then return end
  if choice == 1 then flow_static_address() end
  if choice == 2 then toggle_lang() end
  if choice == 3 then RUNNING = false end
end

-- ------------------------------------------------------------
-- 入口
-- ------------------------------------------------------------

-- 初始化：先读配置确定界面语言，再检查 session
-- （顺序很重要：ensure_cfg → read_cfg 会把 LANG 设成用户上次选的语言，
--   这样下面的提示语才是正确的语言）
pcall(math.randomseed, os.time())
ensure_cfg()

-- 空 session 保护：没附加进程时后续调用会崩
if #gg.getRangesList() == 0 then
  gg.alert(t("no_session"))
  return
end

load_ranges()

-- 显示悬浮按钮
gg.showUiButton()

-- 主循环：RUNNING 为 false 时退出，仅由「退出脚本」菜单项置位
-- gg.choice 返回 nil（点空白 / 返回键）不退出，直接 return 继续等下一次点击
while RUNNING do
  if gg.isClickedUiButton() then
    collectgarbage("collect")
    local ok, err = pcall(main_menu)
    if not ok then gg.alert(t("script_err", tostring(err))) end
  end
  gg.sleep(80)
end

if gg.hideUiButton then gg.hideUiButton() end

