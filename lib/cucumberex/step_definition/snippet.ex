defmodule Cucumberex.StepDefinition.Snippet do
  @moduledoc "Generate step definition snippets for undefined steps."

  @int_pattern ~r/-?\d+/
  @float_pattern ~r/-?\d*\.\d+/
  @quoted_pattern ~r/"[^"]*"|'[^']*'/

  @doc """
  Generate a step definition snippet for an undefined step.

  ## Examples

      iex> snippet = Cucumberex.StepDefinition.Snippet.generate("I have 5 cukes")
      iex> String.contains?(snippet, "{int}")
      true
      iex> String.contains?(snippet, "pending()")
      true
  """
  def generate(step_text, type \\ :cucumber_expression) do
    case type do
      :cucumber_expression -> generate_cucumber_expression(step_text)
      :regexp -> generate_regexp(step_text)
    end
  end

  defp generate_cucumber_expression(step_text) do
    {pattern, args} = cucumberify(step_text)
    arg_list = Enum.join(args, ", ")

    """
    step "#{pattern}" do #{if arg_list != "", do: "(#{arg_list})", else: ""}
      pending()
    end
    """
    |> String.trim()
  end

  defp generate_regexp(step_text) do
    {pattern, args} = regexify(step_text)
    arg_list = Enum.join(args, ", ")

    """
    step ~r/^#{pattern}$/ do #{if arg_list != "", do: "(#{arg_list})", else: ""}
      pending()
    end
    """
    |> String.trim()
  end

  defp cucumberify(text) do
    # Replace floats before ints (floats contain digits)
    {text, n_floats} = replace_all(text, @float_pattern, "{float}", 0)
    {text, n_ints} = replace_all(text, @int_pattern, "{int}", 0)
    {text, n_quoted} = replace_all(text, @quoted_pattern, "{string}", 0)

    args =
      (List.duplicate("int", n_ints) ++
         List.duplicate("float", n_floats) ++
         List.duplicate("string", n_quoted))
      |> Enum.with_index(1)
      |> Enum.map(fn {_t, i} -> "arg#{i}" end)

    {text, args}
  end

  defp regexify(text) do
    {text, n_floats} = replace_all(text, @float_pattern, ~s/(-?\\d*\\.\\d+)/, 0)
    {text, n_ints} = replace_all(text, @int_pattern, "(-?\\d+)", 0)
    {text, n_quoted} = replace_all(text, @quoted_pattern, ~s/("[^"]*")/, 0)
    total = n_floats + n_ints + n_quoted
    args = Enum.map(1..max(total, 0), fn i -> "arg#{i}" end)
    {Regex.escape(text) |> unescape_groups(), args}
  end

  defp replace_all(text, pattern, replacement, count) do
    matches = Regex.scan(pattern, text) |> length()
    {Regex.replace(pattern, text, replacement), count + matches}
  end

  defp unescape_groups(text) do
    String.replace(text, "\\(", "(") |> String.replace("\\)", ")")
  end
end
