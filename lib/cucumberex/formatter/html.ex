defmodule Cucumberex.Formatter.HTML do
  @moduledoc "HTML report formatter."

  use Cucumberex.Formatter
  alias Cucumberex.Events

  defstruct [
    :output_path,
    features: [],
    current_feature: nil,
    current_scenarios: [],
    current_scenario: nil,
    current_steps: []
  ]

  @impl GenServer
  def init(opts) do
    {:ok,
     %__MODULE__{
       output_path: Keyword.get(opts, :output, "cucumber_report.html")
     }}
  end

  defp on_event(%Events.FeatureLoaded{feature: feature, uri: uri}, state) do
    f = %{name: feature.name, uri: uri, scenarios: []}
    prev = flush_feature(state)
    %{prev | current_feature: f, current_scenarios: []}
  end

  defp on_event(%Events.TestCaseStarted{pickle: pickle}, state) do
    s = %{name: pickle.name, tags: pickle.tags, steps: [], status: :passed}
    %{state | current_scenario: s, current_steps: []}
  end

  defp on_event(%Events.TestStepFinished{step: step, result: result}, state) do
    entry = %{text: step.text, status: result.status, error: result.error}
    %{state | current_steps: state.current_steps ++ [entry]}
  end

  defp on_event(%Events.TestCaseFinished{result: result}, state) do
    scenario = %{state.current_scenario | steps: state.current_steps, status: result.status}
    %{state | current_scenarios: state.current_scenarios ++ [scenario], current_steps: []}
  end

  defp on_event(%Events.TestRunFinished{}, state) do
    final = flush_feature(state)
    html = build_html(final.features)
    File.write!(state.output_path, html)
    final
  end

  defp on_event(_, state), do: state

  defp flush_feature(%{current_feature: nil} = state), do: state

  defp flush_feature(state) do
    feature = %{state.current_feature | scenarios: state.current_scenarios}
    %{state | features: state.features ++ [feature], current_feature: nil, current_scenarios: []}
  end

  defp build_html(features) do
    scenarios_html = Enum.map_join(features, "\n", &feature_html/1)
    total = Enum.sum(Enum.map(features, fn f -> length(f.scenarios) end))

    passed =
      Enum.sum(
        Enum.map(features, fn f ->
          Enum.count(f.scenarios, &(&1.status == :passed))
        end)
      )

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>Cucumberex Report</title>
      <style>
        body { font-family: sans-serif; margin: 2rem; background: #f5f5f5; }
        h1 { color: #333; }
        .feature { background: white; border-radius: 6px; padding: 1rem; margin: 1rem 0; box-shadow: 0 1px 3px rgba(0,0,0,.1); }
        .feature h2 { margin: 0 0 0.5rem; color: #555; font-size: 1.1rem; }
        .scenario { margin: 0.5rem 0; padding: 0.5rem; border-left: 4px solid #ccc; }
        .scenario.passed { border-color: #27ae60; }
        .scenario.failed { border-color: #e74c3c; }
        .scenario.pending { border-color: #f39c12; }
        .scenario.undefined { border-color: #f39c12; }
        .scenario.skipped { border-color: #7f8c8d; }
        .step { font-size: 0.9rem; padding: 2px 0 2px 1rem; }
        .step.passed { color: #27ae60; }
        .step.failed { color: #e74c3c; }
        .step.pending { color: #f39c12; }
        .step.undefined { color: #f39c12; }
        .step.skipped { color: #7f8c8d; }
        .summary { font-size: 1.1rem; padding: 1rem; background: white; border-radius: 6px; }
        .error { font-size: 0.8rem; color: #e74c3c; background: #fde; padding: 4px; margin-top: 4px; }
      </style>
    </head>
    <body>
    <h1>Cucumberex Report</h1>
    <div class="summary">#{passed}/#{total} scenarios passed</div>
    #{scenarios_html}
    </body>
    </html>
    """
  end

  defp feature_html(feature) do
    scenarios = Enum.map_join(feature.scenarios, "\n", &scenario_html/1)

    """
    <div class="feature">
      <h2>#{h(feature.name)} <small>#{h(feature.uri)}</small></h2>
      #{scenarios}
    </div>
    """
  end

  defp scenario_html(scenario) do
    steps = Enum.map_join(scenario.steps, "\n", &step_html/1)
    tags = Enum.map_join(scenario.tags, " ", & &1.name)

    """
    <div class="scenario #{scenario.status}">
      <strong>#{h(scenario.name)}</strong>
      #{if tags != "", do: "<small>#{h(tags)}</small>", else: ""}
      #{steps}
    </div>
    """
  end

  defp step_html(step) do
    error =
      if step.error do
        ~s(<div class="error">#{h(format_error(step.error))}</div>)
      else
        ""
      end

    """
    <div class="step #{step.status}">#{h(step.text)}#{error}</div>
    """
  end

  defp h(nil), do: ""
  defp h(s), do: s |> to_string() |> html_escape()

  defp html_escape(s) do
    s
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp format_error(%{message: m}), do: m
  defp format_error(e), do: inspect(e)
end
