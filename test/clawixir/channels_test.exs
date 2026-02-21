defmodule Clawixir.ChannelsTest do
  use ExUnit.Case, async: true

  alias Clawixir.Channels

  describe "send_reply/4" do
    test "returns error for unknown channel" do
      result = Channels.send_reply(:nonexistent, "user1", %{}, "hello")
      assert {:error, {:unknown_channel, :nonexistent}} = result
    end

    test "webchat channel is a known adapter" do
      # WebChat.send_message broadcasts via PubSub — we just verify it doesn't crash
      # and returns :ok (PubSub is started by the application)
      result = Channels.send_reply(:webchat, "channels_test_user", %{}, "test reply")
      assert result == :ok
    end
  end
end
