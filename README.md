# Cucumberex

[![Hex.pm](https://img.shields.io/hexpm/v/cucumberex.svg)](https://hex.pm/packages/cucumberex)
[![HexDocs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/cucumberex)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A full-featured [Cucumber](https://cucumber.io) BDD framework for Elixir.
Write `.feature` files in Gherkin, bind them to Elixir step definitions,
and run them with `mix cucumber`.

```gherkin
Feature: Belly

  Scenario: Eating cukes
    Given I have 5 cukes in my belly
    When I eat 3 cukes
    Then I should have 2 cukes
```

```elixir
defmodule BellySteps do
  use Cucumberex.DSL

  given_ "I have {int} cukes in my belly", fn world, count ->
    Map.put(world, :cukes, count)
  end

  when_ "I eat {int} cukes", fn world, count ->
    Map.update!(world, :cukes, &(&1 - count))
  end

  then_ "I should have {int} cukes", fn world, expected ->
    if world.cukes != expected do
      raise "Expected #{expected} cukes, got #{world.cukes}"
    end
    world
  end
end
```

```
$ mix cucumber

  Feature: Belly

    Scenario: Eating cukes
      Given I have 5 cukes in my belly
      When I eat 3 cukes
      Then I should have 2 cukes

1 scenario, 1 passed
Finished in 3ms
```

## Table of Contents

- [Why Cucumberex](#why-cucumberex)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Writing Feature Files](#writing-feature-files)
- [Step Definitions](#step-definitions)
- [Cucumber Expressions](#cucumber-expressions)
- [Parameter Types](#parameter-types)
- [World (Scenario State)](#world-scenario-state)
- [Data Tables](#data-tables)
- [Doc Strings](#doc-strings)
- [Hooks](#hooks)
- [Tag Expressions](#tag-expressions)
- [Running Tests](#running-tests)
- [Formatters](#formatters)
- [Configuration](#configuration)
- [Project Layout](#project-layout)
- [Tooling](#tooling)
- [Compatibility](#compatibility)
- [Contributing](#contributing)
- [License](#license)

## Why Cucumberex

- **Full Gherkin**. `Feature`, `Rule`, `Scenario`, `Background`,
  `Scenario Outline` / `Examples`, data tables, doc strings,
  [70+ languages](https://cucumber.io/docs/gherkin/reference/#spoken-languages).
- **Cucumber Expressions and regex**. Use readable templates like
  `{int} cukes` or drop down to `~r/^…$/` when you need full regex control.
- **Hooks**. `before`, `after`, `before_step`, `after_step`, `before_all`,
  `after_all`, with optional tag expression filters.
- **Tag expressions**. `@smoke and not @slow`, parens, `or`, `not`.
- **Formatters**. Pretty, Progress, JSON, HTML, JUnit, and Rerun —
  plus a behaviour for writing your own.
- **No Phoenix, no Ecto, no database**. Cucumberex is a stateless library.
  You can plug it into any Elixir project.
- **Stateful test runs are isolated**. World state is a plain map threaded
  through each scenario — no globals, no leakage between scenarios.

## Installation

Add Cucumberex to your `mix.exs` deps:

```elixir
def deps do
  [
    {:cucumberex, "~> 0.1"}
  ]
end
```

Import the formatter exports so `mix format` doesn't mangle the DSL in
your project's `.formatter.exs`:

```elixir
[
  import_deps: [:cucumberex],
  inputs: ["features/**/*.{ex,exs}", "{mix,.formatter}.exs", ...]
]
```

Then:

```
$ mix deps.get
$ mix cucumber.init
```

`mix cucumber.init` creates:

```
features/
├── example.feature
├── step_definitions/
│   └── steps.ex
└── support/
    └── env.ex
```

Run:

```
$ mix cucumber
```

## Quick Start

**1. Write a feature** (`features/calculator.feature`):

```gherkin
Feature: Calculator

  Scenario: Adding two numbers
    Given I have entered 50 into the calculator
    And I have entered 70 into the calculator
    When I press add
    Then the result should be 120 on the screen
```

**2. Write step definitions** (`features/step_definitions/calculator_steps.ex`):

```elixir
defmodule CalculatorSteps do
  use Cucumberex.DSL

  given_ "I have entered {int} into the calculator", fn world, n ->
    Map.update(world, :stack, [n], &[n | &1])
  end

  when_ "I press add", fn world ->
    Map.put(world, :result, Enum.sum(world.stack))
  end

  then_ "the result should be {int} on the screen", fn world, expected ->
    if world.result != expected do
      raise "Expected #{expected}, got #{world.result}"
    end
    world
  end
end
```

**3. Run:**

```
$ mix cucumber
```

## Mix Tasks

Once installed, Cucumberex ships four mix tasks:

| Task                          | What it does                                          |
|-------------------------------|-------------------------------------------------------|
| `mix cucumber`                | Run the feature suite (main entry point)              |
| `mix cucumber.init`           | Scaffold `features/` with a starter project           |
| `mix cucumber.gen.feature NAME` | Generate an empty `features/NAME.feature`            |
| `mix cucumber.gen.steps NAME` | Generate `features/step_definitions/NAME_steps.ex`    |

Run `mix help cucumber` (or any of the sub-tasks) for full docs.

## Writing Feature Files

Cucumberex uses the official [Gherkin parser](https://hex.pm/packages/cucumber_gherkin),
so you get the full spec:

```gherkin
@smoke
Feature: Authentication

  Background:
    Given the system is online

  Rule: Users with valid credentials can sign in

    Scenario: Successful sign-in
      When I submit valid credentials
      Then I should be signed in

    Scenario Outline: Invalid credentials are rejected
      When I submit "<username>" and "<password>"
      Then I should see error "<message>"

      Examples:
        | username | password | message              |
        | alice    | wrong    | Invalid password     |
        | bob      |          | Password required    |
```

Feature files live under `features/` by default.

## Step Definitions

Step definition modules `use Cucumberex.DSL` and get four macros:

| Macro      | Gherkin keyword       | Use for                              |
|------------|-----------------------|--------------------------------------|
| `given_/2` | `Given`               | Establish context                    |
| `when_/2`  | `When`                | Perform an action                    |
| `then_/2`  | `Then`                | Assert an outcome                    |
| `step/2`   | (any keyword)         | Steps that don't care about keyword  |

Each macro takes a pattern (string or regex) and a function. The function
receives `world` as its first argument, then one argument per captured
parameter, and returns the new world.

```elixir
defmodule AuthSteps do
  use Cucumberex.DSL

  given_ "I am a user named {string}", fn world, name ->
    Map.put(world, :user, %{name: name})
  end

  when_ ~r/^I log in as "(\w+)"$/, fn world, name ->
    token = MyApp.Auth.login(name)
    Map.put(world, :token, token)
  end

  then_ "my token should be valid", fn world ->
    assert MyApp.Auth.valid?(world.token)
    world
  end

  step "debug world", fn world ->
    IO.inspect(world, label: "world")
    world
  end
end
```

### Pending Steps

Call `pending()` anywhere inside a step body to mark the scenario pending:

```elixir
then_ "the report should be generated", fn world ->
  pending()
  world
end
```

## Cucumber Expressions

Prefer Cucumber Expressions to regex — they're more readable and
integrate with parameter types:

| Expression   | Matches                                        |
|--------------|------------------------------------------------|
| `{int}`      | `-?\d+` → `integer`                            |
| `{float}`    | `-?\d*\.\d+` → `float`                         |
| `{word}`     | `[^\s]+` → `String.t()`                        |
| `{string}`   | `"..."` or `'...'` → content without quotes    |
| `(optional)` | Optional literal group                         |
| `a/b/c`      | Alternation (simple words only)                |

```elixir
given_ "I have {int} cukes", fn world, n -> ... end
# matches "I have 5 cukes" → n = 5

given_ "I {word} the button", fn world, verb -> ... end
# matches "I click the button" or "I press the button"

given_ "I open(ed) the page", fn world -> ... end
# matches "I open the page" OR "I opened the page"

given_ "I am on the home/landing/start page", fn world -> ... end
# matches any of the three literal alternatives
```

For full regex control, pass a `~r/…/` sigil instead:

```elixir
given_ ~r/^I have (\d+) cukes$/, fn world, n_str ->
  Map.put(world, :cukes, String.to_integer(n_str))
end
```

## Parameter Types

Built-in types register automatically:

| Type          | Regex                | Transform                |
|---------------|----------------------|--------------------------|
| `int`         | `-?\d+`              | `String.to_integer/1`    |
| `float`       | `-?\d*\.\d+`         | `String.to_float/1`      |
| `word`        | `[^\s]+`             | identity                 |
| `string`      | quoted strings       | content without quotes   |
| `bigdecimal`  | decimal or integer   | `Float` or `Integer`     |
| `double`      | decimal or integer   | `Float` or `Integer`     |
| `byte`, `short`, `long` | `-?\d+`    | `String.to_integer/1`    |

### Custom Parameter Types

Register inside a step module:

```elixir
defmodule MoneySteps do
  use Cucumberex.DSL

  parameter_type "money", ~r/\$\d+(?:\.\d{2})?/, fn [capture] ->
    capture
    |> String.trim_leading("$")
    |> Decimal.new()
  end

  given_ "I have {money}", fn world, amount ->
    Map.put(world, :balance, amount)
  end
end
```

## World (Scenario State)

The world is a plain map threaded through every step in a scenario.
Each scenario gets a fresh world — no state leaks between scenarios.

```elixir
given_ "a registered user", fn world ->
  user = create_user!()
  Map.put(world, :user, user)
end

when_ "they sign in", fn world ->
  token = sign_in!(world.user)
  Map.put(world, :token, token)
end
```

### World Factory

Provide a factory to supply default world fields:

```elixir
# features/support/env.ex
Cucumberex.World.Registry.set_factory(fn ->
  %{
    started_at: DateTime.utc_now(),
    db: :ets.new(:scenario_db, [:set])
  }
end)
```

## Data Tables

Gherkin data tables become `Cucumberex.DataTable` structs:

```gherkin
Scenario: Signing up users
  Given the following users:
    | name  | email             | role  |
    | alice | alice@example.com | admin |
    | bob   | bob@example.com   | user  |
```

```elixir
given_ "the following users:", fn world, table ->
  users = Cucumberex.DataTable.hashes(table)
  # [%{"name" => "alice", ...}, %{"name" => "bob", ...}]
  Map.put(world, :users, users)
end
```

Accessors mirror cucumber-ruby:

| Function               | Returns                                                          |
|------------------------|------------------------------------------------------------------|
| `raw/1`                | `[[cell, ...], ...]` including header row                        |
| `hashes/1`             | `[%{header => value}, ...]` (one map per data row)               |
| `rows/1`               | Data rows without the header                                     |
| `rows_hash/1`          | First column → key, second column → value                        |
| `symbolic_hashes/1`    | Like `hashes/1` but with atom keys (use only with bounded headers) |
| `transpose/1`          | Swap rows and columns                                            |
| `map_headers/2`        | Rename headers via map or function                               |
| `map_column/3`         | Apply a function to every value in a named column                |
| `diff!/2`              | Raise on mismatch, `:ok` otherwise                               |
| `verify_column!/2`     | Raise if column name missing                                     |
| `verify_table_width!/2`| Raise if any row width differs                                   |

> **Note:** `symbolic_hashes/1` calls `String.to_atom/1` on headers.
> Only use it with known, bounded header values (e.g. fixture tables
> whose headers match struct fields). For arbitrary user input, use
> `hashes/1` to avoid unbounded atom creation.

## Doc Strings

Multi-line step arguments parse into `Cucumberex.DocString`:

```gherkin
Given a blog post with content:
  """markdown
  # Hello

  This is **bold**.
  """
```

```elixir
given_ "a blog post with content:", fn world, doc ->
  # doc.content       → "# Hello\n\nThis is **bold**."
  # doc.content_type  → "markdown"
  Map.put(world, :post_body, doc.content)
end
```

`DocString` implements `String.Chars`, so interpolation works directly:
`"The body is: #{doc}"`.

## Hooks

All hook macros end with an underscore to avoid clashing with Elixir
keywords (`after`) and for naming consistency.

```elixir
defmodule TestSupport do
  use Cucumberex.Hooks.DSL

  before_all_ fn ->
    MyApp.start_test_environment()
  end

  before_ fn world ->
    Map.put(world, :started_at, System.monotonic_time())
  end

  before_ "@db", fn world ->
    Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
    world
  end

  after_ fn world ->
    MyApp.TestHelper.cleanup()
    world
  end

  after_ "@db", fn world ->
    Ecto.Adapters.SQL.Sandbox.checkin(MyApp.Repo)
    world
  end

  before_step_ fn world ->
    Logger.metadata(step_started_at: System.monotonic_time())
    world
  end

  after_all_ fn ->
    MyApp.stop_test_environment()
  end
end
```

Hook macros and phases:

| Macro                    | When                                      |
|--------------------------|-------------------------------------------|
| `before_all_/1`          | Once, before any scenario                 |
| `before_/1`, `before_/2` | Before each scenario                      |
| `before_step_/1`         | Before each step                          |
| `after_step_/1`          | After each step                           |
| `after_/1`, `after_/2`   | After each scenario (passed or failed)    |
| `after_all_/1`           | Once, after all scenarios                 |
| `around_/1`, `around_/2` | Wrap the scenario                         |

The two-arity `before_` / `after_` / `around_` take a tag expression as
the first argument to scope the hook:

```elixir
before_ "@admin and not @guest", fn world -> ... end
```

## Tag Expressions

Tag filters support boolean logic:

```
@smoke
@smoke and @fast
@smoke or @wip
not @slow
(@smoke or @wip) and not @flaky
```

Run only tagged scenarios:

```
$ mix cucumber --tags @smoke
$ mix cucumber --tags "@smoke and not @slow"
$ mix cucumber --tags "(@api or @web) and @happy-path"
```

The same expressions filter hooks:

```elixir
before "@db", fn world -> ... end
after_ "not @readonly", fn world -> ... end
```

## Running Tests

```
mix cucumber [options] [feature files or directories]
```

### Filtering

| Flag                         | Meaning                                        |
|------------------------------|------------------------------------------------|
| `-t`, `--tags EXPR`          | Tag expression                                 |
| `-n`, `--name PATTERN`       | Scenario name substring                        |
| `-e`, `--exclude PATTERN`    | Skip paths matching pattern (repeatable)       |
| `features/x.feature:42`      | Run only the scenario at line 42               |

### Execution

| Flag                     | Meaning                                            |
|--------------------------|----------------------------------------------------|
| `-d`, `--dry-run`        | Parse and match without executing step bodies      |
| `--fail-fast`            | Stop at the first failure                          |
| `--strict`               | Fail run if any scenario is undefined or pending   |
| `--strict-undefined`     | Fail only on undefined steps                       |
| `--strict-pending`       | Fail only on pending steps                         |
| `--wip`                  | Fail if *any* scenario passes (Work-In-Progress)   |
| `--retry N`              | Retry each failing scenario up to `N` times        |
| `--order ORDER`          | `defined` (default), `random`, or `reverse`        |
| `--random [SEED]`        | Shortcut for `--order random` with seed            |
| `--reverse`              | Shortcut for `--order reverse`                     |

### Reporting

| Flag                         | Meaning                                        |
|------------------------------|------------------------------------------------|
| `-f`, `--format FORMAT`      | `pretty` (default), `progress`, `json`, `html`, `junit`, `rerun` |
| `-o`, `--out FILE`           | Write formatter output to `FILE`               |
| `-c`, `--color` / `--no-color` | Toggle ANSI color                            |
| `--no-source`                | Hide step source locations                     |
| `-i`, `--no-snippets`        | Hide snippets for undefined steps              |
| `--no-duration`              | Hide scenario duration                         |
| `-x`, `--expand`             | Expand scenario outline tables                 |
| `-b`, `--backtrace`          | Show full backtraces                           |
| `-v`, `--verbose`            | Show loaded files                              |
| `-q`, `--quiet`              | Shorthand for `--no-snippets --no-source --no-duration` |
| `--snippet-type TYPE`        | `cucumber_expression` (default) or `regexp`    |

### Examples

```
# Only smoke tests, JSON output
mix cucumber --tags @smoke --format json --out smoke.json

# Dry-run the whole suite to find undefined steps
mix cucumber --dry-run --strict-undefined

# Run last failure set
mix cucumber --format rerun --out tmp/rerun.txt
mix cucumber @tmp/rerun.txt

# Randomize with a fixed seed for CI reproducibility
mix cucumber --random 42
```

## Formatters

Formatters are GenServers that subscribe to the event bus. Cucumberex
ships six, and you can write your own by implementing the
`Cucumberex.Formatter` behaviour.

| Formatter  | Output        | Typical use                            |
|------------|---------------|----------------------------------------|
| `pretty`   | Terminal      | Local development (default)            |
| `progress` | Terminal      | CI logs — one dot per step             |
| `json`     | File / stdout | Consumed by cucumber-json tools        |
| `html`     | File          | Self-contained visual report           |
| `junit`    | File          | CI dashboards (Jenkins, CircleCI, etc.)|
| `rerun`    | File          | `file:line` list of failed scenarios   |

### Multiple Formatters

Stack `--format` + `--out` pairs (via `cucumber.yml` or repeat on CLI) to
emit several reports at once:

```yaml
# cucumber.yml
default: --format pretty --format json --out tmp/report.json --format html --out tmp/report.html
```

### Custom Formatters

```elixir
defmodule MyFormatter do
  use Cucumberex.Formatter

  @impl GenServer
  def init(_opts), do: {:ok, %{failures: 0}}

  defp on_event(%Cucumberex.Events.TestStepFinished{result: %{status: :failed}}, state) do
    %{state | failures: state.failures + 1}
  end

  defp on_event(%Cucumberex.Events.TestRunFinished{}, state) do
    IO.puts("Total failures: #{state.failures}")
    state
  end

  defp on_event(_event, state), do: state
end
```

Select it on the CLI or in `cucumber.yml`:

```
mix cucumber --format MyFormatter
```

## Configuration

Cucumberex reads configuration from four sources; later sources override
earlier ones:

1. Built-in defaults
2. `:cucumberex, :config` in `mix.exs` / `config/config.exs`
3. `cucumber.yml` profile (looked up in `cucumber.yml`, `cucumber.yaml`,
   `.config/cucumber.yml`, `config/cucumber.yml`)
4. CLI arguments

### `cucumber.yml` Profiles

```yaml
default: --format pretty --strict
ci: --format progress --format junit --out tmp/junit.xml --strict
smoke: --tags @smoke --fail-fast
wip: --tags @wip --wip
```

Select a profile with `--profile`:

```
mix cucumber --profile ci
```

### `mix.exs` Config

```elixir
# config/config.exs
import Config

config :cucumberex,
  paths: ["features"],
  exclude: ["deprecated"],
  strict: true
```

## Project Layout

A typical Cucumberex project:

```
my_app/
├── features/
│   ├── authentication.feature
│   ├── reporting.feature
│   ├── step_definitions/
│   │   ├── auth_steps.ex
│   │   └── reporting_steps.ex
│   └── support/
│       ├── env.ex             # World factory, before_all/after_all
│       └── test_helpers.ex    # Shared helpers
├── cucumber.yml               # Optional profiles
├── config/
│   └── config.exs
└── mix.exs
```

Cucumberex auto-loads every `.ex` file under `features/support` and
`features/step_definitions`. Use `--require PATH` to load additional files
or directories.

## Tooling

The project itself is a good reference for Elixir tooling conventions:

```
mix compile --warnings-as-errors
mix test                          # 78 doctests + 31 unit tests
mix format --check-formatted
mix credo --strict                # 0 issues
mix dialyzer                      # 0 warnings
mix cucumber                      # 11 scenarios (this project's own features)
```

## Compatibility

| Dependency          | Version               |
|---------------------|-----------------------|
| Elixir              | `~> 1.14`             |
| `cucumber_gherkin`  | `~> 39.0`             |
| `cucumber_messages` | `~> 32.0`             |
| `jason`             | `~> 1.4`              |
| `yaml_elixir`       | `~> 2.9`              |
| `nimble_options`    | `~> 1.0`              |

## Contributing

Issues and PRs welcome at
[github.com/jeffreybaird/cucumberex](https://github.com/jeffreybaird/cucumberex).

This project adheres to the conventions in [`CLAUDE.md`](./CLAUDE.md) and
the skill files under `.claude/`:

- Tagged-tuple error protocol (`{:ok, _}` / `{:error, :atom}`)
- Narrow `rescue` (specific exception types only)
- Every public function has a doctest (exempting I/O and GenServer calls)
- Tests are specifications — never modify tests to make them pass
- Trunk-based development, atomic commits, linear history

Before opening a PR, run:

```
mix format
mix credo --strict
mix dialyzer
mix test
mix cucumber
```

## License

[MIT](./LICENSE) © 2026 Jeffrey Baird
