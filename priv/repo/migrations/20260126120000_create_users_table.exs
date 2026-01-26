defmodule PrzetargowyPrzeglad.Repo.Migrations.CreateUsersTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :password, :string, null: false
      add :subscription_plan, :string, null: false, default: "free"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
  end
end
