defmodule Clawixir.TaskOrchestratorTest do
  use ExUnit.Case, async: true

  alias Clawixir.TaskOrchestrator

  describe "run/2" do
    test "returns {:ok, result} on immediate success" do
      assert {:ok, 42} = TaskOrchestrator.run(fn -> 42 end)
    end

    test "returns {:ok, result} when function returns {:ok, value}" do
      assert {:ok, {:ok, :hello}} = TaskOrchestrator.run(fn -> {:ok, :hello} end)
    end

    test "retries on transient failure and eventually succeeds" do
      # Use an agent to track call count
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      result =
        TaskOrchestrator.run(
          fn ->
            count = Agent.get_and_update(agent, fn n -> {n, n + 1} end)

            if count < 2 do
              {:error, :transient}
            else
              {:ok, :recovered}
            end
          end,
          retries: 3,
          timeout_ms: 5_000,
          backoff_ms: 50
        )

      assert {:ok, {:ok, :recovered}} = result

      final_count = Agent.get(agent, & &1)
      assert final_count == 3  # called 3 times total (2 failures + 1 success)

      Agent.stop(agent)
    end

    test "returns error after max retries exceeded" do
      result =
        TaskOrchestrator.run(
          fn -> {:error, :always_fails} end,
          retries: 2,
          timeout_ms: 5_000,
          backoff_ms: 10
        )

      assert {:error, :max_retries_exceeded, :always_fails} = result
    end

    test "handles timeout gracefully" do
      result =
        TaskOrchestrator.run(
          fn -> Process.sleep(10_000) end,
          retries: 0,
          timeout_ms: 100,
          backoff_ms: 10
        )

      assert {:error, :max_retries_exceeded, :timeout} = result
    end
  end
end
