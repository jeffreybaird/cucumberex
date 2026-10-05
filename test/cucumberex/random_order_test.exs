defmodule Cucumberex.RandomOrderTest do
  @moduledoc """
  `--random [SEED]` must parse an optional seed without swallowing paths, and
  every random run must report a seed that reproduces its order.
  """

  use ExUnit.Case

  alias Cucumberex.Config.Loader

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
end
