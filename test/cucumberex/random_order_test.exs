defmodule Cucumberex.RandomOrderTest do
  @moduledoc """
  `--random [SEED]` must parse an optional seed without swallowing paths, and
  every random run must report a seed that reproduces its order.
  """

  use ExUnit.Case

  alias Cucumberex.Config.Loader
  alias Cucumberex.Events
  alias Cucumberex.Formatter.{Pretty, Progress}
  alias Cucumberex.Test.EventRecorder

  defmodule Steps do
    use Cucumberex.DSL

    given_("a random order step", fn world -> world end)
  end

  @feature "test/fixtures/features/random_order/many.feature"
  @defined_order Enum.map(1..8, &"S#{&1}")

  setup_all do
    Cucumberex.DSL.load_module(Steps)
    :ok
  end

  describe "Loader.parse_cli/1 with --random" do
    test "takes a following integer as the seed" do
      assert Loader.parse_cli(["--random", "42"]) == %{order: :random, random_seed: 42}
    end

    test "treats a following path as a path, not a seed" do
      assert Loader.parse_cli(["--random", "features/"]) ==
               %{order: :random, paths: ["features/"]}
    end

    test "treats a following flag as a flag, not a seed" do
      assert Loader.parse_cli(["--random", "--dry-run"]) == %{order: :random, dry_run: true}
    end

    test "works as the last argument" do
      assert Loader.parse_cli(["--random"]) == %{order: :random}
    end
  end

  describe "random order seed" do
    test "an unseeded random run reports the seed it used" do
      {seed, _order} = run_recorded(order: :random)

      assert is_integer(seed)
    end

    test "rerunning with the reported seed reproduces the order" do
      {seed, order} = run_recorded(order: :random)

      assert run_recorded(order: :random, random_seed: seed) == {seed, order}
    end

    test "the same explicit seed gives the same order every time" do
      {42, order} = run_recorded(order: :random, random_seed: 42)

      assert run_recorded(order: :random, random_seed: 42) == {42, order}
      assert Enum.sort(order) == @defined_order
    end

    test "different seeds can give different orders" do
      orders = for seed <- 1..10, do: run_recorded(order: :random, random_seed: seed) |> elem(1)

      assert length(Enum.uniq(orders)) > 1
    end

    test "a defined-order run reports no seed" do
      assert run_recorded(order: :defined) == {nil, @defined_order}
    end

    test "shuffling leaves the caller's random state untouched" do
      :rand.seed(:exsss, 7)
      expected = :rand.uniform(1_000_000)

      :rand.seed(:exsss, 7)
      run_recorded(order: :random, random_seed: 42)

      assert :rand.uniform(1_000_000) == expected
    end
  end

  describe "seed output" do
    test "pretty prints the seed before the scenarios and after the summary" do
      output = run_output(Pretty, order: :random, random_seed: 42)

      assert [_before, _between, _after] = String.split(output, "Randomized with seed 42")
      assert output =~ ~r/\ARandomized with seed 42\n/
      assert output =~ ~r/Randomized with seed 42\n\z/
    end

    test "progress prints the seed before the scenarios and after the summary" do
      output = run_output(Progress, order: :random, random_seed: 42)

      assert output =~ ~r/\ARandomized with seed 42\n/
      assert output =~ ~r/Randomized with seed 42\n\z/
    end

    test "nothing about seeds is printed for a defined-order run" do
      refute run_output(Pretty, order: :defined) =~ "Randomized"
      refute run_output(Progress, order: :defined) =~ "Randomized"
    end
  end

  defp config(extra) do
    %Cucumberex.Config{}
    |> Map.from_struct()
    |> Map.merge(%{paths: [@feature], color: false})
    |> Map.merge(Map.new(extra))
  end

  defp run_recorded(extra) do
    Cucumberex.Runner.run(config([{:formatters, [{EventRecorder, [to: self()]}]} | extra]))
    events = EventRecorder.flush()

    [%Events.TestRunStarted{random_seed: seed}] =
      for %Events.TestRunStarted{} = e <- events, do: e

    {seed, for(%Events.TestCaseStarted{pickle: p} <- events, do: p.name)}
  end

  defp run_output(formatter, extra) do
    Cucumberex.Runner.run(config([{:formatters, [{formatter, [output: self()]}]} | extra]))
    collect_output()
  end

  defp collect_output(acc \\ []) do
    receive do
      {:formatter_output, s} -> collect_output([s | acc])
    after
      0 -> acc |> Enum.reverse() |> IO.iodata_to_binary()
    end
  end
end
