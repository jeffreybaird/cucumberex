defmodule Cucumberex.World do
  @moduledoc """
  World context: a plain map threaded through each scenario.
  Isolated per scenario — no state shared between scenarios.

  Modules registered with `world_module/1` have their functions imported
  into the world context namespace, accessible via `world.module_name.fun()`.

  Custom world factories can be registered globally.
  """

  @type t :: map()

  @doc """
  Creates a fresh world for a new scenario.

      iex> w = Cucumberex.World.new()
      iex> w.__tags__
      []
      iex> w = Cucumberex.World.new(%{db: :mock})
      iex> w.db
      :mock
  """
  def new(extra \\ %{}) do
    base = %{
      __tags__: [],
      __scenario_name__: nil,
      __feature_name__: nil
    }

    Map.merge(base, extra)
  end

  @doc """
  Sets scenario metadata on the world.

      iex> pickle = %{tags: [%{name: "@smoke"}], name: "Login", uri: "features/auth.feature"}
      iex> w = Cucumberex.World.set_scenario(%{}, pickle)
      iex> w.__tags__
      ["@smoke"]
      iex> w.__scenario_name__
      "Login"
  """
  def set_scenario(world, pickle) do
    tags = Enum.map(pickle.tags, & &1.name)

    world
    |> Map.put(:__tags__, tags)
    |> Map.put(:__scenario_name__, pickle.name)
    |> Map.put(:__uri__, pickle.uri)
  end

  @doc """
  Builds a world using the given factory, or a default empty world if nil.

      iex> w = Cucumberex.World.build(nil)
      iex> Map.has_key?(w, :__tags__)
      true
      iex> w = Cucumberex.World.build(fn -> %{custom: true} end)
      iex> w.custom
      true
  """
  def build(factory \\ nil) do
    case factory do
      nil -> new()
      fun when is_function(fun, 0) -> fun.()
      fun when is_function(fun, 1) -> fun.(new())
      _ -> new()
    end
  end
end

defmodule Cucumberex.World.Registry do
  @moduledoc "Global registry for the world factory function."

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def set_factory(server \\ __MODULE__, fun) do
    GenServer.call(server, {:set_factory, fun})
  end

  def get_factory(server \\ __MODULE__) do
    GenServer.call(server, :get_factory)
  end

  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end

  @impl true
  def init(nil) do
    {:ok, %{factory: nil}}
  end

  @impl true
  def handle_call({:set_factory, fun}, _from, state) do
    {:reply, :ok, %{state | factory: fun}}
  end

  @impl true
  def handle_call(:get_factory, _from, state) do
    {:reply, state.factory, state}
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{factory: nil}}
  end
end
