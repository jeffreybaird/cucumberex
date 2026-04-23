defmodule Cucumberex.Runner.StepRunner do
  @moduledoc "Execute a single pickle step."

  alias Cucumberex.{DataTable, DocString, DSL, Events, Result}
  alias Cucumberex.Events.Bus
  alias Cucumberex.StepDefinition.Matcher

  def run(step, world, config, bus) do
    text = step.text
    start = System.monotonic_time(:millisecond)

    broadcast(bus, %Events.TestStepStarted{step: step})

    {result, new_world} =
      case Matcher.match(text, config.step_registry, config.param_type_registry) do
        {:undefined, snippets} ->
          broadcast(bus, %Events.UndefinedStep{step: step, snippet: hd(snippets)})
          {Result.undefined(), world}

        {:ambiguous, matches} ->
          broadcast(bus, %Events.AmbiguousStep{step: step, matches: matches})
          {Result.ambiguous(matches), world}

        {:ok, step_def, args} ->
          extra_args = build_extra_args(step, args)
          run_step_def(step_def, world, extra_args, config, start)
      end

    broadcast(bus, %Events.TestStepFinished{step: step, result: result})
    {result, new_world}
  end

  defp run_step_def(step_def, world, args, _config, start) do
    case DSL.execute_step(step_def.fun, world, args) do
      {:ok, new_world} ->
        duration = System.monotonic_time(:millisecond) - start
        {Result.passed(duration), new_world}

      {:pending, new_world} ->
        {Result.pending(), new_world}

      {:error, e, new_world} ->
        duration = System.monotonic_time(:millisecond) - start
        {Result.failed(e, duration), new_world}
    end
  end

  defp build_extra_args(step, pattern_args) do
    arg_args = build_step_arg(step.argument)
    pattern_args ++ arg_args
  end

  defp build_step_arg(nil), do: []

  defp build_step_arg(%CucumberMessages.PickleStepArgument.PickleTable{} = table) do
    [DataTable.from_pickle_table(table)]
  end

  defp build_step_arg(%CucumberMessages.PickleStepArgument.PickleDocString{} = doc) do
    [DocString.from_pickle_doc_string(%{content: doc.content, media_type: doc.media_type || ""})]
  end

  defp build_step_arg(_), do: []

  defp broadcast(bus, event), do: Bus.broadcast(bus, event)
end
