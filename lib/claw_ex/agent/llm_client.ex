defmodule Clawixir.Agent.LLMClient do
  @moduledoc """
  Unified LLM client supporting Anthropic (Claude) and OpenAI (GPT-4o / o-series).

  Reads from config:
    config :clawixir, :llm,
      provider: :anthropic,   # or :openai
      model:    "claude-opus-4-5",
      api_key:  System.get_env("ANTHROPIC_API_KEY")
  """

  require Logger

  @anthropic_url "https://api.anthropic.com/v1/messages"
  @openai_url    "https://api.openai.com/v1/chat/completions"
  @anthropic_version "2023-06-01"

  @doc """
  Send a chat request to the configured LLM provider.

  Returns:
    {:ok, %{role: "assistant", content: text}}
    {:ok, %{role: "assistant", tool_calls: [...]}}
    {:error, reason}
  """
  @spec chat([map()], [map()]) :: {:ok, map()} | {:error, any()}
  def chat(messages, tools \\ []) do
    cfg = Application.fetch_env!(:clawixir, :llm)

    case cfg[:provider] do
      :anthropic -> anthropic_chat(messages, tools, cfg)
      :openai    -> openai_chat(messages, tools, cfg)
      other      -> {:error, {:unknown_provider, other}}
    end
  end

  # ─── Anthropic ──────────────────────────────────────────────────────────────

  defp anthropic_chat(messages, tools, cfg) do
    {system_msgs, user_msgs} = Enum.split_with(messages, &(&1.role == "system"))
    system_text = Enum.map_join(system_msgs, "\n", & &1.content)

    body = %{
      model: cfg[:model] || "claude-opus-4-5",
      max_tokens: 4096,
      system: system_text,
      messages: normalize_messages(user_msgs),
      tools: format_tools_anthropic(tools)
    }

    case Req.post(@anthropic_url,
           json: body,
           headers: anthropic_headers(cfg[:api_key]),
           receive_timeout: 60_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        parse_anthropic_response(body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("[LLMClient/Anthropic] HTTP #{status}: #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_anthropic_response(%{"stop_reason" => "tool_use", "content" => content}) do
    tool_calls =
      content
      |> Enum.filter(&(&1["type"] == "tool_use"))
      |> Enum.map(fn tc ->
        %{
          "id"       => tc["id"],
          "type"     => "function",
          "function" => %{"name" => tc["name"], "arguments" => Jason.encode!(tc["input"])}
        }
      end)

    {:ok, %{role: "assistant", tool_calls: tool_calls}}
  end

  defp parse_anthropic_response(%{"content" => [%{"type" => "text", "text" => text} | _]}) do
    {:ok, %{role: "assistant", content: text}}
  end

  defp parse_anthropic_response(body), do: {:error, {:unexpected_anthropic_response, body}}

  defp anthropic_headers(api_key) do
    [
      {"x-api-key", api_key},
      {"anthropic-version", @anthropic_version},
      {"content-type", "application/json"}
    ]
  end

  defp format_tools_anthropic([]), do: []
  defp format_tools_anthropic(tools) do
    Enum.map(tools, fn t ->
      %{
        name:         t.name,
        description:  t.description,
        input_schema: t.parameters
      }
    end)
  end

  # ─── OpenAI ─────────────────────────────────────────────────────────────────

  defp openai_chat(messages, tools, cfg) do
    body =
      %{
        model: cfg[:model] || "gpt-4o",
        messages: normalize_messages(messages),
        max_tokens: 4096
      }
      |> maybe_add_tools(tools)

    case Req.post(@openai_url,
           json: body,
           headers: openai_headers(cfg[:api_key]),
           receive_timeout: 60_000
         ) do
      {:ok, %{status: 200, body: body}} ->
        parse_openai_response(body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("[LLMClient/OpenAI] HTTP #{status}: #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_openai_response(%{"choices" => [%{"message" => msg} | _]}) do
    case msg do
      %{"tool_calls" => tool_calls} when is_list(tool_calls) ->
        {:ok, %{role: "assistant", tool_calls: tool_calls}}

      %{"content" => text} ->
        {:ok, %{role: "assistant", content: text}}
    end
  end

  defp parse_openai_response(body), do: {:error, {:unexpected_openai_response, body}}

  defp openai_headers(api_key) do
    [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]
  end

  defp maybe_add_tools(body, []), do: body
  defp maybe_add_tools(body, tools) do
    Map.put(body, :tools, Enum.map(tools, fn t ->
      %{type: "function", function: %{name: t.name, description: t.description, parameters: t.parameters}}
    end))
  end

  # ─── Shared helpers ─────────────────────────────────────────────────────────

  defp normalize_messages(messages) do
    Enum.map(messages, fn m ->
      m
      |> Map.take([:role, :content, :tool_calls, :tool_call_id])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end)
  end
end
