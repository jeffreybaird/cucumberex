defmodule Cucumberex.Runner do
  @moduledoc "Top-level test runner: load features, filter, order, execute, report."

  alias Cucumberex.{Events, Result}
  alias Cucumberex.Events.Bus
  alias Cucumberex.Filter.{LineFilter, NameFilter, TagExpression}
  alias Cucumberex.Formatter.Pretty
  alias Cucumberex.Hooks.Registry, as: HookRegistry
  alias Cucumberex.Runner.ScenarioRunner

  def run(config) do
    {:ok, bus} = Bus.start_link()
    formatter_pids = setup_formatters(config, bus)

    broadcast(bus, %Events.TestRunStarted{timestamp: DateTime.utc_now()})

    run_before_all(config, bus)

    pickles = load_pickles(config, bus)
    filtered = filter_pickles(pickles, config)
    ordered = order_pickles(filtered, config)

    results =
      if config[:dry_run] do
        run_dry(ordered, config, bus)
      else
        run_pickles(ordered, config, bus)
      end

    run_after_all(config, bus)

    success = evaluate_success(results, config)

    broadcast(bus, %Events.TestRunFinished{
      timestamp: DateTime.utc_now(),
      success: success,
      results: results
    })

    Bus.drain(bus)
    flush_formatters(formatter_pids)

    exit_code = if success, do: 0, else: 1

    if config[:wip] do
      wip_exit(results)
    else
      exit_code
    end
  end

  defp load_pickles(config, bus) do
    paths = config[:paths] || ["features"]
    feature_files = expand_feature_files(paths, config)

    Enum.flat_map(feature_files, fn path ->
      envelopes = CucumberGherkin.parse_path(path, [])
      Enum.each(envelopes, &broadcast_feature_loaded(&1, path, bus))
      Enum.flat_map(envelopes, &extract_pickle/1)
    end)
  end

  defp broadcast_feature_loaded(%{message: {:gherkin_document, doc}}, path, bus)
       when not is_nil(doc.feature) do
    broadcast(bus, %Events.FeatureLoaded{uri: path, feature: doc.feature})
  end

  defp broadcast_feature_loaded(_envelope, _path, _bus), do: :ok

  defp extract_pickle(%{message: {:pickle, pickle}}), do: [pickle]
  defp extract_pickle(_envelope), do: []

  defp expand_feature_files(paths, config) do
    exclude = config[:exclude] || []

    paths
    |> Enum.flat_map(&wildcard_features/1)
    |> Enum.reject(&excluded?(&1, exclude))
  end

  defp wildcard_features(path) do
    if File.dir?(path) do
      Path.wildcard(Path.join(path, "**/*.feature"))
    else
      [path]
    end
  end

  defp excluded?(path, exclude_patterns) do
    Enum.any?(exclude_patterns, &matches_exclude?(path, &1))
  end

  defp matches_exclude?(path, %Regex{} = pattern), do: path =~ pattern

  defp matches_exclude?(path, pattern) when is_binary(pattern),
    do: String.contains?(path, pattern)

  defp filter_pickles(pickles, config) do
    tag_expr = config[:tags]
    name_pattern = config[:name]
    line_filters = config[:lines] || []

    Enum.filter(pickles, fn p ->
      tags = Enum.map(p.tags, & &1.name)

      TagExpression.evaluate(tag_expr, tags) and
        NameFilter.matches?(p.name, name_pattern) and
        LineFilter.matches?(p.uri, nil, line_filters)
    end)
  end

  defp order_pickles(pickles, config) do
    case config[:order] do
      :random ->
        seed = config[:random_seed] || :rand.uniform(9999)
        :rand.seed(:exsss, {seed, seed, seed})
        Enum.shuffle(pickles)

      :reverse ->
        Enum.reverse(pickles)

      _ ->
        pickles
    end
  end

  defp run_pickles(pickles, config, bus) do
    retry_count = config[:retry] || 0
    fail_fast = config[:fail_fast] || false

    Enum.reduce_while(pickles, [], fn pickle, acc ->
      result = run_with_retry(pickle, config, bus, retry_count)

      new_acc = [result | acc]

      if fail_fast and Result.failed?(result) do
        {:halt, new_acc}
      else
        {:cont, new_acc}
      end
    end)
    |> Enum.reverse()
  end

  defp run_with_retry(pickle, config, bus, retries_left) do
    result = ScenarioRunner.run(pickle, config, bus)

    if Result.failed?(result) and retries_left > 0 do
      run_with_retry(pickle, config, bus, retries_left - 1)
    else
      result
    end
  end

  defp run_dry(pickles, _config, bus) do
    Enum.map(pickles, fn pickle ->
      broadcast(bus, %Events.TestCaseStarted{pickle: pickle, attempt: 0})
      result = Result.skipped()
      broadcast(bus, %Events.TestCaseFinished{pickle: pickle, result: result})
      result
    end)
  end

  defp run_before_all(config, bus) do
    HookRegistry.for_phase(config.hook_registry, :before_all)
    |> Enum.each(fn hook ->
      broadcast(bus, %Events.HookStarted{hook: hook, phase: :before_all})
      result = execute_global_hook(hook)
      broadcast(bus, %Events.HookFinished{hook: hook, phase: :before_all, result: result})
    end)
  end

  defp run_after_all(config, bus) do
    HookRegistry.for_phase(config.hook_registry, :after_all)
    |> Enum.each(fn hook ->
      broadcast(bus, %Events.HookStarted{hook: hook, phase: :after_all})
      result = execute_global_hook(hook)
      broadcast(bus, %Events.HookFinished{hook: hook, phase: :after_all, result: result})
    end)
  end

  defp execute_global_hook(%{fun: fun}) do
    fun.()
    Result.passed()
  rescue
    e -> Result.failed(e)
  end

  defp evaluate_success(results, config) do
    not has_hard_failure?(results) and not violates_strict_mode?(results, config)
  end

  defp has_hard_failure?(results) do
    Enum.any?(results, &Result.failed?/1) or
      Enum.any?(results, &(&1.status == :ambiguous))
  end

  defp violates_strict_mode?(results, config) do
    has_undefined = Enum.any?(results, &(&1.status == :undefined))
    has_pending = Enum.any?(results, &(&1.status == :pending))

    (config[:strict_undefined] and has_undefined) or
      (config[:strict_pending] and has_pending) or
      (config[:strict] and (has_undefined or has_pending))
  end

  defp wip_exit(results) do
    if Enum.any?(results, &Result.passed?/1), do: 1, else: 0
  end

  defp setup_formatters(config, bus) do
    formatters = config[:formatters] || [{Pretty, []}]

    Enum.map(formatters, fn
      {mod, opts} ->
        {:ok, fmt} = mod.start_link(opts)
        Bus.subscribe(bus, fmt)
        fmt

      mod when is_atom(mod) ->
        {:ok, fmt} = mod.start_link([])
        Bus.subscribe(bus, fmt)
        fmt
    end)
  end

  # Synchronous call drains each formatter's mailbox before returning,
  # ensuring file writes in on_event(TestRunFinished) complete before exit.
  defp flush_formatters(formatter_pids) do
    Enum.each(formatter_pids, fn pid -> GenServer.call(pid, :finish) end)
  end

  defp broadcast(bus, event), do: Bus.broadcast(bus, event)
end
