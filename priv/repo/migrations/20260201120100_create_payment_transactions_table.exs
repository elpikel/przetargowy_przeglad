defmodule PrzetargowyPrzeglad.Repo.Migrations.CreatePaymentTransactionsTable do
  use Ecto.Migration

  def change do
    create table(:payment_transactions) do
      add :subscription_id, references(:subscriptions, on_delete: :nilify_all)
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :tpay_transaction_id, :string
      add :tpay_title, :string
      add :type, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :currency, :string, default: "PLN"
      add :error_code, :string
      add :error_message, :string
      add :tpay_response, :map, default: %{}
      add :paid_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:payment_transactions, [:subscription_id])
    create index(:payment_transactions, [:user_id])
    create index(:payment_transactions, [:status])

    create unique_index(:payment_transactions, [:tpay_transaction_id],
             where: "tpay_transaction_id IS NOT NULL"
           )
  end
end
