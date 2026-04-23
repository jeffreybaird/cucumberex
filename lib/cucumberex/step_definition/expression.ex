defmodule Cucumberex.StepDefinition.Expression do
  @moduledoc """
  Compile Cucumber Expressions and plain Regex patterns to Elixir regexes.

  Cucumber Expression syntax:
    {int}        → -?\\d+
    {float}      → -?\\d*\\.\\d+
    {string}     → "..." or '...'
    {word}       → [^\\s]+
    {paramtype}  → looked up in ParameterType registry
    (optional)   → optional group
    a/b          → alternation
  """

  alias Cucumberex.ParameterType

  @type match :: %{args: list(), param_types: list(ParameterType.t())}

  @doc """
  Compile a Cucumber Expression string or `Regex` to an internal match pattern.

  The `param_type_registry` pid is required for Cucumber Expressions containing
  `{custom_type}` parameters; plain strings and regexes don't need it.

  ## Examples

      iex> {:regex, _} = Cucumberex.StepDefinition.Expression.compile(~r/^foo$/)

      iex> {kind, _} = Cucumberex.StepDefinition.Expression.compile("^raw regex$", nil)
      iex> kind
      :regex
  """
  def compile(pattern, param_type_registry \\ Cucumberex.ParameterType.Registry)

  def compile(%Regex{} = r, _registry), do: {:regex, r}

  def compile(pattern, registry) when is_binary(pattern) do
    if String.starts_with?(pattern, "^") or String.contains?(pattern, "(?") do
      {:regex, Regex.compile!(pattern)}
    else
      {:cucumber_expression, build_cucumber_regex(pattern, registry)}
    end
  end

  @doc """
  Match step text against a pattern, returning `%{args: [...]}` or nil.

  ## Examples

      iex> Cucumberex.StepDefinition.Expression.match(~r/^hello (\\w+)$/, "hello world", nil)
      %{args: ["world"], param_types: []}

      iex> Cucumberex.StepDefinition.Expression.match(~r/^nope$/, "hello", nil)
      nil
  """
  def match(pattern, text, registry \\ Cucumberex.ParameterType.Registry)

  def match(%Regex{} = r, text, _registry) do
    case Regex.run(r, text, return: :index) do
      nil ->
        nil

      _ ->
        captures = Regex.run(r, text)
        %{args: tl(captures), param_types: []}
    end
  end

  def match(pattern, text, registry) when is_binary(pattern) do
    {compiled, param_types} = build_cucumber_regex_with_types(pattern, registry)

    case Regex.run(compiled, text) do
      nil ->
        nil

      [full | captures] ->
        if full == text do
          args = transform_captures(captures, param_types)
          %{args: args, param_types: param_types}
        else
          nil
        end
    end
  end

  defp build_cucumber_regex(pattern, registry) do
    {regex, _} = build_cucumber_regex_with_types(pattern, registry)
    regex
  end

  defp build_cucumber_regex_with_types(pattern, registry) do
    {regex_parts, param_types} = parse_cucumber_expression(pattern, registry)
    regex_str = "^" <> Enum.join(regex_parts, "") <> "$"
    {Regex.compile!(regex_str), param_types}
  end

  defp parse_cucumber_expression(pattern, registry) do
    # tokenize: {param}, (optional), a/b alternation, literal text
    tokens = tokenize(pattern)

    Enum.reduce(tokens, {[], []}, fn token, {parts, types} ->
      case token do
        {:param, name} ->
          pt = lookup_param_type(name, registry)
          regexp_src = param_type_regexp_src(pt)
          {parts ++ ["(#{regexp_src})"], types ++ [pt]}

        {:optional, text} ->
          escaped = Regex.escape(text)
          {parts ++ ["(?:#{escaped})?"], types}

        {:alternation, options} ->
          alts = Enum.map_join(options, "|", &Regex.escape/1)
          {parts ++ ["(?:#{alts})"], types}

        {:literal, text} ->
          {parts ++ [Regex.escape(text)], types}
      end
    end)
  end

  defp tokenize(pattern) do
    tokenize(pattern, [], "")
  end

  defp tokenize("", acc, buf) do
    flush(acc, buf)
  end

  defp tokenize("{" <> rest, acc, buf) do
    acc = flush(acc, buf)

    case :binary.split(rest, "}") do
      [name, remainder] -> tokenize(remainder, acc ++ [{:param, name}], "")
      _ -> tokenize(rest, acc, buf <> "{")
    end
  end

  defp tokenize("(" <> rest, acc, buf) do
    acc = flush(acc, buf)

    case :binary.split(rest, ")") do
      [inner, remainder] -> tokenize(remainder, acc ++ [{:optional, inner}], "")
      _ -> tokenize(rest, acc, buf <> "(")
    end
  end

  defp tokenize(<<c::utf8, rest::binary>>, acc, buf) do
    tokenize(rest, acc, buf <> <<c::utf8>>)
  end

  defp flush(acc, ""), do: acc

  defp flush(acc, buf) do
    acc ++ [classify_buffer(buf)]
  end

  defp classify_buffer(buf) do
    parts = String.split(buf, "/")

    if length(parts) > 1 and Enum.all?(parts, &simple_word?/1) do
      {:alternation, parts}
    else
      {:literal, buf}
    end
  end

  defp simple_word?(s), do: s =~ ~r/^\S+$/

  defp lookup_param_type(name, registry) do
    case Cucumberex.ParameterType.Registry.find(registry, name) do
      nil -> default_param_type(name)
      pt -> pt
    end
  end

  defp default_param_type("int"),
    do: %ParameterType{
      name: "int",
      regexp: ~r/-?\d+/,
      transformer: fn [s] -> String.to_integer(s) end
    }

  defp default_param_type("float"),
    do: %ParameterType{
      name: "float",
      regexp: ~r/-?\d*\.\d+/,
      transformer: fn [s] -> String.to_float(s) end
    }

  defp default_param_type("string"),
    do: %ParameterType{
      name: "string",
      regexp: ~r/"[^"]*"|'[^']*'/,
      transformer: fn [s] -> String.trim(s, "\"") |> String.trim("'") end
    }

  defp default_param_type("word"),
    do: %ParameterType{name: "word", regexp: ~r/[^\s]+/, transformer: fn [s] -> s end}

  defp default_param_type(name),
    do: %ParameterType{name: name, regexp: ~r/.+/, transformer: fn [s] -> s end}

  defp param_type_regexp_src(%ParameterType{regexp: r}) when is_struct(r, Regex) do
    Regex.source(r)
  end

  defp param_type_regexp_src(%ParameterType{regexp: r}) when is_binary(r), do: r

  defp param_type_regexp_src(%ParameterType{regexp: [r | _]}) when is_struct(r, Regex) do
    Regex.source(r)
  end

  defp transform_captures(captures, param_types) do
    Enum.zip(captures, param_types)
    |> Enum.map(fn {capture, pt} ->
      pt.transformer.([capture])
    end)
  end
end
