defmodule Clawixir.Skills.BuiltIn.BrowserControl do
  @moduledoc """
  Built-in browser automation skill.

  Delegates all real work to the external Node.js/Playwright browser service
  via `Clawixir.BrowserClient`. The LLM can call this tool to:
  - Navigate and read page content
  - Take screenshots
  - Scrape specific elements
  - Click elements and fill/submit forms
  """
  @behaviour Clawixir.Skills.Skill

  alias Clawixir.BrowserClient

  @impl true
  def name, do: "browser"

  @impl true
  def definition do
    %{
      name: name(),
      description: """
      Control a web browser. Can navigate to URLs and read content, take screenshots,
      scrape specific elements, click buttons/links, and fill and submit forms.
      Actions: navigate, screenshot, scrape, click, fill_and_submit.
      """,
      parameters: %{
        type: "object",
        properties: %{
          action: %{
            type: "string",
            enum: ["navigate", "screenshot", "scrape", "click", "fill_and_submit"],
            description: "The browser action to perform"
          },
          url: %{
            type: "string",
            description: "The target URL"
          },
          selector: %{
            type: "string",
            description: "CSS selector for click or scrape actions (optional for scrape)"
          },
          form: %{
            type: "array",
            description: "Form fields to fill. Array of {selector, value} for fill_and_submit.",
            items: %{
              type: "object",
              properties: %{
                selector: %{type: "string"},
                value: %{type: "string"}
              }
            }
          },
          submit: %{
            type: "string",
            description: "CSS selector for submit button (required for fill_and_submit)"
          },
          full_page: %{
            type: "boolean",
            description: "Capture full page height in screenshot (default false)"
          }
        },
        required: ["action", "url"]
      }
    }
  end

  @impl true
  def run(%{"action" => "navigate", "url" => url} = args) do
    wait_for = Map.get(args, "wait_for", "load")
    case BrowserClient.navigate(url, wait_for) do
      {:ok, result} -> result
      {:error, err} -> %{error: to_string(err)}
    end
  end

  def run(%{"action" => "screenshot", "url" => url} = args) do
    full_page = Map.get(args, "full_page", false)
    case BrowserClient.screenshot(url, full_page) do
      {:ok, result} -> Map.put(result, :note, "image_base64 contains a PNG screenshot")
      {:error, err} -> %{error: to_string(err)}
    end
  end

  def run(%{"action" => "scrape", "url" => url} = args) do
    selector = Map.get(args, "selector")
    case BrowserClient.scrape(url, selector) do
      {:ok, result} -> result
      {:error, err} -> %{error: to_string(err)}
    end
  end

  def run(%{"action" => "click", "url" => url, "selector" => selector}) do
    case BrowserClient.click(url, selector) do
      {:ok, result} -> result
      {:error, err} -> %{error: to_string(err)}
    end
  end

  def run(%{"action" => "fill_and_submit", "url" => url} = args) do
    form   = Map.get(args, "form", [])
    submit = Map.get(args, "submit", "button[type=submit]")
    case BrowserClient.fill_and_submit(url, form, submit) do
      {:ok, result} -> result
      {:error, err} -> %{error: to_string(err)}
    end
  end

  def run(args), do: %{error: "Unknown or incomplete browser action: #{inspect(args)}"}
end
