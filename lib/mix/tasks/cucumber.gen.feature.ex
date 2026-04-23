defmodule Mix.Tasks.Cucumber.Gen.Feature do
  @shortdoc "Generate a feature file under features/"
  @moduledoc """
  Generate a `.feature` skeleton under `features/`.

  ## Usage

      mix cucumber.gen.feature NAME

  NAME is snake_cased for the filename and humanized for the `Feature:` line.
  Refuses to overwrite an existing file.

  ## Examples

      mix cucumber.gen.feature authentication
      # → features/authentication.feature
  """

  use Mix.Task

  @impl Mix.Task
  def run([]) do
    Mix.raise("mix cucumber.gen.feature expects a NAME argument")
  end

  def run([name | _]) do
    filename = Macro.underscore(name)
    path = "features/#{filename}.feature"
    title = humanize(filename)

    File.mkdir_p!("features")

    if File.exists?(path) do
      Mix.raise("#{path} already exists")
    end

    File.write!(path, """
    Feature: #{title}

      Scenario: TODO describe this scenario
        Given TODO
        When TODO
        Then TODO
    """)

    Mix.shell().info("Created #{path}")
  end

  defp humanize(name) do
    name
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
