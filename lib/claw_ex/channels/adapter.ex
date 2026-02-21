defmodule Clawixir.Channels.Adapter do
  @moduledoc "Behaviour all channel adapters must implement."

  @doc "Send a text reply to the user identified by user_id."
  @callback send_message(user_id :: String.t(), original_msg :: map(), text :: String.t()) ::
              :ok | {:error, any()}
end
