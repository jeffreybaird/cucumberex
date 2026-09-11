defmodule Cucumberex.Formatter.Progress do
  @moduledoc "Dot-per-step progress formatter (like RSpec's progress formatter)."

  use Cucumberex.Formatter
  alias Cucumberex.Events
  alias Cucumberex.Formatter.{ANSI, Failure, Output}

  defstruct [
    :device,
    :color,
    :backtrace,
    results: [],
    failures: [],
    undefined_snippets: [],
    step_count: 0,
    col: 0
  ]

  @cols 70

  @impl GenServer
  def init(opts) do
    {:ok,
     %__MODULE__{
       device: Output.open(Keyword.get(opts, :output, :stdio)),
       color: Keyword.get(opts, :color, IO.ANSI.enabled?()),
       backtrace: Keyword.get(opts, :backtrace, false)
     }}
  end

  defp on_event(%Events.TestStepFinished{step: step, result: result}, state) do
    dot = step_char(result.status)
    colored = colorize(state, dot, result.status)
    print(state, colored)
    new_col = state.col + 1

    state = if result.status == :failed, do: record_failure(state, step, result), else: state

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
    print_failures(state)
    print_summary(state)
    state
  end

  defp on_event(_, state), do: state

  defp on_finish(state) do
    Output.close(state.device)
    state
  end

  defp record_failure(state, step, result) do
    %{state | failures: [{step, result} | state.failures]}
  end

  defp print_failures(%{failures: []}), do: :ok

  defp print_failures(state) do
    print(state, "Failures:\n\n")

    state.failures
    |> Enum.reverse()
    |> Enum.with_index(1)
    |> Enum.each(fn {{step, result}, i} ->
      header = colorize(state, "  #{i}) #{step.text}", :failed)

      block =
        colorize(
          state,
          Failure.describe(result, indent: "     ", backtrace: state.backtrace),
          :failed
        )

      print(state, header <> "\n" <> block <> "\n\n")
    end)
  end

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

  defp print(%{device: device}, s), do: Output.write(device, s)
end
