defmodule Cucumberex.Formatter.JSON do
  @moduledoc "JSON formatter — emits cucumber-compatible JSON report."

  use Cucumberex.Formatter
  alias Cucumberex.Events

  defstruct [:output_path, features: %{}, current_feature_uri: nil, step_results: []]

  @impl GenServer
  def init(opts) do
    {:ok,
     %__MODULE__{
       output_path: Keyword.get(opts, :output, "cucumber_report.json")
     }}
  end

  defp on_event(%Events.FeatureLoaded{uri: uri, feature: feature}, state) do
    entry = %{
      "uri" => uri,
      "id" => slugify(feature.name),
      "name" => feature.name,
      "description" => feature.description || "",
      "keyword" => "Feature",
      "elements" => []
    }

    %{state | features: Map.put(state.features, uri, entry), current_feature_uri: uri}
  end

  defp on_event(%Events.TestCaseStarted{pickle: pickle}, state) do
    %{state | step_results: [], current_feature_uri: pickle.uri}
  end

  defp on_event(%Events.TestStepFinished{step: step, result: result}, state) do
    step_entry = %{
      "name" => step.text,
      "keyword" => "Step",
      "result" => %{
        "status" => to_string(result.status),
        "duration" => (result.duration_ms || 0) * 1_000_000,
        "error_message" => format_error(result.error)
      }
    }

    %{state | step_results: state.step_results ++ [step_entry]}
  end

  defp on_event(%Events.TestCaseFinished{pickle: pickle, result: _result}, state) do
    element = %{
      "id" => slugify(pickle.name),
      "name" => pickle.name,
      "description" => "",
      "keyword" => "Scenario",
      "type" => "scenario",
      "tags" => Enum.map(pickle.tags, &%{"name" => &1.name}),
      "steps" => state.step_results
    }

    features =
      Map.update(state.features, pickle.uri, %{}, fn f ->
        Map.update(f, "elements", [], &(&1 ++ [element]))
      end)

    %{state | features: features, step_results: []}
  end

  defp on_event(%Events.TestRunFinished{}, state) do
    json = state.features |> Map.values() |> Jason.encode!(pretty: true)
    write_output(state.output_path, json)
    state
  end

  defp on_event(_, state), do: state

  defp write_output("-", json), do: IO.puts(json)
  defp write_output(path, json), do: File.write!(path, json)

  defp slugify(name), do: name |> String.downcase() |> String.replace(~r/\s+/, "-")

  defp format_error(nil), do: nil
  defp format_error(%{message: msg}), do: msg
  defp format_error(e), do: inspect(e)
end
