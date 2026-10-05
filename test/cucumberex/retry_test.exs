defmodule Cucumberex.RetryTest do
  @moduledoc """
  `--retry N` must label each attempt of a scenario with its attempt number
  and whether another attempt will follow.
  """

  use ExUnit.Case

  alias Cucumberex.Events
  alias Cucumberex.Formatter.{HTML, JSON, JUnit, Pretty, Progress, Rerun}
  alias Cucumberex.Test.EventRecorder

  defmodule Steps do
    use Cucumberex.DSL

    given_("a retry step that always fails", fn _world -> raise "always fails" end)

    given_("a retry step that fails only the first time", fn world ->
      if Agent.get_and_update(Cucumberex.RetryTest.Calls, &{&1, &1 + 1}) == 0,
        do: raise("first attempt fails")

      world
    end)

    given_("a retry step that passes", fn world -> world end)
  end

  @feature "test/fixtures/features/retry/retry.feature"

  setup_all do
    Cucumberex.DSL.load_module(Steps)
    :ok
  end

  setup do
    start_supervised!(%{
      id: :calls,
      start: {Agent, :start_link, [fn -> 0 end, [name: __MODULE__.Calls]]}
    })

    :ok
  end

  describe "attempts on test case events" do
    test "a scenario that keeps failing is attempted retry + 1 times" do
      events = run_recorded("@always_fails", 2)

      assert started_attempts(events) == [0, 1, 2]
      assert finished_attempts(events) == [{0, true}, {1, true}, {2, false}]
    end

    test "a scenario stops retrying once it passes" do
      events = run_recorded("@flaky", 2)

      assert started_attempts(events) == [0, 1]
      assert finished_attempts(events) == [{0, true}, {1, false}]
    end

    test "a passing scenario runs once and is not retried" do
      events = run_recorded("@passes", 2)

      assert started_attempts(events) == [0]
      assert finished_attempts(events) == [{0, false}]
    end

    test "without --retry a failing scenario runs once and is not retried" do
      events = run_recorded("@always_fails", 0)

      assert started_attempts(events) == [0]
      assert finished_attempts(events) == [{0, false}]
    end
  end

  describe "formatters report only each scenario's final attempt" do
    test "pretty counts a retried failing scenario once" do
      assert run_output(Pretty, "@always_fails", 2) =~ "1 scenario, 1 failed\n"
    end

    test "pretty counts a scenario that passed on retry as passed" do
      assert run_output(Pretty, "@flaky", 1) =~ "1 scenario, 1 passed\n"
    end

    test "progress counts a retried failing scenario once and lists its failure once" do
      output = run_output(Progress, "@always_fails", 2)

      assert output =~ "1 scenarios (0 passed, 1 failed, 0 pending, 0 undefined)"
      assert length(String.split(output, "** (RuntimeError) always fails")) == 2
    end

    test "progress lists no failure for a scenario that passed on retry" do
      output = run_output(Progress, "@flaky", 1)

      assert output =~ "1 scenarios (1 passed, 0 failed, 0 pending, 0 undefined)"
      refute output =~ "Failures:"
    end

    test "json reports a retried scenario once, with its final steps" do
      [feature] = "@flaky" |> run_to_file(JSON, 1) |> Jason.decode!()

      assert [%{"steps" => [%{"result" => %{"status" => "passed"}}]}] = feature["elements"]
    end

    test "junit reports a retried scenario as one passing testcase" do
      xml = run_to_file("@flaky", JUnit, 1)

      assert length(String.split(xml, "<testcase")) == 2
      refute xml =~ "<failure"
    end

    test "html reports a retried scenario once" do
      html = run_to_file("@always_fails", HTML, 2)

      assert length(String.split(html, "Always fails")) == 2
    end

    test "rerun does not list a scenario that passed on retry" do
      path = tmp_path("rerun.txt")
      run_with_formatter("@flaky", 1, {Rerun, [output: path]})

      refute File.exists?(path)
    end
  end

  defp run_output(formatter, tags, retry) do
    run_with_formatter(tags, retry, {formatter, [output: self(), color: false]})
    collect_output()
  end

  defp run_to_file(tags, formatter, retry) do
    path = tmp_path("report")
    run_with_formatter(tags, retry, {formatter, [output: path]})
    File.read!(path)
  end

  defp run_with_formatter(tags, retry, formatter) do
    %Cucumberex.Config{}
    |> Map.from_struct()
    |> Map.merge(%{paths: [@feature], tags: tags, retry: retry, formatters: [formatter]})
    |> Cucumberex.Runner.run()
  end

  defp tmp_path(name) do
    path = Path.join(System.tmp_dir!(), "cuc_retry_#{System.unique_integer([:positive])}_#{name}")
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp collect_output(acc \\ []) do
    receive do
      {:formatter_output, s} -> collect_output([s | acc])
    after
      0 -> acc |> Enum.reverse() |> IO.iodata_to_binary()
    end
  end

  defp run_recorded(tags, retry) do
    %Cucumberex.Config{}
    |> Map.from_struct()
    |> Map.merge(%{
      paths: [@feature],
      tags: tags,
      retry: retry,
      formatters: [{EventRecorder, [to: self()]}]
    })
    |> Cucumberex.Runner.run()

    EventRecorder.flush()
  end

  defp started_attempts(events),
    do: for(%Events.TestCaseStarted{attempt: a} <- events, do: a)

  defp finished_attempts(events),
    do: for(%Events.TestCaseFinished{attempt: a, will_be_retried: r} <- events, do: {a, r})
end
