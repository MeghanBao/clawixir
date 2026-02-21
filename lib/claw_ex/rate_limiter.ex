defmodule Clawixir.RateLimiter do
  @moduledoc """
  ETS-based per-session rate limiter using a sliding window algorithm.

  Prevents any single session from flooding the LLM with requests.
  Default limit: 10 requests per 60 seconds per session.

  Usage:

      case Clawixir.RateLimiter.check(session_key) do
        :ok              -> # proceed
        {:error, :rate_limited, retry_after_ms} -> # reject with wait time
      end

  Configuration (in application env):

      config :clawixir, :rate_limiter,
        max_requests: 10,
        window_ms: 60_000
  """

  use GenServer
  require Logger

  @name __MODULE__
  @table :rate_limiter

  # ─── Public API ────────────────────────────────────────────────────────────

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: @name)

  @spec check(String.t()) :: :ok | {:error, :rate_limited, non_neg_integer()}
  def check(session_key) do
    {max_req, window_ms} = config()
    now = System.monotonic_time(:millisecond)
    cutoff = now - window_ms

    # Fetch existing timestamps, remove old ones, check count
    timestamps =
      case :ets.lookup(@table, session_key) do
        [{^session_key, ts}] -> Enum.filter(ts, &(&1 > cutoff))
        []                   -> []
      end

    if length(timestamps) >= max_req do
      oldest = Enum.min(timestamps)
      retry_after = oldest + window_ms - now
      {:error, :rate_limited, retry_after}
    else
      :ets.insert(@table, {session_key, timestamps ++ [now]})
      :ok
    end
  end

  # ─── GenServer callbacks ────────────────────────────────────────────────────

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true, write_concurrency: true])
    # Periodically clean up stale sessions
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    {_, window_ms} = config()
    cutoff = System.monotonic_time(:millisecond) - window_ms

    :ets.select_delete(@table, [
      {{:_, :"$1"}, [{:==, {:length, :"$1"}, 0}], [true]}
    ])

    # Remove expired timestamps from all sessions
    :ets.foldl(
      fn {key, timestamps}, _ ->
        fresh = Enum.filter(timestamps, &(&1 > cutoff))
        if fresh == [], do: :ets.delete(@table, key), else: :ets.insert(@table, {key, fresh})
      end,
      :ok,
      @table
    )

    schedule_cleanup()
    {:noreply, state}
  end

  # ─── Helpers ───────────────────────────────────────────────────────────────

  defp config do
    cfg = Application.get_env(:clawixir, :rate_limiter, [])
    {cfg[:max_requests] || 10, cfg[:window_ms] || 60_000}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, 60_000)
end
