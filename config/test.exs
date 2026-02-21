import Config

config :logger, level: :warning

# Test endpoint — use a random port so tests don't clash with dev
config :clawixir, ClawixirWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_min_64_chars_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  server: false

# Disable external subprocess management in tests
config :clawixir, :browser_process, enabled: false
config :clawixir, :ai_process, enabled: false

# LLM — no real API calls in unit tests
config :clawixir, :llm,
  provider: :anthropic,
  model: "test-model",
  api_key: "test-key"

# Rate limiter — keep defaults (tests use unique keys, so no conflict)
config :clawixir, :rate_limiter,
  max_requests: 10,
  window_ms: 60_000

# Ecto — test database (separate from dev)
config :clawixir, Clawixir.Repo,
  database: "clawixir_test.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5
