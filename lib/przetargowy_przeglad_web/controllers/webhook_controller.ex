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

    # Skip signature verification for sandbox, verify in production
    tpay_api_url = Application.get_env(:przetargowy_przeglad, :tpay)[:api_url]
    is_sandbox = tpay_api_url == "https://openapi.sandbox.tpay.com"

    result =
      if is_sandbox do
        WebhookHandler.handle_without_verification(params)
      else
        WebhookHandler.handle(Jason.encode!(params), signature)
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
