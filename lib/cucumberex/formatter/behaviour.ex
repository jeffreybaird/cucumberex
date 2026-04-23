defmodule Cucumberex.Formatter do
  @moduledoc """
  Formatter behaviour for Cucumberex.

  Formatters are GenServers. The Events.Bus dispatches events via
  `GenServer.cast(pid, {:event, event})`. Implement private `on_event/2`
  clauses to handle each event type and update state.

  The runner calls `GenServer.call(pid, :finish)` after `TestRunFinished`
  to synchronously drain the formatter before the process exits.
  """

  @callback start_link(opts :: keyword()) :: {:ok, pid()} | {:error, any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Cucumberex.Formatter
      use GenServer

      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts)
      end

      @impl GenServer
      def handle_cast({:event, event}, state) do
        {:noreply, on_event(event, state)}
      end

      @impl GenServer
      def handle_call(:finish, _from, state) do
        {:reply, :ok, on_finish(state)}
      end

      defp on_finish(state), do: state

      defoverridable on_finish: 1
    end
  end
end

defmodule Cucumberex.Formatter.ANSI do
  @moduledoc "ANSI color helpers. Each function wraps `s` in an ANSI color then a reset."

  @doc """
  Wrap `s` in green ANSI codes.

  ## Examples

      iex> Cucumberex.Formatter.ANSI.green("x")
      IO.ANSI.green() <> "x" <> IO.ANSI.reset()
  """
  def green(s), do: IO.ANSI.green() <> s <> IO.ANSI.reset()

  @doc """
  Wrap `s` in red ANSI codes.

  ## Examples

      iex> Cucumberex.Formatter.ANSI.red("x")
      IO.ANSI.red() <> "x" <> IO.ANSI.reset()
  """
  def red(s), do: IO.ANSI.red() <> s <> IO.ANSI.reset()

  @doc """
  Wrap `s` in yellow ANSI codes.

  ## Examples

      iex> Cucumberex.Formatter.ANSI.yellow("x")
      IO.ANSI.yellow() <> "x" <> IO.ANSI.reset()
  """
  def yellow(s), do: IO.ANSI.yellow() <> s <> IO.ANSI.reset()

  @doc """
  Wrap `s` in cyan ANSI codes.

  ## Examples

      iex> Cucumberex.Formatter.ANSI.cyan("x")
      IO.ANSI.cyan() <> "x" <> IO.ANSI.reset()
  """
  def cyan(s), do: IO.ANSI.cyan() <> s <> IO.ANSI.reset()

  @doc """
  Wrap `s` in blue ANSI codes.

  ## Examples

      iex> Cucumberex.Formatter.ANSI.blue("x")
      IO.ANSI.blue() <> "x" <> IO.ANSI.reset()
  """
  def blue(s), do: IO.ANSI.blue() <> s <> IO.ANSI.reset()

  @doc """
  Wrap `s` in light-black (grey) ANSI codes.

  ## Examples

      iex> Cucumberex.Formatter.ANSI.grey("x")
      IO.ANSI.light_black() <> "x" <> IO.ANSI.reset()
  """
  def grey(s), do: IO.ANSI.light_black() <> s <> IO.ANSI.reset()

  @doc """
  Wrap `s` in bright (bold) ANSI codes.

  ## Examples

      iex> Cucumberex.Formatter.ANSI.bold("x")
      IO.ANSI.bright() <> "x" <> IO.ANSI.reset()
  """
  def bold(s), do: IO.ANSI.bright() <> s <> IO.ANSI.reset()

  @doc """
  Colorize `s` by result status. Unknown statuses return `s` unchanged.

  ## Examples

      iex> Cucumberex.Formatter.ANSI.colorize("ok", :passed) == Cucumberex.Formatter.ANSI.green("ok")
      true

      iex> Cucumberex.Formatter.ANSI.colorize("x", :unknown_status)
      "x"
  """
  def colorize(s, :passed), do: green(s)
  def colorize(s, :failed), do: red(s)
  def colorize(s, :pending), do: yellow(s)
  def colorize(s, :undefined), do: yellow(s)
  def colorize(s, :skipped), do: cyan(s)
  def colorize(s, :ambiguous), do: red(s)
  def colorize(s, _), do: s
end
