# Elixir測試

## 測試=契約
見`test-contract.md`。既有測試=規格，禁改/弱化/刪除使其通過。

## 每行為分支需測試
每`case`/`cond`/`if`臂至少一測試。無未測路徑。

## 新功能必需測試類別

**1. 單元測試**
- 快樂路徑
- 每`{:error, _}`返回路徑
- 邊緣情況（空輸入/nil/邊界值）

**2. Doctest覆蓋**
- 每公開函數有doctest（快樂路徑）
- `doctest MyModule`於測試案例執行模組doctest

**3. 整合測試**
- 完整流水線：輸入→處理→輸出
- 此專案：完整feature文件→步驟執行→結果

## 模組結構
```elixir
defmodule MyApp.SomeModuleTest do
  use ExUnit.Case, async: true
  # async: false若模組使用已命名GenServer或全局狀態
end
```

## `describe`組織
外層模組=主體；`describe`=場景。
```elixir
describe "parse_cli/1 with --tags" do
  test "parses single tag expression" do ...
  test "last --tags wins if repeated" do ...
end
```

## 斷言精確性
```elixir
assert result == {:ok, 42}     # ✅ 精確
assert {:ok, _} = result       # ✅ 結構重要時用模式匹配
assert result                  # ❌ 過寬
```

## 禁
- 測試庫內部（Regex.run/Enum.map行為）
- 重複斷言已有低層測試覆蓋之行為
