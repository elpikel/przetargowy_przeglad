defmodule PrzetargowyPrzeglad.Stripe.ClientStub do
  @moduledoc """
  Stub implementation of Stripe client for development and testing.

  In development mode, this stub automatically redirects to the success URL
  to simulate a successful Stripe checkout without actually calling the Stripe API.
  This allows you to test the subscription flow without needing real Stripe credentials.
  """

  @behaviour PrzetargowyPrzeglad.Stripe.ClientBehaviour

  def create_checkout_session(params) do
    session_id = "cs_test_#{System.unique_integer([:positive])}"

    # In development, redirect to a dev route that simulates Stripe checkout
    # Extract metadata to pass to the dev checkout page
    metadata = params[:metadata] || %{}
    user_id = metadata["user_id"] || metadata[:user_id]
    subscription_id = metadata["subscription_id"] || metadata[:subscription_id]
    success_url = params[:success_url] || params.success_url

    # Build dev checkout URL with query params
    checkout_url =
      if user_id && subscription_id && success_url do
        "http://localhost:4000/dev/stripe/checkout?session_id=#{session_id}&user_id=#{user_id}&subscription_id=#{subscription_id}&success_url=#{URI.encode_www_form(success_url)}"
      else
        # Fallback for tests that don't provide full params
        success_url || "http://localhost:4000/dashboard/subscription/success"
      end

    {:ok,
     %{
       session_id: session_id,
       checkout_url: checkout_url
     }}
  end

  def get_checkout_session(session_id) do
    {:ok,
     %{
       id: session_id,
       subscription: "sub_test_123",
       customer: "cus_test_123",
       url: "https://checkout.stripe.com/test"
     }}
  end

  def get_subscription(subscription_id) do
    {:ok,
     %{
       id: subscription_id,
       status: "active",
       cancel_at_period_end: false,
       current_period_end: System.system_time(:second) + 30 * 24 * 60 * 60
     }}
  end

  def cancel_subscription(subscription_id, cancel_immediately) do
    {:ok,
     %{
       id: subscription_id,
       cancel_at_period_end: !cancel_immediately,
       status: if(cancel_immediately, do: "cancelled", else: "active")
     }}
  end

  def reactivate_subscription(subscription_id) do
    {:ok,
     %{
       id: subscription_id,
       cancel_at_period_end: false,
       status: "active"
     }}
  end

  def create_refund(payment_intent_id, _amount) do
    {:ok,
     %{
       id: "re_test_#{System.unique_integer([:positive])}",
       payment_intent: payment_intent_id,
       status: "succeeded"
     }}
  end

  def get_invoice(invoice_id) do
    {:ok,
     %{
       id: invoice_id,
       status: "paid",
       amount_paid: 1900
     }}
  end
end
