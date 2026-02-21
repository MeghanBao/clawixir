defmodule ClawixirWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :clawixir

  # LiveView WebSocket (for the chat UI)
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: ClawixirWeb.session_options()]]

  # Channel WebSocket (for raw WebSocket clients — Telegram/WhatsApp/etc.)
  socket "/socket", ClawixirWeb.UserSocket,
    websocket: true,
    longpoll: false

  # Serve static files (CSS, JS, images)
  plug Plug.Static,
    at: "/",
    from: :clawixir,
    gzip: false,
    only: ClawixirWeb.static_paths()

  # Request logger
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # Body parsers
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, ClawixirWeb.session_options()
  plug ClawixirWeb.Router
end
