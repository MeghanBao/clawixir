defmodule Clawixir.Channels.Slack do
  @moduledoc """
  Slack channel adapter using the Web API + Events API.

  Incoming events arrive at POST /webhooks/slack.
  Outgoing replies use chat.postMessage.

  Required env: SLACK_BOT_TOKEN
  """
  @behaviour Clawixir.Channels.Adapter

  require Logger

  @slack_post_url "https://slack.com/api/chat.postMessage"

  # ─── Inbound ────────────────────────────────────────────────────────────────

  @doc "Handle an incoming Slack Events API payload."
  def handle_event(%{"type" => "url_verification", "challenge" => c}), do: {:challenge, c}

  def handle_event(%{"event" => %{"type" => "message", "text" => text, "user" => user, "channel" => chan}}) do
    Clawixir.Gateway.dispatch(%{
      channel:  :slack,
      user_id:  user,
      text:     text,
      metadata: %{channel_id: chan}
    })
    :ok
  end

  def handle_event(_), do: :ignored

  # ─── Outbound ───────────────────────────────────────────────────────────────

  @impl true
  def send_message(_user_id, %{metadata: %{channel_id: channel_id}}, text) do
    token = Application.get_env(:clawixir, :slack_bot_token)

    case Req.post(@slack_post_url,
           json: %{channel: channel_id, text: text},
           headers: [{"authorization", "Bearer #{token}"}]
         ) do
      {:ok, %{status: 200, body: %{"ok" => true}}} ->
        :ok

      {:ok, %{body: %{"ok" => false, "error" => err}}} ->
        Logger.error("[Slack] send failed: #{err}")
        {:error, {:slack_error, err}}

      {:error, _} = err ->
        err
    end
  end

  def send_message(user_id, _msg, text) do
    Logger.warning("[Slack] no channel_id for user #{user_id}, dropping: #{text}")
    :ok
  end
end
