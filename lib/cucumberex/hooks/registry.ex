defmodule Cucumberex.Hooks.Registry do
  @moduledoc "GenServer registry for all hooks."

  use GenServer

  alias Cucumberex.Hook

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def register(server \\ __MODULE__, %Hook{} = hook) do
    GenServer.call(server, {:register, hook})
  end

  def for_phase(server \\ __MODULE__, phase) do
    GenServer.call(server, {:for_phase, phase})
  end

  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end

  @impl true
  def init([]) do
    {:ok, %{hooks: []}}
  end

  @impl true
  def handle_call({:register, hook}, _from, state) do
    {:reply, :ok, %{state | hooks: [hook | state.hooks]}}
  end

  @impl true
  def handle_call({:for_phase, phase}, _from, state) do
    hooks =
      state.hooks
      |> Enum.filter(&(&1.phase == phase))
      |> Enum.sort_by(& &1.order)

    {:reply, hooks, state}
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{hooks: []}}
  end
end
