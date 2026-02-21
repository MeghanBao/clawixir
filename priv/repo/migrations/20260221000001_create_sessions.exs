defmodule Clawixir.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("lower(hex(randomblob(16)))")
      add :key, :string, null: false
      add :channel, :string, null: false
      add :user_id, :string, null: false
      add :history, :text, null: false, default: "[]"

      timestamps()
    end

    create unique_index(:sessions, [:key])
    create index(:sessions, [:user_id])
    create index(:sessions, [:channel, :user_id])
  end
end
