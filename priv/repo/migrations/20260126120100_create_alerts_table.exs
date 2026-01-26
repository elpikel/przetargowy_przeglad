defmodule PrzetargowyPrzeglad.Repo.Migrations.CreateAlertsTable do
  use Ecto.Migration

  def change do
    create table(:alerts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :rules, :jsonb, null: false, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create index(:alerts, [:user_id])
  end
end
