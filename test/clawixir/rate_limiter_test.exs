defmodule Clawixir.RateLimiterTest do
  use ExUnit.Case

  alias Clawixir.RateLimiter

  # Each test gets its own ETS table via the GenServer.
  # We use unique session keys per test to avoid cross-test contamination.

  setup do
    # RateLimiter is started by the application supervisor.
    # Generate a unique session key for each test.
    key = "test_session_#{:erlang.unique_integer([:positive])}"
    {:ok, key: key}
  end

  describe "check/1" do
    test "allows requests under the limit", %{key: key} do
      assert :ok = RateLimiter.check(key)
    end

    test "allows up to max_requests within the window", %{key: key} do
      {max_req, _} = rate_limiter_config()

      for _ <- 1..max_req do
        assert :ok = RateLimiter.check(key)
      end
    end

    test "blocks requests exceeding the limit", %{key: key} do
      {max_req, _} = rate_limiter_config()

      for _ <- 1..max_req do
        RateLimiter.check(key)
      end

      assert {:error, :rate_limited, retry_after_ms} = RateLimiter.check(key)
      assert is_integer(retry_after_ms)
      assert retry_after_ms > 0
    end

    test "different sessions are independent", %{key: key} do
      other_key = key <> "_other"
      {max_req, _} = rate_limiter_config()

      # Exhaust one session
      for _ <- 1..max_req do
        RateLimiter.check(key)
      end

      # Other session should still work
      assert :ok = RateLimiter.check(other_key)
    end
  end

  defp rate_limiter_config do
    cfg = Application.get_env(:clawixir, :rate_limiter, [])
    {cfg[:max_requests] || 10, cfg[:window_ms] || 60_000}
  end
end
