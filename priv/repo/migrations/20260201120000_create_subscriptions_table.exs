defmodule PrzetargowyPrzeglad.Repo.Migrations.CreateSubscriptionsTable do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :tpay_subscription_id, :string
      add :tpay_client_id, :string
      add :status, :string, null: false, default: "pending"
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      add :cancelled_at, :utc_datetime
      add :cancel_at_period_end, :boolean, default: false
      add :amount, :decimal, precision: 10, scale: 2, default: 19.00
      add :currency, :string, default: "PLN"
      add :retry_count, :integer, default: 0
      add :last_payment_error, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:subscriptions, [:user_id])
    create index(:subscriptions, [:status])
    create index(:subscriptions, [:current_period_end])

    create unique_index(:subscriptions, [:tpay_subscription_id],
             where: "tpay_subscription_id IS NOT NULL"
           )
  end
end
