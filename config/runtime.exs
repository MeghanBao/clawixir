import Config

# Runtime config — reads from environment variables at startup.
# All secrets must be set here (never in config.exs which is compiled into the release).

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise "SECRET_KEY_BASE env var is not set. Run: mix phx.gen.secret"

config :clawixir, ClawixirWeb.Endpoint,
  http: [
    ip: {0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "4000")
  ],
  secret_key_base: secret_key_base

# ─── LLM provider ─────────────────────────────────────────────────────────────
llm_provider = System.get_env("LLM_PROVIDER", "anthropic") |> String.to_atom()

config :clawixir, :llm,
  provider: llm_provider,
  model:    System.get_env("LLM_MODEL") || (if llm_provider == :openai, do: "gpt-4o", else: "claude-opus-4-5"),
  api_key:  System.get_env(if(llm_provider == :openai, do: "OPENAI_API_KEY", else: "ANTHROPIC_API_KEY"))

# ─── Channel tokens ───────────────────────────────────────────────────────────
config :clawixir,
  telegram_bot_token:      System.get_env("TELEGRAM_BOT_TOKEN"),
  slack_bot_token:         System.get_env("SLACK_BOT_TOKEN"),
  whatsapp_access_token:   System.get_env("WHATSAPP_ACCESS_TOKEN"),
  whatsapp_phone_number_id: System.get_env("WHATSAPP_PHONE_NUMBER_ID"),
  whatsapp_verify_token:   System.get_env("WHATSAPP_VERIFY_TOKEN")

# ─── External services ────────────────────────────────────────────────────────
config :clawixir,
  browser_service_url: System.get_env("BROWSER_SERVICE_URL", "http://localhost:4001"),
  ai_service_url:      System.get_env("AI_SERVICE_URL",      "http://localhost:5001"),
  cluster_enabled:     System.get_env("CLUSTER_ENABLED", "false") == "true",
  cluster_secret:      System.get_env("CLUSTER_SECRET", "claw_ex_default_secret")
