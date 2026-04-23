# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `mix cucumber.init` as a dedicated task (extracted from `mix cucumber --init`).
- `mix cucumber.gen.feature NAME` generates an empty feature file.
- `mix cucumber.gen.steps NAME` generates a step definition module.
- `.formatter.exs` exports `locals_without_parens` for all DSL and hook
  macros. Consumers add `import_deps: [:cucumberex]` to their
  `.formatter.exs` to avoid `mix format` mangling step definitions.

### Removed

- `mix cucumber --init` flag (use `mix cucumber.init` instead).

### Fixed

- README hook examples and phase table now use the actual macro names
  (`before_`, `after_`, `before_step_`, `after_step_`, `before_all_`,
  `after_all_`, `around_`).

## [0.1.0] - 2026-04-23

Initial release.

### Added

- **DSL** (`Cucumberex.DSL`): `given_/2`, `when_/2`, `then_/2`, `step/2` macros
  for registering step definitions against Cucumber Expressions or regular
  expressions. `pending/0` marks a step pending at runtime. `world_module/1`
  and `parameter_type/3` for scenario-scoped composition.
- **Hooks** (`Cucumberex.Hooks.DSL`): `before_/1,2`, `after_/1,2`,
  `before_step/1,2`, `after_step/1,2`, `before_all/0,1`, `after_all/0,1`,
  with optional tag expression filters.
- **Cucumber Expressions**: built-in `{int}`, `{float}`, `{word}`, `{string}`,
  `{bigdecimal}`, `{double}`, `{byte}`, `{short}`, `{long}` parameter types;
  custom types registered via `parameter_type/3`.
- **Gherkin**: full `Feature` / `Rule` / `Scenario` / `Background` /
  `Scenario Outline` / `Examples` support via `cucumber_gherkin`, including
  data tables and doc strings.
- **Data tables** (`Cucumberex.DataTable`): `raw/1`, `hashes/1`, `rows/1`,
  `rows_hash/1`, `symbolic_hashes/1`, `transpose/1`, `map_headers/2`,
  `map_column/3`, `diff!/2`, `verify_column!/2`, `verify_table_width!/2`.
- **Doc strings** (`Cucumberex.DocString`): multi-line step arguments with
  optional media type; implements `String.Chars`.
- **Tag expressions** (`Cucumberex.Filter.TagExpression`): `and`, `or`, `not`,
  and parenthesized grouping. Also `Cucumberex.Filter.NameFilter` (substring
  / regex) and `Cucumberex.Filter.LineFilter` (`file:line` targeting).
- **Formatters** (`Cucumberex.Formatter`): GenServer-based behaviour with
  built-in `Pretty`, `Progress`, `JSON`, `HTML`, `JUnit`, and `Rerun`.
- **Event bus** (`Cucumberex.Events.Bus`): broadcasts `TestRunStarted`,
  `TestRunFinished`, `FeatureLoaded`, `TestCaseStarted`, `TestCaseFinished`,
  `TestStepStarted`, `TestStepFinished`, `HookStarted`, `HookFinished`,
  `UndefinedStep`, `AmbiguousStep`. `drain/1` provides a sync barrier for
  shutdown.
- **Runner** (`Cucumberex.Runner`): filter by tag / name / line, order
  (`:defined`, `:random`, `:reverse`), retry failed scenarios, fail-fast,
  WIP mode, dry run, strict mode for undefined / pending / both.
- **Configuration** (`Cucumberex.Config.Loader`): layered precedence —
  defaults, `mix.exs` config, `cucumber.yml` profile, CLI args (highest).
- **Mix task** (`mix cucumber`): CLI with short and long option forms;
  `--init` scaffolds a project; `--version`; `--i18n-languages` /
  `--i18n-keywords` surface Gherkin's language support.
- **World** (`Cucumberex.World`): scenario-isolated state map with optional
  global factory via `Cucumberex.World.Registry`.
- **Snippets** (`Cucumberex.StepDefinition.Snippet`): undefined-step
  skeletons in Cucumber Expression or regexp form.
- **Tooling**: `mix format`, `mix credo --strict` (clean), `mix dialyzer`
  (clean), 78 doctests + 31 unit tests.

[Unreleased]: https://github.com/jeffreybaird/cucumberex/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/jeffreybaird/cucumberex/releases/tag/v0.1.0
