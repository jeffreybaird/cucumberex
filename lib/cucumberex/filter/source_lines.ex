defmodule Cucumberex.Filter.SourceLines do
  @moduledoc """
  Map pickles back to the feature-file lines they came from, so `file:LINE`
  filters can select scenarios.

  A pickle covers the line of its `Scenario`/`Scenario Outline` keyword, the
  line of every step it runs (Background steps included), and, for an outline
  row, the line of its `Examples` row.
  """

  @doc """
  Index every scenario, step, and Examples row in a Gherkin document by its
  AST node id, mapping each id to its source line.

  ## Examples

      iex> doc = %{feature: %{children: [
      ...>   %{value: {:scenario, %{id: "s1", location: %{line: 3},
      ...>     steps: [%{id: "st1", location: %{line: 4}}], examples: []}}}
      ...> ]}}
      iex> Cucumberex.Filter.SourceLines.index(doc)
      %{"s1" => 3, "st1" => 4}

      iex> Cucumberex.Filter.SourceLines.index(%{feature: nil})
      %{}
  """
  def index(%{feature: nil}), do: %{}
  def index(%{feature: feature}), do: index_children(feature.children, %{})

  @doc """
  The source lines a pickle covers, given an index built by `index/1`.

  ## Examples

      iex> index = %{"s1" => 3, "st1" => 4, "row1" => 9}
      iex> pickle = %{ast_node_ids: ["s1", "row1"], steps: [%{ast_node_ids: ["st1", "row1"]}]}
      iex> Cucumberex.Filter.SourceLines.pickle_lines(pickle, index)
      [3, 4, 9]
  """
  def pickle_lines(pickle, index) do
    step_ids = Enum.flat_map(pickle.steps, & &1.ast_node_ids)

    (pickle.ast_node_ids ++ step_ids)
    |> Enum.map(&Map.get(index, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp index_children(children, acc) do
    Enum.reduce(children, acc, fn %{value: value}, acc -> index_child(value, acc) end)
  end

  defp index_child({:background, background}, acc), do: index_steps(background.steps, acc)
  defp index_child({:rule, rule}, acc), do: index_children(rule.children, acc)

  defp index_child({:scenario, scenario}, acc) do
    acc
    |> Map.put(scenario.id, scenario.location.line)
    |> then(&index_steps(scenario.steps, &1))
    |> then(&index_example_rows(scenario.examples, &1))
  end

  defp index_child(_other, acc), do: acc

  defp index_steps(steps, acc) do
    Enum.reduce(steps, acc, &Map.put(&2, &1.id, &1.location.line))
  end

  defp index_example_rows(examples, acc) do
    examples
    |> Enum.flat_map(& &1.table_body)
    |> Enum.reduce(acc, &Map.put(&2, &1.id, &1.location.line))
  end
end
