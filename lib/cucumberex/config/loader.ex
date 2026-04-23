defmodule Cucumberex.Config.Loader do
  @moduledoc """
  Load configuration from:
    1. cucumber.yml or .config/cucumber.yml profiles
    2. mix.exs :cucumberex config
    3. CLI args (highest priority)
  """

  alias Cucumberex.Config

  @profile_files ["cucumber.yml", "cucumber.yaml", ".config/cucumber.yml", "config/cucumber.yml"]

  def load(cli_args \\ [], profile \\ "default") do
    base = default_config()
    mix_config = load_mix_config()
    profile_config = load_profile(profile)
    cli_config = parse_cli(cli_args)

    base
    |> Map.merge(mix_config)
    |> Map.merge(profile_config)
    |> Map.merge(cli_config)
    |> Config.normalize()
  end

  defp default_config do
    struct(Config) |> Map.from_struct()
  end

  defp load_mix_config do
    Application.get_env(:cucumberex, :config, []) |> Map.new()
  rescue
    ArgumentError -> %{}
  end

  defp load_profile(profile_name) do
    case find_profile_file() do
      nil -> %{}
      path -> parse_profile_file(path, profile_name)
    end
  end

  defp find_profile_file do
    Enum.find(@profile_files, &File.exists?/1)
  end

  defp parse_profile_file(path, profile_name) do
    yaml = YamlElixir.read_from_file!(path)
    profile = Map.get(yaml, profile_name) || Map.get(yaml, to_string(profile_name))

    if profile do
      parse_profile_args(profile)
    else
      %{}
    end
  rescue
    e ->
      require Logger
      Logger.warning("Could not parse cucumber profile file #{path}: #{inspect(e)}")
      %{}
  end

  defp parse_profile_args(args) when is_binary(args) do
    args |> String.split() |> parse_cli()
  end

  defp parse_profile_args(args) when is_list(args) do
    parse_cli(args)
  end

  defp parse_profile_args(_), do: %{}

  @doc """
  Parse CLI arguments into a config map.

  ## Examples

      iex> Cucumberex.Config.Loader.parse_cli(["--tags", "@smoke"])
      %{tags: "@smoke"}

      iex> Cucumberex.Config.Loader.parse_cli(["--dry-run", "features/a.feature"])
      %{dry_run: true, paths: ["features/a.feature"]}

      iex> Cucumberex.Config.Loader.parse_cli([])
      %{}
  """
  def parse_cli(args) when is_list(args) do
    parse_cli(args, %{}, [])
  end

  defp parse_cli([], acc, paths) do
    if paths != [], do: Map.put(acc, :paths, Enum.reverse(paths)), else: acc
  end

  defp parse_cli(["--tags", expr | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :tags, expr), paths)
  end

  defp parse_cli(["-t", expr | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :tags, expr), paths)
  end

  defp parse_cli(["--name", pattern | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :name, pattern), paths)
  end

  defp parse_cli(["-n", pattern | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :name, pattern), paths)
  end

  defp parse_cli(["--format", fmt | rest], acc, paths) do
    mod = resolve_formatter(fmt)
    parse_cli(rest, Map.update(acc, :formatters, [{mod, []}], &(&1 ++ [{mod, []}])), paths)
  end

  defp parse_cli(["-f", fmt | rest], acc, paths) do
    parse_cli(["--format", fmt | rest], acc, paths)
  end

  defp parse_cli(["--out", out | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :output, out), paths)
  end

  defp parse_cli(["-o", out | rest], acc, paths) do
    parse_cli(["--out", out | rest], acc, paths)
  end

  defp parse_cli(["--require", r | rest], acc, paths) do
    parse_cli(rest, Map.update(acc, :require, [r], &[r | &1]), paths)
  end

  defp parse_cli(["-r", r | rest], acc, paths) do
    parse_cli(["--require", r | rest], acc, paths)
  end

  defp parse_cli(["--dry-run" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :dry_run, true), paths)
  end

  defp parse_cli(["-d" | rest], acc, paths) do
    parse_cli(["--dry-run" | rest], acc, paths)
  end

  defp parse_cli(["--fail-fast" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :fail_fast, true), paths)
  end

  defp parse_cli(["--strict" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :strict, true), paths)
  end

  defp parse_cli(["--strict-undefined" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :strict_undefined, true), paths)
  end

  defp parse_cli(["--strict-pending" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :strict_pending, true), paths)
  end

  defp parse_cli(["--wip" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :wip, true), paths)
  end

  defp parse_cli(["--order", order | rest], acc, paths) do
    o =
      case order do
        "random" -> :random
        "reverse" -> :reverse
        _ -> :defined
      end

    parse_cli(rest, Map.put(acc, :order, o), paths)
  end

  defp parse_cli(["--reverse" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :order, :reverse), paths)
  end

  defp parse_cli(["--random", seed | rest], acc, paths) do
    parse_cli(
      rest,
      Map.merge(acc, %{order: :random, random_seed: String.to_integer(seed)}),
      paths
    )
  end

  defp parse_cli(["--retry", n | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :retry, String.to_integer(n)), paths)
  end

  defp parse_cli(["--backtrace" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :backtrace, true), paths)
  end

  defp parse_cli(["-b" | rest], acc, paths) do
    parse_cli(["--backtrace" | rest], acc, paths)
  end

  defp parse_cli(["--no-color" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :color, false), paths)
  end

  defp parse_cli(["--color" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :color, true), paths)
  end

  defp parse_cli(["-c" | rest], acc, paths) do
    parse_cli(["--color" | rest], acc, paths)
  end

  defp parse_cli(["--no-source" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :source, false), paths)
  end

  defp parse_cli(["--no-snippets" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :snippets, false), paths)
  end

  defp parse_cli(["-i" | rest], acc, paths) do
    parse_cli(["--no-snippets" | rest], acc, paths)
  end

  defp parse_cli(["--no-duration" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :duration, false), paths)
  end

  defp parse_cli(["--expand" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :expand, true), paths)
  end

  defp parse_cli(["-x" | rest], acc, paths) do
    parse_cli(["--expand" | rest], acc, paths)
  end

  defp parse_cli(["--profile", p | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :profile, p), paths)
  end

  defp parse_cli(["-p", p | rest], acc, paths) do
    parse_cli(["--profile", p | rest], acc, paths)
  end

  defp parse_cli(["--exclude", pattern | rest], acc, paths) do
    parse_cli(rest, Map.update(acc, :exclude, [pattern], &[pattern | &1]), paths)
  end

  defp parse_cli(["-e", pattern | rest], acc, paths) do
    parse_cli(["--exclude", pattern | rest], acc, paths)
  end

  defp parse_cli(["--verbose" | rest], acc, paths) do
    parse_cli(rest, Map.put(acc, :verbose, true), paths)
  end

  defp parse_cli(["-v" | rest], acc, paths) do
    parse_cli(["--verbose" | rest], acc, paths)
  end

  defp parse_cli(["--quiet" | rest], acc, paths) do
    parse_cli(rest, Map.merge(acc, %{snippets: false, source: false, duration: false}), paths)
  end

  defp parse_cli(["-q" | rest], acc, paths) do
    parse_cli(["--quiet" | rest], acc, paths)
  end

  defp parse_cli(["--snippet-type", type | rest], acc, paths) do
    t =
      case type do
        "regexp" -> :regexp
        _ -> :cucumber_expression
      end

    parse_cli(rest, Map.put(acc, :snippet_type, t), paths)
  end

  defp parse_cli([arg | rest], acc, paths) do
    # Feature file path or unknown flag - add to paths
    if String.starts_with?(arg, "-") do
      parse_cli(rest, acc, paths)
    else
      parse_cli(rest, acc, [arg | paths])
    end
  end

  defp resolve_formatter("pretty"), do: Cucumberex.Formatter.Pretty
  defp resolve_formatter("progress"), do: Cucumberex.Formatter.Progress
  defp resolve_formatter("json"), do: Cucumberex.Formatter.JSON
  defp resolve_formatter("html"), do: Cucumberex.Formatter.HTML
  defp resolve_formatter("junit"), do: Cucumberex.Formatter.JUnit
  defp resolve_formatter("rerun"), do: Cucumberex.Formatter.Rerun

  defp resolve_formatter(other) do
    Module.concat([Macro.camelize(other)])
  rescue
    ArgumentError -> Cucumberex.Formatter.Pretty
  end
end
