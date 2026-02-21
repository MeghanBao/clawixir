defmodule Clawixir.Gateway do
  @moduledoc """
  Central control plane for Clawixir.

  Responsibilities:
  - Receive inbound messages from channel adapters
  - Route each message to the correct `Clawixir.Agent.Session`
  - Spawn a new session if one doesn't exist for the (channel, user_id) pair
  - Track active sessions in `Clawixir.SessionRegistry`

  ## Message format

  All channel adapters must call `Clawixir.Gateway.dispatch/1` with a map:

      %{
        channel:  :telegram | :slack | :discord | :webchat | :whatsapp,
        user_id:  "string",
        text:     "user message text",
        metadata: %{}   # channel-specific extras (username, chat_id, etc.)
      }
  """

  use GenServer
  require Logger

  alias Clawixir.Agent.Session

  @name __MODULE__

  # ─── Public API ────────────────────────────────────────────────────────────

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: @name)

  @doc "Dispatch an inbound message from a channel adapter to the right session."
  @spec dispatch(map()) :: :ok
  def dispatch(message), do: GenServer.cast(@name, {:dispatch, message})

  @doc "List all active sessions as [{session_key, pid}]."
  def list_sessions do
    Registry.select(Clawixir.SessionRegistry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
  end

  # ─── GenServer callbacks ────────────────────────────────────────────────────

  @impl true
  def init(state) do
    Logger.info("[Gateway] started")
    {:ok, state}
  end

  @impl true
  def handle_cast({:dispatch, %{channel: channel, user_id: user_id} = msg}, state) do
    session_key = session_key(channel, user_id)

    pid =
      case Registry.lookup(Clawixir.SessionRegistry, session_key) do
        [{pid, _}] ->
          pid

        [] ->
          {:ok, pid} =
            DynamicSupervisor.start_child(
              Clawixir.SessionSupervisor,
              {Session, %{key: session_key, channel: channel, user_id: user_id}}
            )

          Logger.info("[Gateway] new session #{session_key} -> #{inspect(pid)}")
          pid
      end

    Session.ingest(pid, msg)
    {:noreply, state}
  end

  # ─── Helpers ───────────────────────────────────────────────────────────────

  defp session_key(channel, user_id), do: "#{channel}:#{user_id}"
end
