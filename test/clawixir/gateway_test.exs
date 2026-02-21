defmodule Clawixir.GatewayTest do
  use ExUnit.Case

  alias Clawixir.Gateway

  describe "dispatch/1" do
    test "creates a new session for a new user" do
      user_id = "gw_test_user_#{:erlang.unique_integer([:positive])}"

      msg = %{
        channel: :webchat,
        user_id: user_id,
        text: "hello",
        metadata: %{}
      }

      # dispatch is a cast, so it returns :ok immediately
      assert :ok = Gateway.dispatch(msg)

      # Give the GenServer time to process
      Process.sleep(200)

      # Session should now appear in the registry
      sessions = Gateway.list_sessions()
      keys = Enum.map(sessions, fn {key, _pid} -> key end)
      assert "webchat:#{user_id}" in keys
    end

    test "reuses existing session for the same user" do
      user_id = "gw_test_reuse_#{:erlang.unique_integer([:positive])}"

      msg = %{
        channel: :webchat,
        user_id: user_id,
        text: "first",
        metadata: %{}
      }

      Gateway.dispatch(msg)
      Process.sleep(200)

      # Get the PID from the first session
      [{_, pid1}] =
        Gateway.list_sessions()
        |> Enum.filter(fn {key, _} -> key == "webchat:#{user_id}" end)

      # Send a second message
      Gateway.dispatch(%{msg | text: "second"})
      Process.sleep(200)

      # Should be the same PID (session reused)
      [{_, pid2}] =
        Gateway.list_sessions()
        |> Enum.filter(fn {key, _} -> key == "webchat:#{user_id}" end)

      assert pid1 == pid2
    end
  end

  describe "list_sessions/0" do
    test "returns a list" do
      assert is_list(Gateway.list_sessions())
    end
  end
end
