defmodule ClawixirWeb do
  @moduledoc """
  Entry point for ClawixirWeb components.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def session_options do
    [
      store: :cookie,
      key: "_claw_ex_key",
      signing_salt: "claw_ex_salt",
      same_site: "Lax"
    ]
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: []
      import Plug.Conn
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {ClawixirWeb.Layouts, :app}
      unquote(html_helpers())
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.Component
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
