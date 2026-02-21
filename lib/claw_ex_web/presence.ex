defmodule ClawixirWeb.Presence do
  @moduledoc """
  Phoenix Presence tracker for Clawixir WebChat sessions.

  Tracks which devices a user has connected with, enabling:
  - Real-time "X is connected on 2 devices" awareness
  - "AI is thinking..." state visible across all devices simultaneously
  - Graceful handoff when one device disconnects mid-conversation

  This is the feature that separates Clawixir from every Go/Rust *Claw
  rewrite — in Elixir it's < 10 lines of code. In Go/Rust you'd need
  Redis + custom pub/sub + rollout logic.

  ## Client events (WebSocket)

  On join, clients receive:

      {"event": "presence_state", "payload": {"alice": [{"device": "...", "online_at": 1234}]}}

  When another device connects/disconnects:

      {"event": "presence_diff", "payload": {"joins": {...}, "leaves": {...}}}

  When AI starts/finishes thinking:

      {"event": "presence_diff", "payload": {"joins": {"alice": [{"thinking": true}]}}}
  """

  use Phoenix.Presence,
    otp_app: :clawixir,
    pubsub_server: Clawixir.PubSub
end
