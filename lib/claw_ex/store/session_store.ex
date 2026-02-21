defmodule Clawixir.Store.SessionStore do
  @moduledoc """
  Persistent session storage backed by SQLite via Ecto.

  Provides `save/3`, `load/1`, and `delete/1` for session history persistence.
  Sessions are keyed by the same string used in the process Registry (`channel:user_id`).

  ## Usage

      # Save after each message exchange
      SessionStore.save("telegram:alice", :telegram, "alice", history)

      # Restore when a session is re-created
      case SessionStore.load("telegram:alice") do
        {:ok, history} -> # resume
        :not_found     -> # start fresh
      end
  """

  alias Clawixir.Repo
  alias Clawixir.Store.SessionRecord
  import Ecto.Query

  @doc "Save or update a session's history."
  @spec save(String.t(), atom(), String.t(), [map()]) :: {:ok, SessionRecord.t()} | {:error, Ecto.Changeset.t()}
  def save(key, channel, user_id, history) do
    history_json = Jason.encode!(history)

    case Repo.get_by(SessionRecord, key: key) do
      nil ->
        %SessionRecord{}
        |> SessionRecord.changeset(%{
          key: key,
          channel: to_string(channel),
          user_id: user_id,
          history: history_json
        })
        |> Repo.insert()

      existing ->
        existing
        |> SessionRecord.changeset(%{history: history_json})
        |> Repo.update()
    end
  end

  @doc "Load a session's history by key. Returns {:ok, history_list} or :not_found."
  @spec load(String.t()) :: {:ok, [map()]} | :not_found
  def load(key) do
    case Repo.get_by(SessionRecord, key: key) do
      nil -> :not_found
      record ->
        history = Jason.decode!(record.history, keys: :atoms)
        {:ok, history}
    end
  end

  @doc "Delete a session from persistent storage."
  @spec delete(String.t()) :: :ok
  def delete(key) do
    from(s in SessionRecord, where: s.key == ^key)
    |> Repo.delete_all()

    :ok
  end

  @doc "List all persisted sessions."
  @spec list_all() :: [SessionRecord.t()]
  def list_all do
    Repo.all(SessionRecord)
  end
end
