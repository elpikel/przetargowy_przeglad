defmodule PrzetargowyPrzeglad.Repo.Migrations.CreateSubscribers do
  use Ecto.Migration

  def change do
    create table(:subscribers) do
      add :email, :citext, null: false
      add :name, :string
      add :company_name, :string
      add :industry, :string
      add :regions, {:array, :string}, default: []
      add :status, :string, default: "pending"
      add :confirmation_token, :string
      add :confirmed_at, :utc_datetime
      add :unsubscribed_at, :utc_datetime

      timestamps()
    end

    create unique_index(:subscribers, [:email])
    create unique_index(:subscribers, [:confirmation_token])

    create index(:subscribers, [:status])
  end
end
