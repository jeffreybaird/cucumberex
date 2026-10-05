defmodule Cucumberex.RetryTest do
  @moduledoc """
  `--retry N` must label each attempt of a scenario with its attempt number
  and whether another attempt will follow.
  """

  use ExUnit.Case

  alias Cucumberex.Events
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
