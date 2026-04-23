defmodule Cucumberex.Config do
  @moduledoc "Configuration struct for a Cucumber run."

  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    # Feature file paths / dirs
    paths: ["features"],
    # Require additional files/dirs
    require: [],
    # Tag expression filter
    tags: nil,
    # Scenario name filter (string or regex)
    name: nil,
    # Line filters [{uri, line}]
    lines: [],
    # Exclude patterns
    exclude: [],
    # Formatters [{module, opts}]
    formatters: [{Cucumberex.Formatter.Pretty, []}],
    # Output for default formatter
    output: :stdio,
    # Color output
    color: true,
    # Show step source locations
    source: true,
    # Show snippets for undefined steps
    snippets: true,
    # Snippet type: :cucumber_expression | :regexp
    snippet_type: :cucumber_expression,
    # Don't execute steps
    dry_run: false,
    # Stop at first failure
    fail_fast: false,
    # Strict mode: fail on undefined/pending
    strict: false,
    strict_undefined: false,
    strict_pending: false,
    strict_flaky: false,
    # WIP mode: fail if any pass
    wip: false,
    # Order: :defined | :random | :reverse
    order: :defined,
    # Random seed
    random_seed: nil,
    # Retry failed scenarios N times
    retry: 0,
    # Retry total threshold
    retry_total: nil,
    # Show backtraces on failure
    backtrace: false,
    # Suppress duration output
    duration: true,
    # Verbose: show loaded files
    verbose: false,
    # Expand scenario outlines in output
    expand: false,
    # i18n language
    language: "en",
    # Profile name
    profile: "default",
    # Step definition registry pid
    step_registry: Cucumberex.StepDefinition.Registry,
    # Hook registry pid
    hook_registry: Cucumberex.Hooks.Registry,
    # Parameter type registry pid
    param_type_registry: Cucumberex.ParameterType.Registry,
    # World factory fn/0 or nil
    world_factory: nil,
    # Step module list (auto-discovered or explicit)
    step_modules: [],
    # Support module list
    support_modules: []
  ]

  @type t :: %__MODULE__{}

  @doc """
  Merge a keyword list of options into a Config.

  ## Examples

      iex> Cucumberex.Config.from_opts(paths: ["features/a.feature"]).paths
      ["features/a.feature"]

      iex> Cucumberex.Config.from_opts([]).order
      :defined
  """
  def from_opts(opts) when is_list(opts) do
    struct(__MODULE__, opts)
  end

  @doc """
  Apply strict shorthand: `:strict` implies `:strict_undefined` and `:strict_pending`.

  ## Examples

      iex> Cucumberex.Config.normalize(%{strict: true, strict_undefined: false, strict_pending: false})
      %{strict: true, strict_undefined: true, strict_pending: true}

      iex> Cucumberex.Config.normalize(%{strict: false})
      %{strict: false}
  """
  def normalize(%{strict: true} = c) do
    Map.merge(c, %{strict_undefined: true, strict_pending: true})
  end

  def normalize(c), do: c
end
