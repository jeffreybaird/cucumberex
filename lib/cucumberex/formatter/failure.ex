defmodule Cucumberex.Formatter.Failure do
  @moduledoc """
  Render a failed step's error the way ExUnit renders a failing test:
  the exception module and message, the step's source location, and — when
  backtraces are enabled — the captured stacktrace.

  Shared by the pretty and progress formatters so failure output is identical
  across them.
  """

  alias Cucumberex.Result

  @doc """
  Describe a failed result as a block of text.

  Options:

    * `:backtrace` - include the captured stacktrace (default `false`)
    * `:indent` - string prepended to every line (default `""`)

  ## Examples

      iex> r = %Cucumberex.Result{status: :failed, error: %RuntimeError{message: "boom"}, location: "features/steps.ex:5"}
      iex> Cucumberex.Formatter.Failure.describe(r)
      "** (RuntimeError) boom\\n     at features/steps.ex:5"

      iex> r = %Cucumberex.Result{status: :failed, error: %RuntimeError{message: "boom"}}
      iex> Cucumberex.Formatter.Failure.describe(r, indent: "  ")
      "  ** (RuntimeError) boom"

      iex> r = %Cucumberex.Result{status: :failed, error: :weird}
      iex> Cucumberex.Formatter.Failure.describe(r)
      "** (throw) :weird"
  """
  def describe(%Result{} = result, opts \\ []) do
    indent = Keyword.get(opts, :indent, "")
    backtrace? = Keyword.get(opts, :backtrace, false)

    [header_line(result.error)]
    |> append(location_line(result.location))
    |> append(backtrace_block(result.stacktrace, backtrace?))
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join("\n", &(indent <> &1))
  end

  defp append(lines, nil), do: lines
  defp append(lines, more), do: lines ++ List.wrap(more)

  defp header_line(error) when is_exception(error),
    do: "** (#{inspect(error.__struct__)}) #{Exception.message(error)}"

  defp header_line(nil), do: "** (unknown error)"
  defp header_line(error), do: "** (throw) #{inspect(error)}"

  defp location_line(nil), do: nil
  defp location_line(location), do: "     at #{location}"

  defp backtrace_block(nil, _), do: nil
  defp backtrace_block([], _), do: nil
  defp backtrace_block(_stacktrace, false), do: nil

  defp backtrace_block(stacktrace, true) do
    lines =
      stacktrace
      |> Exception.format_stacktrace()
      |> String.split("\n", trim: true)
      |> Enum.map(&"       #{String.trim_leading(&1)}")

    ["     stacktrace:" | lines]
  end
end
