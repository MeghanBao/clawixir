defmodule Clawixir.Skills.BuiltIn.RagQuery do
  @moduledoc """
  Built-in RAG (Retrieval-Augmented Generation) skill.
  Delegates to the external Python AI Service via `Clawixir.Services.AiClient`.
  Falls back gracefully if the AI service is not running.
  """
  @behaviour Clawixir.Skills.Skill

  alias Clawixir.Services.AiClient

  @impl true
  def name, do: "rag_query"

  @impl true
  def definition do
    %{
      name: name(),
      description: "Query a knowledge base using RAG (Retrieval-Augmented Generation). Useful for answering questions based on uploaded documents or a specific collection.",
      parameters: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "The question or search query"
          },
          collection: %{
            type: "string",
            description: "Optional: name of the document collection to search (default: all)"
          }
        },
        required: ["query"]
      }
    }
  end

  @impl true
  def run(%{"query" => query} = args) do
    collection = Map.get(args, "collection")
    case AiClient.rag_query(query, collection) do
      {:ok, result}                    -> result
      {:error, :ai_service_unavailable} -> %{error: "RAG service is not running. Start the Python AI service to use this feature."}
      {:error, reason}                 -> %{error: "RAG query failed: #{inspect(reason)}"}
    end
  end
end
