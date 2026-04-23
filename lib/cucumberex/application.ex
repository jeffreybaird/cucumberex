defmodule Cucumberex.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Cucumberex.StepDefinition.Registry, name: Cucumberex.StepDefinition.Registry},
      {Cucumberex.Hooks.Registry, name: Cucumberex.Hooks.Registry},
      {Cucumberex.ParameterType.Registry, name: Cucumberex.ParameterType.Registry},
      {Cucumberex.World.Registry, name: Cucumberex.World.Registry}
    ]

    opts = [strategy: :one_for_one, name: Cucumberex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
