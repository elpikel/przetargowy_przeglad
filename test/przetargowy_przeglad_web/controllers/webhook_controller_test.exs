defmodule PrzetargowyPrzegladWeb.WebhookControllerTest do
  use PrzetargowyPrzegladWeb.ConnCase, async: true

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzeglad.Payments
  alias PrzetargowyPrzeglad.Payments.PaymentTransaction
  alias PrzetargowyPrzeglad.Payments.Subscription
  alias PrzetargowyPrzeglad.Repo

  defp create_user do
    {:ok, %{user: user}} =
      Accounts.register_user(%{
        email: "test#{System.unique_integer()}@example.com",
        password: "password123",
        tender_category: "Dostawy",
        region: "mazowieckie"
      })

    user
  end

  defp create_subscription(user) do
    {:ok, subscription} =
      %Subscription{}
      |> Subscription.create_changeset(%{user_id: user.id})
      |> Repo.insert()

    subscription
  end

  defp create_transaction(subscription, user, tpay_id) do
    {:ok, transaction} =
      %PaymentTransaction{}
      |> PaymentTransaction.create_changeset(%{
        subscription_id: subscription.id,
        user_id: user.id,
        type: "initial",
        amount: Decimal.new("19.00"),
        tpay_transaction_id: tpay_id
      })
      |> Repo.insert()

    transaction
  end

  describe "POST /webhooks/tpay" do
    test "processes successful payment webhook", %{conn: conn} do
      user = create_user()
      subscription = create_subscription(user)
      _transaction = create_transaction(subscription, user, "webhook_test_123")

      payload = %{
        "tr_id" => "webhook_test_123",
        "tr_status" => "TRUE",
        "tr_amount" => "19.00",
        "cli_auth" => "card_token_webhook"
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/tpay", payload)

      assert response(conn, 200) == "TRUE"

      # Verify subscription was activated
      updated_subscription = Payments.get_subscription(subscription.id)
      assert updated_subscription.status == "active"
    end

    test "processes failed payment webhook", %{conn: conn} do
      user = create_user()
      subscription = create_subscription(user)
      _transaction = create_transaction(subscription, user, "webhook_fail_456")

      payload = %{
        "tr_id" => "webhook_fail_456",
        "tr_status" => "FALSE",
        "tr_error" => "card_declined",
        "err_desc" => "Card declined"
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/tpay", payload)

      assert response(conn, 200) == "TRUE"

      # Verify transaction was marked as failed
      transaction = Payments.get_transaction_by_tpay_id("webhook_fail_456")
      assert transaction.status == "failed"
    end

    test "handles unknown transaction gracefully", %{conn: conn} do
      payload = %{
        "tr_id" => "unknown_transaction",
        "tr_status" => "TRUE"
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/tpay", payload)

      # Should still return 200 to prevent retries
      assert response(conn, 200) == "TRUE"
    end

    test "handles malformed payload", %{conn: conn} do
      payload = %{"invalid" => "data"}

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhooks/tpay", payload)

      # Should return 200 even for errors
      assert response(conn, 200) == "TRUE"
    end
  end
end
