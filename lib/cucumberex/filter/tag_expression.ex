defmodule Cucumberex.Filter.TagExpression do
  @moduledoc """
  Parse and evaluate Cucumber tag expressions.

  Supports:
    @smoke              — single tag
    @smoke and @fast    — AND
    @smoke or @wip      — OR
    not @slow           — NOT
    (@smoke or @wip) and not @skip  — grouping
    @feature:limit      — tag limits (parsed but limit enforcement is in runner)
  """

  @doc """
  Evaluate a tag expression string against a list of tags.

  ## Examples

      iex> Cucumberex.Filter.TagExpression.evaluate("@smoke", ["@smoke"])
      true

      iex> Cucumberex.Filter.TagExpression.evaluate("@smoke and @fast", ["@smoke"])
      false

      iex> Cucumberex.Filter.TagExpression.evaluate("@smoke or @wip", ["@wip"])
      true

      iex> Cucumberex.Filter.TagExpression.evaluate("not @slow", ["@fast"])
      true

      iex> Cucumberex.Filter.TagExpression.evaluate(nil, ["@any"])
      true
  """
  def evaluate(expr, tags) when is_binary(expr) and is_list(tags) do
    normalized_tags = normalize_tags(tags)

    expr
    |> parse()
    |> eval(normalized_tags)
  end

  def evaluate(nil, _tags), do: true

  defp normalize_tags(tags) do
    Enum.map(tags, fn t ->
      t |> String.trim_leading("@") |> String.downcase()
    end)
  end

  # --- Parser ---

  defp parse(expr) do
    expr
    |> String.trim()
    |> tokenize()
    |> parse_expr()
    |> elem(0)
  end

  defp tokenize(expr) do
    expr
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(fn token ->
      cond do
        token == "(" ->
          [:lparen]

        token == ")" ->
          [:rparen]

        String.starts_with?(token, "(") ->
          [:lparen | tokenize(String.slice(token, 1..-1//1))]

        String.ends_with?(token, ")") ->
          tokenize(String.slice(token, 0..-2//1)) ++ [:rparen]

        true ->
          [{:tag, token}]
      end
    end)
  end

  # Pratt-style recursive descent: or > and > not > atom
  defp parse_expr(tokens), do: parse_or(tokens)

  defp parse_or(tokens) do
    {left, rest} = parse_and(tokens)
    parse_or_rest(left, rest)
  end

  defp parse_or_rest(left, [{:tag, t} | rest]) when t in ["or", "OR"] do
    {right, rest2} = parse_and(rest)
    parse_or_rest({:or, left, right}, rest2)
  end

  defp parse_or_rest(left, rest), do: {left, rest}

  defp parse_and(tokens) do
    {left, rest} = parse_not(tokens)
    parse_and_rest(left, rest)
  end

  defp parse_and_rest(left, [{:tag, t} | rest]) when t in ["and", "AND"] do
    {right, rest2} = parse_not(rest)
    parse_and_rest({:and, left, right}, rest2)
  end

  defp parse_and_rest(left, rest), do: {left, rest}

  defp parse_not([{:tag, t} | rest]) when t in ["not", "NOT"] do
    {expr, rest2} = parse_atom(rest)
    {{:not, expr}, rest2}
  end

  defp parse_not(tokens), do: parse_atom(tokens)

  defp parse_atom([:lparen | rest]) do
    {expr, rest2} = parse_expr(rest)

    case rest2 do
      [:rparen | rest3] -> {expr, rest3}
      _ -> {expr, rest2}
    end
  end

  defp parse_atom([{:tag, tag} | rest]) do
    clean = String.trim_leading(tag, "@") |> String.downcase()
    {{:tag, clean}, rest}
  end

  defp parse_atom([]), do: {{:lit, true}, []}
  defp parse_atom(rest), do: {{:lit, true}, rest}

  # --- Evaluator ---

  defp eval({:tag, t}, tags), do: t in tags
  defp eval({:and, l, r}, tags), do: eval(l, tags) and eval(r, tags)
  defp eval({:or, l, r}, tags), do: eval(l, tags) or eval(r, tags)
  defp eval({:not, e}, tags), do: not eval(e, tags)
  defp eval({:lit, v}, _tags), do: v
end

defmodule Cucumberex.Filter.NameFilter do
  @moduledoc "Filter scenarios by name pattern."

  @doc """
  Match a scenario name against a pattern (nil, substring, or regex).

  ## Examples

      iex> Cucumberex.Filter.NameFilter.matches?("Eating cukes", nil)
      true

      iex> Cucumberex.Filter.NameFilter.matches?("Eating cukes", "cukes")
      true

      iex> Cucumberex.Filter.NameFilter.matches?("Eating cukes", "missing")
      false

      iex> Cucumberex.Filter.NameFilter.matches?("Eating cukes", ~r/^Eating/)
      true
  """
  def matches?(_name, nil), do: true

  def matches?(name, pattern) when is_binary(pattern) do
    String.contains?(name, pattern)
  end

  def matches?(name, %Regex{} = pattern) do
    name =~ pattern
  end
end

defmodule Cucumberex.Filter.LineFilter do
  @moduledoc "Filter scenarios by file:line."

  @doc """
  Match a scenario uri/line pair against a list of line filters.
  An empty filter list matches everything.

  ## Examples

      iex> Cucumberex.Filter.LineFilter.matches?("features/a.feature", 5, [])
      true

      iex> Cucumberex.Filter.LineFilter.matches?("features/a.feature", 5, [{"features/a.feature", 5}])
      true

      iex> Cucumberex.Filter.LineFilter.matches?("features/a.feature", 6, [{"features/a.feature", 5}])
      false

      iex> Cucumberex.Filter.LineFilter.matches?("features/a.feature", 5, ["features/a.feature"])
      true
  """
  def matches?(_uri, _line, []), do: true

  def matches?(uri, line, lines) when is_list(lines) do
    Enum.any?(lines, fn
      {filter_uri, filter_line} ->
        Path.expand(filter_uri) == Path.expand(uri) and line == filter_line

      filter_uri when is_binary(filter_uri) ->
        Path.expand(filter_uri) == Path.expand(uri)
    end)
  end
end
