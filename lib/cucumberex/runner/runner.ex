defmodule Cucumberex.Runner do
  @moduledoc "Top-level test runner: load features, filter, order, execute, report."

  alias Cucumberex.{Events, Hook, Result}
  alias Cucumberex.Events.Bus
  alias Cucumberex.Filter.{LineFilter, NameFilter, SourceLines, TagExpression}
  alias Cucumberex.Formatter.Pretty
  alias Cucumberex.Hooks.Registry, as: HookRegistry
  alias Cucumberex.Runner.ScenarioRunner

  def run(config) do
    config = ensure_random_seed(config)
    {:ok, bus} = Bus.start_link()
    formatter_pids = setup_formatters(config, bus)

    broadcast(bus, %Events.TestRunStarted{
      timestamp: DateTime.utc_now(),
      random_seed: config[:random_seed]
    })

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

  # Returns `{pickle, source_lines}` pairs; the lines feed `file:LINE` filters.
  defp load_pickles(config, bus) do
    paths = config[:paths] || ["features"]
    feature_files = expand_feature_files(paths, config)

    Enum.flat_map(feature_files, fn path ->
      envelopes = CucumberGherkin.parse_path(path, [])
      Enum.each(envelopes, &broadcast_feature_loaded(&1, path, bus))
      line_index = envelopes |> Enum.map(&index_source_lines/1) |> Enum.reduce(%{}, &Map.merge/2)

      for pickle <- Enum.flat_map(envelopes, &extract_pickle/1),
          do: {pickle, SourceLines.pickle_lines(pickle, line_index)}
    end)
  end

  defp index_source_lines(%{message: {:gherkin_document, doc}}), do: SourceLines.index(doc)
  defp index_source_lines(_envelope), do: %{}

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

    for {p, source_lines} <- pickles,
        tags = Enum.map(p.tags, & &1.name),
        TagExpression.evaluate(tag_expr, tags),
        NameFilter.matches?(p.name, name_pattern),
        LineFilter.selects?(p.uri, source_lines, line_filters),
        do: p
  end

  # A random run always has a seed, chosen up front, so formatters can report
  # it and the same order can be replayed with `--random SEED`.
  defp ensure_random_seed(%{order: :random} = config) do
    if config[:random_seed],
      do: config,
      else: Map.put(config, :random_seed, :rand.uniform(99_999))
  end

  defp ensure_random_seed(config), do: config

  defp order_pickles(pickles, config) do
    case config[:order] do
      :random ->
        shuffle_with_seed(pickles, config[:random_seed])

      :reverse ->
        Enum.reverse(pickles)

      _ ->
        pickles
    end
  end

  # Uses an explicit PRNG state so the caller's process-global :rand state is
  # left untouched, and the order depends only on the seed.
  defp shuffle_with_seed(pickles, seed) do
    {keyed, _state} =
      Enum.map_reduce(pickles, :rand.seed_s(:exsss, seed), fn pickle, state ->
        {key, state} = :rand.uniform_s(state)
        {{key, pickle}, state}
      end)

    keyed |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1))
  end

  defp run_pickles(pickles, config, bus) do
    retry_count = config[:retry] || 0
    fail_fast = config[:fail_fast] || false

    Enum.reduce_while(pickles, [], fn pickle, acc ->
      result = run_with_retry(pickle, config, bus, 0, retry_count)

      new_acc = [result | acc]

      if fail_fast and Result.failed?(result) do
        {:halt, new_acc}
      else
        {:cont, new_acc}
      end
    end)
    |> Enum.reverse()
  end

  defp run_with_retry(pickle, config, bus, attempt, retries_left) do
    attempt_config = Map.merge(config, %{attempt: attempt, retries_left: retries_left})
    result = ScenarioRunner.run(pickle, attempt_config, bus)

    if ScenarioRunner.will_be_retried?(result, retries_left) do
      run_with_retry(pickle, config, bus, attempt + 1, retries_left - 1)
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
    |> Hook.in_run_order(:before_all)
    |> Enum.each(fn hook ->
      broadcast(bus, %Events.HookStarted{hook: hook, phase: :before_all})
      result = execute_global_hook(hook)
      broadcast(bus, %Events.HookFinished{hook: hook, phase: :before_all, result: result})
    end)
  end

  defp run_after_all(config, bus) do
    HookRegistry.for_phase(config.hook_registry, :after_all)
    |> Hook.in_run_order(:after_all)
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
      {mod, opts} -> start_formatter(mod, opts, config, bus)
      mod when is_atom(mod) -> start_formatter(mod, [], config, bus)
    end)
  end

  defp start_formatter(mod, opts, config, bus) do
    {:ok, fmt} = mod.start_link(formatter_opts(opts, config))
    Bus.subscribe(bus, fmt)
    fmt
  end

  # Thread run-wide `--out` and `--backtrace` into each formatter. `--out` only
  # overrides when it names a real destination; without it, file formatters keep
  # their own default paths. Explicit per-formatter opts always win.
  defp formatter_opts(opts, config) do
    opts
    |> maybe_put_output(config[:output])
    |> Keyword.put_new(:backtrace, config[:backtrace] || false)
  end

  defp maybe_put_output(opts, output) when is_binary(output),
    do: Keyword.put_new(opts, :output, output)

  defp maybe_put_output(opts, _output), do: opts

  # Synchronous call drains each formatter's mailbox before returning,
  # ensuring file writes in on_event(TestRunFinished) complete before exit.
  defp flush_formatters(formatter_pids) do
    Enum.each(formatter_pids, fn pid -> GenServer.call(pid, :finish) end)
  end

  defp broadcast(bus, event), do: Bus.broadcast(bus, event)
end
