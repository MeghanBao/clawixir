defmodule Clawixir.AuditTest do
  use ExUnit.Case, async: true

  alias Clawixir.Audit

  describe "log/2" do
    test "logs a valid event without error" do
      assert :ok = Audit.log(:message_received, %{session: "test", channel: :webchat, length: 5})
    end

    test "logs all valid event types" do
      events = [
        :message_received,
        :llm_called,
        :tool_called,
        :rate_limited,
        :session_created,
        :session_timeout,
        :session_crashed,
        :service_up,
        :service_down
      ]

      for event <- events do
        assert :ok = Audit.log(event, %{test: true})
      end
    end

    test "emits telemetry event" do
      ref = make_ref()
      test_pid = self()

      :telemetry.attach(
        "audit-test-#{inspect(ref)}",
        [:clawixir, :audit, :tool_called],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:telemetry, metadata})
        end,
        nil
      )

      Audit.log(:tool_called, %{session: "test", tool: "calculate", ok: true})

      assert_receive {:telemetry, metadata}, 1_000
      assert metadata.tool == "calculate"

      :telemetry.detach("audit-test-#{inspect(ref)}")
    end

    test "handles unknown event gracefully" do
      # Should not raise, just log a warning
      assert :ok = Audit.log(:totally_unknown_event, %{})
    end
  end
end
