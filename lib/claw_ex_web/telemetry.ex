defmodule ClawixirWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    # Attach audit event handlers (connects Audit.log -> Telemetry reporters)
    Clawixir.TelemetryHandler.attach_all()

    children = [
      # Periodic measurements
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix metrics
      summary("phoenix.endpoint.start.system_time", unit: {:native, :millisecond}),
      summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.router_dispatch.stop.duration", unit: {:native, :millisecond}),

      # VM metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Clawixir audit counters (from Clawixir.Audit.log/2 → TelemetryHandler)
      counter("clawixir.audit.message_received.count", tags: [:channel]),
      counter("clawixir.audit.llm_called.count",       tags: [:model]),
      counter("clawixir.audit.tool_called.count",       tags: [:tool]),
      counter("clawixir.audit.rate_limited.count",      tags: [:session]),
      counter("clawixir.audit.session_created.count"),
      counter("clawixir.audit.session_timeout.count"),
      counter("clawixir.audit.session_crashed.count",   tags: [:reason]),
      counter("clawixir.audit.service_up.count",        tags: [:service]),
      counter("clawixir.audit.service_down.count",      tags: [:service])
    ]
  end

  defp periodic_measurements do
    [
      {ClawixirWeb.Telemetry, :dispatch_stats, []}
    ]
  end

  def dispatch_stats do
    sessions = length(Clawixir.Gateway.list_sessions())
    :telemetry.execute([:clawixir, :sessions], %{count: sessions}, %{})
  end
end
