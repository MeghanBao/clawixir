defmodule ClawixirWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:*", ClawixirWeb.ChatChannel

  @impl true
  def connect(%{"user_id" => user_id}, socket, _connect_info) do
    {:ok, assign(socket, :user_id, user_id)}
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
