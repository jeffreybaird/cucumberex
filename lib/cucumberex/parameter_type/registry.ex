defmodule Cucumberex.ParameterType.Registry do
  @moduledoc "Registry for parameter types used in Cucumber Expressions."

  use GenServer

  alias Cucumberex.ParameterType.BuiltIn

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def register(server \\ __MODULE__, pt) do
    GenServer.call(server, {:register, pt})
  end

  def all(server \\ __MODULE__) do
    GenServer.call(server, :all)
  end

  def find(server \\ __MODULE__, name) do
    GenServer.call(server, {:find, name})
  end

  @impl true
  def init([]) do
    state = %{types: %{}}
    state = register_built_ins(state)
    {:ok, state}
  end

  @impl true
  def handle_call({:register, pt}, _from, state) do
    {:reply, :ok, put_in(state, [:types, pt.name], pt)}
  end

  @impl true
  def handle_call(:all, _from, state) do
    {:reply, Map.values(state.types), state}
  end

  @impl true
  def handle_call({:find, name}, _from, state) do
    {:reply, Map.get(state.types, name), state}
  end

  defp register_built_ins(state) do
    Enum.reduce(BuiltIn.all(), state, fn pt, acc ->
      put_in(acc, [:types, pt.name], pt)
    end)
  end
end
