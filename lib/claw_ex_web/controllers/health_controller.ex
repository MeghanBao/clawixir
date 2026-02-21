defmodule ClawixirWeb.HealthController do
  @moduledoc "Health check — returns gateway and external service status."
  use ClawixirWeb, :controller

  alias Clawixir.Services.Monitor

  def index(conn, _params) do
    sessions = length(Clawixir.Gateway.list_sessions())
    services = Monitor.status()

    status =
      if Enum.all?([:browser, :ai], &(Map.get(services, &1) != :down)) do
        "ok"
      else
        "degraded"
      end

    conn
    |> put_status(:ok)
    |> json(%{
      status:          status,
      active_sessions: sessions,
      services: %{
        browser: to_string(Map.get(services, :browser, :unknown)),
        ai:      to_string(Map.get(services, :ai, :unknown))
      }
    })
  end
end
