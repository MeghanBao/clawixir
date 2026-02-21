defmodule Clawixir.Application do
  @moduledoc """
  OTP Application entry point for Clawixir.

  Supervision tree (start order = dependency order):

    [Optional]  Cluster.Supervisor            — libcluster multi-node (if CLUSTER_ENABLED=true)
    ──────────────────────────────────────────────────────────────────────────
    Clawixir.Services.BrowserProcess            — Node.js Playwright (Port, managed)
    Clawixir.Services.AiProcess                 — Python AI service (Port, opt-in)
    Clawixir.PubSub                             — Phoenix PubSub (required by Presence)
    ClawixirWeb.Presence                        — multi-device session awareness
    Clawixir.SessionRegistry                    — ETS registry for per-user agent sessions
    Clawixir.SessionSupervisor                  — DynamicSupervisor for session processes
    Clawixir.RateLimiter                        — ETS sliding-window rate limiter
    Clawixir.Services.Monitor                   — external service health polling
    Clawixir.Agent.ToolRegistry                 — skill/tool catalogue
    Clawixir.Gateway                            — central message router
    Clawixir.Channels.Supervisor                — per-channel crash-isolated adapters
    ClawixirWeb.Telemetry                       — metrics
    ClawixirWeb.Endpoint                        — Phoenix HTTP/WebSocket

  One `mix phx.server` starts everything — no separate Node.js or Python
  startup commands required. Both subprocesses are crash-isolated and
  auto-restarted by the supervisor if they exit unexpectedly.
  """

  use Application

  @impl true
  def start(_type, _args) do
    Dotenvy.source!([".env", ".env.local", System.get_env()])

    # Conditionally include libcluster if CLUSTER_ENABLED=true
    cluster_children =
      case Clawixir.Cluster.child_spec_if_enabled() do
        nil   -> []
        spec  -> [spec]
      end

    children =
      cluster_children ++
      [
        # ── External subprocess management (the three tiers) ─────────────────
        # Node.js Playwright browser service (Port — managed by BEAM)
        Clawixir.Services.BrowserProcess,

        # Python AI/RAG service (Port — opt-in, set enabled: true in config)
        Clawixir.Services.AiProcess,
        # ─────────────────────────────────────────────────────────────────────

        # ── Persistent storage ───────────────────────────────────────────────
        Clawixir.Repo,

        # PubSub — required by Phoenix Presence and Phoenix Channels
        {Phoenix.PubSub, name: Clawixir.PubSub},

        # Presence — multi-device session awareness (the Elixir differentiator)
        ClawixirWeb.Presence,

        # Process registry for agent sessions
        {Registry, keys: :unique, name: Clawixir.SessionRegistry},

        # Dynamic supervisor for per-session agent processes
        {DynamicSupervisor, name: Clawixir.SessionSupervisor, strategy: :one_for_one},

        # ── Production-grade gateway infrastructure ──────────────────────────
        # Per-session rate limiter (ETS sliding window)
        Clawixir.RateLimiter,

        # External service health monitor (polls browser + AI services)
        Clawixir.Services.Monitor,

        # Tool / Skill registry
        Clawixir.Agent.ToolRegistry,
        # ────────────────────────────────────────────────────────────────────

        # Gateway — routes inbound messages to the correct agent session
        Clawixir.Gateway,

        # Channel supervisor — per-channel crash isolation (one_for_one)
        Clawixir.Channels.Supervisor,

        # Telemetry
        ClawixirWeb.Telemetry,

        # Phoenix web endpoint
        ClawixirWeb.Endpoint
      ]

    opts = [strategy: :one_for_one, name: Clawixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update config during hot-code upgrades (zero-downtime deploys)
  @impl true
  def config_change(changed, _new, removed) do
    ClawixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
