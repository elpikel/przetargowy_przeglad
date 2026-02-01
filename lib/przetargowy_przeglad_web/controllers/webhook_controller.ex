defmodule PrzetargowyPrzegladWeb.WebhookController do
  use PrzetargowyPrzegladWeb, :controller

  alias PrzetargowyPrzeglad.Tpay.WebhookHandler

  require Logger

  @doc """
  Handles Tpay payment webhooks.
  Endpoint: POST /webhooks/tpay

  Tpay sends notifications for:
  - Successful payments
  - Failed payments
  - Chargebacks/refunds
  """
  def tpay(conn, params) do
    # Get raw body for signature verification
    # Note: Raw body should be captured by a plug if signature verification is needed
    signature = get_req_header(conn, "x-jws-signature") |> List.first()

    Logger.info("Received Tpay webhook: #{inspect(params)}")

    # For now, handle without strict signature verification in development
    # In production, you should verify the signature
    result =
      if Mix.env() == :prod do
        WebhookHandler.handle(Jason.encode!(params), signature)
      else
        WebhookHandler.handle_without_verification(params)
      end

    case result do
      {:ok, event_type} ->
        Logger.info("Tpay webhook processed successfully: #{event_type}")
        # Tpay expects "TRUE" response for successful processing
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "TRUE")

      {:error, :invalid_signature} ->
        Logger.warning("Invalid Tpay webhook signature")

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(401, "Invalid signature")

      {:error, reason} ->
        Logger.error("Tpay webhook processing error: #{inspect(reason)}")
        # Return 200 to prevent Tpay from retrying (we've logged the error)
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "TRUE")
    end
  end
end
