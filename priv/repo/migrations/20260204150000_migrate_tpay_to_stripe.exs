defmodule PrzetargowyPrzeglad.Repo.Migrations.MigrateTpayToStripe do
  use Ecto.Migration

  def up do
    # Rename columns in subscriptions table
    rename table(:subscriptions), :tpay_subscription_id, to: :stripe_subscription_id
    rename table(:subscriptions), :tpay_client_id, to: :stripe_customer_id

    # Rename columns in payment_transactions table
    rename table(:payment_transactions), :tpay_transaction_id, to: :stripe_payment_intent_id
    rename table(:payment_transactions), :tpay_title, to: :stripe_description
    rename table(:payment_transactions), :tpay_response, to: :stripe_response
  end

  def down do
    # Revert column names in subscriptions table
    rename table(:subscriptions), :stripe_subscription_id, to: :tpay_subscription_id
    rename table(:subscriptions), :stripe_customer_id, to: :tpay_client_id

    # Revert column names in payment_transactions table
    rename table(:payment_transactions), :stripe_payment_intent_id, to: :tpay_transaction_id
    rename table(:payment_transactions), :stripe_description, to: :tpay_title
    rename table(:payment_transactions), :stripe_response, to: :tpay_response
  end
end
