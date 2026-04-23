defmodule Cucumberex.StepDefinition.Registry do
  @moduledoc "GenServer registry for step definitions."

  use GenServer

  alias Cucumberex.StepDefinition

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def register(server \\ __MODULE__, %StepDefinition{} = step_def) do
    GenServer.call(server, {:register, step_def})
  end

  def all(server \\ __MODULE__) do
    GenServer.call(server, :all)
  end

  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end

  @impl true
  def init([]) do
    {:ok, %{steps: []}}
  end

  @impl true
  def handle_call({:register, step_def}, _from, state) do
    {:reply, :ok, %{state | steps: [step_def | state.steps]}}
  end

  @impl true
  def handle_call(:all, _from, state) do
    {:reply, Enum.reverse(state.steps), state}
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{steps: []}}
  end
end
