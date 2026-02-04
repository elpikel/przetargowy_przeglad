defmodule PrzetargowyPrzeglad.Stripe.Client do
  @moduledoc """
  HTTP client for Stripe payment gateway API.
  Handles subscription creation, checkout sessions, and payment processing.

  ## Configuration

  Required environment variables:
  - STRIPE_API_KEY - Stripe secret API key
  - STRIPE_WEBHOOK_SECRET - Webhook signing secret

  ## Usage

      # Create a checkout session for subscription
      Stripe.Client.create_checkout_session(%{
        customer_email: "user@example.com",
        success_url: "https://example.com/success",
        cancel_url: "https://example.com/cancel"
      })
  """

  @behaviour PrzetargowyPrzeglad.Stripe.ClientBehaviour

  require Logger

  @doc """
  Creates a Stripe Checkout Session for subscription payment.
  Returns {:ok, %{session_id: id, checkout_url: url}} on success.

  Options:
  - customer_id: Use existing Stripe customer (preserves saved payment methods)
  - customer_email: Create new customer or find by email (if customer_id not provided)
  """
  def create_checkout_session(params) do
    price_id = get_price_id()

    checkout_params = %{
      mode: :subscription,
      line_items: [
        %{
          price: price_id,
          quantity: 1
        }
      ],
      success_url: params.success_url,
      cancel_url: params.cancel_url,
      metadata: params[:metadata] || %{}
    }

    # Use existing customer if available (better UX - preserves payment methods)
    checkout_params =
      if params[:customer_id] do
        Map.put(checkout_params, :customer, params.customer_id)
      else
        Map.put(checkout_params, :customer_email, params.customer_email)
      end

    case Stripe.Checkout.Session.create(checkout_params) do
      {:ok, session} ->
        Logger.info("Stripe checkout session created: id=#{session.id}")
        {:ok, %{session_id: session.id, checkout_url: session.url}}

      {:error, %Stripe.Error{} = error} ->
        Logger.error("Stripe checkout session error: #{inspect(error)}")
        {:error, error.message}
    end
  end

  @doc """
  Retrieves a Checkout Session by ID.
  """
  def get_checkout_session(session_id) do
    case Stripe.Checkout.Session.retrieve(session_id, %{expand: ["subscription", "customer"]}) do
      {:ok, session} ->
        {:ok, session}

      {:error, %Stripe.Error{} = error} ->
        Logger.error("Failed to retrieve checkout session: #{inspect(error)}")
        {:error, error.message}
    end
  end

  @doc """
  Retrieves a subscription by ID.
  """
  def get_subscription(subscription_id) do
    case Stripe.Subscription.retrieve(subscription_id) do
      {:ok, subscription} ->
        {:ok, subscription}

      {:error, %Stripe.Error{} = error} ->
        Logger.error("Failed to retrieve subscription: #{inspect(error)}")
        {:error, error.message}
    end
  end

  @doc """
  Cancels a subscription immediately or at period end.
  """
  def cancel_subscription(subscription_id, cancel_immediately \\ false) do
    params =
      if cancel_immediately do
        %{}
      else
        %{cancel_at_period_end: true}
      end

    case Stripe.Subscription.update(subscription_id, params) do
      {:ok, subscription} ->
        Logger.info("Stripe subscription cancelled: id=#{subscription_id}")
        {:ok, subscription}

      {:error, %Stripe.Error{} = error} ->
        Logger.error("Failed to cancel subscription: #{inspect(error)}")
        {:error, error.message}
    end
  end

  @doc """
  Reactivates a subscription that was set to cancel at period end.
  """
  def reactivate_subscription(subscription_id) do
    params = %{cancel_at_period_end: false}

    case Stripe.Subscription.update(subscription_id, params) do
      {:ok, subscription} ->
        Logger.info("Stripe subscription reactivated: id=#{subscription_id}")
        {:ok, subscription}

      {:error, %Stripe.Error{} = error} ->
        Logger.error("Failed to reactivate subscription: #{inspect(error)}")
        {:error, error.message}
    end
  end

  @doc """
  Creates a refund for a payment intent.
  """
  def create_refund(payment_intent_id, amount \\ nil) do
    params =
      if amount do
        %{payment_intent: payment_intent_id, amount: amount}
      else
        %{payment_intent: payment_intent_id}
      end

    case Stripe.Refund.create(params) do
      {:ok, refund} ->
        Logger.info("Stripe refund created: id=#{refund.id}")
        {:ok, refund}

      {:error, %Stripe.Error{} = error} ->
        Logger.error("Failed to create refund: #{inspect(error)}")
        {:error, error.message}
    end
  end

  @doc """
  Retrieves an invoice by ID.
  """
  def get_invoice(invoice_id) do
    case Stripe.Invoice.retrieve(invoice_id) do
      {:ok, invoice} ->
        {:ok, invoice}

      {:error, %Stripe.Error{} = error} ->
        Logger.error("Failed to retrieve invoice: #{inspect(error)}")
        {:error, error.message}
    end
  end

  # ============================================================================
  # Configuration
  # ============================================================================

  defp get_price_id do
    :przetargowy_przeglad
    |> Application.get_env(:stripe, [])
    |> Keyword.get(:price_id)
  end
end
