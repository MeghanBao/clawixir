defmodule Clawixir.Channels.WhatsAppMonitor do
  @moduledoc """
  Supervised process representing the WhatsApp channel adapter lifecycle.

  On startup, validates that the required Meta Cloud API credentials are
  configured. If credentials are missing, logs a warning and stays idle
  (does not crash — crash would trigger a supervisor restart loop).

  **Crash isolation**: `:transient` restart — a WhatsApp API error does
  NOT restart Telegram, WebChat, or any user sessions.

  Future: can poll `GET /phone_numbers/{id}` for rate-limit headroom,
  subscribe to Meta webhook health events, etc.
  """

  use GenServer, restart: :transient
  require Logger

  @graph_url "https://graph.facebook.com/v19.0"
  @check_interval_ms 60_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(_) do
    Logger.info("[WhatsAppMonitor] starting")
    send(self(), :verify)
    {:ok, %{status: :starting}}
  end

  @impl true
  def handle_info(:verify, state) do
    token   = Application.get_env(:clawixir, :whatsapp_access_token)
    phone_id = Application.get_env(:clawixir, :whatsapp_phone_number_id)

    cond do
      is_nil(token) or token == "" ->
        Logger.warning("[WhatsAppMonitor] WHATSAPP_ACCESS_TOKEN not set — WhatsApp disabled")
        {:noreply, %{state | status: :disabled}}

      is_nil(phone_id) or phone_id == "" ->
        Logger.warning("[WhatsAppMonitor] WHATSAPP_PHONE_NUMBER_ID not set — WhatsApp disabled")
        {:noreply, %{state | status: :disabled}}

      true ->
        case verify_credentials(token, phone_id) do
          {:ok, display_name} ->
            Logger.info("[WhatsAppMonitor] ✅ connected: #{display_name}")
            Process.send_after(self(), :verify, @check_interval_ms)
            {:noreply, %{state | status: :ok}}

          {:error, reason} ->
            Logger.warning("[WhatsAppMonitor] credential check failed: #{inspect(reason)}")
            Process.send_after(self(), :verify, @check_interval_ms)
            {:noreply, %{state | status: :degraded}}
        end
    end
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state.status, state}

  # ─── Internal ───────────────────────────────────────────────────────────────

  defp verify_credentials(token, phone_id) do
    url = "#{@graph_url}/#{phone_id}"
    case Req.get(url, headers: [{"authorization", "Bearer #{token}"}]) do
      {:ok, %{status: 200, body: %{"verified_name" => name}}} -> {:ok, name}
      {:ok, %{status: status, body: body}} ->
        msg = get_in(body, ["error", "message"]) || "HTTP #{status}"
        {:error, msg}
      {:error, _} -> {:error, :unreachable}
    end
  end
end
