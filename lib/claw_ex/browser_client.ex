defmodule Clawixir.BrowserClient do
  @moduledoc """
  HTTP client for the external Node.js/Playwright Browser Service.

  The Browser Service runs independently at `BROWSER_SERVICE_URL` (default: http://localhost:4001).
  The Elixir Gateway NEVER runs Playwright — it delegates all browser automation here.

  This module is the only place in the Elixir codebase that knows about the
  browser service API. Skills call `Clawixir.BrowserClient.navigate/1` etc.
  """

  require Logger

  @default_url "http://localhost:4001"
  @timeout_ms  40_000

  defp base_url do
    Application.get_env(:clawixir, :browser_service_url, @default_url)
  end

  # ─── Health ─────────────────────────────────────────────────────────────────

  @doc "Check if the browser service is reachable."
  @spec health() :: :ok | {:error, :unavailable}
  def health do
    case Req.get("#{base_url()}/health", receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> :ok
      _                     -> {:error, :unavailable}
    end
  end

  # ─── Browser actions ────────────────────────────────────────────────────────

  @doc """
  Navigate to a URL and return `%{title, url, text}`.
  """
  @spec navigate(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def navigate(url, wait_for \\ "load") do
    post("/navigate", %{url: url, wait_for: wait_for})
  end

  @doc """
  Take a screenshot of a URL and return `%{image_base64}`.
  """
  @spec screenshot(String.t(), boolean()) :: {:ok, map()} | {:error, any()}
  def screenshot(url, full_page \\ false) do
    post("/screenshot", %{url: url, full_page: full_page})
  end

  @doc """
  Click an element identified by `selector` on `url`.
  Returns `%{ok, result_url, text}`.
  """
  @spec click(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def click(url, selector) do
    post("/click", %{url: url, selector: selector})
  end

  @doc """
  Scrape text content from `url`, optionally filtered by a CSS `selector`.
  Returns `%{url, content}`.
  """
  @spec scrape(String.t(), String.t() | nil) :: {:ok, map()} | {:error, any()}
  def scrape(url, selector \\ nil) do
    body = %{url: url}
    body = if selector, do: Map.put(body, :selector, selector), else: body
    post("/scrape", body)
  end

  @doc """
  Fill form fields and submit.
  `form` is a list of `%{selector: "...", value: "..."}` maps.
  `submit` is the CSS selector for the submit button.
  """
  @spec fill_and_submit(String.t(), [map()], String.t()) :: {:ok, map()} | {:error, any()}
  def fill_and_submit(url, form, submit) do
    post("/fill_and_submit", %{url: url, form: form, submit: submit})
  end

  # ─── Internal ───────────────────────────────────────────────────────────────

  defp post(path, body) do
    case Req.post("#{base_url()}#{path}", json: body, receive_timeout: @timeout_ms) do
      {:ok, %{status: 200, body: resp}} ->
        {:ok, resp}

      {:ok, %{status: status, body: %{"error" => msg}}} ->
        Logger.warning("[BrowserClient] #{path} → HTTP #{status}: #{msg}")
        {:error, msg}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, exception} ->
        Logger.error("[BrowserClient] #{path} request failed: #{inspect(exception)}")
        {:error, :browser_service_unreachable}
    end
  end
end
