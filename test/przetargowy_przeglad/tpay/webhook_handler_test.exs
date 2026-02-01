defmodule PrzetargowyPrzeglad.Tpay.WebhookHandlerTest do
  use PrzetargowyPrzeglad.DataCase, async: true

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzeglad.Payments
  alias PrzetargowyPrzeglad.Payments.PaymentTransaction
  alias PrzetargowyPrzeglad.Payments.Subscription
  alias PrzetargowyPrzeglad.Tpay.WebhookHandler

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

  describe "handle_without_verification/1" do
    test "processes successful payment" do
      user = create_user()
      subscription = create_subscription(user)
      _transaction = create_transaction(subscription, user, "tr_success_123")

      payload = %{
        "tr_id" => "tr_success_123",
        "tr_status" => "TRUE",
        "tr_amount" => "19.00",
        "cli_auth" => "card_token_abc"
      }

      assert {:ok, :payment_completed} = WebhookHandler.handle_without_verification(payload)

      # Check subscription was activated
      updated_subscription = Payments.get_subscription(subscription.id)
      assert updated_subscription.status == "active"
      assert updated_subscription.tpay_subscription_id == "card_token_abc"

      # Check user was upgraded
      updated_user = Accounts.get_user(user.id)
      assert updated_user.subscription_plan == "paid"
    end

    test "processes failed payment" do
      user = create_user()
      subscription = create_subscription(user)
      _transaction = create_transaction(subscription, user, "tr_failed_456")

      payload = %{
        "tr_id" => "tr_failed_456",
        "tr_status" => "FALSE",
        "tr_error" => "insufficient_funds",
        "err_desc" => "Insufficient funds"
      }

      assert {:ok, :payment_failed} = WebhookHandler.handle_without_verification(payload)

      # Check transaction was marked as failed
      transaction = Payments.get_transaction_by_tpay_id("tr_failed_456")
      assert transaction.status == "failed"
      assert transaction.error_code == "insufficient_funds"
    end

    test "processes chargeback" do
      user = create_user()
      subscription = create_subscription(user)
      transaction = create_transaction(subscription, user, "tr_chargeback_789")

      # Complete the transaction first
      transaction
      |> PaymentTransaction.complete_changeset(%{})
      |> Repo.update()

      payload = %{
        "tr_id" => "tr_chargeback_789",
        "tr_status" => "CHARGEBACK"
      }

      assert {:ok, :refund_processed} = WebhookHandler.handle_without_verification(payload)
    end

    test "handles unknown status gracefully" do
      user = create_user()
      subscription = create_subscription(user)
      _transaction = create_transaction(subscription, user, "tr_unknown_status")

      payload = %{
        "tr_id" => "tr_unknown_status",
        "tr_status" => "PENDING"
      }

      assert {:ok, :unknown_status} = WebhookHandler.handle_without_verification(payload)
    end

    test "handles missing transaction_id" do
      payload = %{
        "tr_status" => "TRUE"
      }

      assert {:error, :unrecognized_event} = WebhookHandler.handle_without_verification(payload)
    end

    test "handles invalid JSON" do
      assert {:error, :invalid_json} = WebhookHandler.handle_without_verification("not json")
    end
  end

  describe "handle/2" do
    test "handles payload with nil signature in dev mode" do
      user = create_user()
      subscription = create_subscription(user)
      _transaction = create_transaction(subscription, user, "tr_nosig_123")

      payload =
        Jason.encode!(%{
          "tr_id" => "tr_nosig_123",
          "tr_status" => "TRUE",
          "cli_auth" => "token"
        })

      # In test mode, missing signature returns error
      assert {:error, :missing_signature} = WebhookHandler.handle(payload, nil)
    end
  end
end
