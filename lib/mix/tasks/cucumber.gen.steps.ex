defmodule Mix.Tasks.Cucumber.Gen.Steps do
  @shortdoc "Generate a step definition module under features/step_definitions/"
  @moduledoc """
  Generate a step definition module skeleton.

  ## Usage

      mix cucumber.gen.steps NAME

  NAME is snake_cased for the filename and camel-cased for the module.
  Refuses to overwrite an existing file.

  ## Examples

      mix cucumber.gen.steps authentication
      # → features/step_definitions/authentication_steps.ex
      # → defmodule AuthenticationSteps
  """

  use Mix.Task

  @impl Mix.Task
  def run([]) do
    Mix.raise("mix cucumber.gen.steps expects a NAME argument")
  end

  def run([name | _]) do
    filename = Macro.underscore(name) <> "_steps"
    path = "features/step_definitions/#{filename}.ex"
    mod = Macro.camelize(filename)

    File.mkdir_p!("features/step_definitions")

    if File.exists?(path) do
      Mix.raise("#{path} already exists")
    end

    File.write!(path, """
    defmodule #{mod} do
      use Cucumberex.DSL

      given_ "TODO pattern", fn world ->
        world
      end

      when_ "TODO pattern", fn world ->
        world
      end

      then_ "TODO pattern", fn world ->
        world
      end
    end
    """)

    Mix.shell().info("Created #{path}")
  end
end
