defmodule ClawixirWeb.ChatChannel do
  @moduledoc """
  Phoenix Channel for the built-in WebChat interface.

  Clients join "chat:<user_id>" and send `message` events.

  ## Phoenix Presence (the Elixir differentiator)

  On join, each connected device is tracked via `ClawixirWeb.Presence`.
  All devices for the same user see:

  - `presence_state`  — full map of who is currently connected
  - `presence_diff`   — delta when a device joins/leaves
  - `thinking`        — broadcast when AI is working (visible on all devices)

  This multi-device awareness requires zero external dependencies in Elixir.
  The equivalent in Go/Rust needs Redis + a custom pub-sub layer.
  """

  use ClawixirWeb, :channel

  alias Clawixir.Channels.WebChat
  alias ClawixirWeb.Presence

  @impl true
  def join("chat:" <> user_id, _params, socket) do
    socket = assign(socket, :user_id, user_id)

    # Track this device in Presence after join completes
    send(self(), :after_join)

    {:ok, socket}
  end

  @impl true
  def handle_in("message", %{"text" => text}, socket) do
    user_id = socket.assigns.user_id

    # Broadcast "AI is thinking" to all devices before dispatching
    broadcast_thinking(socket, user_id, true)

    WebChat.handle_message(user_id, text, self())

    {:noreply, socket}
  end

  # ─── Presence: track this device after join ─────────────────────────────────

  @impl true
  def handle_info(:after_join, socket) do
    user_id  = socket.assigns.user_id
    device   = socket.id || "unknown"

    {:ok, _} =
      Presence.track(socket, user_id, %{
        device:     device,
        online_at:  System.system_time(:second)
      })

    # Push current presence state to this device
    push(socket, "presence_state", Presence.list(socket))

    {:noreply, socket}
  end

  # ─── Reply from agent session ────────────────────────────────────────────────

  @impl true
  def handle_info({:webchat_reply, text}, socket) do
    user_id = socket.assigns.user_id

    # Clear "thinking" on all devices before sending reply
    broadcast_thinking(socket, user_id, false)

    push(socket, "reply", %{text: text})
    {:noreply, socket}
  end

  # ─── Helpers ────────────────────────────────────────────────────────────────

  defp broadcast_thinking(socket, user_id, thinking?) do
    # Update presence metadata to show thinking state — all devices see it
    Presence.update(socket, user_id, fn meta ->
      Map.put(meta, :thinking, thinking?)
    end)
  end
end
