defmodule Clawixir.Channels.WhatsApp do
  @moduledoc """
  WhatsApp channel adapter using the Meta WhatsApp Business Cloud API.

  ## Setup (free tier available)

  1. Go to https://developers.facebook.com → Create App → Business
  2. Add "WhatsApp" product → get a test number
  3. Set webhook URL: `https://your-domain.com/api/webhooks/whatsapp`
  4. Set webhook verify token (any string you choose) → `WHATSAPP_VERIFY_TOKEN`
  5. Subscribe to `messages` webhook field
  6. Copy the permanent access token → `WHATSAPP_ACCESS_TOKEN`
  7. Copy your Phone Number ID → `WHATSAPP_PHONE_NUMBER_ID`

  ## Required env vars

      WHATSAPP_ACCESS_TOKEN=EAAxxxxxxxx
      WHATSAPP_PHONE_NUMBER_ID=1234567890
      WHATSAPP_VERIFY_TOKEN=my_secret_verify_token

  ## Message flow

      Meta Cloud API
        → POST /api/webhooks/whatsapp
          → WhatsApp.handle_message/1
            → Clawixir.Gateway.dispatch/1
              → Agent.Session (LLM loop)
                → WhatsApp.send_message/3
                  → POST https://graph.facebook.com/...
  """

  @behaviour Clawixir.Channels.Adapter

  require Logger

  @graph_url "https://graph.facebook.com/v19.0"

  # ─── Inbound: webhook verification ─────────────────────────────────────────

  @doc """
  Verify the webhook subscription (GET request from Meta).
  Called by WebhookController for the GET /api/webhooks/whatsapp route.
  Returns {:ok, challenge} or :error.
  """
  def verify_webhook(params) do
    expected_token = Application.get_env(:clawixir, :whatsapp_verify_token)

    case params do
      %{
        "hub.mode"       => "subscribe",
        "hub.verify_token" => ^expected_token,
        "hub.challenge"  => challenge
      } ->
        {:ok, challenge}

      _ ->
        :error
    end
  end

  # ─── Inbound: message events ────────────────────────────────────────────────

  @doc """
  Parse a WhatsApp webhook payload and dispatch to Gateway.
  Only handles text messages. Ignores reactions, status updates, etc.
  """
  def handle_message(%{"entry" => entries}) do
    Enum.each(entries, fn entry ->
      entry
      |> get_in(["changes"])
      |> List.wrap()
      |> Enum.each(&process_change/1)
    end)

    :ok
  end

  def handle_message(_), do: :ignored

  defp process_change(%{
    "value" => %{
      "messages"   => [%{"type" => "text", "text" => %{"body" => text}, "from" => from} | _],
      "metadata"   => %{"phone_number_id" => phone_number_id}
    }
  }) do
    Clawixir.Gateway.dispatch(%{
      channel:  :whatsapp,
      user_id:  from,
      text:     text,
      metadata: %{phone_number_id: phone_number_id, to: from}
    })
  end

  defp process_change(_), do: :ignored

  # ─── Outbound: send a reply ──────────────────────────────────────────────────

  @impl true
  def send_message(_user_id, %{metadata: %{to: to, phone_number_id: phone_id}}, text) do
    token    = Application.get_env(:clawixir, :whatsapp_access_token)
    url      = "#{@graph_url}/#{phone_id}/messages"

    body = %{
      messaging_product: "whatsapp",
      recipient_type:    "individual",
      to:                to,
      type:              "text",
      text:              %{body: text}
    }

    case Req.post(url,
           json: body,
           headers: [{"authorization", "Bearer #{token}"}]
         ) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error("[WhatsApp] send failed #{status}: #{inspect(resp_body)}")
        {:error, {:whatsapp_api_error, status}}

      {:error, _} = err ->
        err
    end
  end

  def send_message(user_id, _msg, text) do
    Logger.warning("[WhatsApp] no metadata for #{user_id}, dropping: #{text}")
    :ok
  end
end
