defmodule Cucumberex.ParameterType.BuiltIn do
  @moduledoc "Built-in Cucumber parameter types."

  alias Cucumberex.ParameterType

  @doc """
  Return all built-in parameter types.

  ## Examples

      iex> names = Cucumberex.ParameterType.BuiltIn.all() |> Enum.map(& &1.name)
      iex> "int" in names and "float" in names and "string" in names and "word" in names
      true
  """
  def all do
    [
      ParameterType.new("int", ~r/-?\d+/, fn [s] -> String.to_integer(s) end,
        description: "Matches integers"
      ),
      ParameterType.new("float", ~r/-?\d*\.\d+/, fn [s] -> String.to_float(s) end,
        description: "Matches floats"
      ),
      ParameterType.new("word", ~r/[^\s]+/, fn [s] -> s end,
        description: "Matches one word (no spaces)"
      ),
      ParameterType.new(
        "string",
        ~r/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/,
        fn [s] ->
          String.slice(s, 1, byte_size(s) - 2) |> unescape()
        end,
        description: "Matches a quoted string"
      ),
      ParameterType.new(
        "bigdecimal",
        ~r/-?\d*\.?\d+/,
        fn [s] ->
          case Float.parse(s) do
            {f, ""} -> f
            _ -> String.to_integer(s) * 1.0
          end
        end,
        description: "Matches a decimal number",
        use_for_snippets: false
      ),
      ParameterType.new(
        "double",
        ~r/-?\d*\.?\d+/,
        fn [s] ->
          case Float.parse(s) do
            {f, ""} -> f
            _ -> String.to_integer(s) * 1.0
          end
        end,
        description: "Matches a double"
      ),
      ParameterType.new("byte", ~r/-?\d+/, fn [s] -> String.to_integer(s) end,
        description: "Matches a byte value",
        use_for_snippets: false
      ),
      ParameterType.new("short", ~r/-?\d+/, fn [s] -> String.to_integer(s) end,
        description: "Matches a short value",
        use_for_snippets: false
      ),
      ParameterType.new("long", ~r/-?\d+/, fn [s] -> String.to_integer(s) end,
        description: "Matches a long value",
        use_for_snippets: false
      )
    ]
  end

  defp unescape(s) when is_binary(s) do
    s
    |> String.replace("\\\"", "\"")
    |> String.replace("\\'", "'")
    |> String.replace("\\\\", "\\")
  end
end
