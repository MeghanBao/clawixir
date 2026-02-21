defmodule Clawixir.Channels.WebChat do
  @moduledoc """
  WebChat channel adapter — real-time chat via Phoenix Channels (WebSocket)
  and Phoenix LiveView.

  For raw WebSocket clients: connect to ws://<host>/socket/websocket and join
  the "chat:<user_id>" topic.

  For LiveView: the ChatLive module dispatches via Gateway and receives replies
  via PubSub broadcast on the "webchat:reply:<user_id>" topic.
  """
  @behaviour Clawixir.Channels.Adapter

  require Logger

  @doc """
  Dispatch a message from the WebSocket channel to the Gateway.
  Called by `ClawixirWeb.ChatChannel`.
  """
  def handle_message(user_id, text, socket_pid) do
    Clawixir.Gateway.dispatch(%{
      channel:  :webchat,
      user_id:  user_id,
      text:     text,
      metadata: %{socket_pid: socket_pid}
    })
  end

  @impl true
  def send_message(user_id, %{metadata: %{socket_pid: pid}}, text) do
    # Reply to raw WebSocket client
    send(pid, {:webchat_reply, text})
    # Also broadcast to LiveView clients on the same user_id
    broadcast_to_liveview(user_id, text)
    :ok
  end

  def send_message(user_id, _msg, text) do
    # No socket_pid — likely a LiveView client, broadcast via PubSub
    broadcast_to_liveview(user_id, text)
    :ok
  end

  defp broadcast_to_liveview(user_id, text) do
    Phoenix.PubSub.broadcast(
      Clawixir.PubSub,
      "webchat:reply:#{user_id}",
      {:webchat_reply, text}
    )
  end
end
