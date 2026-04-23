defmodule Cucumberex.Formatter.Progress do
  @moduledoc "Dot-per-step progress formatter (like RSpec's progress formatter)."

  use Cucumberex.Formatter
  alias Cucumberex.Events
  alias Cucumberex.Formatter.ANSI

  defstruct [:output, :color, results: [], undefined_snippets: [], step_count: 0, col: 0]

  @cols 70

  @impl GenServer
  def init(opts) do
    {:ok,
     %__MODULE__{
       output: Keyword.get(opts, :output, :stdio),
       color: Keyword.get(opts, :color, IO.ANSI.enabled?())
     }}
  end

  defp on_event(%Events.TestStepFinished{result: result}, state) do
    dot = step_char(result.status)
    colored = colorize(state, dot, result.status)
    print(state, colored)
    new_col = state.col + 1

    if new_col >= @cols do
      print(state, "\n")
      %{state | step_count: state.step_count + 1, col: 0}
    else
      %{state | step_count: state.step_count + 1, col: new_col}
    end
  end

  defp on_event(%Events.TestCaseFinished{result: result}, state) do
    %{state | results: [result | state.results]}
  end

  defp on_event(%Events.UndefinedStep{snippet: snippet}, state) do
    %{state | undefined_snippets: [snippet | state.undefined_snippets]}
  end

  defp on_event(%Events.TestRunFinished{}, state) do
    print(state, "\n\n")
    print_summary(state)
    state
  end

  defp on_event(_, state), do: state

  defp step_char(:passed), do: "."
  defp step_char(:failed), do: "F"
  defp step_char(:pending), do: "P"
  defp step_char(:undefined), do: "U"
  defp step_char(:skipped), do: "-"
  defp step_char(:ambiguous), do: "A"
  defp step_char(_), do: "?"

  defp print_summary(state) do
    results = Enum.reverse(state.results)
    passed = Enum.count(results, &(&1.status == :passed))
    failed = Enum.count(results, &(&1.status == :failed))
    pending = Enum.count(results, &(&1.status == :pending))
    undefined = Enum.count(results, &(&1.status == :undefined))

    msg =
      "#{length(results)} scenarios (#{passed} passed, #{failed} failed, #{pending} pending, #{undefined} undefined)"

    print(state, msg <> "\n")
  end

  defp colorize(%{color: true}, s, status), do: ANSI.colorize(s, status)
  defp colorize(_, s, _), do: s

  defp print(%{output: :stdio}, s), do: IO.write(s)
  defp print(%{output: pid}, s) when is_pid(pid), do: send(pid, {:formatter_output, s})
end
