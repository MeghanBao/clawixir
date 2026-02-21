defmodule ClawixirWeb.Router do
  use ClawixirWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {ClawixirWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # ── LiveView WebChat UI ──────────────────────────────────────────────────
  scope "/", ClawixirWeb do
    pipe_through :browser

    live "/chat", ChatLive
  end

  # ── API + Webhooks ───────────────────────────────────────────────────────
  scope "/api", ClawixirWeb do
    pipe_through :api

    # Health-check
    get  "/health", HealthController, :index

    # Webhook endpoints for channel adapters
    post "/webhooks/telegram",            WebhookController, :telegram
    post "/webhooks/slack",               WebhookController, :slack

    # WhatsApp requires a GET for webhook verification + POST for messages
    get  "/webhooks/whatsapp",            WebhookController, :whatsapp_verify
    post "/webhooks/whatsapp",            WebhookController, :whatsapp
  end
end
