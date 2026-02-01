defmodule PrzetargowyPrzeglad.Repo.Migrations.FixPaymentTransactionsForeignKey do
  use Ecto.Migration

  def change do
    # Drop the existing foreign key constraint that uses nilify_all
    # This conflicts with the NOT NULL constraint on user_id
    drop constraint(:payment_transactions, "payment_transactions_user_id_fkey")

    # Re-add with delete_all (CASCADE) so transactions are deleted with the user
    alter table(:payment_transactions) do
      modify :user_id, references(:users, on_delete: :delete_all), null: false
    end
  end
end
