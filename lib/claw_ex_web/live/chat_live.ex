defmodule ClawixirWeb.ChatLive do
  @moduledoc """
  Phoenix LiveView for the WebChat interface.

  Provides a real-time chat UI that connects to the Clawixir Gateway.
  Messages are dispatched via PubSub so the agent's reply arrives
  asynchronously via `handle_info`.
  """
  use Phoenix.LiveView

  alias Clawixir.Gateway

  @impl true
  def mount(_params, _session, socket) do
    user_id = "live_#{:erlang.unique_integer([:positive])}"
    topic = "webchat:reply:#{user_id}"

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Clawixir.PubSub, topic)
    end

    {:ok,
     assign(socket,
       user_id: user_id,
       messages: [],
       input: "",
       thinking: false
     ), layout: {ClawixirWeb.Layouts, :app}}
  end

  @impl true
  def handle_event("send", %{"message" => text}, socket) when byte_size(text) > 0 do
    user_msg = %{role: :user, content: String.trim(text)}
    messages = socket.assigns.messages ++ [user_msg]

    # Dispatch to the gateway
    Gateway.dispatch(%{
      channel: :webchat,
      user_id: socket.assigns.user_id,
      text: String.trim(text),
      metadata: %{source: :liveview}
    })

    {:noreply, assign(socket, messages: messages, input: "", thinking: true)}
  end

  def handle_event("send", _params, socket), do: {:noreply, socket}

  def handle_event("update_input", %{"message" => text}, socket) do
    {:noreply, assign(socket, input: text)}
  end

  @impl true
  def handle_info({:webchat_reply, text}, socket) do
    bot_msg = %{role: :assistant, content: text}
    messages = socket.assigns.messages ++ [bot_msg]
    {:noreply, assign(socket, messages: messages, thinking: false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="chat-container">
      <!-- Header -->
      <header class="chat-header">
        <div class="header-glow"></div>
        <div class="header-content">
          <span class="logo">🦞</span>
          <h1>Clawixir</h1>
          <span class="badge">AI Assistant</span>
        </div>
      </header>

      <!-- Messages -->
      <div class="messages-area" id="messages" phx-hook="ScrollBottom">
        <%= if @messages == [] do %>
          <div class="empty-state">
            <div class="empty-icon">🦞</div>
            <h2>Welcome to Clawixir</h2>
            <p>Your personal AI assistant, powered by Elixir and the BEAM.</p>
            <div class="suggestions">
              <button phx-click="send" phx-value-message="What can you do?" class="suggestion-chip">
                💡 What can you do?
              </button>
              <button phx-click="send" phx-value-message="What's the weather in Berlin?" class="suggestion-chip">
                🌤️ Weather in Berlin
              </button>
              <button phx-click="send" phx-value-message="Calculate (17 * 23) + 42" class="suggestion-chip">
                🧮 Quick math
              </button>
            </div>
          </div>
        <% end %>

        <%= for msg <- @messages do %>
          <div class={"message #{msg.role}"}>
            <div class="message-bubble">
              <div class="message-avatar">
                <%= if msg.role == :user, do: "👤", else: "🦞" %>
              </div>
              <div class="message-content">
                <div class="message-text"><%= msg.content %></div>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @thinking do %>
          <div class="message assistant">
            <div class="message-bubble">
              <div class="message-avatar">🦞</div>
              <div class="message-content">
                <div class="thinking-dots">
                  <span></span><span></span><span></span>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Input -->
      <form class="input-area" phx-submit="send">
        <div class="input-glow"></div>
        <div class="input-wrapper">
          <input
            type="text"
            name="message"
            value={@input}
            phx-change="update_input"
            placeholder="Message Clawixir..."
            autocomplete="off"
            autofocus
          />
          <button type="submit" class={"send-btn #{if @thinking, do: "disabled"}"} disabled={@thinking}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M22 2L11 13M22 2L15 22L11 13M22 2L2 9L11 13" />
            </svg>
          </button>
        </div>
      </form>
    </div>
    """
  end
end
