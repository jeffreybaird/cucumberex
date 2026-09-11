defmodule Cucumberex.Logging do
  @moduledoc """
  Keep stdout reserved for formatter payload.

  Machine-readable formatters (e.g. JSON) write their document to stdout, so
  any `Logger` output has to go elsewhere or it corrupts the payload. Routing
  logs to standard error is the conventional behaviour for a CLI test runner
  and guarantees stdout is only the formatter's output.
  """

  require Logger

  @doc """
  Send `Logger` output to standard error.

  Handles both the legacy `:console` backend (Elixir < 1.15) and the Erlang
  `:logger` default handler (Elixir >= 1.15). Best-effort: an unknown logging
  setup is left untouched rather than crashing the run. All I/O, so no doctest.
  """
  def route_to_stderr do
    if console_backend?() do
      Logger.configure_backend(:console, device: :standard_error)
    else
      route_default_handler()
    end
  end

  defp console_backend?, do: :console in Application.get_env(:logger, :backends, [])

  defp route_default_handler do
    case :logger.get_handler_config(:default) do
      {:ok, _config} ->
        :logger.update_handler_config(:default, :config, %{type: :standard_error})

      _ ->
        :ok
    end
  end
end
