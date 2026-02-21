defmodule Clawixir.Store.SessionRecord do
  @moduledoc """
  Ecto schema for persisted session data.

  Stores the conversation history as JSON in a text column.
  Keyed by the same session key used in the Registry (`channel:user_id`).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "sessions" do
    field :key, :string
    field :channel, :string
    field :user_id, :string
    field :history, :string, default: "[]"

    timestamps()
  end

  @required ~w(key channel user_id)a
  @optional ~w(history)a

  def changeset(record, attrs) do
    record
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:key)
  end
end
