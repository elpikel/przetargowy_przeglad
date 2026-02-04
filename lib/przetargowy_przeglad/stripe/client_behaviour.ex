defmodule PrzetargowyPrzeglad.Stripe.ClientBehaviour do
  @moduledoc """
  Behaviour for Stripe client operations.
  Allows mocking in tests while using the real implementation in production.
  """

  @type checkout_params :: %{
          customer_email: String.t(),
          success_url: String.t(),
          cancel_url: String.t(),
          metadata: map()
        }

  @type checkout_result :: %{session_id: String.t(), checkout_url: String.t()}

  @callback create_checkout_session(checkout_params()) ::
              {:ok, checkout_result()} | {:error, term()}

  @callback get_checkout_session(String.t()) :: {:ok, map()} | {:error, term()}

  @callback get_subscription(String.t()) :: {:ok, map()} | {:error, term()}

  @callback cancel_subscription(String.t(), boolean()) :: {:ok, map()} | {:error, term()}

  @callback reactivate_subscription(String.t()) :: {:ok, map()} | {:error, term()}

  @callback create_refund(String.t(), integer() | nil) :: {:ok, map()} | {:error, term()}

  @callback get_invoice(String.t()) :: {:ok, map()} | {:error, term()}
end
