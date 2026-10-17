# Technical Internals

[简体中文](技术实现.md) · **English**

This document explains the structure and key algorithms of `Lib_Tool R1.lua`, for readers who want to modify the script, debug it, or port the logic.

Suggested reading order: start with *Layers*, then jump to the section you need. Code excerpts are taken from R1 and lightly trimmed.

---

## Table of Contents

- [Layers](#layers)
- [Path Layer](#path-layer)
- [File Backend](#file-backend)
- [Numeric Layer](#numeric-layer)
- [Collection Layer](#collection-layer)
- [Records and Validation](#records-and-validation)
- [Formatting Layer](#formatting-layer)
- [Config Layer](#config-layer)
- [i18n](#i18n)
- [UI Index Mapping](#ui-index-mapping)
- [Entry and Main Loop](#entry-and-main-loop)
- [Performance](#performance)
- [Extension Points](#extension-points)
- [Debugging Tips](#debugging-tips)

---

## Layers

The script is split into 10 blocks separated by comment rules. **Lower layers never depend on upper ones.**

```
┌──────────────────────────────────────────────────────┐
│ ⓪ i18n              VERSION / LANG / STR / t()         │
├──────────────────────────────────────────────────────┤
│ ① Constants         SCRIPT_DIR / DEFAULT_OUT / limits │
├──────────────────────────────────────────────────────┤
│ ② Utilities         has_text trim basename dirname …  │
├──────────────────────────────────────────────────────┤
│ ③ File backend      try_write family (pure I/O)        │
├──────────────────────────────────────────────────────┤
│ ④ Path & numbers    norm_path resolve_out_path parse_num│
├──────────────────────────────────────────────────────┤
│ ⑤ Collection        load_ranges load_selected all_static│
├──────────────────────────────────────────────────────┤
│ ⑥ Business          make_record verify_rows sort_rows  │
├──────────────────────────────────────────────────────┤
│ ⑦ Formatting        fmt_lua fmt_json fmt_csv render    │
├──────────────────────────────────────────────────────┤
│ ⑧ Config            serialize deserialize read/write   │
├──────────────────────────────────────────────────────┤
│ ⑨ UI                step_* flow_* main_menu            │
└──────────────────────────────────────────────────────┘
```

Design constraints (stated in the source comments):

- **The UI layer only shows dialogs, never computes data**; the business layer only computes, never shows dialogs.
- **Every user-facing string must go through `t(key)`.** No hard-coded text; new strings go into both tables.
- The only exceptions are two `gg.toast` calls (corrupt config, failed config save) and the confirmation after `verify_rows` — the first two are failure feedback from the config layer, the last is a flow decision; none of them touch data conversion.
- Every call into an external API (`io.*`, `os.*`, `gg.*`) is wrapped in `pcall`, because GG's implementation differs across ROMs and "obviously working" calls can throw.

---

## Path Layer

### Order of operations in `norm_path`

The order is not arbitrary — each step may produce the form the next one expects:

| # | Operation | Purpose |
| --- | --- | --- |
| 1 | `trim` | strip surrounding whitespace (pasted paths usually have some) |
| 2 | strip `content://<authority>` / `file://` / `document://` / any `scheme://` | URI prefixes from SAF and file pickers |
| 3 | selectively decode `%XX` | only the four characters that change semantics |
| 4 | split `/tree/<tree>/document/<doc>` | SAF tree + document composite form |
| 5 | strip leftover `tree/` `document/` | single-part forms |
| 6 | `primary:` → `/storage/emulated/0/` | SAF volume alias |
| 7 | `\` → `/` | Windows-style separators |
| 8 | must start with `/`, else return `""` | relative paths are rejected |

Typical inputs and outputs:

| Input | Output |
| --- | --- |
| `/sdcard/base.lua` | `/sdcard/base.lua` |
| `file:///sdcard/base.lua` | `/sdcard/base.lua` |
| `content://com.android.externalstorage.documents/tree/primary%3ADownload/document/primary%3ADownload%2Fbase.lua` | `/storage/emulated/0/Download/base.lua` |
| `content://com.android.externalstorage.documents/document/primary%3Abase.lua` | `/storage/emulated/0/base.lua` |
| `primary:Download/base.lua` | `/storage/emulated/0/Download/base.lua` |
| `./base.lua` | `""` (rejected) |
| `已输出的基址.lua` | `""` (rejected; caller falls back) |

### Why only four characters are decoded

```lua
s = s:gsub("%%(%x%x)", function(h)
  local c = tonumber(h, 16)
  if c == 0x25 then return "%" end
  if c == 0x2F then return "/" end
  if c == 0x3A then return ":" end
  if c == 0x20 then return " " end
  return "%" .. h
end)
```

Decoding everything would interpret the bytes of a UTF-8 filename as individual `%XX` escapes and produce an invalid byte sequence. Escapes like `%2C` (comma) or `%28` (parenthesis) don't affect path semantics, so leaving them untouched is safer.

### Fallback in `resolve_out_path`

```
norm_path(p)
  ├─ empty → use the raw string
  ├─ still empty, or ends with "/" (a directory) → return nil
  ├─ path_ok (length < 240 and starts with "/") → return as-is
  └─ otherwise → SCRIPT_DIR + basename
```

There is **no pre-write probe** (no test file, no `access` check): writability is decided by `try_write` when it actually writes. Otherwise every check would leave probe files behind.

The 240-character cap in `path_ok` is a conservative compromise between `NAME_MAX` (255) and overall path limits; UTF-8 filenames hit it sooner because it counts bytes.

---

## File Backend

### `try_write` decision tree

```
try_write(path, blob)
│
├─ blob not a string / bad path / empty filename → fail immediately
│
├─ tmp = dir + "." + name + ".lt" + <time>_<seq>_<rand> + ".tmp"
├─ raw_write(tmp, blob)
│   │
│   ├─ success
│   │   ├─ ① rename(tmp → path)            ✅ return path
│   │   ├─ ② remove(path) + rename retry    ✅ return path
│   │   ├─ ③ remove(path) + direct write    ✅ return path (drop tmp)
│   │   ├─ ④ rename to alt (name_<ts>.ext)  ✅ return alt
│   │   ├─ ⑤ direct write to alt            ✅ return alt
│   │   ├─ ⑥ tmp is readable                ✅ return tmp
│   │   └─ ⑦ drop tmp, "stale FUSE cache"
│   │
│   └─ failure
│       ├─ remove(path) + direct write      ✅ return path
│       ├─ path is readable                 ✅ return path
│       └─ drop tmp, return the real error
```

Key points:

- **Unique temp names**: `time + sequence + random` (`uniq_suffix`), each source wrapped in `pcall` so a disabled `os.time` can't break assembly. Multiple writes in the same second never collide.
- **The temp file starts with a dot and ends with `.tmp`** so it is easy to spot and clean. `drop_tmp` renames it to `.bak` when deletion fails, so junk never accumulates as `.tmp`.
- **The primary signal is the write/close return value**; `probe_readable` is corroborating only. On scoped storage "written but not yet readable" is normal, so trusting the probe alone would report false failures.
- **`saved_path` may differ from the requested path.** Every caller must use the returned value: `write_output` and `write_cfg` both do, and the final report flags "saved to the paths above" when it happens.

### Mode cycling in `raw_write`

```lua
local modes = { "wb", "w", "w+b", "w+" }
```

GG's `io` accepts different mode strings on different ROMs (some only `wb`, some prefer `w+b`). Each attempt is followed by `flush` + `close`, and the first success returns.

`f:write()` is also wrapped in `pcall` and its return value checked — some implementations return `nil` silently when the disk is full.

### Removal and probing

```lua
local function safe_remove(path)
  local ok, res = pcall(os.remove, path)
  return ok and is_true(res)
end
```

On some ROMs `os.remove` throws instead of returning `nil, err` for a missing file, hence the `pcall`; `is_true` treats both `nil` and `false` as failure.

`probe_readable` retries up to `VERIFY_TRIES = 3` times with `RETRY_SLEEP = 120ms` between attempts — the visibility delay for newly created files on scoped storage is usually in that range.

---

## Numeric Layer

### `parse_num` flow

```
trim → strip thousands separators
  ├─ contains "~" → take the substring after it (upper bound)
  ├─ starts with "-" → remember negative, strip it
  ├─ prefix "0x"/"0X"
  │   ├─ tonumber(hex, 16)
  │   └─ if the result is negative and the input was pure hex → accumulate manually as float
  └─ otherwise tonumber(s)
  └─ reject nil / nan / ±inf
  └─ apply the negative sign
```

Two details matter:

**1. Manual accumulation for large hex values**

In Lua 5.3+, `tonumber("FFFFFFFFFFFFFFFF", 16)` wraps to a negative 64-bit integer. The script then accumulates as a float:

```lua
local acc = 0.0
for i = 1, #hex do acc = acc * 16.0 + tonumber(hex:sub(i, i), 16) end
```

This at least gets the magnitude right (doubles have 53 significant bits, so very large values still lose precision — see *Known Limitations* in the README).

**2. `~` is handled before the sign**

The order is "take the upper bound, then check for a minus", so `-1~5` yields `5`, not `-5`. This is deliberate: search-result ranges like `100~200` are the main use case, and negative ranges are practically nonexistent.

### Literal output

```lua
local function num_to_literal(n)
  local s = tostring(n)
  if s:find(".", 1, true) or s:find("e", 1, true)
     or s:find("inf", 1, true) or s:find("nan", 1, true) then
    return s
  end
  return string.format("%d", n)
end
```

`tostring(12345.0)` yields `"12345.0"`; embedding that in the generated script is legal but ugly, and writing a float literal into a `Dword` can be ambiguous. Integral values are normalised to `12345`.

### Address formatting

```lua
local function hex_addr(v)
  if type(v) ~= "number" then return "?" end
  if v ~= v or v == math.huge or v == -math.huge then return "?" end
  return string.format("0x%X", math.floor(v))
end
```

`%X` **raises** on non-integer values (`number has no integer representation`), so `math.floor` is mandatory; the `v ~= v` NaN test comes first because `math.floor(nan)` behaves differently across versions.

---

## Collection Layer

### Building the range table

```lua
for _, r in ipairs(list) do
  if r.state and STATIC_STATES[r.state] then
    static_list[#static_list + 1] = r
    local m = static_module[r.internalName]
    if m == nil or r.start < m then static_module[r.internalName] = r.start end
  end
end
```

Two structures come out:

| Table | Shape | Used for |
| --- | --- | --- |
| `static_list` | array of `{start, end, state, internalName, …}` | `range_of` linear lookup |
| `static_module` | hash `internalName → smallest start` | offset base, grouping by module |

`static_list` is a plain array with linear scanning rather than an interval tree: segment counts are in the hundreds, so scanning costs less than building an index, and the code stays short and obviously correct.

### Static test

```lua
local STATIC_STATES = { Xa = true, Cb = true, Cd = true, Ps = true }
```

Used in two places:

1. `load_ranges` — filtering while building the table;
2. `all_static` — one batched `gg.getValuesRange(sel)` check over the whole selection.

`all_static` tolerates shape differences:

```lua
local state = type(info) == "table" and info.state or info
```

Some GG versions return `{state="Cd", …}`, others return the state string directly.

> A single non-whitelisted item rejects the entire selection. Mixing non-static addresses into a config would produce writes to random data after a restart — the risk outweighs the benefit of "partially working".

### Deduplication

```lua
if it and it.address ~= nil and not seen[it.address] then
```

The same address can appear several times in the saved list (saved twice, or saved with different types). The first occurrence wins, so the generated script never writes the same location twice.

---

## Records and Validation

### Record shape

```lua
{
  module     = r.internalName,              -- full path; basename on output
  seg_start  = r.start,
  seg_end    = r["end"],
  offset     = hex_addr(item.address - base),  -- string "0x…"
  flags      = item.flags,
  value      = value,
  freeze     = freeze,                      -- already resolved to a boolean
  value_addr = hex_addr(item.address),
}
```

Three design choices:

- **`offset` is stored as a string** because it goes straight into JSON/CSV/Lua; comparisons use `tonumber`. This avoids re-implementing formatting in three places.
- **`freeze` is baked into the record**: the "boolean or table" duality of `frozen(freeze, i)` is resolved once in `make_record`, so sorting and filtering can't misalign it afterwards.
- **`module` keeps the full path, output uses `basename`**: the full path disambiguates same-named `.so` files in different directories for sorting and grouping, while the generated script needs only the filename for `getRangesList(name)`.

### Validation

```lua
local off = row.offset and tonumber(row.offset)
local hit = off and row.seg_start and range_of(row.seg_start + off)
```

It looks like `range_of(original address)` again, but it recomputes from **segment base + offset** — that verifies the numbers actually written to the file are self-consistent, not just that the input was valid. If the range table changed mid-flow (a module got unloaded), this catches it.

Failing rows are not discarded: the user decides whether to write the remainder, and only a total failure aborts.

### Sorting

```lua
table.sort(rows, function(a, b)
  local sa, sb = a.seg_start or 0, b.seg_start or 0
  if sa ~= sb then return sa < sb end
  if a.module ~= b.module then return a.module < b.module end
  local oa, ob = tonumber(a.offset) or 0, tonumber(b.offset) or 0
  if oa ~= ob then return oa < ob end
  return tostring(a.offset) < tostring(b.offset)
end)
```

Three levels: **segment base → module name → numeric offset**. Two reasons:

1. it makes `fmt_lua`'s "one `so=` per module" work (same-module records end up adjacent);
2. it makes output **byte-for-byte reproducible** for the same input, which keeps diffs meaningful.

The third level (string comparison) exists so the order stays total when offsets are equal — otherwise `table.sort` can raise "invalid order function".

---

## Formatting Layer

### Format registry

```lua
local FORMATS = { "lua", "json", "csv" }
local FORMAT_LABEL = { lua = true, json = true, csv = true }
local FORMATTERS = { lua = fmt_lua, json = fmt_json, csv = fmt_csv }
local function fmt_label(f) return t("fmt_" .. tostring(f)) end
```

The **array order of `FORMATS` is the write order**; `normalize_formats` and `parse_formats` both reorder by it, so files are always written in the same sequence regardless of tick order.

Adding a format takes four touches: `FORMATS`, `FORMAT_LABEL`, `fmt_label`'s key (`fmt_xxx` in both string tables), and `FORMATTERS`.

### Lua output

```lua
if r.module ~= cur then
  cur = r.module
  out[#out + 1] = 'so=gg.getRangesList("' .. basename(r.module) .. '")[1].start'
end
out[#out + 1] = "py=" .. hex_addr(tonumber(r.offset))
             .. "\nsetvalue(so+py," .. tostring(r.flags) .. "," .. num_to_literal(parse_num(r.value))
             .. (r.freeze and ",true" or "") .. ")"
```

- `so=` is emitted only when the module changes, relying on `sort_rows` to keep same-module rows adjacent.
- `py` is reformatted via `hex_addr(tonumber(r.offset))`; `offset` is already a `0x` string, so this only guards against a `tonumber` failure.
- `value` is **parsed again** on output: the user may have typed `0x10` or `100~200`, and the generated script needs a plain numeric literal.

> Known wart: if two modules in different paths share a basename, the `so=` line is emitted twice for the same name (the module check uses the full path). Functionally harmless — the second assignment wins and points at the same base.

### JSON output

```lua
s = tostring(s):gsub('[%c"\\]', function(c)
  return JSON_ESC[c] or string.format("\\u%04X", c:byte())
end)
```

`[%c"\\]` matches control characters, double quotes and backslashes in one pass; `JSON_ESC` covers `"` `\` `\b` `\f` `\n` `\r` `\t`, everything else becomes `\u00XX`.

The output is **hand-assembled** rather than produced by a generic serialiser: fixed field order, no trailing comma, one record per line — easy to diff by eye.

`freeze` uses `r.freeze == true` strictly, so `nil` or a string can never leak into a boolean field.

### CSV output

```lua
if s:find('[,"\n\r]') then return '"' .. s:gsub('"', '""') .. '"' end
```

Standard RFC 4180: quote only when necessary, double inner quotes. `\t` is not treated as special (it isn't a CSV delimiter), and no BOM is written (a BOM would make some parsers read the first header as `\uFEFFmodule`).

### Path derivation

```lua
local function format_paths(base, fmts)
  local dir, name = dirname(base), basename(base)
  local stem = split_name(name)
  for i = 1, #fmts do out[i] = dir .. stem .. "." .. fmts[i] end
end
```

`stem` is the first return of `split_name`, which already handles the "empty stem falls back to `out`" case, so an input of `.lua` yields `out.lua` instead of `.lua`.

---

## Config Layer

### Serialisation

```
out_path=<path>
formats=<subset of lua,json,csv>
lang=<zh|en>
history_count=<N>
<path1>\x1F<path2>…
```

Constraints and reasons:

| Treatment | Reason |
| --- | --- |
| `one_line` turns `\r\n` into spaces | newlines would break the one-`key=value`-per-line structure |
| `\x1F` inside a history entry becomes a space | otherwise parsing would split out a phantom record |
| `lang` must precede `history_count` | the parser `break`s at `history_count`, later fields are never read |
| `lang` is validated before writing | only keys present in `STR` are accepted; anything else falls back to the current `LANG` |
| fixed field order | human-readable and diff-friendly |
| `_loaded` and other runtime flags are not persisted | they are session state |

### Deserialisation

```lua
for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
if #lines < 3 then return nil end
```

Fault-tolerance matrix:

| Situation | Behaviour |
| --- | --- |
| CRLF / CR | normalised to LF |
| trailing blank lines | removed |
| fewer than 3 lines | returns `nil` → caller falls back to defaults |
| unknown key | ignored (forward compatible: new fields don't invalidate old readers) |
| `lang` not in `STR` (e.g. `jp`, empty) | that entry is ignored, default language kept, config stays valid |
| `formats` contains invalid names | invalid dropped, valid kept; if all invalid, default `{lua}` kept |
| `history_count` non-numeric / negative | returns `nil` |
| `history_count` above the cap | truncated to `HISTORY_MAX` |
| fewer history entries than declared | keeps what it finds |
| `history_count` missing | returns `nil` (it doubles as the marker for "history section starts here") |

Parsing `break`s at `history_count` because the following line is no longer `key=value` — continuing would just discard the path as an unknown key.

### Dual storage

```lua
local ok_file = false
for i = 1, #CFG_FILES do
  if try_write(CFG_FILES[i], plain) then ok_file = true break end
end

local ok_var = false
if gg.saveVariable then
  local ok, res = pcall(gg.saveVariable, { cfg = plain }, Data_Save_file)
  if ok and res ~= false then ok_var = true end
end
```

- Read: three file candidates, then the GG variable slot; first non-empty wins.
- Write: files (stop at the first success) **plus** the variable slot (always attempted); either success counts.
- `gg.getVariables` returns different shapes across versions; `cfg_blob_from` handles `{blob}` / `{cfg=blob}` / a bare string, and `cfg_blob_from_gg` also tolerates both the with-argument and no-argument signatures.

Writing stops at the first successful file to avoid leaving three copies of the same config behind (later reads could pick a stale one).

### Write timing

At the end of the main flow:

```lua
local cfg = read_cfg()
cfg.out_path = written[1]
if remember then cfg.formats = fmts end
write_cfg(cfg)
history_push(written[1])
```

`history_push` **reads the config again**, replaces only `history`, and writes it back. So a completed run performs two read+write cycles. The benefit is that `history_push` is self-contained; the cost is a second disk write.

> Optimisation not implemented: let `history_push` accept `cfg` to save one round-trip. Note that `written[1]` is the real path — when writing fell back, it differs from what the user typed, and the config must record the real one.

---

## i18n

### Structure

```lua
local VERSION = "R1"
local LANG    = "zh"
local STR = { zh = { ... }, en = { ... } }
local function t(k, ...) ... end
```

The tables are **flat key-value** (`app_title`, `menu_flow`, `verify_bad`, …) with no nesting: one table lookup per call and a trivial fallback. Placeholder strings use `string.format`, so call sites read `t("done", #rows, #written)`.

### Three-level fallback in `t()`

```
STR[LANG][k]  →  STR.zh[k]  →  tostring(k)
```

| Level | Purpose |
| --- | --- |
| 1 | hit in the current language |
| 2 | a missing translation shows Chinese instead of blank |
| 3 | a typo'd key shows the key name instead of `nil` (which would make `gg.alert` raise `bad argument`) |

Arguments are detected with `select("#", ...)`: with no arguments `format` is skipped, so a literal `%` in a string can't be misinterpreted as a specifier.

### Lifetime of the language state

| Moment | Action |
| --- | --- |
| Script start | `LANG = "zh"` (hard-coded default) |
| `ensure_cfg()` → `read_cfg()` | a valid `lang` overwrites `LANG`, aligning the UI with the user's last choice |
| Menu → "Language / 语言" | `toggle_lang()`: switch `LANG`, write the config back, show a toast |
| Every later `read_cfg()` | the stored value wins again (idempotent in normal operation) |

`toggle_lang` has one ordering trap:

```lua
local next_lang = (LANG == "zh") and "en" or "zh"
local cfg = read_cfg()      -- this pulls LANG back to the stored value
LANG = next_lang            -- so overwrite only after reading
cfg.lang = LANG
write_cfg(cfg)
```

Assigning first and reading afterwards makes the switch silently revert — the classic "I tapped it and nothing happened".

### What is *not* translated

| Content | Reason |
| --- | --- |
| Generated field names `module` / `offset` / `flags` / `value_addr` / `value` / `freeze` | downstream scripts parse fixed keys |
| CSV header | same; Excel / pandas select by column name |
| `TYPE_MAP` names (`Dword[4]`, …) | they are GG flag identifiers; translating them misleads |
| Config keys `out_path` / `formats` / `lang` / `history_count` | storage format, independent of UI language |

### Role change of `FORMAT_LABEL`

It once served as both "validity set" and "display name"; i18n split the two:

```lua
local FORMAT_LABEL = { lua = true, json = true, csv = true }     -- membership only
local function fmt_label(f) return t("fmt_" .. tostring(f)) end  -- display only
```

The `if FORMAT_LABEL[x]` checks in `normalize_formats` / `parse_formats` are unaffected; the UI now calls `fmt_label`.

### Name collision

`t` is a very short name and collides easily. `describe()` used to have `local t = item.flags and ...`, which silently shadows the lookup function and produces "attempt to call a number value". It was renamed to `ty`. `uniq_suffix()` still has `local t, r = 0, 0`, which is fine because it never calls `t()`.

### Adding a language

1. Copy `STR.zh` into `STR.ja` and translate (missing keys fall back to Chinese, so you can start with the common ones).
2. Turn `toggle_lang` into a rotation:

```lua
local ORDER = { "zh", "en", "ja" }
local i = 1
for k = 1, #ORDER do if ORDER[k] == LANG then i = k break end end
local next_lang = ORDER[i % #ORDER + 1]
```

3. `serialize` / `deserialize` need no change — they only test `STR[lang]` for existence.

---

## UI Index Mapping

`gg.choice` / `gg.multiChoice` / `gg.prompt` are **1-based arrays**, and the script usually prepends a meta entry ("select all", "all formats"). The convention is: **the meta entry occupies slot 1, business items start at 2, subtract 1 when reading.**

### `step_select_items`

| UI entry | Index | Mapping |
| --- | --- | --- |
| `Select all (N items)` | 1 | `chosen[1..N] = true` |
| item *i* description | i+1 | `chosen[i] = true` |

### `step_pick_freeze`

`gg.choice` returns 1/2/3 → `true` / `false` / per-item table. For per-item mode, `collect_chosen` builds a **compact** `labels` array plus the original indices in `keys`:

```lua
local labels, keys, k = {}, {}, 0
for i = 1, #sel do
  if chosen[i] then
    k = k + 1
    labels[k] = describe(sel[i])
    keys[k]  = i          -- original index
  end
end
```

The resulting map is keyed by `sel` indices and initialised to `false`, so items that were never selected are explicitly `false` rather than absent.

### `step_edit_values`

This is the easiest one to misread. Construction order:

```lua
local defaults, types = { "", false }, { "text", "checkbox" }
-- append business items at defaults[i+2] / types[i+2]
table.insert(labels, 1, t("ev_use_mono"))
table.insert(labels, 1, t("ev_mono"))
```

Two "insert at 1" calls reverse the order, giving:

| Final index | Label | Widget | Read |
| --- | --- | --- | --- |
| 1 | `Single value (…)` | text | `res[1]` |
| 2 | `Use single value` | checkbox | `res[2] == true` |
| 3 … N+2 | item *i* description | text | `res[i + 2]` |

So the **text field is first on screen and the checkbox second**, which is why `defaults[1]=""` and `defaults[2]=false` are ordered that way. The decision logic:

```lua
if res[2] == true then
  local mono = res[1]
  if not has_text(mono) then mono = 0 end
  for i = 1, #keys do values[keys[i]] = mono end
else
  for i = 1, #keys do
    if res[i + 2] ~= nil then values[keys[i]] = res[i + 2] end
  end
end
```

### `step_pick_formats`

| UI entry | Index | Pre-ticked |
| --- | --- | --- |
| `All formats (lua + json + csv)` | 1 | no |
| `fmt_label(FORMATS[i])` | i+1 | `pre[i+1] = true` when remembered |

### `step_output_opts`

Two prompt fields: path (type `file`) and "remember format" (checkbox). Returns `res[1]` and `res[2] == true`. The default path gets two guards:

```lua
if def_path:sub(-4) == ".tmp" or def_path:sub(1, 1) ~= "/" then def_path = DEFAULT_OUT end
```

A `.tmp` ending means the remembered path was a temp file (legacy leftover), so replacing it with the default is safer.

---

## Entry and Main Loop

```lua
-- initialise first (this decides the UI language), then check the session
pcall(math.randomseed, os.time())
ensure_cfg()

if #gg.getRangesList() == 0 then
  gg.alert(t("no_session"))
  return
end

load_ranges()
gg.showUiButton()

while RUNNING do
  if gg.isClickedUiButton() then
    collectgarbage("collect")
    local ok, err = pcall(main_menu)
    if not ok then gg.alert(t("script_err", tostring(err))) end
  end
  gg.sleep(80)
end

if gg.hideUiButton then gg.hideUiButton() end
```

The main menu has three entries:

```lua
local choice = gg.choice({
  t("menu_flow"),   -- 1 extract static base
  t("menu_lang"),   -- 2 language
  t("menu_exit"),   -- 3 exit
}, nil, t("app_title"))
```

Four points:

1. **Initialisation order**: `ensure_cfg()` must run *before* the empty-session check, because it calls `read_cfg()`, which sets `LANG` to the user's last choice — that way even the "no memory ranges" alert is in the right language. `load_ranges()` must run *after* the check, since there is nothing to scan without a session.
2. **`math.randomseed` under `pcall`**: some environments disable `os.time` (returns `nil`), and `randomseed(nil)` raises.
3. **80 ms throttling**: `gg.sleep(80)` yields the CPU so GG and the game stay responsive; `collectgarbage` runs only on clicks, concentrating GC cost on a low-frequency path.
4. **Menu exceptions stay inside**: a failed `pcall(main_menu)` only shows an alert and the loop continues — one bad interaction can't kill the script.

`RUNNING` is set to `false` only by entry 3; every other `nil` return is a plain `return` that leaves the loop state untouched. After a language switch the menu is redrawn in the new language on the next tap.

> **Note**: `load_ranges()` runs once, at startup. If the target module isn't loaded yet, it won't be in the range table and any address inside it is **silently dropped** by `range_of` (visible as "No static base address was generated" or fewer records). Always enter the game and let the target `.so` load **before** running the script. Modules loaded while the script is running are likewise invisible — restart the script.

---

## Performance

| Operation | Complexity | Note |
| --- | --- | --- |
| `load_ranges` | O(segments) | once at startup, usually a few hundred |
| `range_of` | O(segments) | one linear scan per address; about 2N calls in `make_record` + `verify_rows` |
| `all_static` | one API call | batched `getValuesRange`, never per address |
| `sort_rows` | O(N log N) | 3 `tonumber` calls per comparison, N typically < 100 |
| Writing | O(formats × retries) | per-format retries, worst case 3 directories × several fallback branches |

Memory is dominated by `static_list` (references to range objects, no copying) and the output text (KB range for N records). No caches, no global accumulation — everything is released when the script ends.

---

## Extension Points

### Adding an output format

1. Append the name to `FORMATS` (this sets the write order).
2. Add it to `FORMAT_LABEL` and add `fmt_<name>` to **both** string tables.
3. Write `fmt_xxx(rows)` taking the already-sorted record array and returning the full text.
4. Register it in `FORMATTERS`.

No UI changes needed — `step_pick_formats` iterates `FORMATS`.

### Extending the static whitelist

```lua
local STATIC_STATES = { Xa = true, Cb = true, Cd = true, Ps = true }
```

Append the state codes you observe on your ROM; both consumers (`load_ranges`, `all_static`) pick it up automatically. Check the actual state in GG's range list before adding anything.

### Allowing more history

```lua
local HISTORY_MAX = 1
```

Raising it works out of the box for parsing and serialising, but `history_push` currently overwrites (`cfg.history = { path }`). To really keep several entries:

```lua
local cfg = read_cfg()
table.insert(cfg.history, 1, path)
while #cfg.history > HISTORY_MAX do table.remove(cfg.history) end
write_cfg(cfg)
```

### Adding a UI language

See [i18n · Adding a language](#adding-a-language). Add a `STR.xx` table and extend the rotation in `toggle_lang`; the config and UI layers need no change.

### Changing the default output location

`DEFAULT_OUT` is derived from `SCRIPT_DIR`. To default to `Download`:

```lua
local DEFAULT_OUT = "/storage/emulated/0/Download/已输出的基址.lua"
```

Note that `SCRIPT_DIR` depends on `gg.getFile()`, which returns `file://` or an empty string on some GG builds; the script already strips `file://` / `document://` and falls back to `/storage/emulated/0/` when the result doesn't start with `/`.

### Making the generated script use the smallest base

The generated script uses `getRangesList(name)[1].start`. For maximum robustness:

```lua
local rs = gg.getRangesList("libxxx.so")
local base = math.huge
for i = 1, #rs do if rs[i].start < base then base = rs[i].start end end
so = base
```

This matches the script's own `static_module` computation and removes the "wrong mapping" risk.

---

## Debugging Tips

1. **Verify the range table first**: in GG's console, call `gg.getRangesList()` and check the `state` of the target address against `STATIC_STATES`.
2. **Print intermediate records**: temporarily add `print(module, offset, flags, value)` after `make_record` to confirm the base is the *smallest* start, not the first match.
3. **Trust the report for paths**: when a write falls back, `cfg.out_path` holds `written[1]`, which may differ from what you typed.
4. **Test the generated script alone**: run the produced `.lua` in GG and watch for `attempt to index a nil value` (module not loaded).
5. **Reproduce write failures**: `touch` a read-only file with the same name in the target directory to force `try_write`'s fallback branches.
6. **Never experiment with `STATIC_STATES` in production**: adding non-static states makes offsets point at random data after a restart, which can write into unrelated game structures.
7. **Verify a language switch**: set `lang=en` in the config manually and restart. If the UI is still Chinese, `read_cfg` didn't reach that file — probably a stale copy at `/sdcard/Lib_Tool.R1.cfg` won the priority race. Delete the extra copies.
8. **Lua version compatibility**: `for` control variables are read-only in Lua 5.4+ (`attempt to assign to const variable`). This version changed `parse_formats` to introduce a local instead of reassigning the loop variable — avoid writing `for k in ... do k = f(k) end` when patching.
