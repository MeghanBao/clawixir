defmodule Clawixir.Channels.TelegramPoller do
  @moduledoc """
  Supervised process representing the Telegram channel adapter lifecycle.

  Currently webhook-based (Meta pushes updates to us), so this process
  acts as a health-sentinel — it validates the bot token on startup and
  logs readiness. In future it can be upgraded to long-polling mode
  (useful for local dev without a public URL / ngrok).

  **Crash isolation**: this process is `:transient` — if it dies,
  only this supervisor child restarts. Telegram crashing does NOT
  affect WhatsApp, WebChat, or any user sessions.
  """

  use GenServer, restart: :transient
  require Logger

  alias Clawixir.Channels.Telegram

  @retry_interval_ms 15_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(_) do
    Logger.info("[TelegramPoller] starting — webhook mode")
    send(self(), :verify)
    {:ok, %{status: :starting}}
  end

  @impl true
  def handle_info(:verify, state) do
    token = Application.get_env(:clawixir, :telegram_bot_token)

    if is_nil(token) or token == "" do
      Logger.warning("[TelegramPoller] TELEGRAM_BOT_TOKEN not set — Telegram disabled")
      {:noreply, %{state | status: :disabled}}
    else
      case Telegram.verify_token(token) do
        {:ok, bot_name} ->
          Logger.info("[TelegramPoller] ✅ connected as @#{bot_name}")
          # Auto-register webhook if WEBHOOK_URL is configured
          maybe_register_webhook(token)
          {:noreply, %{state | status: :ok}}

        {:error, reason} ->
          Logger.warning("[TelegramPoller] token check failed: #{inspect(reason)} — retrying in #{@retry_interval_ms}ms")
          Process.send_after(self(), :verify, @retry_interval_ms)
          {:noreply, %{state | status: :retrying}}
      end
    end
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state.status, state}

  # ── Auto-webhook registration ───────────────────────────────────────────

  defp maybe_register_webhook(token) do
    case System.get_env("WEBHOOK_URL") do
      nil -> :ok
      "" -> :ok
      base_url ->
        url = String.trim_trailing(base_url, "/") <> "/api/webhooks/telegram"
        Logger.info("[TelegramPoller] registering webhook → #{url}")

        case Req.post("https://api.telegram.org/bot#{token}/setWebhook", json: %{url: url}) do
          {:ok, %{status: 200, body: %{"ok" => true}}} ->
            Logger.info("[TelegramPoller] ✅ webhook registered")

          {:ok, %{body: body}} ->
            Logger.warning("[TelegramPoller] webhook registration failed: #{inspect(body)}")

          {:error, reason} ->
            Logger.warning("[TelegramPoller] webhook registration error: #{inspect(reason)}")
        end
    end
  end
end
