defmodule Cucumberex.LineFilterTest do
  @moduledoc """
  `mix cucumber path/to.feature:LINE` must run only the scenarios at LINE,
  from parsing the CLI argument through to which scenarios the runner starts.
  """

  use ExUnit.Case

  alias Cucumberex.Config.Loader
  alias Cucumberex.Events
  alias Cucumberex.Test.EventRecorder

  defmodule Steps do
    use Cucumberex.DSL

    given_("a line filter background step", fn world -> world end)
    given_("a line filter step", fn world -> world end)
  end

  @lines "test/fixtures/features/line_filter/lines.feature"
  @other "test/fixtures/features/line_filter/other.feature"

  setup_all do
    Cucumberex.DSL.load_module(Steps)
    :ok
  end

  describe "Loader.parse_cli/1 with path:LINE arguments" do
    test "splits a single line suffix into :lines and keeps the bare path" do
      assert Loader.parse_cli(["a.feature:12"]) ==
               %{paths: ["a.feature"], lines: [{"a.feature", 12}]}
    end

    test "splits repeated line suffixes" do
      assert Loader.parse_cli(["a.feature:12:30"]) ==
               %{paths: ["a.feature"], lines: [{"a.feature", 12}, {"a.feature", 30}]}
    end

    test "lists a file once when given several times with lines" do
      assert Loader.parse_cli(["a.feature:3", "a.feature:9"]) ==
               %{paths: ["a.feature"], lines: [{"a.feature", 3}, {"a.feature", 9}]}
    end

    test "leaves plain paths without a :lines entry" do
      assert Loader.parse_cli(["a.feature", "features/"]) ==
               %{paths: ["a.feature", "features/"]}
    end

    test "does not treat a non-numeric colon segment as a line" do
      assert Loader.parse_cli(["C:/features/a.feature"]) ==
               %{paths: ["C:/features/a.feature"]}
    end
  end

  describe "running with line filters" do
    test "a scenario's keyword line runs only that scenario" do
      assert started_names(["#{@lines}:8"]) == ["Second"]
    end

    test "a step line selects the scenario containing it" do
      assert started_names(["#{@lines}:6"]) == ["First"]
    end

    test "an Examples row line runs only that row" do
      assert started_names(["#{@lines}:18"]) == ["Outline 2"]
    end

    test "the outline's keyword line runs every row" do
      assert started_names(["#{@lines}:12"]) == ["Outline 1", "Outline 2"]
    end

    test "several lines run each selected scenario once" do
      assert started_names(["#{@lines}:5:17"]) == ["First", "Outline 1"]
    end

    test "a line that selects no scenario runs nothing from that file" do
      assert started_names(["#{@lines}:1"]) == []
    end

    test "a line filter on one file leaves other files unfiltered" do
      assert started_names(["#{@lines}:8", @other]) == ["Second", "Other"]
    end
  end

  defp started_names(args) do
    config =
      args
      |> Loader.parse_cli()
      |> then(&Map.merge(Map.from_struct(%Cucumberex.Config{}), &1))
      |> Map.put(:formatters, [{EventRecorder, [to: self()]}])

    Cucumberex.Runner.run(config)

    for %Events.TestCaseStarted{pickle: pickle} <- EventRecorder.flush(), do: pickle.name
  end
end
