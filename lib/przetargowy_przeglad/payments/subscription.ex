defmodule PrzetargowyPrzeglad.Payments.Subscription do
  @moduledoc """
  Schema for user subscriptions.
  Tracks Stripe recurring payment subscriptions for premium access.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias PrzetargowyPrzeglad.Accounts.User
  alias PrzetargowyPrzeglad.Payments.PaymentTransaction

  @statuses ~w(pending active cancelled expired failed)
  @max_retry_count 3

  schema "subscriptions" do
    field :stripe_subscription_id, :string
    field :stripe_customer_id, :string
    field :status, :string, default: "pending"
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancelled_at, :utc_datetime
    field :cancel_at_period_end, :boolean, default: false
    field :amount, :decimal
    field :currency, :string, default: "PLN"
    field :retry_count, :integer, default: 0
    field :last_payment_error, :string
    field :metadata, :map, default: %{}

    belongs_to :user, User
    has_many :transactions, PaymentTransaction

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new subscription.
  """
  def create_changeset(subscription \\ %__MODULE__{}, attrs) do
    subscription
    |> cast(attrs, [:user_id, :amount, :currency, :metadata])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
    |> put_change(:status, "pending")
  end

  @doc """
  Changeset for activating a subscription after successful payment.
  """
  def activate_changeset(subscription, attrs) do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    period_end = DateTime.add(now, 30, :day)

    subscription
    |> cast(attrs, [:stripe_subscription_id, :stripe_customer_id, :metadata])
    |> put_change(:status, "active")
    |> put_change(:current_period_start, now)
    |> put_change(:current_period_end, period_end)
    |> put_change(:retry_count, 0)
    |> put_change(:last_payment_error, nil)
  end

  @doc """
  Changeset for renewing a subscription for another period.
  """
  def renew_changeset(subscription) do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    period_end = DateTime.add(now, 30, :day)

    subscription
    |> change()
    |> put_change(:status, "active")
    |> put_change(:current_period_start, now)
    |> put_change(:current_period_end, period_end)
    |> put_change(:retry_count, 0)
    |> put_change(:last_payment_error, nil)
  end

  @doc """
  Changeset for cancelling a subscription.
  If cancel_immediately is true, the subscription is cancelled immediately.
  Otherwise, it will be cancelled at the end of the current period.
  """
  def cancel_changeset(subscription, cancel_immediately \\ false) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    changeset =
      subscription
      |> change()
      |> put_change(:cancelled_at, now)

    if cancel_immediately do
      put_change(changeset, :status, "cancelled")
    else
      put_change(changeset, :cancel_at_period_end, true)
    end
  end

  @doc """
  Changeset for reactivating a cancelled subscription.
  Only works if the subscription was set to cancel at period end but is still active.
  """
  def reactivate_changeset(subscription) do
    subscription
    |> change()
    |> put_change(:cancelled_at, nil)
    |> put_change(:cancel_at_period_end, false)
  end

  @doc """
  Changeset for expiring a subscription.
  """
  def expire_changeset(subscription) do
    subscription
    |> change()
    |> put_change(:status, "expired")
  end

  @doc """
  Changeset for marking a payment failure.
  """
  def payment_failed_changeset(subscription, error_message) do
    new_retry_count = (subscription.retry_count || 0) + 1

    changeset =
      subscription
      |> change()
      |> put_change(:retry_count, new_retry_count)
      |> put_change(:last_payment_error, error_message)

    if new_retry_count >= @max_retry_count do
      put_change(changeset, :status, "failed")
    else
      changeset
    end
  end

  @doc """
  Checks if a subscription is currently active.
  """
  def active?(%__MODULE__{status: "active", current_period_end: end_date}) when not is_nil(end_date) do
    DateTime.before?(DateTime.utc_now(), end_date)
  end

  def active?(_), do: false

  @doc """
  Checks if a subscription is due for renewal (expires within given hours).
  """
  def due_for_renewal?(%__MODULE__{status: "active", current_period_end: end_date, cancel_at_period_end: false})
      when not is_nil(end_date) do
    hours_until_expiry = DateTime.diff(end_date, DateTime.utc_now(), :hour)
    hours_until_expiry <= 24 and hours_until_expiry > 0
  end

  def due_for_renewal?(_), do: false

  @doc """
  Checks if a subscription can be retried for payment.
  """
  def can_retry?(%__MODULE__{retry_count: count}) when count < @max_retry_count, do: true
  def can_retry?(_), do: false

  @doc """
  Returns all valid statuses.
  """
  def statuses, do: @statuses

  @doc """
  Returns the maximum retry count.
  """
  def max_retry_count, do: @max_retry_count
end
