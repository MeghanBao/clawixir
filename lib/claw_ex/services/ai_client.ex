defmodule Clawixir.Services.AiClient do
  @moduledoc """
  Adapter for an external AI/Python microservice (RAG, local LLM, PDF parsing, etc.).

  If you run a local Python service (FastAPI + Ollama, LlamaIndex, etc.) it should
  expose the endpoints below. Configure the URL via the `AI_SERVICE_URL` env var.

  ## Endpoints expected from the Python service:

      POST /rag/query     { query, collection? }     → { answer, sources }
      POST /embed         { text }                   → { embedding: [float] }
      POST /parse_pdf     { url | base64 }           → { text, pages }
      GET  /health                                   → { status: "ok" }

  If the Python service is not running, these functions return {:error, :ai_service_unavailable}.
  The built-in LLMClient (Anthropic/OpenAI) is separate and always required.
  This service is optional and enhances capabilities.
  """

  require Logger

  @default_url "http://localhost:5001"
  @timeout_ms  60_000

  defp base_url do
    Application.get_env(:clawixir, :ai_service_url, @default_url)
  end

  # ─── Health ─────────────────────────────────────────────────────────────────

  @doc "Check if the AI service is reachable."
  @spec health() :: :ok | {:error, :unavailable}
  def health do
    case Req.get("#{base_url()}/health", receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> :ok
      _                     -> {:error, :unavailable}
    end
  end

  # ─── RAG ────────────────────────────────────────────────────────────────────

  @doc """
  Query the RAG (Retrieval-Augmented Generation) system.
  Returns `%{answer: text, sources: [...]}`
  """
  @spec rag_query(String.t(), String.t() | nil) :: {:ok, map()} | {:error, any()}
  def rag_query(query, collection \\ nil) do
    body = %{query: query}
    body = if collection, do: Map.put(body, :collection, collection), else: body
    post("/rag/query", body)
  end

  # ─── Embeddings ─────────────────────────────────────────────────────────────

  @doc "Generate a text embedding vector."
  @spec embed(String.t()) :: {:ok, [float()]} | {:error, any()}
  def embed(text) do
    case post("/embed", %{text: text}) do
      {:ok, %{"embedding" => vec}} -> {:ok, vec}
      other                        -> other
    end
  end

  # ─── PDF parsing ────────────────────────────────────────────────────────────

  @doc "Parse a PDF from a URL and return extracted text."
  @spec parse_pdf(String.t()) :: {:ok, map()} | {:error, any()}
  def parse_pdf(url) do
    post("/parse_pdf", %{url: url})
  end

  # ─── Internal ───────────────────────────────────────────────────────────────

  defp post(path, body) do
    case Req.post("#{base_url()}#{path}", json: body, receive_timeout: @timeout_ms) do
      {:ok, %{status: 200, body: resp}} ->
        {:ok, resp}

      {:ok, %{status: status}} ->
        Logger.warning("[AiClient] #{path} → HTTP #{status}")
        {:error, {:http_error, status}}

      {:error, _} ->
        Logger.warning("[AiClient] #{path} → service unreachable at #{base_url()}")
        {:error, :ai_service_unavailable}
    end
  end
end
