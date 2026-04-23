# Elixir錯誤處理

## 標籤元組協議
所有可失敗公開函數返回標籤元組。錯誤標籤=調用者可模式匹配之具體原子。

```elixir
{:ok, result}              # 成功
{:error, :not_found}       # 具體原子標籤
{:error, :parse_failed, details}  # 附細節
```
禁：`{:error, "not found"}`  禁：`{:error, changeset}`（未標籤）

## Raise vs 返回元組
- **Raise** → 編程錯誤（錯誤參數型別/違反前置條件/不可能狀態）
- **返回`{:error, _}`** → 預期失敗（未找到/解析錯誤/驗證失敗）

```elixir
def parse!(input), do: case parse(input) do
  {:ok, r} -> r
  {:error, r} -> raise ArgumentError, inspect(r)
end

def parse(input) do  # 返回{:ok, _}或{:error, :invalid_syntax}
```

## Rescue窄度
```elixir
rescue ArgumentError -> {:error, :invalid_arg}  # ✅ 具體
rescue _ -> {:error, :unknown}                  # ❌ 廣泛
```

## 外部邊界廣救必須記錄
```elixir
rescue e ->
  require Logger
  Logger.warning("Hook failed: #{inspect(e)}")
  {:error, :hook_failed, e}
```

## Throw只用於控制流，非錯誤
```elixir
catch :pending -> {:pending, world}  # ✅ 非錯誤之提前退出
```

## 禁默默吞噬
`rescue _ -> default_value`無日誌=生產環境不可見。必須記錄。
