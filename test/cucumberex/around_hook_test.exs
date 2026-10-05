defmodule Cucumberex.AroundHookTest do
  @moduledoc """
  `around_` hooks wrap a scenario: they receive the world and a `run`
  function that executes the scenario's before hooks, steps, and after hooks
  and returns the resulting world.
  """

  use ExUnit.Case

  alias Cucumberex.Events
  alias Cucumberex.Test.EventRecorder

  @probe __MODULE__.Probe

  defmodule Steps do
    use Cucumberex.DSL

    given_("an around step", fn world ->
      send(Cucumberex.AroundHookTest.Probe, {:probe, :step})
      world
    end)

    given_("an around step that checks the world", fn world ->
      send(Cucumberex.AroundHookTest.Probe, {:probe, {:step_saw, Map.get(world, :from_around)}})
      world
    end)

    given_("an around step that fails", fn _world ->
      send(Cucumberex.AroundHookTest.Probe, {:probe, :step})
      raise "step failed"
    end)
  end

  defmodule Hooks do
    use Cucumberex.Hooks.DSL

    around_("@around_order", fn world, run ->
      send(Cucumberex.AroundHookTest.Probe, {:probe, :around_start})
      world = run.(world)
      send(Cucumberex.AroundHookTest.Probe, {:probe, :around_end})
      world
    end)

    before_("@around_order", fn world ->
      send(Cucumberex.AroundHookTest.Probe, {:probe, :before})
      world
    end)

    after_("@around_order", fn world ->
      send(Cucumberex.AroundHookTest.Probe, {:probe, :after})
      world
    end)

    around_("@around_world", fn world, run -> run.(Map.put(world, :from_around, :yes)) end)

    around_("@around_no_run", fn world, _run -> world end)

    around_("@around_raise_before", fn _world, _run -> raise "around before" end)

    around_("@around_raise_after", fn world, run ->
      run.(world)
      raise "around after"
    end)

    around_("@around_nested", fn world, run ->
      send(Cucumberex.AroundHookTest.Probe, {:probe, :outer_start})
      world = run.(world)
      send(Cucumberex.AroundHookTest.Probe, {:probe, :outer_end})
      world
    end)

    around_("@around_nested", fn world, run ->
      send(Cucumberex.AroundHookTest.Probe, {:probe, :inner_start})
      world = run.(world)
      send(Cucumberex.AroundHookTest.Probe, {:probe, :inner_end})
      world
    end)

    around_("@around_failing_step", fn world, run ->
      world = run.(world)
      send(Cucumberex.AroundHookTest.Probe, {:probe, :around_end})
      world
    end)
  end

  @feature "test/fixtures/features/around/around.feature"

  setup_all do
    Cucumberex.DSL.load_module(Steps)
    Cucumberex.Hooks.DSL.load_module(Hooks)
    :ok
  end

  setup do
    Process.register(self(), @probe)
    :ok
  end

  test "wraps the before hooks, steps, and after hooks" do
    assert {:passed, _} = run_scenario("@around_order")

    assert probes() == [:around_start, :before, :step, :after, :around_end]
  end

  test "the world passed to run reaches the steps" do
    assert {:passed, _} = run_scenario("@around_world")

    assert probes() == [{:step_saw, :yes}]
  end

  test "a hook that never calls run fails the scenario without running it" do
    assert {:failed, error} = run_scenario("@around_no_run")

    assert Exception.message(error) =~ "did not call run"
    assert probes() == []
  end

  test "a hook that raises before calling run fails the scenario without running it" do
    assert {:failed, %RuntimeError{message: "around before"}} =
             run_scenario("@around_raise_before")

    assert probes() == []
  end

  test "a hook that raises after calling run fails the scenario" do
    assert {:failed, %RuntimeError{message: "around after"}} =
             run_scenario("@around_raise_after")

    assert probes() == [:step]
  end

  test "the first-registered hook is outermost" do
    assert {:passed, _} = run_scenario("@around_nested")

    assert probes() == [:outer_start, :inner_start, :step, :inner_end, :outer_end]
  end

  test "a failing step fails the scenario and control returns to the hook" do
    assert {:failed, %RuntimeError{message: "step failed"}} =
             run_scenario("@around_failing_step")

    assert probes() == [:step, :around_end]
  end

  test "hooks scoped by tag leave other scenarios alone" do
    assert {:passed, _} =
             run_scenario(
               "not @around_order and not @around_world and " <>
                 "not @around_no_run and not @around_raise_before and " <>
                 "not @around_raise_after and not @around_nested and " <>
                 "not @around_failing_step"
             )

    assert probes() == [:step]
  end

  test "the hook is reported with HookStarted and HookFinished events" do
    events = run_events("@around_raise_after")

    assert [%Events.HookStarted{phase: :around}] =
             for(%Events.HookStarted{phase: :around} = e <- events, do: e)

    assert [%Events.HookFinished{phase: :around, result: %{status: :failed}}] =
             for(%Events.HookFinished{phase: :around} = e <- events, do: e)
  end

  defp run_scenario(tags) do
    [%Events.TestCaseFinished{result: result}] =
      for %Events.TestCaseFinished{} = e <- run_events(tags), do: e

    {result.status, result.error}
  end

  defp run_events(tags) do
    %Cucumberex.Config{}
    |> Map.from_struct()
    |> Map.merge(%{paths: [@feature], tags: tags, formatters: [{EventRecorder, [to: self()]}]})
    |> Cucumberex.Runner.run()

    EventRecorder.flush()
  end

  defp probes(acc \\ []) do
    receive do
      {:probe, msg} -> probes([msg | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
