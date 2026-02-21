defmodule Clawixir.Channels.Telegram do
  @moduledoc """
  Telegram channel adapter.

  Incoming webhooks arrive at POST /webhooks/telegram and are dispatched via
  `Clawixir.Gateway.dispatch/1`. Outgoing replies use the Bot API sendMessage endpoint.

  Required env: TELEGRAM_BOT_TOKEN
  """
  @behaviour Clawixir.Channels.Adapter

  require Logger

  @base_url "https://api.telegram.org"

  # ─── Inbound (called by WebhookController) ─────────────────────────────────

  @doc "Parse a raw Telegram update and dispatch it to the Gateway."
  def handle_update(%{"message" => %{"text" => text, "from" => from, "chat" => chat}}) do
    Clawixir.Gateway.dispatch(%{
      channel:  :telegram,
      user_id:  Integer.to_string(from["id"]),
      text:     text,
      metadata: %{chat_id: chat["id"], username: from["username"]}
    })
  end
  def handle_update(_), do: :ignored

  @doc "Validate a bot token by calling getMe. Returns {:ok, bot_username} or {:error, reason}."
  def verify_token(token) do
    case Req.get("#{@base_url}/bot#{token}/getMe") do
      {:ok, %{status: 200, body: %{"result" => %{"username" => name}}}} -> {:ok, name}
      {:ok, %{status: status}} -> {:error, {:http, status}}
      {:error, _} -> {:error, :unreachable}
    end
  end

  # ─── Outbound ───────────────────────────────────────────────────────────────

  @impl true
  def send_message(_user_id, %{metadata: %{chat_id: chat_id}}, text) do
    token = Application.get_env(:clawixir, :telegram_bot_token)
    url   = "#{@base_url}/bot#{token}/sendMessage"

    case Req.post(url, json: %{chat_id: chat_id, text: text, parse_mode: "Markdown"}) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.error("[Telegram] send failed #{status}: #{inspect(body)}")
        {:error, {:telegram_error, status}}

      {:error, _} = err ->
        err
    end
  end

  def send_message(user_id, _msg, text) do
    Logger.warning("[Telegram] no chat_id in metadata for user #{user_id}, dropping: #{text}")
    :ok
  end
end
