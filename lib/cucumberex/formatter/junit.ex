defmodule Cucumberex.Formatter.JUnit do
  @moduledoc "JUnit XML formatter for CI integration."

  use Cucumberex.Formatter
  alias Cucumberex.Events

  defstruct [:output_path, suites: [], current_suite: nil, current_tests: [], step_results: []]

  @impl GenServer
  def init(opts) do
    {:ok,
     %__MODULE__{
       output_path: Keyword.get(opts, :output, "cucumber_junit.xml")
     }}
  end

  defp on_event(%Events.FeatureLoaded{uri: uri, feature: feature}, state) do
    suite = %{name: feature.name, uri: uri, tests: []}
    %{state | current_suite: suite, current_tests: []}
  end

  defp on_event(%Events.TestCaseStarted{}, state) do
    %{state | step_results: []}
  end

  defp on_event(%Events.TestStepFinished{result: result}, state) do
    %{state | step_results: [result | state.step_results]}
  end

  defp on_event(%Events.TestCaseFinished{pickle: pickle, result: result}, state) do
    testcase = build_testcase(pickle, result, Enum.reverse(state.step_results))
    %{state | current_tests: state.current_tests ++ [testcase], step_results: []}
  end

  defp on_event(%Events.TestRunFinished{}, state) do
    suites =
      if state.current_suite do
        suite = %{state.current_suite | tests: state.current_tests}
        state.suites ++ [suite]
      else
        state.suites
      end

    xml = build_xml(suites)
    write_output(state.output_path, xml)
    state
  end

  defp on_event(_, state), do: state

  defp build_testcase(pickle, result, _step_results) do
    failure =
      case result.status do
        :failed ->
          msg = format_error(result.error)

          ~s(<failure message="#{escape_xml(msg)}" type="AssertionError">#{escape_xml(msg)}</failure>)

        :pending ->
          ~s(<skipped message="pending"/>)

        :undefined ->
          ~s(<skipped message="undefined"/>)

        :skipped ->
          ~s(<skipped/>)

        _ ->
          ""
      end

    duration = (result.duration_ms || 0) / 1000

    """
    <testcase name="#{escape_xml(pickle.name)}" classname="#{escape_xml(pickle.uri)}" time="#{duration}">
      #{failure}
    </testcase>
    """
  end

  defp build_xml(suites) do
    total = Enum.sum(Enum.map(suites, fn s -> length(s.tests) end))

    failures =
      Enum.sum(
        Enum.map(suites, fn s ->
          Enum.count(s.tests, &String.contains?(&1, "<failure"))
        end)
      )

    suite_xml =
      Enum.map_join(suites, "\n", fn suite ->
        """
        <testsuite name="#{escape_xml(suite.name)}" tests="#{length(suite.tests)}" failures="#{failures}">
          #{Enum.join(suite.tests, "\n  ")}
        </testsuite>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <testsuites tests="#{total}" failures="#{failures}">
    #{suite_xml}
    </testsuites>
    """
  end

  defp write_output("-", xml), do: IO.puts(xml)
  defp write_output(path, xml), do: File.write!(path, xml)

  defp escape_xml(nil), do: ""

  defp escape_xml(s) do
    s
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp format_error(nil), do: "failed"
  defp format_error(%{message: m}), do: m
  defp format_error(e), do: inspect(e)
end
