# 🦞 Clawixir — Personal AI Assistant in Elixir

> **Clawixir** is an Elixir rewrite of [OpenClaw](https://github.com/openclaw/openclaw) — a personal AI assistant you host yourself, built on the OTP Actor model and Phoenix.
>
> **Why Elixir for an AI gateway?** Each user session is a lightweight BEAM process (~2 KB) — the same concurrency model that lets WhatsApp serve 2 billion users. This means thousands of parallel AI conversations with per-session crash isolation, zero-downtime upgrades, and native multi-node clustering — all without Redis, Kubernetes sidecars, or external queue infrastructure.

---

## Why Elixir?

| Capability | How Elixir delivers it |
|---|---|
| Session isolation | Each user gets an isolated GenServer — one crash never affects another |
| Channel crash isolation | `one_for_one` Supervisor: Telegram dying ≠ WhatsApp dying |
| Multi-device awareness | Phoenix Presence built-in — no Redis needed |
| Hot code reload | Zero-downtime upgrades, no WebSocket reconnects |
| Multi-node clustering | BEAM native via `Node.connect/1` + libcluster |
| Fault tolerance | `let it crash` + Supervisor trees — not hand-rolled |

---

## Three-Tier Architecture

> **Elixir = Orchestrator · Node.js = Browser · Python = AI**

```
┌──────────────────────────── TIER 1: Elixir/BEAM ───────────────────────────────┐
│                           Clawixir Gateway (GenServer)                            │
│   Presence · Sessions · Retry/backoff · Rate limiting · Audit · Clustering      │
│                                                                                  │
│  ┌───────────────┐     ┌──────────────────┐     ┌──────────────────────────┐   │
│  │ Agent.Session │────►│  Agent.LLMClient │     │  Channel Adapters        │   │
│  │ (per-user GS) │     │  Anthropic / OAI │     │  Telegram · WhatsApp     │   │
│  │  history []   │     └──────────────────┘     │  WebChat (Phoenix WS)    │   │
│  │  15min timeout│                              └──────────────────────────┘   │
│  └───────┬───────┘                                                              │
│          │ HTTP → external services                                             │
└──────────┼──────────────────────────────────────────────────────────────────────┘
           │
    ┌──────┴──────────────────────────────────────┐
    ▼                                             ▼
┌───────────────────────────┐       ┌──────────────────────────────┐
│  TIER 2: Node.js :4001    │       │  TIER 3: Python :5001        │
│  Playwright (Chromium)    │       │  RAG · LlamaIndex · Ollama   │
│  navigate · screenshot    │       │  embeddings · PDF parsing    │
│  scrape · click · fill    │       │  Vector DB (Chroma/FAISS)    │
└───────────────────────────┘       └──────────────────────────────┘
```

---

## Features

### Channels
- **Telegram** — webhook-based, full message support
- **WhatsApp** — Meta Cloud API (free tier), webhook verify + replies
- **WebChat** — built-in Phoenix WebSocket, zero setup

### Agent
- **Any LLM** — Anthropic Claude or OpenAI GPT-4o, switched via env var
- **Agentic tool loop** — LLM calls tools iteratively until final answer
- **15-min idle timeout** — sessions GC themselves automatically

### Built-in Skills

| Skill | Notes |
|---|---|
| `get_weather` | Open-Meteo, no API key |
| `web_search` | DuckDuckGo Instant Answer |
| `get_datetime` | UTC |
| `calculate` | Safe recursive-descent parser |
| `browser` | Delegates to Node.js Playwright service |
| `rag_query` | Delegates to Python AI service |

### Production-grade Gateway (the Elixir differentiator)

| Module | What it does |
|---|---|
| `TaskOrchestrator` | Retry + exponential backoff + jitter + timeout |
| `Services.Monitor` | Health-polls browser/AI services every 15s |
| `RateLimiter` | ETS sliding-window, 10 req/60s per session |
| `Audit` | Structured events + telemetry for every action |
| `Channels.Supervisor` | `one_for_one`: Telegram crash ≠ WhatsApp crash |
| `TelegramPoller` | Validates bot token on start, retries on fail |
| `WhatsAppMonitor` | Validates Meta credentials every 60s |
| `ClawixirWeb.Presence` | Multi-device session awareness via Phoenix Presence |
| `Clawixir.Cluster` | opt-in BEAM clustering (Gossip/DNS/EPMD) |
| `Services.BrowserProcess` | Node.js Playwright managed as Elixir Port child |
| `Services.AiProcess` | Python AI service managed as Elixir Port child (opt-in) |

---

## Quick Start

### Prerequisites
- [Elixir 1.16+](https://elixir-lang.org/install.html) (OTP 26+)
- An Anthropic or OpenAI API key
- Node.js 20+ (for browser skill — installed once with `npm install` in `browser_service/`)

### 1. Install

```bash
git clone https://github.com/you/clawixir && cd clawixir
mix deps.get
```

### 2. Configure

```bash
cp .env.example .env
# Fill in LLM key + channel tokens
```

### 3. Run

```bash
# One command — starts Elixir gateway + Node.js browser service together
mix phx.server
```

> **First time only**: install Node.js deps and Playwright browser:
> ```bash
> cd browser_service && npm install && npx playwright install chromium && cd ..
> ```
>
> To disable the managed browser service (e.g. run it separately),
> set `enabled: false` for `:browser_process` in `config/config.exs`.

Health check:

```bash
curl http://localhost:4000/api/health
# {"status":"ok","active_sessions":0,"services":{"browser":"up","ai":"unknown"}}
```

---

## Channels Setup

### Quick Setup (recommended)

```bash
mix claw.setup
```

The interactive wizard configures everything — LLM provider, Telegram (auto-validates token + auto-registers webhook), WhatsApp, and Phoenix — then writes `.env`.

```
🦞  Clawixir Setup Wizard
─────────────────────────────────────

[1] LLM Provider
  Provider (anthropic/openai) [anthropic]:
  Anthropic API Key: sk-ant-...
  Model [claude-sonnet-4-20250514]:

[2] Telegram Channel
  Bot Token (from @BotFather): 123456:ABC...
  ✅ Connected as @MyClawBot
  Webhook URL (e.g. https://your-domain.com): https://example.com
  ✅ Webhook registered → https://example.com/api/webhooks/telegram

[3] WhatsApp Channel
  ⏭  WhatsApp skipped

[4] Phoenix Settings
  Auto-generated SECRET_KEY_BASE
  Port [4000]:

✅ Setup complete! .env written.
```

### WebChat (always-on)

Open `http://localhost:4000/chat` for the LiveView UI — no API keys required.

Or connect via raw WebSocket:
```javascript
const ws = new WebSocket("ws://localhost:4000/socket/websocket?user_id=alice&vsn=2.0.0");
ws.onopen = () => {
  ws.send(JSON.stringify([null,"1","chat:alice","phx_join",{}]));
  ws.send(JSON.stringify([null,"2","chat:alice","message",{"text":"Hello!"}]));
};
```

---

## Multi-Node Clustering (opt-in)

```bash
# Enable gossip clustering (LAN — nodes find each other automatically)
CLUSTER_ENABLED=true mix phx.server

# Test two nodes locally
iex --sname node1 --cookie secret -S mix phx.server
iex --sname node2 --cookie secret -S mix phx.server
# → connects within seconds; Presence and PubSub sync across nodes
```

For Kubernetes/Fly.io: `CLUSTER_STRATEGY=dns CLUSTER_DNS_NAME=claw-ex.internal`

---

## Adding Custom Skills

```elixir
defmodule MyApp.Skills.Dice do
  @behaviour Clawixir.Skills.Skill

  def name, do: "roll_dice"
  def definition do
    %{name: name(), description: "Roll an n-sided dice.",
      parameters: %{type: "object",
        properties: %{sides: %{type: "integer", description: "Sides (default 6)"}},
        required: []}}
  end
  def run(args) do
    %{result: :rand.uniform(Map.get(args, "sides", 6))}
  end
end

Clawixir.Agent.ToolRegistry.register(MyApp.Skills.Dice)
```

---

## Project Structure

```
clawixir/
├── config/
│   ├── config.exs          # Base config (PubSub, rate limiter, service URLs)
│   ├── dev.exs
│   ├── runtime.exs         # All secrets from env vars
│   └── test.exs
├── lib/
│   ├── clawixir/
│   │   ├── application.ex          # OTP supervision tree
│   │   ├── gateway.ex              # Central message router
│   │   ├── cluster.ex              # opt-in libcluster (Gossip/DNS/EPMD)
│   │   ├── rate_limiter.ex         # ETS sliding-window rate limiter
│   │   ├── task_orchestrator.ex    # Retry + backoff + timeout
│   │   ├── audit.ex                # Structured audit logger + telemetry
│   │   ├── browser_client.ex       # HTTP → Node.js browser service
│   │   ├── channels.ex             # Channel façade
│   │   ├── channels/
│   │   │   ├── adapter.ex          # Behaviour
│   │   │   ├── supervisor.ex       # one_for_one crash isolation
│   │   │   ├── telegram.ex         # Telegram Bot API
│   │   │   ├── telegram_poller.ex  # Supervised sentinel (transient)
│   │   │   ├── whatsapp.ex         # Meta Cloud API
│   │   │   ├── whatsapp_monitor.ex # Supervised credential checker (transient)
│   │   │   └── web_chat.ex         # Phoenix WebSocket
│   │   ├── services/
│   │   │   ├── monitor.ex          # External service health polling
│   │   │   ├── browser_process.ex  # Node.js Port child (managed by BEAM)
│   │   │   ├── ai_process.ex       # Python Port child (opt-in)
│   │   │   └── ai_client.ex        # HTTP → Python AI service
│   │   ├── agent/
│   │   │   ├── session.ex          # Per-user loop + rate limit + audit + timeout
│   │   │   ├── llm_client.ex       # Anthropic + OpenAI client
│   │   │   └── tool_registry.ex    # Skill catalogue
│   │   └── skills/built_in/
│   │       ├── weather.ex · web_search.ex · date_time.ex · calculator.ex
│   │       ├── browser_control.ex  # → Playwright service
│   │       └── rag_query.ex        # → Python AI service
│   └── claw_ex_web/
│       ├── presence.ex             # Phoenix Presence (multi-device)
│       ├── endpoint.ex · router.ex · telemetry.ex · user_socket.ex
│       ├── channels/chat_channel.ex    # Presence tracking + thinking indicator
│       └── controllers/
│           ├── webhook_controller.ex   # Telegram · WhatsApp (GET+POST)
│           └── health_controller.ex    # /api/health + service status
├── browser_service/                    # Node.js + Playwright (Tier 2)
│   ├── src/server.js
│   ├── package.json
│   └── README.md
├── assets/                              # LiveView frontend assets
│   ├── css/app.css                     # Dark-mode glassmorphism chat UI
│   └── js/app.js                       # LiveSocket + ScrollBottom hook
├── priv/
│   └── repo/migrations/               # Ecto migrations (SQLite)
├── test/                               # ExUnit test suite
│   ├── test_helper.exs
│   └── clawixir/
│       ├── skills/calculator_test.exs
│       ├── rate_limiter_test.exs
│       ├── task_orchestrator_test.exs
│       ├── audit_test.exs
│       ├── gateway_test.exs
│       ├── channels_test.exs
│       └── agent/tool_registry_test.exs
├── .env.example
├── .gitignore
└── mix.exs
```

---

## Configuration Reference

| Env variable | Default | Description |
|---|---|---|
| `LLM_PROVIDER` | `anthropic` | `anthropic` or `openai` |
| `LLM_MODEL` | `claude-opus-4-5` | Model name |
| `ANTHROPIC_API_KEY` | — | Claude API key |
| `OPENAI_API_KEY` | — | OpenAI API key |
| `TELEGRAM_BOT_TOKEN` | — | From @BotFather |
| `WHATSAPP_ACCESS_TOKEN` | — | Meta Cloud API token |
| `WHATSAPP_PHONE_NUMBER_ID` | — | Meta phone number ID |
| `WHATSAPP_VERIFY_TOKEN` | — | Webhook verify secret |
| `BROWSER_SERVICE_URL` | `http://localhost:4001` | Node.js Playwright service |
| `AI_SERVICE_URL` | `http://localhost:5001` | Python AI/RAG service |
| `CLUSTER_ENABLED` | `false` | Enable libcluster |
| `CLUSTER_STRATEGY` | `gossip` | `gossip` / `dns` / `epmd` |
| `CLUSTER_DNS_NAME` | — | For DNS strategy (Kubernetes) |
| `CLUSTER_SECRET` | — | Gossip shared secret |
| `SECRET_KEY_BASE` | — | `mix phx.gen.secret` |
| `PORT` | `4000` | HTTP port |

---

## Roadmap

- [x] Telegram + WhatsApp + WebChat channels
- [x] Anthropic + OpenAI LLM (tool-calling loop)
- [x] Browser automation (Playwright service)
- [x] RAG / PDF / embeddings (Python service)
- [x] Per-session rate limiting (ETS)
- [x] Retry + backoff orchestrator
- [x] External service health monitor
- [x] Structured audit logging + telemetry
- [x] Per-channel crash isolation (supervised transient processes)
- [x] Phoenix Presence (multi-device session awareness)
- [x] opt-in BEAM clustering (Gossip / DNS / EPMD)
- [x] Unified process management (Node.js + Python as supervised Port children)
- [x] Unit test suite (Calculator, RateLimiter, TaskOrchestrator, Audit, Gateway, ToolRegistry, Channels)
- [x] Persistent session storage (SQLite via Ecto)
- [x] LiveView WebChat UI (dark-mode, glassmorphism, real-time)
- [ ] Voice mode (Whisper STT + ElevenLabs TTS)
- [ ] Skill registry (load skills from GitHub)
- [ ] Signal / Matrix adapter

---

## License

MIT — see [LICENSE](LICENSE).

---

*Clawixir is an independent Elixir reimplementation inspired by [OpenClaw](https://github.com/openclaw/openclaw).*
