defmodule Cucumberex.Formatter.Rerun do
  @moduledoc """
  Rerun formatter: writes failed scenario locations to a file.
  Use with `mix cucumber @rerun.txt` to re-run only failures.
  """

  use Cucumberex.Formatter
  alias Cucumberex.Events

  defstruct [:output_path, failed: []]

  @impl GenServer
  def init(opts) do
    {:ok,
     %__MODULE__{
       output_path: Keyword.get(opts, :output, "rerun.txt")
     }}
  end

  defp on_event(%Events.TestCaseFinished{pickle: pickle, result: result}, state) do
    case result.status do
      :failed -> %{state | failed: [pickle.uri | state.failed]}
      _ -> state
    end
  end

  defp on_event(%Events.TestRunFinished{}, state) do
    if state.failed != [] do
      content = state.failed |> Enum.reverse() |> Enum.uniq() |> Enum.join("\n")
      File.write!(state.output_path, content <> "\n")
    end

    state
  end

  defp on_event(_, state), do: state
end
