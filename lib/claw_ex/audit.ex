defmodule Clawixir.Audit do
  @moduledoc """
  Structured audit logger for all meaningful system events.

  Emits structured log lines and `:telemetry` events for every:
  - Inbound message received by a session
  - LLM call (with model, prompt token estimate)
  - Tool invocation (with name, duration, success/fail)
  - Rate-limit rejection
  - Session lifecycle (created, idle timeout, crashed)
  - External service state change (up/down)

  Audit records go to the Elixir Logger (structured JSON-like format) and can
  be forwarded to any log aggregator (Loki, Datadog, etc.) by configuring a
  Logger backend.

  ## Usage

      Clawixir.Audit.log(:message_received, %{session: key, channel: :telegram, length: 42})
      Clawixir.Audit.log(:tool_called, %{session: key, tool: "browser", duration_ms: 1200, ok: true})
      Clawixir.Audit.log(:rate_limited, %{session: key, retry_after_ms: 4500})
  """

  require Logger

  @events [
    :message_received,
    :llm_called,
    :tool_called,
    :rate_limited,
    :session_created,
    :session_timeout,
    :session_crashed,
    :service_up,
    :service_down
  ]

  @doc "Log a structured audit event. `event` must be one of #{inspect(@events)}."
  @spec log(atom(), map()) :: :ok
  def log(event, meta \\ %{}) when event in @events do
    ts = DateTime.utc_now() |> DateTime.to_iso8601()

    record =
      meta
      |> Map.put(:event, event)
      |> Map.put(:ts, ts)

    Logger.info(fn -> "[Audit] " <> format_record(record) end,
      audit: true,
      event: event
    )

    :telemetry.execute(
      [:clawixir, :audit, event],
      %{count: 1},
      Map.put(record, :event, event)
    )

    :ok
  end

  def log(event, _meta) do
    Logger.warning("[Audit] unknown event: #{inspect(event)}")
    :ok
  end

  # ─── Formatting ─────────────────────────────────────────────────────────────

  defp format_record(map) do
    map
    |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v)}" end)
    |> Enum.join(" ")
  end
end
