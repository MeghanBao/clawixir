defmodule Clawixir.Services.BrowserProcess do
  @moduledoc """
  Supervises the Node.js Playwright browser service as an Elixir Port.

  When this GenServer starts, it spawns `node browser_service/src/server.js`
  as a child OS process. When the GenServer stops (because the application
  is shutting down or the supervisor restarts it), the Port — and the Node.js
  process — is killed automatically by the BEAM.

  This means `mix phx.server` starts ALL three tiers:

      BEAM starts → Clawixir.Services.BrowserProcess starts
                  → Port.open("node browser_service/src/server.js")
                  → Node.js HTTP server listening on :4001

  ## Upgrade path

  For production, replace Port with `MuonTrap`:

      {:muontrap, "~> 1.0"}

  MuonTrap uses cgroups to guarantee the subprocess dies even if the BEAM
  is kill -9'd (Port leaves zombie processes on a hard kill).

  ## Configuration

      config :clawixir, :browser_process,
        enabled: true,           # set false to use external service instead
        command: "node",
        args: ["browser_service/src/server.js"],
        port: 4001

  Set `enabled: false` if you prefer to run the browser service separately.
  """

  use GenServer, restart: :transient
  require Logger

  @name __MODULE__

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: @name)

  # ─── GenServer callbacks ────────────────────────────────────────────────────

  @impl true
  def init(_) do
    cfg = Application.get_env(:clawixir, :browser_process, [])

    if Keyword.get(cfg, :enabled, true) do
      start_node_process(cfg)
    else
      Logger.info("[BrowserProcess] disabled — using external service")
      {:ok, %{port: nil, enabled: false}}
    end
  end

  @impl true
  def handle_info({port, {:data, {:line, line}}}, %{port: port} = state) do
    Logger.info("[BrowserService] #{line}")
    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:exit_status, 0}}, %{port: port} = state) do
    Logger.info("[BrowserProcess] Node.js process exited cleanly")
    {:stop, :normal, %{state | port: nil}}
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("[BrowserProcess] Node.js crashed with exit status #{status} — supervisor will restart")
    {:stop, {:browser_crashed, status}, %{state | port: nil}}
  end

  # Generic port message (binary data without line mode): log and continue
  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) when is_binary(data) do
    Logger.debug("[BrowserService] #{String.trim(data)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[BrowserProcess] unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{port: port}) when not is_nil(port) do
    Logger.info("[BrowserProcess] terminating — closing Node.js Port")
    Port.close(port)
  end

  def terminate(_reason, _state), do: :ok

  # ─── Internal ───────────────────────────────────────────────────────────────

  defp start_node_process(cfg) do
    cmd    = Keyword.get(cfg, :command, "node")
    args   = Keyword.get(cfg, :args, ["browser_service/src/server.js"])
    port_n = Keyword.get(cfg, :port, 4001)

    env = [
      {~c"PORT", to_charlist(to_string(port_n))}
    ]

    # Resolve executable path
    case System.find_executable(cmd) do
      nil ->
        Logger.warning("[BrowserProcess] '#{cmd}' not found in PATH — browser service disabled")
        {:ok, %{port: nil, enabled: false}}

      exe ->
        Logger.info("[BrowserProcess] starting Node.js browser service on port #{port_n}")

        port =
          Port.open(
            {:spawn_executable, exe},
            [
              :binary,
              :exit_status,
              {:line, 4096},
              {:args, args},
              {:env, env},
              {:cd, File.cwd!()}
            ]
          )

        {:ok, %{port: port, enabled: true}}
    end
  end
end
