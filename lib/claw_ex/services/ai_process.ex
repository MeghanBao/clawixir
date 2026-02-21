defmodule Clawixir.Services.AiProcess do
  @moduledoc """
  Supervises the optional Python AI/RAG service as an Elixir Port.

  Same pattern as `Clawixir.Services.BrowserProcess`: the Python process is
  a child of the Elixir supervision tree — it starts, stops, and restarts
  with the BEAM.

  ## Configuration

      config :clawixir, :ai_process,
        enabled: false,          # opt-in (AI service is optional)
        command: "python",
        args: ["-m", "ai_service.main"],
        port: 5001

  Set `enabled: true` to have Elixir manage the Python process automatically.
  Set `enabled: false` to start the Python service separately (or not use it).
  """

  use GenServer, restart: :transient
  require Logger

  @name __MODULE__

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: @name)

  @impl true
  def init(_) do
    cfg = Application.get_env(:clawixir, :ai_process, [])

    if Keyword.get(cfg, :enabled, false) do
      start_python_process(cfg)
    else
      Logger.info("[AiProcess] disabled — using external AI service or none")
      {:ok, %{port: nil, enabled: false}}
    end
  end

  @impl true
  def handle_info({port, {:data, {:line, line}}}, %{port: port} = state) do
    Logger.info("[AiService] #{line}")
    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    if status == 0 do
      Logger.info("[AiProcess] Python process exited cleanly")
      {:stop, :normal, %{state | port: nil}}
    else
      Logger.error("[AiProcess] Python service crashed (exit #{status}) — supervisor will restart")
      {:stop, {:ai_crashed, status}, %{state | port: nil}}
    end
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) when is_binary(data) do
    Logger.debug("[AiService] #{String.trim(data)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{port: port}) when not is_nil(port) do
    Logger.info("[AiProcess] terminating — closing Python Port")
    Port.close(port)
  end

  def terminate(_reason, _state), do: :ok

  # ─── Internal ───────────────────────────────────────────────────────────────

  defp start_python_process(cfg) do
    cmd    = Keyword.get(cfg, :command, "python3")
    args   = Keyword.get(cfg, :args, ["-m", "ai_service.main"])
    port_n = Keyword.get(cfg, :port, 5001)

    env = [{~c"PORT", to_charlist(to_string(port_n))}]

    case System.find_executable(cmd) do
      nil ->
        Logger.warning("[AiProcess] '#{cmd}' not found in PATH — AI service disabled")
        {:ok, %{port: nil, enabled: false}}

      exe ->
        Logger.info("[AiProcess] starting Python AI service on port #{port_n}")

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
