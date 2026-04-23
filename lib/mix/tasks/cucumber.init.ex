defmodule Mix.Tasks.Cucumber.Init do
  @shortdoc "Scaffold a Cucumberex project structure"
  @moduledoc """
  Scaffold `features/`, a starter step module, a starter env file, and an
  example feature so `mix cucumber` runs green immediately.

  ## Usage

      mix cucumber.init

  Creates (skips any that already exist):

      features/
      features/support/env.ex
      features/step_definitions/steps.ex
      features/example.feature
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    dirs = ["features", "features/support", "features/step_definitions"]

    Enum.each(dirs, fn dir ->
      File.mkdir_p!(dir)
      Mix.shell().info("Created #{dir}/")
    end)

    create_file("features/support/env.ex", """
    # Cucumberex environment setup
    # This file is loaded before your step definitions.

    # Example: Set up a world factory
    # Cucumberex.World.Registry.set_factory(fn -> %{db: :ets.new(:world, [:set])} end)
    """)

    create_file("features/step_definitions/steps.ex", """
    defmodule MySteps do
      use Cucumberex.DSL

      given_ "I have {int} cukes in my belly", fn world, count ->
        Map.put(world, :cukes, count)
      end

      then_ "I should have {int} cukes", fn world, expected ->
        if world.cukes != expected do
          raise "Expected \#{expected} cukes but got \#{world.cukes}"
        end

        world
      end
    end
    """)

    create_file("features/example.feature", """
    Feature: Example feature

      Scenario: Basic scenario
        Given I have 5 cukes in my belly
        Then I should have 5 cukes
    """)

    Mix.shell().info("\nProject initialized! Run: mix cucumber")
  end

  defp create_file(path, content) do
    if File.exists?(path) do
      Mix.shell().info("Skipped #{path} (already exists)")
    else
      File.write!(path, content)
      Mix.shell().info("Created #{path}")
    end
  end
end
