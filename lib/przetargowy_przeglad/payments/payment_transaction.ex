defmodule PrzetargowyPrzeglad.Payments.PaymentTransaction do
  @moduledoc """
  Schema for payment transactions.
  Tracks all payment attempts and their results.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias PrzetargowyPrzeglad.Accounts.User
  alias PrzetargowyPrzeglad.Payments.Subscription

  @types ~w(initial renewal refund)
  @statuses ~w(pending completed failed refunded)

  schema "payment_transactions" do
    field :tpay_transaction_id, :string
    field :tpay_title, :string
    field :type, :string
    field :status, :string, default: "pending"
    field :amount, :decimal
    field :currency, :string, default: "PLN"
    field :error_code, :string
    field :error_message, :string
    field :tpay_response, :map, default: %{}
    field :paid_at, :utc_datetime

    belongs_to :subscription, Subscription
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new transaction.
  """
  def create_changeset(transaction \\ %__MODULE__{}, attrs) do
    transaction
    |> cast(attrs, [:subscription_id, :user_id, :tpay_transaction_id, :tpay_title, :type, :amount, :currency])
    |> validate_required([:user_id, :type, :amount])
    |> validate_inclusion(:type, @types)
    |> put_change(:status, "pending")
  end

  @doc """
  Changeset for marking a transaction as completed.
  """
  def complete_changeset(transaction, tpay_response) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    transaction
    |> change()
    |> put_change(:status, "completed")
    |> put_change(:tpay_response, tpay_response)
    |> put_change(:paid_at, now)
  end

  @doc """
  Changeset for marking a transaction as failed.
  """
  def fail_changeset(transaction, error_code, error_message) do
    transaction
    |> change()
    |> put_change(:status, "failed")
    |> put_change(:error_code, error_code)
    |> put_change(:error_message, error_message)
  end

  @doc """
  Changeset for marking a transaction as refunded.
  """
  def refund_changeset(transaction, tpay_response) do
    transaction
    |> change()
    |> put_change(:status, "refunded")
    |> put_change(:tpay_response, tpay_response)
  end

  @doc """
  Returns all valid types.
  """
  def types, do: @types

  @doc """
  Returns all valid statuses.
  """
  def statuses, do: @statuses
end
