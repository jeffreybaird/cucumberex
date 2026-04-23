# Elixir碼風

## 單責
函數一事。`@doc`含「and」→拆分。

## 管道優先
多步轉換用`|>`。頂→底流。

## 公開函數需Doctest
每`def`（非`defp`）需`@doc`含至少一doctest（快樂路徑）。豁免：I/O及外部服務函數。

## 標籤元組錯誤協議
```elixir
{:ok, result}
{:error, :not_found}
{:error, :parse_failed, details}
```
禁裸`{:error, string}`。禁字串錯誤訊息於公開函數。

## 私函數前綴示意圖
```elixir
defp reject_expired_tokens(tokens)  # ✅
defp filter_tokens(tokens)          # ❌
```

## 窄Rescue
```elixir
rescue ArgumentError -> default    # ✅
rescue _ -> default                # ❌
```
若必須廣救→至少`Logger.warning`記錯。

## 注釋只說為何
不說做什麼。代碼已說。唯隱性約束/微妙不變量/特定bug繞路需注。

## 禁
- 無doctest公開函數（豁免除外）
- 未測試分支（每`case`/`cond`/`if`臂需測）
- 提交含`IO.inspect`
- 廣`rescue _ ->`無日誌
