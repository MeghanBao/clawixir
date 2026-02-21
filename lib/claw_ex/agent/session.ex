defmodule Clawixir.Agent.Session do
  @moduledoc """
  A per-user agent session.

  Each session holds:
  - conversation history (list of %{role, content} maps)
  - the channel + user_id it belongs to

  Production-grade features (the real Elixir value-add):
  - **Rate limiting** via `Clawixir.RateLimiter` — rejects if session exceeds quota
  - **Audit logging** via `Clawixir.Audit` — every inbound message and tool call is recorded
  - **Retry + timeout** via `Clawixir.TaskOrchestrator` — LLM and tool calls are wrapped
  - **Idle timeout** — session terminates itself after #{div(@idle_timeout_ms, 60_000)} minutes of inactivity
  - **Service-aware** — checks `Clawixir.Services.Monitor` before calling browser/AI

  The session runs an agentic LLM loop:
  1. Check rate limit
  2. Append user message to history
  3. Call LLM (with retry)
  4. If LLM returns tool_calls → execute tool (with retry + service health check) → append → loop
  5. Final text reply → send via channel adapter
  """

  use GenServer, restart: :temporary
  require Logger

  alias Clawixir.Agent.{LLMClient, ToolRegistry}
  alias Clawixir.{Audit, Channels, RateLimiter, Services.Monitor, TaskOrchestrator}
  alias Clawixir.Store.SessionStore

  @max_tool_iterations 8
  @idle_timeout_ms 15 * 60 * 1000  # 15 minutes

  @system_prompt """
  You are Clawixir 🦞, a personal AI assistant powered by Elixir and the Actor model.
  You are helpful, concise, and have access to tools to help the user.
  When using tools, prefer minimal round-trips. When finished, respond directly to the user.
  """

  # ─── Public API ────────────────────────────────────────────────────────────

  def start_link(%{key: key} = opts) do
    GenServer.start_link(__MODULE__, opts, name: via(key))
  end

  @doc "Feed an inbound message into this session."
  def ingest(pid, message), do: GenServer.cast(pid, {:ingest, message})

  # ─── GenServer callbacks ────────────────────────────────────────────────────

  @impl true
  def init(%{key: key, channel: channel, user_id: user_id}) do
    Audit.log(:session_created, %{session: key, channel: channel, user_id: user_id})

    # Try to restore persisted history, fall back to fresh system prompt
    history =
      case SessionStore.load(key) do
        {:ok, persisted} ->
          Logger.info("[Session #{key}] restored #{length(persisted)} messages from storage")
          persisted
        :not_found ->
          [%{role: "system", content: @system_prompt}]
      end

    {:ok,
     %{
       key:     key,
       channel: channel,
       user_id: user_id,
       history: history
     }, @idle_timeout_ms}
  end

  @impl true
  def handle_cast({:ingest, msg}, state) do
    Audit.log(:message_received, %{session: state.key, channel: state.channel, length: String.length(msg.text)})

    # ── Rate limit check ───────────────────────────────────────────────────
    case RateLimiter.check(state.key) do
      {:error, :rate_limited, retry_after_ms} ->
        Audit.log(:rate_limited, %{session: state.key, retry_after_ms: retry_after_ms})
        wait_s = Float.round(retry_after_ms / 1000, 1)
        Channels.send_reply(state.channel, state.user_id, msg,
          "⏳ You're sending messages too fast. Please wait #{wait_s}s.")
        {:noreply, state, @idle_timeout_ms}

      :ok ->
        Logger.info("[Session #{state.key}] ← #{inspect(msg.text)}")
        new_history = state.history ++ [%{role: "user", content: msg.text}]
        tools = ToolRegistry.all_tools()

        {reply, updated_history} =
          case run_agent_loop(state.key, new_history, tools, 0) do
            {:ok, text, hist} ->
              Logger.info("[Session #{state.key}] → #{inspect(text)}")
              {text, hist}

            {:error, :max_retries_exceeded, reason} ->
              Logger.error("[Session #{state.key}] retries exhausted: #{inspect(reason)}")
              {"⚠️ Service is temporarily unavailable. Please try again shortly.", state.history}

            {:error, reason} ->
              Logger.error("[Session #{state.key}] agent error: #{inspect(reason)}")
              {"⚠️ Something went wrong. Please try again.", state.history}
          end

        Channels.send_reply(state.channel, state.user_id, msg, reply)

        # Persist updated history asynchronously
        Task.start(fn ->
          SessionStore.save(state.key, state.channel, state.user_id, updated_history)
        end)

        {:noreply, %{state | history: updated_history}, @idle_timeout_ms}
    end
  end

  # Idle timeout — let the session die gracefully
  @impl true
  def handle_info(:timeout, state) do
    Audit.log(:session_timeout, %{session: state.key, channel: state.channel})
    Logger.info("[Session #{state.key}] idle timeout — terminating")
    {:stop, :normal, state}
  end

  # ─── Agent loop ─────────────────────────────────────────────────────────────

  defp run_agent_loop(_key, _history, _tools, iter) when iter >= @max_tool_iterations do
    {:error, :max_tool_iterations}
  end

  defp run_agent_loop(key, history, tools, iter) do
    # Call LLM with retry via TaskOrchestrator
    llm_result =
      TaskOrchestrator.run(
        fn -> LLMClient.chat(history, tools) end,
        name: "llm:chat",
        retries: 2,
        timeout_ms: 60_000,
        backoff_ms: 500
      )

    Audit.log(:llm_called, %{session: key, attempt: iter + 1})

    case llm_result do
      {:ok, {:ok, %{role: "assistant", content: text}}} when is_binary(text) ->
        {:ok, text, history ++ [%{role: "assistant", content: text}]}

      {:ok, {:ok, %{role: "assistant", tool_calls: tool_calls}}} ->
        history_with_call = history ++ [%{role: "assistant", content: nil, tool_calls: tool_calls}]

        tool_results =
          Enum.map(tool_calls, fn tc ->
            tool_name = tc["function"]["name"]
            tool_args = Jason.decode!(tc["function"]["arguments"])

            # Skip browser/AI tools if external service is unavailable
            result = maybe_invoke_tool(key, tool_name, tool_args)

            %{role: "tool", tool_call_id: tc["id"], content: Jason.encode!(result)}
          end)

        run_agent_loop(key, history_with_call ++ tool_results, tools, iter + 1)

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:error, _, _} = err ->
        err

      {:error, _} = err ->
        err
    end
  end

  # ─── Tool invocation with service health guard ──────────────────────────────

  defp maybe_invoke_tool(key, tool_name, tool_args) do
    # Browser tool guard
    if tool_name == "browser" and not Monitor.available?(:browser) do
      Audit.log(:tool_called, %{session: key, tool: tool_name, ok: false, reason: :service_down})
      %{error: "Browser service is currently unavailable. Please try again later."}
    else
      t0 = System.monotonic_time(:millisecond)
      result = ToolRegistry.invoke(tool_name, tool_args)
      duration_ms = System.monotonic_time(:millisecond) - t0
      Audit.log(:tool_called, %{session: key, tool: tool_name, duration_ms: duration_ms, ok: true})
      result
    end
  end

  # ─── Registry helpers ───────────────────────────────────────────────────────

  defp via(key), do: {:via, Registry, {Clawixir.SessionRegistry, key}}
end
