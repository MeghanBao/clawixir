defmodule Clawixir.Repo do
  @moduledoc """
  Ecto repository backed by SQLite3.

  Provides persistent storage for session histories and future data needs.
  SQLite is chosen for zero-config deployment — no external database server required.
  """
  use Ecto.Repo,
    otp_app: :clawixir,
    adapter: Ecto.Adapters.SQLite3
end
