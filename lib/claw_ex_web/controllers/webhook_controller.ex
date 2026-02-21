defmodule ClawixirWeb.WebhookController do
  @moduledoc "Handles inbound webhook POST/GET requests from channel providers."
  use ClawixirWeb, :controller

  alias Clawixir.Channels.{Telegram, Slack, WhatsApp}

  # ─── Telegram ───────────────────────────────────────────────────────────────
  def telegram(conn, params) do
    Telegram.handle_update(params)
    conn |> put_status(:ok) |> json(%{ok: true})
  end

  # ─── Slack ──────────────────────────────────────────────────────────────────
  def slack(conn, params) do
    case Slack.handle_event(params) do
      {:challenge, token} ->
        conn |> put_status(:ok) |> json(%{challenge: token})

      _ ->
        conn |> put_status(:ok) |> json(%{ok: true})
    end
  end

  # ─── WhatsApp ───────────────────────────────────────────────────────────────

  # GET: Meta webhook verification (subscribe handshake)
  def whatsapp_verify(conn, params) do
    case WhatsApp.verify_webhook(params) do
      {:ok, challenge} ->
        conn |> put_status(:ok) |> text(challenge)

      :error ->
        conn |> put_status(:forbidden) |> json(%{error: "invalid verify token"})
    end
  end

  # POST: Actual messages from Meta
  def whatsapp(conn, params) do
    WhatsApp.handle_message(params)
    conn |> put_status(:ok) |> json(%{ok: true})
  end
end
