defmodule Clawixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :clawixir,
      version: "0.1.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      releases: releases(),
      deps: deps()
    ]
  end

  # ─── OTP Releases (required for hot code upgrades) ──────────────────────────
  # Build:   MIX_ENV=prod mix release
  # Upgrade: MIX_ENV=prod mix release --overwrite (then bin/clawixir upgrade <vsn>)
  defp releases do
    [
      clawixir: [
        include_executables_for: [:unix],
        # Keep ERTS bundled so the target machine doesn't need Erlang installed
        include_erts: true,
        # Strip debug info from beam files in prod to reduce size
        strip_beams: Mix.env() == :prod,
        # runtime.exs is evaluated at boot on the target machine
        runtime_config_path: "config/runtime.exs",
        # Steps needed for hot upgrades (appup / relup generation)
        steps: [:assemble, :tar]
      ]
    ]
  end

  def application do
    [
      mod: {Clawixir.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto, :eex]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Web / HTTP
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 0.20"},
      {:bandit, "~> 1.0"},
      {:websock_adapter, "~> 0.5"},

      # HTTP client
      {:req, "~> 0.5"},

      # JSON
      {:jason, "~> 1.4"},

      # Database — SQLite via Ecto (zero config persistence)
      {:ecto_sql, "~> 3.11"},
      {:ecto_sqlite3, "~> 0.17"},

      # Process registry — using OTP built-in (no extra hex package needed)

      # Concurrent job processing
      {:broadway, "~> 1.0"},

      # Optional: multi-node BEAM clustering (enable via CLUSTER_ENABLED=true)
      {:libcluster, "~> 3.3"},

      # PubSub (required for Phoenix Presence)
      {:phoenix_pubsub, "~> 2.1"},

      # Environment / config
      {:dotenvy, "~> 0.8"},

      # Telemetry
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},

      # HTML / LiveView UI
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.5", only: :dev, runtime: false},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},

      # Dev / test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "claw.onboard": ["run priv/scripts/onboard.exs"],
      "claw.setup": ["claw.setup"]
    ]
  end
end
