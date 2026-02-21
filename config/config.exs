import Config

config :clawixir, ClawixirWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: ClawixirWeb.ErrorJSON], layout: false],
  pubsub_server: Clawixir.PubSub,
  live_view: [signing_salt: "clawixir_lv_salt"]

# Ecto Repo — SQLite (zero config, no external DB server)
config :clawixir, Clawixir.Repo,
  database: "clawixir_#{config_env()}.db",
  pool_size: 5

config :clawixir,
  ecto_repos: [Clawixir.Repo]

# LLM provider config (override via environment in runtime.exs)
config :clawixir, :llm,
  provider: :anthropic,
  model: "claude-opus-4-5",
  api_key: nil  # set via ANTHROPIC_API_KEY in .env

# Rate limiter: 10 messages per 60 seconds per session
config :clawixir, :rate_limiter,
  max_requests: 10,
  window_ms: 60_000

# External service URLs (override in runtime.exs via env vars)
config :clawixir,
  browser_service_url: "http://localhost:4001",
  ai_service_url:      "http://localhost:5001",
  cluster_enabled:     false

# ── Subprocess management ───────────────────────────────────────────────────
# When enabled: true, Elixir starts these services automatically as Port children.
# Set enabled: false to run them separately (or disable entirely).

config :clawixir, :browser_process,
  enabled: true,
  command: "node",
  args: ["browser_service/src/server.js"],
  port: 4001

config :clawixir, :ai_process,
  enabled: false,          # opt-in — set true if you run a Python AI service
  command: "python3",
  args: ["-m", "ai_service.main"],
  port: 5001

# Phoenix PubSub (required by Presence and Phoenix Channels)
config :clawixir, Clawixir.PubSub,
  name: Clawixir.PubSub,
  adapter: Phoenix.PubSub.PG2

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# esbuild for LiveView JS bundling
config :esbuild,
  version: "0.24.2",
  clawixir: [
    args: ~w(js/app.js --bundle --target=es2020 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

import_config "#{config_env()}.exs"
