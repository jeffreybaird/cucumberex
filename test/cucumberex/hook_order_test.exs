defmodule Cucumberex.HookOrderTest do
  @moduledoc """
  Hooks of one phase run in Cucumber's order: before hooks in the order they
  were defined, after hooks in reverse, so setup and teardown nest.
  """

  use ExUnit.Case

  @probe __MODULE__.Probe

  defmodule Steps do
    use Cucumberex.DSL

    given_("a hook order step", fn world ->
      Cucumberex.HookOrderTest.probe(:step)
      world
    end)
  end

  defmodule Hooks do
    use Cucumberex.Hooks.DSL

    before_all_(fn -> Cucumberex.HookOrderTest.probe(:before_all_1) end)
    before_all_(fn -> Cucumberex.HookOrderTest.probe(:before_all_2) end)
    after_all_(fn -> Cucumberex.HookOrderTest.probe(:after_all_1) end)
    after_all_(fn -> Cucumberex.HookOrderTest.probe(:after_all_2) end)

    before_("@hook_order", fn world -> Cucumberex.HookOrderTest.probe(:before_1) && world end)
    before_("@hook_order", fn world -> Cucumberex.HookOrderTest.probe(:before_2) && world end)
    after_("@hook_order", fn world -> Cucumberex.HookOrderTest.probe(:after_1) && world end)
    after_("@hook_order", fn world -> Cucumberex.HookOrderTest.probe(:after_2) && world end)

    before_step_(fn world -> Cucumberex.HookOrderTest.probe(:before_step_1) && world end)
    before_step_(fn world -> Cucumberex.HookOrderTest.probe(:before_step_2) && world end)
    after_step_(fn world -> Cucumberex.HookOrderTest.probe(:after_step_1) && world end)
    after_step_(fn world -> Cucumberex.HookOrderTest.probe(:after_step_2) && world end)
  end

  # Hooks without tags run for every test module's scenarios, so only report
  # while this module's test process is listening.
  def probe(event) do
    if pid = Process.whereis(@probe), do: send(pid, {:probe, event})
    true
  end

  setup_all do
    Cucumberex.DSL.load_module(Steps)
    Cucumberex.Hooks.DSL.load_module(Hooks)
    :ok
  end

  setup do
    Process.register(self(), @probe)
    :ok
  end

  test "before hooks run in definition order and after hooks in reverse" do
    %Cucumberex.Config{}
    |> Map.from_struct()
    |> Map.merge(%{
      paths: ["test/fixtures/features/hook_order/hook_order.feature"],
      formatters: [{Cucumberex.Test.EventRecorder, [to: self()]}]
    })
    |> Cucumberex.Runner.run()

    assert probes() == [
             :before_all_1,
             :before_all_2,
             :before_1,
             :before_2,
             :before_step_1,
             :before_step_2,
             :step,
             :after_step_2,
             :after_step_1,
             :after_2,
             :after_1,
             :after_all_2,
             :after_all_1
           ]
  end

  defp probes(acc \\ []) do
    receive do
      {:probe, event} -> probes([event | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
