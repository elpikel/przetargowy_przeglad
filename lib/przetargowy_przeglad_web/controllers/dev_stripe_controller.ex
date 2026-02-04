defmodule PrzetargowyPrzegladWeb.DevStripeController do
  @moduledoc """
  Development-only controller that simulates Stripe checkout flow.
  This allows testing the subscription flow without real Stripe credentials.
  """
  use PrzetargowyPrzegladWeb, :controller

  alias PrzetargowyPrzeglad.Payments

  @doc """
  Simulates the Stripe checkout page in development.
  Shows a simple page with a button to simulate successful payment.
  """
  def checkout(conn, %{"session_id" => session_id, "success_url" => success_url, "user_id" => user_id, "subscription_id" => subscription_id}) do
    conn
    |> put_layout(html: :root)
    |> render(:checkout,
      session_id: session_id,
      success_url: success_url,
      user_id: user_id,
      subscription_id: subscription_id
    )
  end

  @doc """
  Simulates a successful Stripe payment.
  Triggers the webhook handler to activate the subscription.
  """
  def simulate_payment(conn, %{"session_id" => session_id, "user_id" => user_id, "subscription_id" => subscription_id, "success_url" => success_url}) do
    # Simulate the webhook event
    webhook_event = %{
      session_id: session_id,
      subscription_id: "sub_dev_#{System.unique_integer([:positive])}",
      customer_id: "cus_dev_#{System.unique_integer([:positive])}",
      amount: Decimal.new("19.00"),
      metadata: %{
        "user_id" => user_id,
        "subscription_id" => subscription_id
      },
      raw_event: %{"type" => "checkout.session.completed"}
    }

    case Payments.handle_payment_completed(webhook_event) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "✅ Dev Mode: Payment simulated successfully!")
        |> redirect(external: success_url)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to activate subscription: #{inspect(reason)}")
        |> redirect(external: success_url)
    end
  end
end
