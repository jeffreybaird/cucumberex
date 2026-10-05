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

    body = fn world -> run_body(pickle, tags, world, config, bus) end
    {_world, all_results} = wrap_in_around_hooks(body, tags, config, bus).(world)
    scenario_result = determine_scenario_result(all_results)

    broadcast(bus, %Events.TestCaseFinished{
      pickle: pickle,
      result: scenario_result,
      attempt: config[:attempt] || 0,
      will_be_retried: will_be_retried?(scenario_result, config[:retries_left] || 0)
    })

    scenario_result
  end

  @doc """
  Whether a scenario attempt that produced `result` is followed by another
  attempt, given how many retries remain.

  ## Examples

      iex> Cucumberex.Runner.ScenarioRunner.will_be_retried?(Cucumberex.Result.failed(%RuntimeError{}), 1)
      true

      iex> Cucumberex.Runner.ScenarioRunner.will_be_retried?(Cucumberex.Result.failed(%RuntimeError{}), 0)
      false

      iex> Cucumberex.Runner.ScenarioRunner.will_be_retried?(Cucumberex.Result.passed(), 1)
      false
  """
  def will_be_retried?(result, retries_left), do: Result.failed?(result) and retries_left > 0

  # Before hooks, steps, and after hooks: everything an around hook wraps.
  # Returns the final world and every result that decides the scenario's status.
  defp run_body(pickle, tags, world, config, bus) do
    {world, before_result} = run_hooks(:before, tags, world, config, bus)

    {world, step_results} =
      if Result.failed?(before_result) do
        skipped_results = Enum.map(pickle.steps, fn _ -> Result.skipped() end)
        {world, skipped_results}
      else
        run_steps(pickle.steps, tags, world, config, bus)
      end

    {world, after_result} = run_hooks(:after, tags, world, config, bus)

    {world, [before_result, after_result | step_results]}
  end

  # Nest the body inside every applicable around hook, first-defined outermost:
  # reducing over the reversed list wraps the last-defined hook innermost.
  defp wrap_in_around_hooks(body, tags, config, bus) do
    config.hook_registry
    |> HookRegistry.for_phase(:around)
    |> Enum.filter(&Hook.applies_to?(&1, tags))
    |> Enum.reverse()
    |> Enum.reduce(body, fn hook, inner -> fn world -> run_around(hook, inner, world, bus) end end)
  end

  # The hook's `run` returns only the world, so the wrapped results travel back
  # in a message tagged with a fresh ref. Sending to the runner process keeps
  # this working when the hook calls `run` from another process.
  defp run_around(hook, inner, world, bus) do
    ref = make_ref()
    runner = self()

    run = fn w ->
      {w, results} = inner.(w)
      send(runner, {ref, results})
      w
    end

    broadcast(bus, %Events.HookStarted{hook: hook, phase: :around})
    {hook_result, final_world} = call_around(hook, world, run)
    inner_results = receive_around_results(ref)
    hook_result = require_run_called(hook_result, inner_results, hook)
    broadcast(bus, %Events.HookFinished{hook: hook, phase: :around, result: hook_result})

    {final_world, [hook_result | inner_results || []]}
  end

  defp call_around(hook, world, run) do
    case hook.fun.(world, run) do
      new_world when is_map(new_world) -> {Result.passed(), new_world}
      _other -> {Result.passed(), world}
    end
  rescue
    e -> {Result.failed(e), world}
  end

  defp receive_around_results(ref) do
    receive do
      {^ref, results} -> results
    after
      0 -> nil
    end
  end

  defp require_run_called(%Result{status: :passed}, nil, hook) do
    Result.failed(%RuntimeError{
      message: "around hook at #{hook.location} did not call run, so the scenario never ran"
    })
  end

  defp require_run_called(hook_result, _inner_results, _hook), do: hook_result

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
      |> Hook.in_run_order(phase)

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
