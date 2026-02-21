defmodule Clawixir.Channels do
  @moduledoc """
  Public façade for sending replies back through a channel adapter.

  Channel adapters live in `Clawixir.Channels.*` and implement
  the `Clawixir.Channels.Adapter` behaviour.

  The sender should call:

      Clawixir.Channels.send_reply(:telegram, user_id, original_msg, "Hello!")
  """

  alias Clawixir.Channels.{Telegram, Slack, WebChat, WhatsApp}

  @adapters %{
    telegram: Telegram,
    slack:    Slack,
    webchat:  WebChat,
    whatsapp: WhatsApp
  }

  @doc "Send a reply to a user via the originating channel."
  @spec send_reply(atom(), String.t(), map(), String.t()) :: :ok | {:error, any()}
  def send_reply(channel, user_id, original_msg, text) do
    case Map.fetch(@adapters, channel) do
      {:ok, mod} -> mod.send_message(user_id, original_msg, text)
      :error     -> {:error, {:unknown_channel, channel}}
    end
  end
end
