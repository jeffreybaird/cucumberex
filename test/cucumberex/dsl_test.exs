defmodule Cucumberex.DSLTest do
  use ExUnit.Case, async: true

  defmodule TestSteps do
    use Cucumberex.DSL

    given_("I have {int} items", fn world, count ->
      Map.put(world, :count, count)
    end)

    when_("I add {int} items", fn world, n ->
      Map.update(world, :count, n, &(&1 + n))
    end)

    then_("I should have {int} items", fn world, expected ->
      unless world.count == expected do
        raise "Expected #{expected} items but got #{world.count}"
      end

      world
    end)

    step("a pending step", fn _world -> pending() end)

    step(~r/regex step (\w+)/, fn world, arg ->
      Map.put(world, :regex_arg, arg)
    end)
  end

  test "step definitions are collected" do
    steps = TestSteps.__cucumberex_steps__()
    assert length(steps) == 5
  end

  test "step tuple has correct structure" do
    steps = TestSteps.__cucumberex_steps__()
    {pattern, keyword, location, fun_name} = hd(steps)
    assert is_binary(pattern)
    assert keyword == :given
    assert is_binary(location)
    assert is_atom(fun_name)
  end

  test "step function executes and updates world" do
    {_pattern, _kw, _loc, fun_name} =
      TestSteps.__cucumberex_steps__()
      |> Enum.find(fn {p, _, _, _} ->
        is_binary(p) and String.contains?(p, "have {int} items")
      end)

    world = %{}
    {:ok, new_world} = Cucumberex.DSL.execute_step({TestSteps, fun_name}, world, [5])
    assert new_world.count == 5
  end

  test "pending returns {:pending, world}" do
    {_pattern, _kw, _loc, fun_name} =
      TestSteps.__cucumberex_steps__()
      |> Enum.find(fn {p, _, _, _} -> p == "a pending step" end)

    world = %{}
    result = Cucumberex.DSL.execute_step({TestSteps, fun_name}, world, [])
    assert {:pending, _} = result
  end

  test "regex step is deserialized correctly" do
    steps = TestSteps.__cucumberex_steps__()

    {pattern, _, _, _} =
      Enum.find(steps, fn {p, _, _, _} ->
        match?({:regex, _, _}, p)
      end)

    assert {:regex, "regex step (\\w+)", ""} = pattern
  end
end
