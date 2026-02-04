defmodule PrzetargowyPrzeglad.Stripe.WebhookHandler do
  @moduledoc """
  Handles incoming webhooks from Stripe payment gateway.
  Verifies webhook signatures and processes payment notifications.

  ## Webhook Events

  Stripe sends notifications for various events:
  - checkout.session.completed - Initial subscription payment completed
  - invoice.payment_succeeded - Recurring payment succeeded
  - invoice.payment_failed - Payment failed
  - customer.subscription.updated - Subscription updated
  - customer.subscription.deleted - Subscription cancelled
  - charge.refunded - Refund processed
  """

  alias PrzetargowyPrzeglad.Payments

  require Logger

  @doc """
  Verifies and processes a webhook payload.
  Returns {:ok, result} or {:error, reason}.

  ## Parameters
  - payload: The raw request body (JSON string)
  - signature: The Stripe-Signature header value
  """
  def handle(payload, signature) do
    with {:ok, event} <- verify_signature(payload, signature) do
      process_event(event)
    end
  end

  @doc """
  Handles webhook without signature verification (for testing/development).
  """
  def handle_without_verification(payload) do
    with {:ok, event} <- parse_payload(payload) do
      process_event(event)
    end
  end

  # ============================================================================
  # Signature Verification
  # ============================================================================

  defp verify_signature(payload, signature) when is_binary(signature) do
    webhook_secret = get_webhook_secret()

    if is_nil(webhook_secret) or webhook_secret == "" do
      Logger.warning("Stripe webhook secret not configured, skipping verification")
      parse_payload(payload)
    else
      case Stripe.Webhook.construct_event(payload, signature, webhook_secret) do
        {:ok, event} ->
          {:ok, event}

        {:error, reason} ->
          Logger.warning("Stripe webhook signature verification failed: #{inspect(reason)}")
          {:error, :invalid_signature}
      end
    end
  end

  defp verify_signature(_payload, nil) do
    Logger.warning("Stripe webhook received without signature")
    {:error, :missing_signature}
  end

  # ============================================================================
  # Payload Parsing
  # ============================================================================

  defp parse_payload(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:error, :invalid_json}
    end
  end

  defp parse_payload(payload) when is_map(payload) do
    {:ok, payload}
  end

  # ============================================================================
  # Event Processing - Stripe.Event structs (from verified webhooks)
  # ============================================================================

  defp process_event(%Stripe.Event{type: "checkout.session.completed", data: %{object: session}} = event) do
    # Initial subscription payment completed
    Logger.info("Stripe webhook: Checkout session completed #{session.id}")

    subscription_id = session.subscription
    customer_id = session.customer
    amount_total = session.amount_total
    metadata = session.metadata || %{}

    result =
      Payments.handle_payment_completed(%{
        session_id: session.id,
        subscription_id: subscription_id,
        customer_id: customer_id,
        amount: if(amount_total, do: Decimal.div(Decimal.new(amount_total), 100)),
        metadata: metadata,
        raw_event: to_json_safe(event)
      })

    case result do
      {:ok, _} -> {:ok, :checkout_completed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%Stripe.Event{type: "checkout.session.async_payment_succeeded", data: %{object: session}} = event) do
    # Async payment succeeded (e.g., SEPA, bank transfer)
    Logger.info("Stripe webhook: Checkout session async payment succeeded #{session.id}")

    subscription_id = session.subscription
    customer_id = session.customer
    amount_total = session.amount_total
    metadata = session.metadata || %{}

    result =
      Payments.handle_payment_completed(%{
        session_id: session.id,
        subscription_id: subscription_id,
        customer_id: customer_id,
        amount: if(amount_total, do: Decimal.div(Decimal.new(amount_total), 100)),
        metadata: metadata,
        raw_event: to_json_safe(event)
      })

    case result do
      {:ok, _} -> {:ok, :async_payment_succeeded}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%Stripe.Event{type: "invoice.payment_succeeded", data: %{object: invoice}} = event) do
    # Subscription payment succeeded (including renewals)
    Logger.info("Stripe webhook: Invoice payment succeeded #{invoice.id}")

    subscription_id = invoice.subscription
    customer_id = invoice.customer
    amount_paid = invoice.amount_paid
    payment_intent_id = invoice.payment_intent

    result =
      Payments.handle_payment_completed(%{
        invoice_id: invoice.id,
        subscription_id: subscription_id,
        customer_id: customer_id,
        payment_intent_id: payment_intent_id,
        amount: if(amount_paid, do: Decimal.div(Decimal.new(amount_paid), 100)),
        raw_event: to_json_safe(event)
      })

    case result do
      {:ok, _} -> {:ok, :payment_succeeded}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%Stripe.Event{type: "invoice.payment_failed", data: %{object: invoice}} = event) do
    # Payment failed
    Logger.info("Stripe webhook: Invoice payment failed #{invoice.id}")

    subscription_id = invoice.subscription
    error_message = get_in(invoice, [:last_finalization_error, :message]) || "Payment failed"

    result =
      Payments.handle_payment_failed(%{
        invoice_id: invoice.id,
        subscription_id: subscription_id,
        error_code: "payment_failed",
        error_message: error_message,
        raw_event: to_json_safe(event)
      })

    case result do
      {:ok, _} -> {:ok, :payment_failed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%Stripe.Event{type: "customer.subscription.updated", data: %{object: subscription}} = event) do
    # Subscription updated (e.g., cancelled, reactivated)
    Logger.info("Stripe webhook: Subscription updated #{subscription.id}")

    result =
      Payments.handle_subscription_updated(%{
        subscription_id: subscription.id,
        status: subscription.status,
        cancel_at_period_end: subscription.cancel_at_period_end,
        current_period_end: subscription.current_period_end,
        raw_event: to_json_safe(event)
      })

    case result do
      {:ok, _} -> {:ok, :subscription_updated}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%Stripe.Event{type: "customer.subscription.deleted", data: %{object: subscription}} = event) do
    # Subscription deleted/expired
    Logger.info("Stripe webhook: Subscription deleted #{subscription.id}")

    result =
      Payments.handle_subscription_deleted(%{
        subscription_id: subscription.id,
        raw_event: to_json_safe(event)
      })

    case result do
      {:ok, _} -> {:ok, :subscription_deleted}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%Stripe.Event{type: "charge.refunded", data: %{object: charge}} = event) do
    # Refund processed
    Logger.info("Stripe webhook: Charge refunded #{charge.id}")

    payment_intent_id = charge.payment_intent
    refund_amount = charge.amount_refunded

    result =
      Payments.handle_refund(%{
        charge_id: charge.id,
        payment_intent_id: payment_intent_id,
        amount: if(refund_amount, do: Decimal.div(Decimal.new(refund_amount), 100)),
        raw_event: to_json_safe(event)
      })

    case result do
      {:ok, _} -> {:ok, :refund_processed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%Stripe.Event{type: event_type}) do
    # Unknown Stripe event type, log for debugging
    Logger.info("Stripe webhook: Unhandled event type '#{event_type}'")
    {:ok, :unhandled_event}
  end

  # ============================================================================
  # Event Processing - Plain maps (from tests without verification)
  # ============================================================================

  defp process_event(%{"type" => "checkout.session.completed"} = event) do
    session = event["data"]["object"]
    Logger.info("Stripe webhook: Checkout session completed #{session["id"]}")

    result =
      Payments.handle_payment_completed(%{
        session_id: session["id"],
        subscription_id: session["subscription"],
        customer_id: session["customer"],
        amount: if(session["amount_total"], do: Decimal.div(Decimal.new(session["amount_total"]), 100)),
        metadata: session["metadata"] || %{},
        raw_event: event
      })

    case result do
      {:ok, _} -> {:ok, :checkout_completed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%{"type" => "invoice.payment_succeeded"} = event) do
    invoice = event["data"]["object"]
    Logger.info("Stripe webhook: Invoice payment succeeded #{invoice["id"]}")

    result =
      Payments.handle_payment_completed(%{
        invoice_id: invoice["id"],
        subscription_id: invoice["subscription"],
        customer_id: invoice["customer"],
        payment_intent_id: invoice["payment_intent"],
        amount: if(invoice["amount_paid"], do: Decimal.div(Decimal.new(invoice["amount_paid"]), 100)),
        raw_event: event
      })

    case result do
      {:ok, _} -> {:ok, :payment_succeeded}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%{"type" => "invoice.payment_failed"} = event) do
    invoice = event["data"]["object"]
    Logger.info("Stripe webhook: Invoice payment failed #{invoice["id"]}")

    error_message = get_in(event, ["data", "object", "last_finalization_error", "message"]) || "Payment failed"

    result =
      Payments.handle_payment_failed(%{
        invoice_id: invoice["id"],
        subscription_id: invoice["subscription"],
        error_code: "payment_failed",
        error_message: error_message,
        raw_event: event
      })

    case result do
      {:ok, _} -> {:ok, :payment_failed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%{"type" => "customer.subscription.updated"} = event) do
    subscription = event["data"]["object"]
    Logger.info("Stripe webhook: Subscription updated #{subscription["id"]}")

    result =
      Payments.handle_subscription_updated(%{
        subscription_id: subscription["id"],
        status: subscription["status"],
        cancel_at_period_end: subscription["cancel_at_period_end"],
        current_period_end: subscription["current_period_end"],
        raw_event: event
      })

    case result do
      {:ok, _} -> {:ok, :subscription_updated}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%{"type" => "customer.subscription.deleted"} = event) do
    subscription = event["data"]["object"]
    Logger.info("Stripe webhook: Subscription deleted #{subscription["id"]}")

    result =
      Payments.handle_subscription_deleted(%{
        subscription_id: subscription["id"],
        raw_event: event
      })

    case result do
      {:ok, _} -> {:ok, :subscription_deleted}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%{"type" => "charge.refunded"} = event) do
    charge = event["data"]["object"]
    Logger.info("Stripe webhook: Charge refunded #{charge["id"]}")

    result =
      Payments.handle_refund(%{
        charge_id: charge["id"],
        payment_intent_id: charge["payment_intent"],
        amount: if(charge["amount_refunded"], do: Decimal.div(Decimal.new(charge["amount_refunded"]), 100)),
        raw_event: event
      })

    case result do
      {:ok, _} -> {:ok, :refund_processed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%{"type" => event_type}) do
    Logger.info("Stripe webhook: Unhandled event type '#{event_type}'")
    {:ok, :unhandled_event}
  end

  defp process_event(event) do
    Logger.warning("Stripe webhook: Unrecognized event format: #{inspect(event)}")
    {:error, :unrecognized_event}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp get_webhook_secret do
    :przetargowy_przeglad
    |> Application.get_env(:stripe, [])
    |> Keyword.get(:webhook_secret)
  end

  # Converts Stripe structs to plain maps for JSON storage in the database
  defp to_json_safe(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> to_json_safe()
  end

  defp to_json_safe(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {k, to_json_safe(v)} end)
  end

  defp to_json_safe(list) when is_list(list) do
    Enum.map(list, &to_json_safe/1)
  end

  defp to_json_safe(value), do: value
end
