defmodule PrzetargowyPrzegladWeb.WebhookController do
  use PrzetargowyPrzegladWeb, :controller

  alias PrzetargowyPrzeglad.Stripe.WebhookHandler

  require Logger

  @doc """
  Handles Stripe payment webhooks.
  Endpoint: POST /webhooks/stripe

  Stripe sends notifications for:
  - checkout.session.completed (successful initial payment)
  - invoice.payment_succeeded (successful recurring payment)
  - invoice.payment_failed (failed payment)
  - customer.subscription.updated (subscription changed)
  - customer.subscription.deleted (subscription cancelled/expired)
  - charge.refunded (refund processed)
  """
  def stripe(conn, params) do
    # Get raw body (cached before parsing) and signature for verification
    signature = conn |> get_req_header("stripe-signature") |> List.first()
    raw_body = conn.assigns[:raw_body] || ""

    Logger.info("Received Stripe webhook: type=#{params["type"]}")

    # Always verify signature in production and dev, skip only in test environment
    result =
      if Application.get_env(:przetargowy_przeglad, :env) == :test do
        WebhookHandler.handle_without_verification(params)
      else
        WebhookHandler.handle(raw_body, signature)
      end

    case result do
      {:ok, event_type} ->
        Logger.info("Stripe webhook processed successfully: #{event_type}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{received: true}))

      {:error, :invalid_signature} ->
        Logger.warning("Invalid Stripe webhook signature")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Invalid signature"}))

      {:error, reason} ->
        Logger.error("Stripe webhook processing error: #{inspect(reason)}")
        # Return 200 to prevent Stripe from retrying (we've logged the error)
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{received: true}))
    end
  end
end
