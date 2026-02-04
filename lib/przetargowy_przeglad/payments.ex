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

  require Logger

  @subscription_amount Decimal.new("19.00")
  @subscription_currency "PLN"

  # Get the Stripe client module (real or mock based on config)
  defp stripe_client do
    Application.get_env(:przetargowy_przeglad, :stripe_client, PrzetargowyPrzeglad.Stripe.Client)
  end

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
  Gets a subscription by Stripe subscription ID.
  """
  def get_subscription_by_stripe_id(stripe_subscription_id) do
    Repo.get_by(Subscription, stripe_subscription_id: stripe_subscription_id)
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
  Note: With Stripe, renewals are automatic. This is mainly for monitoring.
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
  Initiates a new subscription by creating a Stripe Checkout Session.
  Returns {:ok, %{redirect_url: url, subscription: subscription}} on success.
  """
  def create_subscription(user, callbacks) do
    # Check if user already has a subscription
    case get_user_subscription(user.id) do
      %Subscription{status: "active"} ->
        {:error, :already_subscribed}

      existing_subscription ->
        # Capture customer_id BEFORE deleting (for better resubscription UX)
        existing_customer_id = existing_subscription && existing_subscription.stripe_customer_id

        # Delete any old non-active subscription
        if existing_subscription, do: Repo.delete(existing_subscription)

        # Create new subscription record
        subscription_attrs = %{
          user_id: user.id,
          amount: @subscription_amount,
          currency: @subscription_currency
        }

        with {:ok, subscription} <- create_subscription_record(subscription_attrs),
             {:ok, stripe_result} <- initiate_stripe_checkout(user, subscription, callbacks, existing_customer_id) do
          {:ok,
           %{
             redirect_url: stripe_result.checkout_url,
             subscription: subscription,
             session_id: stripe_result.session_id
           }}
        end
    end
  end

  defp create_subscription_record(attrs) do
    %Subscription{}
    |> Subscription.create_changeset(attrs)
    |> Repo.insert()
  end

  defp initiate_stripe_checkout(user, subscription, callbacks, existing_customer_id) do
    params = %{
      success_url: callbacks.success_url,
      cancel_url: callbacks.error_url,
      metadata: %{
        user_id: to_string(user.id),
        subscription_id: to_string(subscription.id)
      }
    }

    # Use existing customer if available (preserves saved payment methods)
    params =
      if existing_customer_id do
        Map.put(params, :customer_id, existing_customer_id)
      else
        Map.put(params, :customer_email, user.email)
      end

    stripe_client().create_checkout_session(params)
  end

  @doc """
  Activates a subscription after successful payment.
  Called from webhook handler when checkout.session.completed event is received.
  """
  def activate_subscription(subscription, stripe_data) do
    Repo.transaction(fn ->
      # Activate subscription
      {:ok, subscription} =
        subscription
        |> Subscription.activate_changeset(%{
          stripe_subscription_id: stripe_data.subscription_id,
          stripe_customer_id: stripe_data.customer_id
        })
        |> Repo.update()

      # Upgrade user to premium
      Accounts.upgrade_to_premium(subscription.user_id)

      subscription
    end)
  end

  # Private helper - activates subscription without transaction
  defp do_activate_subscription(subscription, stripe_data) do
    # Activate subscription
    {:ok, subscription} =
      subscription
      |> Subscription.activate_changeset(%{
        stripe_subscription_id: stripe_data.subscription_id,
        stripe_customer_id: stripe_data.customer_id
      })
      |> Repo.update()

    # Upgrade user to premium
    Accounts.upgrade_to_premium(subscription.user_id)

    subscription
  end

  @doc """
  Renews a subscription for another period.
  Called from webhook handler when invoice.payment_succeeded event is received.
  """
  def renew_subscription(subscription) do
    subscription
    |> Subscription.renew_changeset()
    |> Repo.update()
  end

  @doc """
  Cancels a subscription. By default, cancels at period end.
  """
  def cancel_subscription(subscription, immediately \\ false) do
    Repo.transaction(fn ->
      # Cancel in Stripe
      case stripe_client().cancel_subscription(subscription.stripe_subscription_id, immediately) do
        {:ok, _stripe_subscription} ->
          # Update local subscription
          {:ok, subscription} =
            subscription
            |> Subscription.cancel_changeset(immediately)
            |> Repo.update()

          # If cancelling immediately, downgrade user
          if immediately do
            Accounts.downgrade_to_free(subscription.user_id)
          end

          subscription

        {:error, reason} ->
          Logger.error("Failed to cancel Stripe subscription: #{inspect(reason)}")
          Repo.rollback(reason)
      end
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
      Repo.transaction(fn ->
        case stripe_client().reactivate_subscription(subscription.stripe_subscription_id) do
          {:ok, _stripe_subscription} ->
            {:ok, subscription} =
              subscription
              |> Subscription.reactivate_changeset()
              |> Repo.update()

            subscription

          {:error, reason} ->
            Logger.error("Failed to reactivate Stripe subscription: #{inspect(reason)}")
            Repo.rollback(reason)
        end
      end)
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
  Also removes all premium alerts.
  """
  def expire_subscription(subscription) do
    Repo.transaction(fn ->
      {:ok, subscription} =
        subscription
        |> Subscription.expire_changeset()
        |> Repo.update()

      # Downgrade user
      Accounts.downgrade_to_free(subscription.user_id)

      # Remove premium alerts
      Accounts.delete_premium_alerts(subscription.user_id)

      subscription
    end)
  end

  # ============================================================================
  # Webhook Handlers
  # ============================================================================

  @doc """
  Handles a successful payment notification from Stripe.
  Can be called for both initial checkout and recurring invoices.
  """
  def handle_payment_completed(%{session_id: _session_id, subscription_id: stripe_subscription_id} = event) do
    # This is a checkout.session.completed event (initial payment)
    metadata = event[:metadata] || %{}
    subscription_id = metadata["subscription_id"]

    if subscription_id do
      subscription = get_subscription(subscription_id)

      if subscription do
        Repo.transaction(fn ->
          # Create transaction record
          create_initial_transaction(subscription, event)

          # Activate subscription
          do_activate_subscription(subscription, %{
            subscription_id: stripe_subscription_id,
            customer_id: event.customer_id
          })

          :ok
        end)
      else
        Logger.warning("No subscription found for ID: #{subscription_id}")
        {:error, :subscription_not_found}
      end
    else
      Logger.warning("No subscription_id in metadata")
      {:error, :missing_metadata}
    end
  end

  def handle_payment_completed(%{invoice_id: _invoice_id, subscription_id: stripe_subscription_id} = event) do
    # This is an invoice.payment_succeeded event (renewal)
    subscription = get_subscription_by_stripe_id(stripe_subscription_id)

    if subscription do
      Repo.transaction(fn ->
        # Create transaction record
        create_renewal_transaction_from_webhook(subscription, event)

        # Renew subscription
        {:ok, _subscription} = renew_subscription(subscription)

        :ok
      end)
    else
      Logger.warning("No subscription found for Stripe ID: #{stripe_subscription_id}")
      {:error, :subscription_not_found}
    end
  end

  @doc """
  Handles a failed payment notification from Stripe.
  """
  def handle_payment_failed(%{invoice_id: _invoice_id, subscription_id: stripe_subscription_id} = event) do
    subscription = get_subscription_by_stripe_id(stripe_subscription_id)

    if subscription do
      Repo.transaction(fn ->
        # Create failed transaction record
        create_failed_transaction(subscription, event)

        # Update subscription retry count
        {:ok, _subscription} =
          subscription
          |> Subscription.payment_failed_changeset(event.error_message)
          |> Repo.update()

        :ok
      end)
    else
      Logger.warning("No subscription found for Stripe ID: #{stripe_subscription_id}")
      {:error, :subscription_not_found}
    end
  end

  @doc """
  Handles a subscription update notification from Stripe.
  """
  def handle_subscription_updated(%{subscription_id: stripe_subscription_id} = event) do
    subscription = get_subscription_by_stripe_id(stripe_subscription_id)

    if subscription do
      attrs = %{
        cancel_at_period_end: event.cancel_at_period_end,
        current_period_end: DateTime.from_unix!(event.current_period_end)
      }

      subscription
      |> Ecto.Changeset.change(attrs)
      |> Repo.update()
    else
      {:error, :subscription_not_found}
    end
  end

  @doc """
  Handles a subscription deletion notification from Stripe.
  """
  def handle_subscription_deleted(%{subscription_id: stripe_subscription_id}) do
    subscription = get_subscription_by_stripe_id(stripe_subscription_id)

    if subscription do
      expire_subscription(subscription)
    else
      {:error, :subscription_not_found}
    end
  end

  @doc """
  Handles a refund notification from Stripe.
  """
  def handle_refund(%{payment_intent_id: payment_intent_id} = event) do
    transaction = get_transaction_by_stripe_payment_intent_id(payment_intent_id)

    if transaction do
      transaction
      |> PaymentTransaction.refund_changeset(event.raw_event)
      |> Repo.update()
    else
      {:error, :transaction_not_found}
    end
  end

  # ============================================================================
  # Transaction Helpers
  # ============================================================================

  defp create_initial_transaction(subscription, event) do
    attrs = %{
      subscription_id: subscription.id,
      user_id: subscription.user_id,
      type: "initial",
      amount: event[:amount] || @subscription_amount,
      currency: @subscription_currency,
      stripe_description: "Przetargowy Przegląd Premium - initial payment",
      stripe_payment_intent_id: event[:payment_intent_id]
    }

    %PaymentTransaction{}
    |> PaymentTransaction.create_changeset(attrs)
    |> Ecto.Changeset.put_change(:status, "completed")
    |> Ecto.Changeset.put_change(:stripe_response, event.raw_event || %{})
    |> Ecto.Changeset.put_change(:paid_at, DateTime.truncate(DateTime.utc_now(), :second))
    |> Repo.insert()
  end

  defp create_renewal_transaction_from_webhook(subscription, event) do
    attrs = %{
      subscription_id: subscription.id,
      user_id: subscription.user_id,
      type: "renewal",
      amount: event[:amount] || subscription.amount,
      currency: subscription.currency,
      stripe_description: "Przetargowy Przegląd Premium - renewal",
      stripe_payment_intent_id: event[:payment_intent_id]
    }

    %PaymentTransaction{}
    |> PaymentTransaction.create_changeset(attrs)
    |> Ecto.Changeset.put_change(:status, "completed")
    |> Ecto.Changeset.put_change(:stripe_response, event.raw_event || %{})
    |> Ecto.Changeset.put_change(:paid_at, DateTime.truncate(DateTime.utc_now(), :second))
    |> Repo.insert()
  end

  defp create_failed_transaction(subscription, event) do
    attrs = %{
      subscription_id: subscription.id,
      user_id: subscription.user_id,
      type: "renewal",
      amount: subscription.amount,
      currency: subscription.currency,
      stripe_description: "Przetargowy Przegląd Premium - failed renewal"
    }

    %PaymentTransaction{}
    |> PaymentTransaction.create_changeset(attrs)
    |> Ecto.Changeset.put_change(:status, "failed")
    |> Ecto.Changeset.put_change(:error_code, event.error_code)
    |> Ecto.Changeset.put_change(:error_message, event.error_message)
    |> Ecto.Changeset.put_change(:stripe_response, event.raw_event || %{})
    |> Repo.insert()
  end

  # ============================================================================
  # Transaction Queries
  # ============================================================================

  @doc """
  Gets a transaction by Stripe payment intent ID.
  """
  def get_transaction_by_stripe_payment_intent_id(stripe_payment_intent_id) do
    Repo.get_by(PaymentTransaction, stripe_payment_intent_id: stripe_payment_intent_id)
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

  @doc """
  Returns the subscription amount.
  """
  def subscription_amount, do: @subscription_amount

  @doc """
  Returns the subscription currency.
  """
  def subscription_currency, do: @subscription_currency
end
