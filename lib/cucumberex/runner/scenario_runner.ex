defmodule Cucumberex.Runner.ScenarioRunner do
  @moduledoc "Execute a single pickle (scenario/scenario outline row)."

  alias Cucumberex.{Events, Result, World}
  alias Cucumberex.Events.Bus
  alias Cucumberex.Hook
  alias Cucumberex.Hooks.Registry, as: HookRegistry
  alias Cucumberex.Runner.StepRunner

  def run(pickle, config, bus) do
    tags = Enum.map(pickle.tags, & &1.name)

    # Run Before hooks
    world = World.build(config.world_factory)
    world = World.set_scenario(world, pickle)

    broadcast(bus, %Events.TestCaseStarted{pickle: pickle, attempt: config[:attempt] || 0})

    {world, before_result} = run_hooks(:before, tags, world, config, bus)

    {world, step_results} =
      if Result.failed?(before_result) do
        skipped_results = Enum.map(pickle.steps, fn _ -> Result.skipped() end)
        {world, skipped_results}
      else
        run_steps(pickle.steps, tags, world, config, bus)
      end

    {_world, after_result} = run_hooks(:after, tags, world, config, bus)

    all_results = [before_result, after_result | step_results]
    scenario_result = determine_scenario_result(all_results)

    broadcast(bus, %Events.TestCaseFinished{pickle: pickle, result: scenario_result})
    scenario_result
  end

  defp run_steps(steps, tags, world, config, bus) do
    if config[:dry_run] do
      skipped = Enum.map(steps, fn _ -> Result.skipped() end)
      {world, skipped}
    else
      run_steps_sequentially(steps, tags, world, config, bus, [])
    end
  end

  defp run_steps_sequentially([], _tags, world, _config, _bus, acc) do
    {world, Enum.reverse(acc)}
  end

  defp run_steps_sequentially([step | rest], tags, world, config, bus, acc) do
    {world, _} = run_hooks(:before_step, tags, world, config, bus)

    prev_failed = Enum.any?(acc, &Result.failed?/1)

    {result, world} =
      if prev_failed do
        {Result.skipped(), world}
      else
        StepRunner.run(step, world, config, bus)
      end

    {world, _} = run_hooks(:after_step, tags, world, config, bus)

    halt =
      (result.status == :undefined and config[:strict_undefined]) or
        (result.status == :pending and config[:strict_pending])

    if halt do
      remaining_skipped = Enum.map(rest, fn _ -> Result.skipped() end)
      {world, Enum.reverse([result | acc]) ++ remaining_skipped}
    else
      run_steps_sequentially(rest, tags, world, config, bus, [result | acc])
    end
  end

  defp run_hooks(phase, tags, world, config, bus) do
    hooks =
      config.hook_registry
      |> HookRegistry.for_phase(phase)
      |> Enum.filter(&Hook.applies_to?(&1, tags))

    Enum.reduce_while(hooks, {world, Result.passed()}, fn hook, {w, _} ->
      broadcast(bus, %Events.HookStarted{hook: hook, phase: phase})
      {result, new_w} = execute_hook(hook, w)
      broadcast(bus, %Events.HookFinished{hook: hook, phase: phase, result: result})

      if Result.failed?(result) do
        {:halt, {new_w, result}}
      else
        {:cont, {new_w, result}}
      end
    end)
  end

  defp execute_hook(%{fun: fun, phase: phase}, world) do
    case phase do
      p when p in [:before, :after, :before_step, :after_step] ->
        result = fun.(world)
        new_world = if is_map(result), do: result, else: world
        {Result.passed(), new_world}

      :around ->
        {Result.passed(), world}

      p when p in [:before_all, :after_all, :install_plugin] ->
        fun.()
        {Result.passed(), world}
    end
  rescue
    e -> {Result.failed(e), world}
  end

  defp determine_scenario_result(results) do
    cond do
      Enum.any?(results, &(&1.status == :failed)) -> Enum.find(results, &Result.failed?/1)
      Enum.any?(results, &(&1.status == :ambiguous)) -> Result.ambiguous([])
      Enum.any?(results, &(&1.status == :undefined)) -> Result.undefined()
      Enum.any?(results, &(&1.status == :pending)) -> Result.pending()
      true -> Result.passed()
    end
  end

  defp broadcast(bus, event), do: Bus.broadcast(bus, event)
end
