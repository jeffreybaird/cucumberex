defmodule Cucumberex.Formatter.Pretty do
  @moduledoc "Human-friendly colored terminal output."

  use Cucumberex.Formatter
  alias Cucumberex.Events
  alias Cucumberex.Formatter.ANSI

  defstruct [
    :output,
    :color,
    :snippets,
    current_feature: nil,
    results: [],
    undefined_snippets: [],
    start_time: nil
  ]

  @impl GenServer
  def init(opts) do
    output = Keyword.get(opts, :output, :stdio)
    color = Keyword.get(opts, :color, IO.ANSI.enabled?())
    {:ok, %__MODULE__{output: output, color: color, snippets: []}}
  end

  defp on_event(%Events.TestRunStarted{}, state) do
    %{state | start_time: System.monotonic_time(:millisecond)}
  end

  defp on_event(%Events.FeatureLoaded{uri: uri, feature: feature}, state) do
    puts(state, "\n#{ANSI.bold(feature.name)} (#{uri})")

    if feature.description && feature.description != "" do
      puts(state, "  #{String.trim(feature.description)}")
    end

    %{state | current_feature: feature}
  end

  defp on_event(%Events.TestCaseStarted{pickle: pickle}, state) do
    tags = format_tags(pickle.tags)
    if tags != "", do: puts(state, "  #{ANSI.cyan(tags)}")
    puts(state, "  #{ANSI.bold(pickle.name)}")
    state
  end

  defp on_event(%Events.TestStepFinished{step: step, result: result}, state) do
    text = "    #{format_keyword(step)}#{step.text}"
    colored = colorize(state, text, result.status)
    puts(state, colored)

    case result.status do
      :failed ->
        puts(state, colorize(state, "      #{format_error(result.error)}", :failed))

      :undefined ->
        :ok

      _ ->
        :ok
    end

    state
  end

  defp on_event(%Events.TestCaseFinished{result: result}, state) do
    %{state | results: [result | state.results]}
  end

  defp on_event(%Events.UndefinedStep{snippet: snippet}, state) do
    %{state | undefined_snippets: [snippet | state.undefined_snippets]}
  end

  defp on_event(%Events.TestRunFinished{}, state) do
    duration = System.monotonic_time(:millisecond) - (state.start_time || 0)
    puts(state, "")
    print_summary(state)
    puts(state, "\nFinished in #{format_duration(duration)}")

    unless state.undefined_snippets == [] do
      puts(
        state,
        "\nYou can implement step definitions for undefined steps with these snippets:\n"
      )

      state.undefined_snippets
      |> Enum.uniq()
      |> Enum.each(fn s -> puts(state, ANSI.yellow(s)) end)
    end

    state
  end

  defp on_event(_, state), do: state

  defp print_summary(state) do
    results = Enum.reverse(state.results)
    total = length(results)
    passed = Enum.count(results, &(&1.status == :passed))
    failed = Enum.count(results, &(&1.status == :failed))
    pending = Enum.count(results, &(&1.status == :pending))
    undefined = Enum.count(results, &(&1.status == :undefined))
    skipped = Enum.count(results, &(&1.status == :skipped))

    parts =
      [
        "#{total} scenario#{plural(total)}",
        if(passed > 0, do: colorize(state, "#{passed} passed", :passed), else: nil),
        if(failed > 0, do: colorize(state, "#{failed} failed", :failed), else: nil),
        if(pending > 0, do: colorize(state, "#{pending} pending", :pending), else: nil),
        if(undefined > 0, do: colorize(state, "#{undefined} undefined", :undefined), else: nil),
        if(skipped > 0, do: colorize(state, "#{skipped} skipped", :skipped), else: nil)
      ]
      |> Enum.reject(&is_nil/1)

    puts(state, Enum.join(parts, ", "))
  end

  defp format_tags([]), do: ""
  defp format_tags(tags), do: Enum.map_join(tags, " ", & &1.name)

  defp format_keyword(%{ast_node_ids: _}), do: ""

  defp format_error(nil), do: "(no error)"
  defp format_error(%{message: msg}), do: msg
  defp format_error(e), do: inspect(e)

  defp colorize(%{color: true}, s, status), do: ANSI.colorize(s, status)
  defp colorize(_, s, _), do: s

  defp puts(%{output: :stdio}, s), do: IO.puts(s)

  defp puts(%{output: {:file, path}}, s) do
    File.write!(path, s <> "\n", [:append])
  end

  defp puts(%{output: pid}, s) when is_pid(pid), do: send(pid, {:formatter_output, s})

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"

  defp format_duration(ms) do
    secs = ms / 1000
    :io_lib.format("~.3fs", [secs]) |> to_string()
  end

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
