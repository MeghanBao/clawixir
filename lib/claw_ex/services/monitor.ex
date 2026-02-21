defmodule Clawixir.Services.Monitor do
  @moduledoc """
  Periodically health-checks external services (Browser Service, AI Service)
  and maintains a shared availability status in ETS.

  Other modules query health via:

      Clawixir.Services.Monitor.available?(:browser)   # → true | false
      Clawixir.Services.Monitor.available?(:ai)

  If a service goes down and comes back up, a log message is emitted.
  This lets the Gateway degrade gracefully — e.g. skip browser skills if
  the browser service is unreachable, rather than letting every tool call time out.

  Checks every 15 seconds by default.
  """

  use GenServer
  require Logger

  alias Clawixir.BrowserClient
  alias Clawixir.Services.AiClient

  @check_interval_ms 15_000
  @name __MODULE__
  @table :service_health

  # ─── Public API ────────────────────────────────────────────────────────────

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: @name)

  @spec available?(atom()) :: boolean()
  def available?(service) do
    case :ets.lookup(@table, service) do
      [{^service, status}] -> status == :up
      []                   -> false
    end
  end

  @spec status() :: map()
  def status do
    :ets.tab2list(@table) |> Map.new()
  end

  # ─── GenServer callbacks ────────────────────────────────────────────────────

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    :ets.insert(@table, {:browser, :unknown})
    :ets.insert(@table, {:ai, :unknown})

    # First check immediately
    send(self(), :check)

    {:ok, %{}}
  end

  @impl true
  def handle_info(:check, state) do
    check_service(:browser, fn -> BrowserClient.health() end)
    check_service(:ai,      fn -> AiClient.health() end)

    Process.send_after(self(), :check, @check_interval_ms)
    {:noreply, state}
  end

  # ─── Internal ───────────────────────────────────────────────────────────────

  defp check_service(name, health_fn) do
    previous =
      case :ets.lookup(@table, name) do
        [{^name, s}] -> s
        []           -> :unknown
      end

    current =
      case health_fn.() do
        :ok              -> :up
        {:error, _}      -> :down
      end

    :ets.insert(@table, {name, current})

    cond do
      previous != :up   and current == :up   -> Logger.info("[ServiceMonitor] ✅ #{name} is UP")
      previous == :up   and current == :down -> Logger.warning("[ServiceMonitor] ⚠️  #{name} went DOWN")
      previous == :unknown                   -> Logger.info("[ServiceMonitor] #{name} initial status: #{current}")
      true -> :ok
    end
  end
end
