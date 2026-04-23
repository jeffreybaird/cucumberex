# CLAUDE.md — CucumberEx

Claude Code read this every session. Load relevant `.claude/` file when working in that area.

- `.claude/elixir-code-style.md` — function design, doctests, error tuples, rescue rules, comment rules
- `.claude/elixir-error-handling.md` — tagged tuples, raise vs return, rescue scope, swallowing rules
- `.claude/elixir-testing.md` — test categories, ExUnit patterns, doctest coverage
- `.claude/test-contract.md` — tests as specifications: never modify, weaken, or delete tests to pass
- `.claude/git-workflow.md` — trunk-based development, atomic commits, commit message format

---

## Project Overview

CucumberEx = full-featured Cucumber BDD framework for Elixir. Stateless hex package — no Phoenix, no Ecto, no database. Ships as a library that end-user projects `mix cucumber` against.

### Key Modules

| Module | Responsibility |
|--------|---------------|
| `Cucumberex.DSL` | `use Cucumberex.DSL` macro + step registration |
| `Cucumberex.Hooks.DSL` | `before_`/`after_` hook macros |
| `Cucumberex.Runner` | Top-level orchestration: load → filter → order → execute |
| `Cucumberex.Runner.ScenarioRunner` | Per-scenario execution + hook lifecycle |
| `Cucumberex.Runner.StepRunner` | Per-step matching + execution |
| `Cucumberex.StepDefinition.Expression` | Cucumber Expression + Regex compilation |
| `Cucumberex.StepDefinition.Matcher` | Match step text against registered definitions |
| `Cucumberex.Formatter` | GenServer behaviour + macro for all formatters |
| `Cucumberex.Events.Bus` | PubSub-style event dispatch to formatter GenServers |
| `Cucumberex.Config.Loader` | CLI arg parsing + YAML profile loading |
| `Cucumberex.DataTable` / `DocString` | Step argument wrappers |
| `Cucumberex.World` | Scenario-isolated state map |

### Formatter Architecture

Formatters are GenServers. The Events.Bus dispatches via `GenServer.cast(pid, {:event, event})` directly — it does NOT call `handle_event/1`. Formatters implement private `on_event/2` clauses. After `TestRunFinished` is broadcast, the Runner calls `GenServer.call(fmt_pid, :finish)` on each formatter to synchronously drain before exit.

---

## Architecture Rules

### 1. Stateless Hex Package

No Ecto, no Phoenix, no runtime dependencies beyond what's in `mix.exs`. No database access. No HTTP servers. The library is invoked by the mix task and runs synchronously.

### 2. Everything Is Functional

No global mutable state except the GenServer registries (step registry, hook registry, parameter type registry) which are started fresh per test run. World state is threaded through function arguments — never stored globally.

### 3. Errors Surface, Not Swallow

Hook errors use `try/rescue` and produce `Result.failed(e)`. Config parse errors log a warning. No silent `rescue _ -> default` without a Logger call.

### 4. One Module Per File

Each `.ex` file contains one public module. Helper modules defined in the same file (e.g. `Cucumberex.DocString` in `data_table.ex`) should be extracted when they grow beyond a few functions.

### 5. Behaviours Are Minimal

The `Cucumberex.Formatter` behaviour exposes only `start_link/1`. The dispatcher (Events.Bus) uses direct `GenServer.cast` — don't add `handle_event/1` back to the behaviour or macro.

---

## Code Style (summary — see `.claude/elixir-code-style.md`)

- Every `def` has a doctest (exempt: I/O, file writes, GenServer calls)
- Error returns: tagged tuples with specific atoms — never bare strings
- Private function names state intent: `defp reject_expired_tokens` not `defp filter`
- Rescue only specific exception types; log warnings on broad rescues
- No `IO.inspect` in committed code

## Testing (see `.claude/elixir-testing.md` and `.claude/test-contract.md`)

Every behavior branch tested. Existing tests are specifications — never modify to make them pass.

Before every commit:
```bash
mix compile --warnings-as-errors
mix test
mix format --check-formatted
```
