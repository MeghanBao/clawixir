defmodule Clawixir.Channels.Supervisor do
  @moduledoc """
  Top-level supervisor for all channel adapter processes.

  ## Crash Isolation Strategy

  Uses `:one_for_one` so each channel is fully independent:

      TelegramPoller  ──┐
                        ├── one_for_one ── if Telegram dies, WhatsApp keeps running
      WhatsAppMonitor ──┘

  Each child has `restart: :transient` (defined on the child module itself),
  meaning it restarts on abnormal exits but stays down if it shut down cleanly
  (e.g. credentials deliberately disabled).

  **This is the key differentiator vs Go/Rust *Claw rewrites**: a panic in
  the Telegram adapter there can cascade to the whole process. Here it's a
  2-second restart of one supervised child.
  """

  use Supervisor

  def start_link(_opts), do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init(_) do
    children = [
      # Telegram channel sentinel (validates bot token, logs readiness)
      {Clawixir.Channels.TelegramPoller, []},

      # WhatsApp channel monitor (validates Meta credentials periodically)
      {Clawixir.Channels.WhatsAppMonitor, []}

      # Future channels: Matrix, Discord, Signal, etc.
      # {Clawixir.Channels.MatrixPoller, []},
    ]

    # one_for_one: each channel is crash-isolated from every other
    Supervisor.init(children, strategy: :one_for_one)
  end
end
