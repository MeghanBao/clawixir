defmodule Clawixir.TelemetryHandler do
  @moduledoc """
  Attaches to all audit telemetry events and forwards them to
  `telemetry_metrics` reporters (e.g. Prometheus, StatsD, LiveDashboard).

  This is the bridge that makes `Clawixir.Audit.log/2` observable from
  external monitoring tools — not just Elixir Logger.

  ## What gets measured

  | Metric | Type | Tags |
  |--------|------|------|
  | `clawixir.audit.message_received` | counter | `channel` |
  | `clawixir.audit.llm_called`       | counter | `model` |
  | `clawixir.audit.tool_called`      | counter | `tool`, `ok` |
  | `clawixir.audit.rate_limited`     | counter | `session` |
  | `clawixir.audit.session_created`  | counter | — |
  | `clawixir.audit.session_timeout`  | counter | — |
  | `clawixir.audit.session_crashed`  | counter | `reason` |
  | `clawixir.audit.service_up`       | counter | `service` |
  | `clawixir.audit.service_down`     | counter | `service` |

  These metrics plug directly into `ClawixirWeb.Telemetry` where
  `telemetry_metrics` defines them for LiveDashboard / Prometheus.

  ## Adding Prometheus

      # mix.exs
      {:telemetry_metrics_prometheus_core, "~> 1.1"}
      {:telemetry_metrics_statsd, "~> 0.7"}   # for StatsD/DataDog

  Then add to `ClawixirWeb.Telemetry.metrics/0`:

      counter("clawixir.audit.message_received.count", tags: [:channel]),
      counter("clawixir.audit.tool_called.count", tags: [:tool, :ok]),
      ...
  """

  require Logger

  @audit_events [
    [:clawixir, :audit, :message_received],
    [:clawixir, :audit, :llm_called],
    [:clawixir, :audit, :tool_called],
    [:clawixir, :audit, :rate_limited],
    [:clawixir, :audit, :session_created],
    [:clawixir, :audit, :session_timeout],
    [:clawixir, :audit, :session_crashed],
    [:clawixir, :audit, :service_up],
    [:clawixir, :audit, :service_down]
  ]

  @doc "Attach all audit telemetry handlers. Called once from `ClawixirWeb.Telemetry.init/1`."
  def attach_all do
    :telemetry.attach_many(
      "claw-ex-audit-handler",
      @audit_events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  @doc false
  def handle_event([:clawixir, :audit, event], measurements, metadata, _config) do
    # Drop a structured log line — useful for log aggregators (Loki, CloudWatch)
    log_fields =
      metadata
      |> Map.put(:event, event)
      |> Map.put(:count, Map.get(measurements, :count, 1))
      |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v)}" end)
      |> Enum.join(" ")

    Logger.info("[Telemetry] #{log_fields}", audit: true, event: event)

    # Plug into any attached reporters (LiveDashboard, Prometheus, StatsD)
    # reporters receive the event via :telemetry.execute — this handler just
    # adds an extra structured log line on top.
    :ok
  end
end
