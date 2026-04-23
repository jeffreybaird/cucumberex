defmodule Cucumberex do
  @moduledoc """
  Full-featured Cucumber BDD framework for Elixir.

  ## Quick Start

  Add to mix.exs:
      {:cucumberex, "~> 0.1"}

  Initialize project structure:
      mix cucumber --init

  Write a feature file:
      # features/belly.feature
      Feature: Belly
        Scenario: Eating cukes
          Given I have 5 cukes in my belly
          When I eat 3 cukes
          Then I should have 2 cukes

  Write step definitions:
      defmodule BellySteps do
        use Cucumberex.DSL

        given_ "I have {int} cukes in my belly", fn world, count ->
          Map.put(world, :cukes, count)
        end

        when_ "I eat {int} cukes", fn world, count ->
          Map.update!(world, :cukes, &(&1 - count))
        end

        then_ "I should have {int} cukes", fn world, expected ->
          unless world.cukes == expected do
            raise "Expected \#{expected} but got \#{world.cukes}"
          end
          world
        end
      end

  Run:
      mix cucumber

  ## Features

  - Full Gherkin support: Feature, Rule, Scenario, Background, Scenario Outline
  - Cucumber Expressions and Regex step patterns
  - Data Tables and Doc Strings
  - Before/After/Around/BeforeStep/AfterStep/BeforeAll/AfterAll hooks
  - Tag expressions with AND/OR/NOT
  - Formatters: Pretty, Progress, JSON, HTML, JUnit, Rerun
  - Configuration via cucumber.yml profiles
  - Dry run, fail-fast, strict, WIP modes
  - Retry failed scenarios
  - Custom parameter types
  - 70+ languages via cucumber_gherkin
  """

  @doc "Run cucumber with the given options. Returns exit code."
  defdelegate run(config), to: Cucumberex.Runner

  @doc """
  Version of cucumberex.

  ## Examples

      iex> Cucumberex.version()
      "0.1.0"
  """
  def version, do: "0.1.0"
end
