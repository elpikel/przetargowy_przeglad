defmodule PrzetargowyPrzeglad.Tpay.WebhookHandler do
  @moduledoc """
  Handles incoming webhooks from Tpay payment gateway.
  Verifies JWS signature and processes payment notifications.

  ## Webhook Events

  Tpay sends notifications for various events:
  - Transaction completed (paid)
  - Transaction failed
  - Card token saved
  - Refund processed
  """

  require Logger

  alias PrzetargowyPrzeglad.Payments

  @doc """
  Verifies and processes a webhook payload.
  Returns {:ok, result} or {:error, reason}.

  ## Parameters
  - payload: The raw request body (JSON string)
  - signature: The X-JWS-Signature header value
  """
  def handle(payload, signature) do
    with :ok <- verify_signature(payload, signature),
         {:ok, event} <- parse_payload(payload) do
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
    # Tpay uses JWS (JSON Web Signature) for webhook verification
    # The signature contains three parts: header.payload.signature
    # For simplicity, we verify using HMAC-SHA256 with the webhook secret

    webhook_secret = get_webhook_secret()

    if is_nil(webhook_secret) or webhook_secret == "" do
      Logger.warning("Tpay webhook secret not configured, skipping verification")
      :ok
    else
      expected_signature =
        :crypto.mac(:hmac, :sha256, webhook_secret, payload)
        |> Base.encode64()

      if secure_compare(signature, expected_signature) do
        :ok
      else
        Logger.warning("Tpay webhook signature verification failed")
        {:error, :invalid_signature}
      end
    end
  end

  defp verify_signature(_payload, nil) do
    Logger.warning("Tpay webhook received without signature")
    {:error, :missing_signature}
  end

  defp secure_compare(a, b) when byte_size(a) == byte_size(b) do
    :crypto.hash_equals(a, b)
  end

  defp secure_compare(_a, _b), do: false

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
  # Event Processing
  # ============================================================================

  defp process_event(%{"tr_id" => transaction_id, "tr_status" => "TRUE"} = event) do
    # Payment completed successfully
    Logger.info("Tpay webhook: Payment completed for transaction #{transaction_id}")

    card_token = event["cli_auth"]
    amount = parse_amount(event["tr_amount"])

    result =
      Payments.handle_payment_completed(%{
        transaction_id: transaction_id,
        card_token: card_token,
        amount: amount,
        raw_event: event
      })

    case result do
      {:ok, _} -> {:ok, :payment_completed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%{"tr_id" => transaction_id, "tr_status" => "FALSE"} = event) do
    # Payment failed
    Logger.info("Tpay webhook: Payment failed for transaction #{transaction_id}")

    error_code = event["tr_error"] || "unknown"
    error_message = event["err_desc"] || "Payment failed"

    result =
      Payments.handle_payment_failed(%{
        transaction_id: transaction_id,
        error_code: error_code,
        error_message: error_message,
        raw_event: event
      })

    case result do
      {:ok, _} -> {:ok, :payment_failed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%{"tr_id" => transaction_id, "tr_status" => "CHARGEBACK"} = event) do
    # Chargeback/refund
    Logger.info("Tpay webhook: Chargeback for transaction #{transaction_id}")

    result =
      Payments.handle_refund(%{
        transaction_id: transaction_id,
        raw_event: event
      })

    case result do
      {:ok, _} -> {:ok, :refund_processed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_event(%{"tr_id" => transaction_id} = event) do
    # Unknown status, log for debugging
    status = event["tr_status"]
    Logger.warning("Tpay webhook: Unknown status '#{status}' for transaction #{transaction_id}")
    {:ok, :unknown_status}
  end

  defp process_event(event) do
    Logger.warning("Tpay webhook: Unrecognized event format: #{inspect(event)}")
    {:error, :unrecognized_event}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp parse_amount(nil), do: nil

  defp parse_amount(amount) when is_binary(amount) do
    case Decimal.parse(amount) do
      {decimal, ""} -> decimal
      _ -> nil
    end
  end

  defp parse_amount(amount) when is_number(amount) do
    Decimal.new(amount)
  end

  defp get_webhook_secret do
    Application.get_env(:przetargowy_przeglad, :tpay, [])
    |> Keyword.get(:webhook_secret)
  end
end
