defmodule Cucumberex.StepDefinition.Matcher do
  @moduledoc "Match a step text against registered step definitions."

  alias Cucumberex.StepDefinition
  alias Cucumberex.StepDefinition.{Expression, Registry, Snippet}

  @type match_result ::
          {:ok, StepDefinition.t(), list()}
          | {:undefined, list()}
          | {:ambiguous, [StepDefinition.t()]}

  def match(step_text, registry \\ Registry, pt_registry \\ Cucumberex.ParameterType.Registry) do
    all_steps = Registry.all(registry)

    matches =
      Enum.flat_map(all_steps, fn step_def ->
        case try_match(step_def, step_text, pt_registry) do
          nil -> []
          args -> [{step_def, args}]
        end
      end)

    case matches do
      [] -> {:undefined, generate_snippets(step_text, all_steps)}
      [{step_def, args}] -> {:ok, step_def, args}
      multiple -> {:ambiguous, Enum.map(multiple, fn {sd, _} -> sd end)}
    end
  end

  defp try_match(%StepDefinition{pattern: pattern}, text, pt_registry) when is_binary(pattern) do
    case Expression.match(pattern, text, pt_registry) do
      nil -> nil
      %{args: args} -> args
    end
  end

  defp try_match(%StepDefinition{pattern: %Regex{} = r}, text, _pt_registry) do
    case Regex.run(r, text) do
      nil -> nil
      [_full | captures] -> captures
    end
  end

  defp generate_snippets(step_text, _existing) do
    [Snippet.generate(step_text)]
  end
end
