defmodule Cucumberex.Events.Bus do
  @moduledoc "Event bus: broadcast test lifecycle events to formatters."

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  # Subscribe a formatter pid; stored as {pid} so dispatch uses GenServer.cast
  def subscribe(bus, fmt_pid) when is_pid(fmt_pid) do
    GenServer.call(bus, {:subscribe, fmt_pid})
  end

  def broadcast(bus, event) do
    GenServer.cast(bus, {:broadcast, event})
  end

  # Synchronous barrier: blocks until all previously-cast broadcasts have been
  # dispatched to subscriber mailboxes. Call before flushing formatters so the
  # TestRunFinished event is guaranteed to be queued before :finish arrives.
  def drain(bus) do
    GenServer.call(bus, :drain)
  end

  @impl true
  def init([]) do
    {:ok, %{subscribers: []}}
  end

  @impl true
  def handle_call({:subscribe, fmt_pid}, _from, state) do
    {:reply, :ok, %{state | subscribers: [fmt_pid | state.subscribers]}}
  end

  @impl true
  def handle_call(:drain, _from, state) do
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:broadcast, event}, state) do
    Enum.each(state.subscribers, fn pid ->
      GenServer.cast(pid, {:event, event})
    end)

    {:noreply, state}
  end
end

defmodule Cucumberex.Events do
  @moduledoc "Event structs for the test lifecycle."

  defmodule TestRunStarted do
    @moduledoc false
    defstruct [:timestamp]
  end

  defmodule TestRunFinished do
    @moduledoc false
    defstruct [:timestamp, :success, :results]
  end

  defmodule FeatureLoaded do
    @moduledoc false
    defstruct [:uri, :feature]
  end

  defmodule TestCaseStarted do
    @moduledoc false
    defstruct [:pickle, :attempt]
  end

  defmodule TestCaseFinished do
    @moduledoc false
    defstruct [:pickle, :result, :attempt]
  end

  defmodule TestStepStarted do
    @moduledoc false
    defstruct [:pickle, :step, :step_def]
  end

  defmodule TestStepFinished do
    @moduledoc false
    defstruct [:pickle, :step, :step_def, :result]
  end

  defmodule HookStarted do
    @moduledoc false
    defstruct [:hook, :phase]
  end

  defmodule HookFinished do
    @moduledoc false
    defstruct [:hook, :phase, :result]
  end

  defmodule UndefinedStep do
    @moduledoc false
    defstruct [:pickle, :step, :snippet]
  end

  defmodule AmbiguousStep do
    @moduledoc false
    defstruct [:pickle, :step, :matches]
  end
end
