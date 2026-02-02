defmodule PrzetargowyPrzeglad.Payments do
  @moduledoc """
  Context module for managing subscriptions and payment transactions.
  Handles the full subscription lifecycle: creation, activation, renewal, and cancellation.
  """

  import Ecto.Query

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzeglad.Payments.PaymentTransaction
  alias PrzetargowyPrzeglad.Payments.Subscription
  alias PrzetargowyPrzeglad.Repo
  alias PrzetargowyPrzeglad.Tpay.Client, as: TpayClient

  require Logger

  @subscription_amount Decimal.new("19.00")
  @subscription_currency "PLN"

  # ============================================================================
  # Subscription Queries
  # ============================================================================

  @doc """
  Gets a user's subscription.
  """
  def get_user_subscription(user_id) do
    Repo.get_by(Subscription, user_id: user_id)
  end

  @doc """
  Gets a subscription by ID.
  """
  def get_subscription(id) do
    Repo.get(Subscription, id)
  end

  @doc """
  Gets a subscription by Tpay subscription ID.
  """
  def get_subscription_by_tpay_id(tpay_subscription_id) do
    Repo.get_by(Subscription, tpay_subscription_id: tpay_subscription_id)
  end

  @doc """
  Checks if a user has an active subscription.
  """
  def subscription_active?(user_id) do
    case get_user_subscription(user_id) do
      nil -> false
      subscription -> Subscription.active?(subscription)
    end
  end

  @doc """
  Lists subscriptions that are due for renewal (expiring within given hours).
  """
  def list_subscriptions_due_for_renewal(hours_ahead \\ 24) do
    cutoff = DateTime.add(DateTime.utc_now(), hours_ahead, :hour)

    Repo.all(
      from(s in Subscription,
        where: s.status == "active",
        where: s.cancel_at_period_end == false,
        where: s.current_period_end <= ^cutoff,
        where: s.current_period_end > ^DateTime.utc_now(),
        preload: [:user]
      )
    )
  end

  @doc """
  Lists subscriptions that have expired (past their period end).
  """
  def list_expired_subscriptions do
    now = DateTime.utc_now()

    Repo.all(from(s in Subscription, where: s.status == "active", where: s.current_period_end < ^now, preload: [:user]))
  end

  @doc """
  Lists subscriptions that failed and can be retried.
  """
  def list_retryable_subscriptions do
    max_retries = Subscription.max_retry_count()

    Repo.all(
      from(s in Subscription,
        where: s.status == "active",
        where: s.retry_count > 0,
        where: s.retry_count < ^max_retries,
        preload: [:user]
      )
    )
  end

  # ============================================================================
  # Subscription Lifecycle
  # ============================================================================

  @doc """
  Initiates a new subscription by creating a Tpay transaction.
  Returns {:ok, %{redirect_url: url, subscription: subscription}} on success.
  """
  def create_subscription(user, callbacks) do
    # Check if user already has a subscription
    case get_user_subscription(user.id) do
      %Subscription{status: "active"} ->
        {:error, :already_subscribed}

      existing_subscription ->
        # Delete any old non-active subscription
        if existing_subscription, do: Repo.delete(existing_subscription)

        # Create new subscription record
        subscription_attrs = %{
          user_id: user.id,
          amount: @subscription_amount,
          currency: @subscription_currency
        }

        with {:ok, subscription} <- create_subscription_record(subscription_attrs),
             {:ok, transaction} <- create_initial_transaction(subscription, user),
             {:ok, tpay_result} <- initiate_tpay_payment(user, transaction, callbacks) do
          # Update transaction with Tpay ID
          update_transaction_tpay_id(transaction, tpay_result.transaction_id)

          {:ok,
           %{
             redirect_url: tpay_result.payment_url,
             subscription: subscription,
             transaction: transaction
           }}
        end
    end
  end

  defp create_subscription_record(attrs) do
    %Subscription{}
    |> Subscription.create_changeset(attrs)
    |> Repo.insert()
  end

  defp create_initial_transaction(subscription, user) do
    attrs = %{
      subscription_id: subscription.id,
      user_id: user.id,
      type: "initial",
      amount: @subscription_amount,
      currency: @subscription_currency,
      tpay_title: "Przetargowy Przegląd Premium - #{user.email}"
    }

    %PaymentTransaction{}
    |> PaymentTransaction.create_changeset(attrs)
    |> Repo.insert()
  end

  defp initiate_tpay_payment(user, transaction, callbacks) do
    TpayClient.create_transaction(%{
      amount: Decimal.to_float(@subscription_amount),
      description: "Przetargowy Przegląd Premium - subskrypcja miesięczna",
      hidden_description: "subscription:#{transaction.id}",
      payer: %{
        email: user.email,
        name: user.email
      },
      callbacks: %{
        success_url: callbacks.success_url,
        error_url: callbacks.error_url,
        notification_url: callbacks.notification_url
      }
    })
  end

  defp update_transaction_tpay_id(transaction, tpay_transaction_id) do
    transaction
    |> Ecto.Changeset.change(%{tpay_transaction_id: tpay_transaction_id})
    |> Repo.update()
  end

  @doc """
  Activates a subscription after successful payment.
  Called from webhook handler.
  """
  def activate_subscription(subscription, tpay_data) do
    Repo.transaction(fn ->
      # Activate subscription
      {:ok, subscription} =
        subscription
        |> Subscription.activate_changeset(%{
          tpay_subscription_id: tpay_data.card_token,
          tpay_client_id: tpay_data[:client_id]
        })
        |> Repo.update()

      # Upgrade user to premium
      Accounts.upgrade_to_premium(subscription.user_id)

      subscription
    end)
  end

  @doc """
  Processes a subscription renewal by charging the saved card.
  """
  def process_renewal(subscription) do
    subscription = Repo.preload(subscription, :user)

    with {:ok, transaction} <- create_renewal_transaction(subscription),
         {:ok, tpay_result} <- charge_renewal(subscription, transaction) do
      # Update transaction with result
      if tpay_result.status == "correct" or tpay_result.status == "pending" do
        update_transaction_tpay_id(transaction, tpay_result.transaction_id)
        {:ok, %{transaction: transaction, tpay_result: tpay_result}}
      else
        handle_renewal_failure(subscription, transaction, "Payment not approved")
      end
    else
      {:error, reason} ->
        Logger.error("Subscription renewal failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp create_renewal_transaction(subscription) do
    attrs = %{
      subscription_id: subscription.id,
      user_id: subscription.user_id,
      type: "renewal",
      amount: subscription.amount,
      currency: subscription.currency,
      tpay_title: "Przetargowy Przegląd Premium - odnowienie"
    }

    %PaymentTransaction{}
    |> PaymentTransaction.create_changeset(attrs)
    |> Repo.insert()
  end

  defp charge_renewal(subscription, _transaction) do
    notification_url = get_webhook_url()

    TpayClient.charge_recurring(subscription.tpay_subscription_id, %{
      amount: Decimal.to_float(subscription.amount),
      description: "Przetargowy Przegląd Premium - odnowienie subskrypcji",
      hidden_description: "renewal:#{subscription.id}",
      payer: %{
        email: subscription.user.email
      },
      callbacks: %{
        notification_url: notification_url
      }
    })
  end

  defp handle_renewal_failure(subscription, transaction, error_message) do
    # Mark transaction as failed
    transaction
    |> PaymentTransaction.fail_changeset("renewal_failed", error_message)
    |> Repo.update()

    # Update subscription retry count
    subscription
    |> Subscription.payment_failed_changeset(error_message)
    |> Repo.update()

    {:error, :renewal_failed}
  end

  @doc """
  Cancels a subscription. By default, cancels at period end.
  """
  def cancel_subscription(subscription, immediately \\ false) do
    Repo.transaction(fn ->
      {:ok, subscription} =
        subscription
        |> Subscription.cancel_changeset(immediately)
        |> Repo.update()

      # If cancelling immediately, downgrade user
      if immediately do
        Accounts.downgrade_to_free(subscription.user_id)

        # Deauthorize the card token if present
        if subscription.tpay_subscription_id do
          TpayClient.deauthorize_card(subscription.tpay_subscription_id)
        end
      end

      subscription
    end)
  end

  @doc """
  Cancels a user's subscription by user ID.
  """
  def cancel_user_subscription(user_id, immediately \\ false) do
    case get_user_subscription(user_id) do
      nil -> {:error, :no_subscription}
      subscription -> cancel_subscription(subscription, immediately)
    end
  end

  @doc """
  Reactivates a cancelled subscription.
  Only works if the subscription was set to cancel at period end but is still active.
  """
  def reactivate_subscription(subscription) do
    if subscription.status == "active" and subscription.cancel_at_period_end do
      subscription
      |> Subscription.reactivate_changeset()
      |> Repo.update()
    else
      {:error, :cannot_reactivate}
    end
  end

  @doc """
  Reactivates a user's subscription by user ID.
  """
  def reactivate_user_subscription(user_id) do
    case get_user_subscription(user_id) do
      nil -> {:error, :no_subscription}
      subscription -> reactivate_subscription(subscription)
    end
  end

  @doc """
  Expires a subscription and downgrades the user.
  """
  def expire_subscription(subscription) do
    Repo.transaction(fn ->
      {:ok, subscription} =
        subscription
        |> Subscription.expire_changeset()
        |> Repo.update()

      # Downgrade user
      Accounts.downgrade_to_free(subscription.user_id)

      subscription
    end)
  end

  # ============================================================================
  # Webhook Handlers
  # ============================================================================

  @doc """
  Handles a successful payment notification from Tpay.
  """
  def handle_payment_completed(%{transaction_id: tpay_transaction_id, card_token: card_token} = event) do
    transaction = get_transaction_by_tpay_id(tpay_transaction_id)

    if transaction do
      Repo.transaction(fn ->
        # Mark transaction as completed
        {:ok, _transaction} =
          transaction
          |> PaymentTransaction.complete_changeset(event.raw_event)
          |> Repo.update()

        # Handle based on transaction type
        case transaction.type do
          "initial" ->
            subscription = get_subscription(transaction.subscription_id)

            if subscription do
              activate_subscription(subscription, %{card_token: card_token})
            end

          "renewal" ->
            subscription = get_subscription(transaction.subscription_id)

            if subscription do
              subscription
              |> Subscription.renew_changeset()
              |> Repo.update()
            end

          _ ->
            :ok
        end

        :ok
      end)
    else
      Logger.warning("No transaction found for Tpay ID: #{tpay_transaction_id}")
      {:error, :transaction_not_found}
    end
  end

  @doc """
  Handles a failed payment notification from Tpay.
  """
  def handle_payment_failed(%{transaction_id: tpay_transaction_id, error_code: error_code, error_message: error_message}) do
    transaction = get_transaction_by_tpay_id(tpay_transaction_id)

    if transaction do
      Repo.transaction(fn ->
        # Mark transaction as failed
        {:ok, _transaction} =
          transaction
          |> PaymentTransaction.fail_changeset(error_code, error_message)
          |> Repo.update()

        # If this is a renewal, update subscription retry count
        if transaction.type == "renewal" and transaction.subscription_id do
          subscription = get_subscription(transaction.subscription_id)

          if subscription do
            subscription
            |> Subscription.payment_failed_changeset(error_message)
            |> Repo.update()
          end
        end

        :ok
      end)
    else
      Logger.warning("No transaction found for Tpay ID: #{tpay_transaction_id}")
      {:error, :transaction_not_found}
    end
  end

  @doc """
  Handles a refund notification from Tpay.
  """
  def handle_refund(%{transaction_id: tpay_transaction_id} = event) do
    transaction = get_transaction_by_tpay_id(tpay_transaction_id)

    if transaction do
      transaction
      |> PaymentTransaction.refund_changeset(event.raw_event)
      |> Repo.update()
    else
      {:error, :transaction_not_found}
    end
  end

  # ============================================================================
  # Transaction Queries
  # ============================================================================

  @doc """
  Gets a transaction by Tpay transaction ID.
  """
  def get_transaction_by_tpay_id(tpay_transaction_id) do
    Repo.get_by(PaymentTransaction, tpay_transaction_id: tpay_transaction_id)
  end

  @doc """
  Lists transactions for a user.
  """
  def list_user_transactions(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    Repo.all(from(t in PaymentTransaction, where: t.user_id == ^user_id, order_by: [desc: t.inserted_at], limit: ^limit))
  end

  @doc """
  Lists transactions for a subscription.
  """
  def list_subscription_transactions(subscription_id) do
    Repo.all(from(t in PaymentTransaction, where: t.subscription_id == ^subscription_id, order_by: [desc: t.inserted_at]))
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp get_webhook_url do
    host = Application.get_env(:przetargowy_przeglad, PrzetargowyPrzegladWeb.Endpoint)[:url][:host]
    scheme = Application.get_env(:przetargowy_przeglad, PrzetargowyPrzegladWeb.Endpoint)[:url][:scheme] || "https"
    "#{scheme}://#{host}/webhooks/tpay"
  end

  @doc """
  Returns the subscription amount.
  """
  def subscription_amount, do: @subscription_amount

  @doc """
  Returns the subscription currency.
  """
  def subscription_currency, do: @subscription_currency
end
