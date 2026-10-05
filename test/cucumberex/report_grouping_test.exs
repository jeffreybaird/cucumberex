defmodule Cucumberex.ReportGroupingTest do
  @moduledoc """
  Reports that group scenarios by feature must put each scenario under the
  feature file it came from, even though every feature is loaded before any
  scenario runs.
  """

  use ExUnit.Case

  alias Cucumberex.Formatter.HTML

  defmodule Steps do
    use Cucumberex.DSL

    given_("a grouping step that passes", fn world -> world end)
    given_("a grouping step that fails", fn _world -> raise "grouping failure" end)
  end

  @features [
    "test/fixtures/features/grouping/a.feature",
    "test/fixtures/features/grouping/b.feature"
  ]

  setup_all do
    Cucumberex.DSL.load_module(Steps)
    :ok
  end

  describe "html" do
    test "lists each scenario under its own feature" do
      html = report(HTML)

      assert html_features(html) == [
               {"Feature A", ["A1 passes", "A2 fails"]},
               {"Feature B", ["B1 passes"]}
             ]

      assert html =~ "2/3 scenarios passed"
    end
  end

  defp report(formatter) do
    path = Path.join(System.tmp_dir!(), "cuc_grouping_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm(path) end)

    %Cucumberex.Config{}
    |> Map.from_struct()
    |> Map.merge(%{paths: @features, formatters: [{formatter, [output: path]}]})
    |> Cucumberex.Runner.run()

    File.read!(path)
  end

  defp html_features(html) do
    html
    |> String.split(~s(<div class="feature">))
    |> tl()
    |> Enum.map(fn block ->
      [name] = Regex.run(~r/<h2>(.*?) <small>/, block, capture: :all_but_first)

      scenarios =
        for [s] <- Regex.scan(~r/<strong>(.*?)<\/strong>/, block, capture: :all_but_first), do: s

      {name, scenarios}
    end)
  end
end
