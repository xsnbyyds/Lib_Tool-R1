#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lib_Tool 冒烟测试：在模拟的 GameGuardian 环境里跑完整流程。

不需要真机、不碰真实文件系统：

- ``io.open`` / ``os.rename`` / ``os.remove`` 全部指向内存字典；
- ``gg.*`` 用脚本化返回值（菜单点击序列、勾选项、弹窗输入）；
- 脚本跑完后直接断言产物内容。

用法::

    pip install lupa
    python tests/smoke_test.py

退出码 0 表示全部通过，1 表示有失败（CI 据此判定）。
"""

from __future__ import annotations

import json
import pathlib
import sys

import lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT_PATH = ROOT / "Lib_Tool R1.lua"

CFG = "/storage/emulated/0/Lib_Tool.R1.cfg"
OUT_LUA = "/storage/emulated/0/base.lua"
OUT_JSON = "/storage/emulated/0/base.json"
OUT_CSV = "/storage/emulated/0/base.csv"

# ---------------------------------------------------------------- 模拟环境

MOCK = r"""
-- 内存文件系统：path -> content
FS = {}

local function file_obj(path, mode)
  if mode:sub(1, 1) == "r" then
    if FS[path] == nil then return nil, "not found" end
    local content = FS[path]
    return {
      read  = function(self, fmt) return content end,
      close = function() return true end,
    }
  end
  FS[path] = ""
  return {
    write = function(self, s) FS[path] = FS[path] .. tostring(s); return true end,
    flush = function() return true end,
    close = function() return true end,
  }
end

io = { open = function(p, m) return file_obj(p, m or "r") end }
os = {
  time = os.time,
  rename = function(a, b)
    if FS[a] ~= nil then FS[b] = FS[a]; FS[a] = nil; return true end
    return nil, "noent"
  end,
  remove = function(p)
    if FS[p] ~= nil then FS[p] = nil; return true end
    return nil, "noent"
  end,
}

ALERTS, TOASTS = {}, {}
local clicks, menu_i = 0, 0

-- 两条勾选项：0x1000(Dword) 与 0x1010(Float)
local SEL = {
  { address = 0x1000, flags = 4,  value = "100" },
  { address = 0x1010, flags = 16, value = "1.5" },
}
-- 单个静态段，min start = 0x1000，因此偏移应为 0x0 / 0x10
local RANGES = {
  { start = 0x1000, ["end"] = 0x2000, state = "Cd", internalName = "/system/lib64/libtest.so" },
}

gg = {
  getFile            = function() return "file:///storage/emulated/0/Lib_Tool R1.lua" end,
  getRangesList      = function(name) return RANGES end,
  getSelectedListItems = function() return SEL end,
  getValuesRange     = function(list)
    local o = {}
    for i = 1, #list do o[i] = { state = "Cd" } end
    return o
  end,

  -- 主菜单走 MENU_SEQ（1=取址 2=切语言 3=退出），其余单选框走 FREEZE_MODE
  choice = function(items, pre, title)
    if title and title:find("Lib Tool", 1, true) then
      menu_i = menu_i + 1
      return MENU_SEQ[menu_i]
    end
    return FREEZE_MODE
  end,

  multiChoice = function(items, pre, title)
    local first = items[1] or ""
    if first:find("全选", 1, true) or first:find("Select all", 1, true) then
      return { [1] = true }                 -- 全选
    end
    if first:find("全部输出", 1, true) or first:find("All formats", 1, true) then
      return FORMAT_PICK                    -- 输出格式
    end
    return { [1] = true }                   -- 逐项冻结：全勾
  end,

  prompt = function(labels, defaults, types)
    if #labels == 2 then
      return { "/storage/emulated/0/base.lua", true }   -- 路径 + 记住格式
    end
    return { "", false, "100", "1.5" }                  -- 不改值
  end,

  alert = function(...)
    local parts = { ... }
    local out = {}
    for i = 1, #parts do out[i] = tostring(parts[i]) end
    ALERTS[#ALERTS + 1] = table.concat(out, " | ")
    return 1
  end,
  toast = function(s) TOASTS[#TOASTS + 1] = tostring(s) end,

  showUiButton       = function() end,
  hideUiButton       = function() end,
  isClickedUiButton  = function() clicks = clicks + 1; return clicks <= #MENU_SEQ end,
  sleep              = function() end,
  saveVariable       = function() return true end,
  getVariables       = function() return nil end,
}
"""


def run(menu_seq, freeze_mode=2, formats=(2,), seed_cfg=None):
    """跑一遍脚本，返回 (alerts, toasts, fs)。"""
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute(MOCK)

    g = L.globals()
    g.MENU_SEQ = L.eval("{" + ",".join(str(i) for i in menu_seq) + "}")
    g.FREEZE_MODE = freeze_mode
    g.FORMAT_PICK = L.eval("{" + ",".join("[%d]=true" % i for i in formats) + "}")
    if seed_cfg:
        g.FS[CFG] = seed_cfg

    L.execute(SCRIPT_PATH.read_text(encoding="utf-8"))

    alerts = L.execute("return ALERTS")
    toasts = L.execute("return TOASTS")
    fs = L.execute("return FS")
    return (
        [alerts[i] for i in range(1, len(alerts) + 1)],
        [toasts[i] for i in range(1, len(toasts) + 1)],
        {k: fs[k] for k in fs.keys()},
    )


# ---------------------------------------------------------------- 断言工具

class Checker:
    def __init__(self):
        self.failed = 0
        self.passed = 0

    def check(self, cond, label, detail=""):
        if cond:
            self.passed += 1
            print("  ok   %s" % label)
        else:
            self.failed += 1
            print("  FAIL %s%s" % (label, ("\n       " + detail) if detail else ""))

    def eq(self, actual, expected, label):
        self.check(actual == expected, label,
                   "expected=%r actual=%r" % (expected, actual))


C = Checker()


# ---------------------------------------------------------------- 用例

def case_language_toggle():
    """无配置 → 主菜单切英文 → 走完流程（只输出 lua）。"""
    print("\n[1] 无配置：切换语言 → 生成 Lua")
    alerts, toasts, fs = run([2, 1, 3], formats=(2,))

    C.check(any("Language switched to English" in t for t in toasts),
            "toast 切换为英文", repr(toasts))
    cfg = fs.get(CFG, "")
    C.check("lang=en" in cfg, "配置写入 lang=en", repr(cfg))
    C.check("history_count=1" in cfg, "配置写入 history_count", repr(cfg))

    lua = fs.get(OUT_LUA, "")
    C.check('so=gg.getRangesList("libtest.so")[1].start' in lua,
            "Lua 输出含模块基址行", lua)
    C.check("py=0x0" in lua and "py=0x10" in lua, "偏移为 0x0 / 0x10", lua)
    C.check("setvalue(so+py,4,100)" in lua, "Dword 值 100 正确", lua)
    C.check("setvalue(so+py,16,1.5)" in lua, "Float 值 1.5 正确", lua)
    C.check(any(a.startswith("Done") for a in alerts), "回执为英文", repr(alerts))


def case_seeded_english():
    """配置已是英文 → 直接跑流程，输出 json + csv。"""
    print("\n[2] 配置 lang=en：直接跑流程（JSON + CSV）")
    seed = "out_path=%s\nformats=lua\nlang=en\nhistory_count=0" % OUT_LUA
    # 格式选择框：items[1]=全部，items[2]=lua，items[3]=json，items[4]=csv
    alerts, toasts, fs = run([1, 3], formats=(3, 4), seed_cfg=seed)

    C.check(not toasts, "无多余 toast", repr(toasts))
    C.check(any(a.startswith("Done") for a in alerts), "回执为英文", repr(alerts))

    raw = fs.get(OUT_JSON, "")
    C.check(bool(raw), "生成了 JSON", repr(sorted(fs.keys())))
    try:
        data = json.loads(raw)
        ok = True
    except Exception as exc:  # noqa: BLE001
        data, ok = None, False
        print("       JSON 解析失败: %s" % exc)
    C.check(ok, "JSON 可被标准解析器读取")
    if ok:
        C.eq(len(data), 2, "JSON 记录数")
        C.eq([r["offset"] for r in data], ["0x0", "0x10"], "JSON 偏移")
        C.eq([r["module"] for r in data], ["libtest.so"] * 2, "JSON 模块名")
        C.eq([r["freeze"] for r in data], [False, False], "JSON freeze 全 false")

    csv = fs.get(OUT_CSV, "")
    lines = csv.splitlines()
    C.eq(lines[0] if lines else "", "module,offset,flags,value_addr,value,freeze",
         "CSV 表头")
    C.eq(len(lines), 3, "CSV 行数（表头 + 2 条）")


def case_seeded_chinese():
    """配置为中文 → 回执应为中文。"""
    print("\n[3] 配置 lang=zh：中文回执")
    seed = "out_path=%s\nformats=lua\nlang=zh\nhistory_count=0" % OUT_LUA
    alerts, _, fs = run([1, 3], formats=(2,), seed_cfg=seed)

    C.check(any(a.startswith("写出完成") for a in alerts), "回执为中文", repr(alerts))
    C.check("lang=zh" in fs.get(CFG, ""), "语言未被意外改写", repr(fs.get(CFG, "")))


def case_freeze_all():
    """全部冻结 → 输出应带 ,true 且脚本头部包含 addListItems。"""
    print("\n[4] 全部冻结：输出含 ,true")
    alerts, _, fs = run([1, 3], freeze_mode=1, formats=(2,))
    lua = fs.get(OUT_LUA, "")

    C.check("gg.addListItems" in lua, "头部含冻结逻辑")
    C.check("setvalue(so+py,4,100,true)" in lua, "Dword 项带 ,true", lua)
    C.check("setvalue(so+py,16,1.5,true)" in lua, "Float 项带 ,true", lua)


def case_corrupt_cfg():
    """配置损坏 → 回落默认值并 toast 提示，流程仍可完成。"""
    print("\n[5] 配置损坏：回落默认值")
    alerts, toasts, fs = run([1, 3], formats=(2,), seed_cfg="garbage")
    C.check(any("Config corrupted" in t or "配置已损坏" in t for t in toasts),
            "提示配置损坏", repr(toasts))
    C.check(bool(fs.get(OUT_LUA, "")), "仍然写出了输出文件", repr(sorted(fs.keys())))


def main():
    if not SCRIPT_PATH.exists():
        print("找不到脚本: %s" % SCRIPT_PATH)
        return 1

    print("Lua 实现: %s" % lupa.LuaRuntime().lua_implementation)
    print("被测脚本: %s" % SCRIPT_PATH.name)

    case_language_toggle()
    case_seeded_english()
    case_seeded_chinese()
    case_freeze_all()
    case_corrupt_cfg()

    print("\n%s：%d 通过，%d 失败" % (
        "全部通过" if C.failed == 0 else "存在失败", C.passed, C.failed))
    return 0 if C.failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
