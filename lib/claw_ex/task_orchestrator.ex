defmodule Clawixir.TaskOrchestrator do
  @moduledoc """
  Async task runner with retry, exponential backoff, timeout, and telemetry.

  This is the "Elixir value-add" layer: it wraps calls to external services
  (LLM, browser, AI) with production-grade fault tolerance that you'd have to
  hand-roll in Go/Rust but get nearly for free via OTP Task + supervisors.

  ## Usage

      # Run with defaults (3 retries, 5s timeout, exponential backoff)
      Clawixir.TaskOrchestrator.run(fn -> do_something() end)

      # Custom options
      Clawixir.TaskOrchestrator.run(fn -> call_browser() end,
        retries: 2,
        timeout_ms: 10_000,
        backoff_ms: 500,
        name: "browser:navigate"
      )

  Returns:
    {:ok, result}
    {:error, :timeout}
    {:error, :max_retries_exceeded, last_error}
  """

  require Logger

  @default_retries   3
  @default_timeout   5_000
  @default_backoff   300   # base backoff ms (doubles each retry)
  @max_backoff       8_000

  @spec run(function(), keyword()) :: {:ok, any()} | {:error, any()}
  def run(fun, opts \\ []) do
    retries   = Keyword.get(opts, :retries, @default_retries)
    timeout   = Keyword.get(opts, :timeout_ms, @default_timeout)
    backoff   = Keyword.get(opts, :backoff_ms, @default_backoff)
    task_name = Keyword.get(opts, :name, "task")

    do_run(fun, task_name, retries, timeout, backoff, 0)
  end

  # ─── Internal ───────────────────────────────────────────────────────────────

  defp do_run(fun, name, max_retries, timeout, base_backoff, attempt) do
    task = Task.async(fun)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {:ok, result}} ->
        if attempt > 0, do: Logger.info("[Orchestrator] #{name} succeeded on attempt #{attempt + 1}")
        {:ok, result}

      {:ok, result} when not is_tuple(result) or elem(result, 0) != :error ->
        {:ok, result}

      {:ok, {:error, reason}} ->
        handle_failure(fun, name, max_retries, timeout, base_backoff, attempt, reason)

      nil ->
        Logger.warning("[Orchestrator] #{name} timed out on attempt #{attempt + 1}")
        handle_failure(fun, name, max_retries, timeout, base_backoff, attempt, :timeout)

      {:exit, reason} ->
        Logger.error("[Orchestrator] #{name} crashed: #{inspect(reason)}")
        handle_failure(fun, name, max_retries, timeout, base_backoff, attempt, {:exit, reason})
    end
  end

  defp handle_failure(_fun, name, max_retries, _timeout, _backoff, attempt, reason)
       when attempt >= max_retries do
    Logger.error("[Orchestrator] #{name} failed after #{attempt + 1} attempts: #{inspect(reason)}")
    {:error, :max_retries_exceeded, reason}
  end

  defp handle_failure(fun, name, max_retries, timeout, base_backoff, attempt, reason) do
    wait_ms = min(base_backoff * :math.pow(2, attempt) |> trunc(), @max_backoff)
    # Add jitter ±20%
    jitter   = trunc(wait_ms * 0.2)
    sleep_ms = wait_ms + :rand.uniform(jitter * 2) - jitter

    Logger.warning("[Orchestrator] #{name} failed (attempt #{attempt + 1}): #{inspect(reason)}. Retrying in #{sleep_ms}ms")
    Process.sleep(sleep_ms)

    do_run(fun, name, max_retries, timeout, base_backoff, attempt + 1)
  end
end
