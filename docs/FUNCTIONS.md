# Function Reference

[简体中文](函数索引.md) · **English**

`Lib_Tool R1.lua` defines **63 functions**: 62 top-level `local function`s plus one nested `push` inside the `CFG_FILES` initialisation block. It **writes no globals** (except `so` / `py` inside the generated output script), so it coexists with other GG scripts without collisions.

Conventions:

- `sel` is the selection array (`gg.getSelectedListItems()` after dedupe). Indices 1..N line up across `sel`, `chosen`, `values` and `freeze`.
- Returning `nil` means "user cancelled" or "precondition failed"; callers treat the first silently and the second usually follows an alert.
- A **record** is `{module, seg_start, seg_end, offset, flags, value, freeze, value_addr}`.

---

## Global constants

| Name | Type | Value / meaning |
| --- | --- | --- |
| `VERSION` | string | `"R1"`, shown in the main menu title |
| `LANG` | string | current UI language, `"zh"` / `"en"`; set from the config's `lang`, toggled from the menu |
| `STR` | table | string tables `{ zh = {...}, en = {...} }`, flat keys |
| `SCRIPT_DIR` | string | script folder with a trailing `/`; falls back to `/storage/emulated/0/` |
| `DEFAULT_OUT` | string | `SCRIPT_DIR .. "已输出的基址.lua"` |
| `Data_Save_file` | string | `"Lib_Tool.R1.cfg"`, the GG variable slot name |
| `RETRY_SLEEP` | number | `120`, retry interval for readability probes (ms) |
| `VERIFY_TRIES` | number | `3`, probe attempts |
| `HISTORY_MAX` | number | `1`, history cap |
| `STATIC_STATES` | table | `{Xa, Cb, Cd, Ps}` static-segment state whitelist |
| `TYPE_MAP` | table | flags → readable type name |
| `static_list` | table | array of static segments, filled by `load_ranges` |
| `static_module` | table | `internalName → smallest start` |
| `FORMATS` | table | `{"lua","json","csv"}`, array order = write order |
| `FORMAT_LABEL` | table | format validity set (values always `true`; display goes through `fmt_label`) |
| `FORMATTERS` | table | format → renderer |
| `LUA_HEAD` | string | `setvalue()` header of the generated script |
| `JSON_ESC` | table | short JSON escape table |
| `CFG_FILES` | table | config path candidates (3, deduped) |
| `RUNNING` | boolean | loop switch, only "exit" sets it to `false` |
| `_seq` | number | temp-file sequence counter |

---

## Utilities

| Function | Signature | Returns | Notes |
| --- | --- | --- | --- |
| `has_text` | `(v)` | boolean | `v` is neither `nil` nor `""`. The number `0` counts as present |
| `trim` | `(v)` | string | strips surrounding whitespace; `nil` → `""` |
| `basename` | `(p)` | string | last path segment: `/a/b/libc.so` → `libc.so` |
| `dirname` | `(p)` | string | directory with trailing `/`; `/` when there is no separator |
| `is_true` | `(v)` | boolean | `v` is neither `nil` nor `false`; normalises `os.*` return values |
| `split_name` | `(name)` | stem, ext | `out.lua` → `"out","lua"`; `.lua` → `"out","lua"`; `out` → `"out",nil` |
| `norm_path` | `(p)` | string | normalises a path; `""` when impossible. See [TECHNICAL · Path Layer](TECHNICAL.md#path-layer) |
| `path_ok` | `(p)` | boolean | string, length < 240, starts with `/` |

---

## File backend

| Function | Signature | Returns | Notes |
| --- | --- | --- | --- |
| `uniq_suffix` | `()` | string | `time_seq_random`; each part is `pcall`-wrapped for uniqueness |
| `raw_write` | `(path, blob)` | `true` / `false, err` | cycles `wb → w → w+b → w+`, then `flush` + `close` |
| `safe_remove` | `(path)` | boolean | `pcall` wrapper around `os.remove`; swallows every error |
| `probe_readable` | `(path, tries?)` | boolean | readable means present; default 3 attempts × 120 ms |
| `drop_tmp` | `(tmp)` | nil | deletes the temp file, or renames it to `.bak` when deletion fails |
| `try_write` | `(path, blob)` | `ok, saved_path, err` | robust write; `saved_path` may differ from `path` |
| `resolve_out_path` | `(p)` | string / nil | valid absolute path kept, otherwise falls back to the script folder; directory forms return `nil` |

`try_write` failure strings:

| String | Meaning |
| --- | --- |
| `blob not string` | content is not a string |
| `bad path` | path fails `path_ok` |
| `bad name` | no filename could be extracted |
| `target path blocked by stale FUSE cache` | the dentry is dead and every fallback failed |
| anything else | raw error from `io.open` / `f:write` |

---

## Numeric

| Function | Signature | Returns | Notes |
| --- | --- | --- | --- |
| `parse_num` | `(v)` | number / nil | supports `0x` hex, thousands separators, `A~B` upper bound, negatives, decimals, scientific notation; non-finite → `nil` |
| `num_to_literal` | `(n)` | string | integers without a decimal point (`12345`), floats kept as-is |
| `hex_addr` | `(v)` | string | uppercase `0x` hex; `"?"` for non-numbers / `nan` / `inf`; floors first |
| `describe` | `(item)` | string | one-line UI description: `value, type: Dword[4], address: 0x…` |

---

## Collection

| Function | Signature | Returns | Notes |
| --- | --- | --- | --- |
| `load_ranges` | `()` | nil | resets and fills `static_list` / `static_module`; **called once at startup only** |
| `range_of` | `(addr)` | range / nil | linear scan for the containing static segment (`start ≤ addr ≤ end`) |
| `module_of` | `(addr)` | string / nil | full module path |
| `load_selected` | `()` | array | saved-list selection, deduped by `address` (first wins) |
| `all_static` | `(sel)` | boolean | one batched `gg.getValuesRange` call; an empty array passes |
| `collect_chosen` | `(sel, chosen)` | labels, keys | compact UI labels plus the original `sel` indices |

---

## Business

| Function | Signature | Returns | Notes |
| --- | --- | --- | --- |
| `make_record` | `(item, value, freeze)` | record / nil | `nil` when the address is outside static segments; base = `static_module[module]` |
| `verify_rows` | `(rows)` | ok_rows, bad_rows | re-checks `seg_start + offset` against the static segments |
| `sort_rows` | `(rows)` | rows | in-place sort: segment base → module → numeric offset |
| `frozen` | `(freeze, i)` | boolean | boolean = global, table = per-item `freeze[i]` |

---

## Formatting

| Function | Signature | Returns | Notes |
| --- | --- | --- | --- |
| `fmt_lua` | `(rows)` | string | freeze script with `LUA_HEAD`; one `so=` per module |
| `json_q` | `(s)` | string | JSON-escapes and quotes; control characters become `\uXXXX` |
| `fmt_json` | `(rows)` | string | hand-written array, 2-space indent, no trailing comma |
| `csv_field` | `(s)` | string | quotes fields containing `,` `"` or newlines, doubling inner quotes |
| `fmt_csv` | `(rows)` | string | fixed header, one record per line |
| `render` | `(rows, fmt)` | string | dispatches to a formatter, unknown formats fall back to `fmt_lua` |
| `normalize_formats` | `(fmts)` | array | drops invalid names, reorders by `FORMATS`, dedupes |
| `parse_formats` | `(v)` | array | parses `"lua,json"` from the config, dropping invalid names |
| `format_paths` | `(base, fmts)` | array | derives `dir + stem + .ext` per format |

> `render` must be called after `sort_rows` — `fmt_lua` relies on same-module rows being adjacent.

---

## i18n

| Function | Signature | Returns | Notes |
| --- | --- | --- | --- |
| `t` | `(k, ...)` | string | current-language text; with arguments it goes through `string.format`; falls back to Chinese, then to the key |
| `fmt_label` | `(f)` | string | display name of a format, equivalent to `t("fmt_" .. f)` |
| `toggle_lang` | `()` | nil | switch zh/en: compute target → `read_cfg` (which resets `LANG`) → overwrite `LANG` → write config → toast |

> `t` is the global lookup function — **never use `t` as a local name** (it silently shadows). The old `local t` in `describe()` is now `ty`.

---

## Config

| Function | Signature | Returns | Notes |
| --- | --- | --- | --- |
| `default_cfg` | `()` | table | `{out_path=DEFAULT_OUT, formats={"lua"}, lang=LANG, history={}}` |
| `one_line` | `(s)` | string | `\r\n` → spaces, keeping one `key=value` per line |
| `serialize` | `(cfg)` | string | fixed field order; `_loaded` is not persisted; history joined with `\x1F` |
| `deserialize` | `(text)` | table / nil | tolerant parse; `< 3` lines or a bad `history_count` → `nil` |
| `cfg_blob_from_file` | `(path)` | string / nil | full file contents; empty means absent |
| `cfg_blob_from` | `(v)` | string / nil | accepts `{blob}` / `{cfg=blob}` / a bare string |
| `cfg_blob_from_gg` | `()` | string / nil | accepts both `getVariables(name)` and `getVariables()` |
| `read_cfg` | `()` | table | files first, variable slot second; carries `_loaded` and applies `lang` |
| `write_cfg` | `(cfg)` | boolean | writes file + variable slot, either success counts |
| `history_push` | `(path)` | nil | re-reads the config, replaces `history`, writes back |
| `ensure_cfg` | `()` | boolean | writes the default config when neither storage has one |
| `push` | `(p)` | nil | **nested**: appends a `CFG_FILES` candidate, deduped; used only at init |

---

## UI

| Function | Signature | Returns | Notes |
| --- | --- | --- | --- |
| `step_pick_list` | `()` | sel / nil | reads the selection and validates it; two failure alerts |
| `step_filter_modules` | `(sel)` | sel / nil | only prompts when > 1 module; "all modules" or filter by module |
| `step_select_items` | `(sel)` | chosen / nil | multi-select with "select all" first; returns `chosen[1..N] = true` |
| `step_pick_freeze` | `(sel, chosen)` | `true`/`false`/table/nil | freeze all / none / per item (keyed by `sel` index) |
| `step_edit_values` | `(sel, chosen)` | values / nil | mixed form; returns `values[sel_index] = input` |
| `step_pick_formats` | `()` | fmts / nil | multi-select, pre-ticked from the config; empty selection alerts and returns `nil` |
| `step_output_opts` | `()` | out_path, remember / nil | path + remember flag; empty path returns `nil` |
| `write_output` | `(want_out, text)` | saved_path / `nil, err` | retries target → script folder → `/sdcard` → `/storage/emulated/0` |
| `flow_static_address` | `()` | nil | the 9-stage orchestration |
| `main_menu` | `()` | nil | menu (extract / language / exit); `choice == nil` only `return`s |

---

## Call graph

```
Entry (top-level chunk)
├─ math.randomseed (pcall)
├─ ensure_cfg                      language first, session check second
│   └─ read_cfg → cfg_blob_from_file ×3 / cfg_blob_from_gg
│                └─ deserialize → LANG = cfg.lang
│   └─ write_cfg → serialize → try_write ×3 / gg.saveVariable
├─ gg.getRangesList() == 0        alert(t("no_session")) + return
├─ load_ranges
├─ gg.showUiButton
└─ while RUNNING
    └─ main_menu
        ├─ 1 → flow_static_address
        │   ├─ step_pick_list      → load_selected, all_static
        │   ├─ step_filter_modules → module_of, basename
        │   ├─ step_select_items   → describe → t
        │   ├─ step_pick_freeze    → collect_chosen, describe
        │   ├─ step_edit_values    → collect_chosen, parse_num
        │   ├─ make_record         → range_of, static_module, hex_addr
        │   ├─ verify_rows         → range_of
        │   ├─ step_pick_formats   → read_cfg, normalize_formats, fmt_label
        │   ├─ step_output_opts    → read_cfg
        │   ├─ resolve_out_path    → norm_path, path_ok
        │   ├─ sort_rows
        │   ├─ format_paths → split_name
        │   ├─ render → fmt_lua / fmt_json / fmt_csv
        │   ├─ write_output → try_write → raw_write / safe_remove / probe_readable / drop_tmp
        │   └─ read_cfg + write_cfg + history_push
        ├─ 2 → toggle_lang → read_cfg, write_cfg
        └─ 3 → RUNNING = false (exit)
```

---

## Return-value semantics

| Return | What the caller should do |
| --- | --- |
| `nil` from `gg.choice` / `multiChoice` / `prompt` | treat as cancel, `return` silently |
| `nil` from a business function (e.g. `resolve_out_path`) | an alert has usually been shown; just `return` |
| `false` from `write_cfg` | a toast was shown; the flow may continue |
| `false, err` from `try_write` | `write_output` moves on to the next directory |
| `ok, saved_path` from `try_write` | always use `saved_path`, never the argument |
