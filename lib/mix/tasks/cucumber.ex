defmodule Mix.Tasks.Cucumber do
  @shortdoc "Run Cucumber BDD feature tests"
  @moduledoc """
  Run Cucumber feature tests.

  ## Usage

      mix cucumber [options] [feature_files]

  ## Options

      -t, --tags EXPR         Filter by tag expression (@smoke, not @wip, @a and @b)
      -n, --name PATTERN      Filter by scenario name
      -f, --format FORMAT     Output format: pretty (default), progress, json, html, junit, rerun
      -o, --out FILE          Write output to file instead of stdout
      -r, --require FILE/DIR  Require file or directory before running
      -d, --dry-run           Parse features without executing steps
          --fail-fast         Stop after first failure
          --strict            Fail on undefined/pending
          --strict-undefined  Fail on undefined steps
          --strict-pending    Fail on pending steps
          --wip               Fail if any scenario passes
          --order ORDER       Run order: defined (default), random, reverse
          --reverse           Run in reverse order
          --random [SEED]     Randomize order with optional seed
          --retry N           Retry failing scenarios N times
      -b, --backtrace         Show full backtraces
      -c, --color / --no-color  Toggle ANSI color
          --no-source         Don't show step source locations
      -i, --no-snippets       Don't print undefined step snippets
          --no-duration       Don't print scenario duration
      -x, --expand            Expand scenario outline tables
      -p, --profile PROFILE   Use named profile from cucumber.yml
      -v, --verbose           Show loaded files
      -q, --quiet             Suppress snippets, source, duration
      -e, --exclude PATTERN   Exclude files matching pattern
          --snippet-type TYPE  Snippet style: cucumber_expression (default) or regexp
          --version           Show version
          --init              Initialize project structure

  ## Examples

      mix cucumber
      mix cucumber features/auth.feature
      mix cucumber --tags @smoke
      mix cucumber --format json --out report.json
      mix cucumber --profile ci
  """

  use Mix.Task

  alias Cucumberex.Config.Loader
  alias Cucumberex.DSL
  alias Cucumberex.Hooks.DSL, as: HooksDSL
  alias Cucumberex.Runner

  @version Cucumberex.MixProject.project()[:version]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      ["--version" | _] ->
        Mix.shell().info("Cucumberex #{@version}")
        :ok

      ["--init" | _] ->
        init_project()

      ["--i18n-languages" | _] ->
        print_languages()

      ["--i18n-keywords", lang | _] ->
        print_keywords(lang)

      _ ->
        run_cucumber(args)
    end
  end

  defp run_cucumber(args) do
    config =
      args
      |> Loader.load()
      |> load_support_files()

    exit_code = Runner.run(config)

    if exit_code != 0 do
      System.at_exit(fn _ -> exit({:shutdown, exit_code}) end)
    end
  end

  defp load_support_files(config) do
    support_dirs = ["features/support", "features/step_definitions"]
    all_dirs = support_dirs ++ config.require

    modules = Enum.flat_map(all_dirs, &compile_path/1)
    Enum.each(modules, &register_module(&1, config))

    %{config | step_modules: modules}
  end

  defp compile_path(dir) do
    cond do
      File.dir?(dir) -> compile_directory(dir)
      File.exists?(dir) -> compile_file(dir)
      true -> []
    end
  end

  defp compile_directory(dir) do
    dir
    |> Path.join("**/*.ex")
    |> Path.wildcard()
    |> Enum.flat_map(&compile_file/1)
  end

  defp compile_file(path) do
    path |> Code.compile_file() |> Enum.map(fn {mod, _} -> mod end)
  end

  defp register_module(mod, config) do
    DSL.load_module(mod, config.step_registry)
    HooksDSL.load_module(mod, config.hook_registry)
  end

  defp init_project do
    dirs = ["features", "features/support", "features/step_definitions"]

    Enum.each(dirs, fn dir ->
      File.mkdir_p!(dir)
      Mix.shell().info("Created #{dir}/")
    end)

    support_file = "features/support/env.ex"

    unless File.exists?(support_file) do
      File.write!(support_file, """
      # Cucumberex environment setup
      # This file is loaded before your step definitions.

      # Example: Set up a world factory
      # Cucumberex.World.Registry.set_factory(fn -> %{db: :ets.new(:world, [:set])} end)
      """)

      Mix.shell().info("Created #{support_file}")
    end

    step_file = "features/step_definitions/steps.ex"

    unless File.exists?(step_file) do
      File.write!(step_file, """
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

      Mix.shell().info("Created #{step_file}")
    end

    example_feature = "features/example.feature"

    unless File.exists?(example_feature) do
      File.write!(example_feature, """
      Feature: Example feature

        Scenario: Basic scenario
          Given I have 5 cukes in my belly
          Then I should have 5 cukes
      """)

      Mix.shell().info("Created #{example_feature}")
    end

    Mix.shell().info("\nProject initialized! Run: mix cucumber")
  end

  defp print_languages do
    Mix.shell().info("Supported languages: en, fr, de, es, pt, nl, it, ru, ja, zh, ar, ... (70+)")
    Mix.shell().info("(Language support delegated to cucumber_gherkin)")
  end

  defp print_keywords(lang) do
    Mix.shell().info("Keywords for language '#{lang}' are provided by the Gherkin specification.")
    Mix.shell().info("See: https://github.com/cucumber/gherkin/blob/main/gherkin-languages.json")
  end
end
