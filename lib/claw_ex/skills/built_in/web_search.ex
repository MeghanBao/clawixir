defmodule Clawixir.Skills.BuiltIn.WebSearch do
  @moduledoc "Built-in web search using DuckDuckGo Instant Answer API."
  @behaviour Clawixir.Skills.Skill

  @impl true
  def name, do: "web_search"

  @impl true
  def definition do
    %{
      name: name(),
      description: "Search the web and return relevant results for a query.",
      parameters: %{
        type: "object",
        properties: %{
          query: %{type: "string", description: "The search query"}
        },
        required: ["query"]
      }
    }
  end

  @impl true
  def run(%{"query" => query}) do
    case Req.get("https://api.duckduckgo.com/",
           params: [q: query, format: "json", no_html: 1, skip_disambig: 1]
         ) do
      {:ok, %{status: 200, body: body}} ->
        parse_ddg(body, query)

      {:error, reason} ->
        %{error: "Search failed: #{inspect(reason)}"}
    end
  end

  defp parse_ddg(body, query) do
    abstract = body["Abstract"]
    related  = body["RelatedTopics"] || []

    results =
      related
      |> Enum.take(4)
      |> Enum.map(fn topic ->
        %{title: topic["Text"] || "", url: topic["FirstURL"] || ""}
      end)

    %{
      query:    query,
      summary:  if(abstract != "", do: abstract, else: "No direct answer found."),
      results:  results
    }
  end
end
