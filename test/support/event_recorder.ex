defmodule Cucumberex.Test.EventRecorder do
  @moduledoc """
  Test formatter that forwards every event it receives to a pid, so tests can
  assert on the exact event stream a run produced.

  Start it with `{Cucumberex.Test.EventRecorder, [to: self()]}`; each event
  arrives as `{:cucumberex_event, event}`.
  """

  use Cucumberex.Formatter

  @impl GenServer
  def init(opts), do: {:ok, Keyword.fetch!(opts, :to)}

  defp on_event(event, pid) do
    send(pid, {:cucumberex_event, event})
    pid
  end

  @doc """
  Drain the recorded events from the calling process's mailbox, in order.
  """
  def flush(acc \\ []) do
    receive do
      {:cucumberex_event, event} -> flush([event | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
