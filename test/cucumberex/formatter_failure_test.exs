defmodule Cucumberex.FormatterFailureTest do
  @moduledoc """
  Runs a feature with a deliberately raising step through each formatter and
  asserts the exception, its message, the step location, the backtrace, file
  output, stdout purity, and the exit status are all reported correctly.
  """

  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Cucumberex.Formatter.{JSON, Pretty, Progress}

  defmodule Steps do
    use Cucumberex.DSL

    given_("the world is missing a key", fn world ->
      Map.fetch!(world, :definitely_missing)
    end)
  end

  @feature "test/fixtures/features/raising.feature"

  setup_all do
    Cucumberex.DSL.load_module(Steps)
    :ok
  end

  # Build a runtime config (a plain map, as the loader produces) for the
  # raising feature, with color off so assertions match raw text.
  defp config(extra) do
    %Cucumberex.Config{}
    |> Map.from_struct()
    |> Map.merge(%{paths: [@feature], color: false})
    |> Map.merge(Map.new(extra))
  end

  defp run(extra), do: Cucumberex.Runner.run(config(extra))

  # Formatters given `output: self()` send every write as a message; drain them.
  defp collect_output(acc \\ []) do
    receive do
      {:formatter_output, s} -> collect_output([s | acc])
    after
      0 -> acc |> Enum.reverse() |> IO.iodata_to_binary()
    end
  end

  describe "pretty formatter" do
    test "prints the exception module, message, and step location for a failed step" do
      run(formatters: [{Pretty, [output: self()]}])
      output = collect_output()

      assert output =~ "** (KeyError)"
      assert output =~ "key :definitely_missing not found"
      assert output =~ "at test/cucumberex/formatter_failure_test.exs:"
      assert output =~ "1 scenario, 1 failed"
      # No stacktrace without --backtrace.
      refute output =~ "stacktrace:"
    end

    test "prints the backtrace when backtrace is enabled" do
      run(formatters: [{Pretty, [output: self()]}], backtrace: true)
      output = collect_output()

      assert output =~ "** (KeyError)"
      assert output =~ "stacktrace:"
      assert output =~ "formatter_failure_test.exs:"
    end
  end

  describe "progress formatter" do
    test "prints a failures section with the exception and location before the summary" do
      run(formatters: [{Progress, [output: self()]}])
      output = collect_output()

      assert output =~ "F"
      assert output =~ "Failures:"
      assert output =~ "** (KeyError)"
      assert output =~ "key :definitely_missing not found"
      assert output =~ "at test/cucumberex/formatter_failure_test.exs:"

      # The failures section comes before the summary line.
      failures_at = :binary.match(output, "Failures:") |> elem(0)
      summary_at = :binary.match(output, "1 scenarios") |> elem(0)
      assert failures_at < summary_at
    end

    test "prints the backtrace when backtrace is enabled" do
      run(formatters: [{Progress, [output: self()]}], backtrace: true)
      output = collect_output()

      assert output =~ "stacktrace:"
    end
  end

  describe "json formatter" do
    test "--out writes the report file, with the exception in the error_message" do
      path = Path.join(System.tmp_dir!(), "cuc_#{System.unique_integer([:positive])}.json")
      on_exit(fn -> File.rm(path) end)

      # `:output` in config mirrors the `--out FILE` CLI flag; it must reach the
      # formatter even though the formatter itself was given no explicit output.
      run(formatters: [{JSON, []}], output: path)

      assert File.exists?(path)
      report = path |> File.read!() |> Jason.decode!()

      error = json_step_error(report)
      assert error =~ "(KeyError)"
      assert error =~ "key :definitely_missing not found"
    end

    test "stdout carries only JSON" do
      stdout =
        capture_io(fn ->
          run(formatters: [{JSON, [output: "-"]}])
        end)

      # The entire stdout must parse as JSON — nothing else may be interleaved.
      report = Jason.decode!(stdout)
      assert json_step_error(report) =~ "(KeyError)"
    end
  end

  test "exit status is non-zero when a step fails" do
    assert run(formatters: [{Progress, [output: self()]}]) == 1
    _ = collect_output()
  end

  describe "log routing" do
    setup do
      on_exit(fn -> Logger.configure_backend(:console, device: :user) end)
      :ok
    end

    test "route_to_stderr/0 sends Logger output to stderr, keeping stdout clean" do
      require Logger

      Cucumberex.Logging.route_to_stderr()

      stdout =
        capture_io(fn ->
          stderr =
            capture_io(:standard_error, fn ->
              Logger.warning("log_line_marker")
              Logger.flush()
            end)

          send(self(), {:stderr, stderr})
        end)

      assert_received {:stderr, stderr}
      assert stderr =~ "log_line_marker"
      refute stdout =~ "log_line_marker"
    end
  end

  defp json_step_error(report) do
    report
    |> hd()
    |> Map.fetch!("elements")
    |> hd()
    |> Map.fetch!("steps")
    |> hd()
    |> get_in(["result", "error_message"])
  end
end
