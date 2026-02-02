defmodule PrzetargowyPrzeglad.PaymentsTest do
  use PrzetargowyPrzeglad.DataCase, async: true

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzeglad.Payments
  alias PrzetargowyPrzeglad.Payments.PaymentTransaction
  alias PrzetargowyPrzeglad.Payments.Subscription

  # Helper to create a verified user
  defp create_user(attrs \\ %{}) do
    default_attrs = %{
      email: "test#{System.unique_integer()}@example.com",
      password: "password123",
      tender_category: "Dostawy",
      region: "mazowieckie"
    }

    {:ok, %{user: user}} = Accounts.register_user(Map.merge(default_attrs, attrs))
    {:ok, user} = Accounts.verify_user_email(user.email_verification_token)
    user
  end

  defp create_subscription(user, attrs \\ %{}) do
    default_attrs = %{
      user_id: user.id,
      amount: Decimal.new("19.00"),
      currency: "PLN"
    }

    {:ok, subscription} =
      %Subscription{}
      |> Subscription.create_changeset(Map.merge(default_attrs, attrs))
      |> Repo.insert()

    subscription
  end

  defp activate_subscription(subscription) do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    period_end = DateTime.add(now, 30, :day)

    {:ok, subscription} =
      subscription
      |> Ecto.Changeset.change(%{
        status: "active",
        current_period_start: now,
        current_period_end: period_end,
        tpay_subscription_id: "test_token_#{System.unique_integer()}"
      })
      |> Repo.update()

    subscription
  end

  describe "get_user_subscription/1" do
    test "returns subscription for user" do
      user = create_user()
      subscription = create_subscription(user)

      found = Payments.get_user_subscription(user.id)
      assert found.id == subscription.id
    end

    test "returns nil when user has no subscription" do
      user = create_user()
      assert Payments.get_user_subscription(user.id) == nil
    end
  end

  describe "subscription_active?/1" do
    test "returns true for active subscription" do
      user = create_user()
      subscription = create_subscription(user)
      _active = activate_subscription(subscription)

      assert Payments.subscription_active?(user.id) == true
    end

    test "returns false for pending subscription" do
      user = create_user()
      _subscription = create_subscription(user)

      assert Payments.subscription_active?(user.id) == false
    end

    test "returns false for expired subscription" do
      user = create_user()
      subscription = create_subscription(user)
      subscription = activate_subscription(subscription)

      # Set period end to the past
      past = DateTime.truncate(DateTime.add(DateTime.utc_now(), -1, :day), :second)

      {:ok, _} =
        subscription
        |> Ecto.Changeset.change(%{current_period_end: past})
        |> Repo.update()

      assert Payments.subscription_active?(user.id) == false
    end

    test "returns false when user has no subscription" do
      user = create_user()
      assert Payments.subscription_active?(user.id) == false
    end
  end

  describe "list_subscriptions_due_for_renewal/1" do
    test "returns subscriptions expiring within hours" do
      user = create_user()
      subscription = create_subscription(user)
      subscription = activate_subscription(subscription)

      # Set period end to 12 hours from now
      soon = DateTime.truncate(DateTime.add(DateTime.utc_now(), 12, :hour), :second)

      {:ok, subscription} =
        subscription
        |> Ecto.Changeset.change(%{current_period_end: soon})
        |> Repo.update()

      results = Payments.list_subscriptions_due_for_renewal(24)
      assert length(results) == 1
      assert hd(results).id == subscription.id
    end

    test "excludes subscriptions marked for cancellation" do
      user = create_user()
      subscription = create_subscription(user)
      subscription = activate_subscription(subscription)

      soon = DateTime.truncate(DateTime.add(DateTime.utc_now(), 12, :hour), :second)

      {:ok, _subscription} =
        subscription
        |> Ecto.Changeset.change(%{
          current_period_end: soon,
          cancel_at_period_end: true
        })
        |> Repo.update()

      results = Payments.list_subscriptions_due_for_renewal(24)
      assert results == []
    end

    test "excludes subscriptions not expiring soon" do
      user = create_user()
      subscription = create_subscription(user)
      _subscription = activate_subscription(subscription)

      # Default is 30 days, so it shouldn't be in the list
      results = Payments.list_subscriptions_due_for_renewal(24)
      assert results == []
    end
  end

  describe "list_expired_subscriptions/0" do
    test "returns subscriptions past their period end" do
      user = create_user()
      subscription = create_subscription(user)
      subscription = activate_subscription(subscription)

      past = DateTime.truncate(DateTime.add(DateTime.utc_now(), -1, :day), :second)

      {:ok, subscription} =
        subscription
        |> Ecto.Changeset.change(%{current_period_end: past})
        |> Repo.update()

      results = Payments.list_expired_subscriptions()
      assert length(results) == 1
      assert hd(results).id == subscription.id
    end

    test "excludes active non-expired subscriptions" do
      user = create_user()
      subscription = create_subscription(user)
      _subscription = activate_subscription(subscription)

      results = Payments.list_expired_subscriptions()
      assert results == []
    end
  end

  describe "cancel_user_subscription/2" do
    test "cancels subscription at period end" do
      user = create_user()
      subscription = create_subscription(user)
      _subscription = activate_subscription(subscription)

      assert {:ok, cancelled} = Payments.cancel_user_subscription(user.id, false)
      assert cancelled.cancel_at_period_end == true
      assert cancelled.cancelled_at
      assert cancelled.status == "active"
    end

    test "cancels subscription immediately when requested" do
      user = create_user()
      subscription = create_subscription(user)
      _subscription = activate_subscription(subscription)

      # First upgrade user to premium
      Accounts.upgrade_to_premium(user.id)

      assert {:ok, cancelled} = Payments.cancel_user_subscription(user.id, true)
      assert cancelled.status == "cancelled"
      assert cancelled.cancelled_at

      # User should be downgraded
      updated_user = Accounts.get_user(user.id)
      assert updated_user.subscription_plan == "free"
    end

    test "returns error when user has no subscription" do
      user = create_user()
      assert {:error, :no_subscription} = Payments.cancel_user_subscription(user.id, false)
    end
  end

  describe "expire_subscription/1" do
    test "expires subscription and downgrades user" do
      user = create_user()
      subscription = create_subscription(user)
      subscription = activate_subscription(subscription)

      # Upgrade user first
      Accounts.upgrade_to_premium(user.id)

      assert {:ok, expired} = Payments.expire_subscription(subscription)
      assert expired.status == "expired"

      # User should be downgraded
      updated_user = Accounts.get_user(user.id)
      assert updated_user.subscription_plan == "free"
    end
  end

  describe "handle_payment_completed/1" do
    test "activates subscription and upgrades user" do
      user = create_user()
      subscription = create_subscription(user)

      # Create a pending transaction
      {:ok, transaction} =
        %PaymentTransaction{}
        |> PaymentTransaction.create_changeset(%{
          subscription_id: subscription.id,
          user_id: user.id,
          type: "initial",
          amount: Decimal.new("19.00"),
          tpay_transaction_id: "test_tr_123"
        })
        |> Repo.insert()

      event = %{
        transaction_id: "test_tr_123",
        card_token: "test_card_token",
        raw_event: %{"tr_status" => "TRUE"}
      }

      assert {:ok, _} = Payments.handle_payment_completed(event)

      # Check subscription is activated
      updated_subscription = Payments.get_subscription(subscription.id)
      assert updated_subscription.status == "active"
      assert updated_subscription.tpay_subscription_id == "test_card_token"

      # Check user is upgraded
      updated_user = Accounts.get_user(user.id)
      assert updated_user.subscription_plan == "paid"

      # Check transaction is completed
      updated_transaction = Repo.get(PaymentTransaction, transaction.id)
      assert updated_transaction.status == "completed"
    end

    test "returns error when transaction not found" do
      event = %{
        transaction_id: "nonexistent",
        card_token: "test_card_token",
        raw_event: %{}
      }

      assert {:error, :transaction_not_found} = Payments.handle_payment_completed(event)
    end
  end

  describe "handle_payment_failed/1" do
    test "marks transaction as failed" do
      user = create_user()
      subscription = create_subscription(user)

      {:ok, transaction} =
        %PaymentTransaction{}
        |> PaymentTransaction.create_changeset(%{
          subscription_id: subscription.id,
          user_id: user.id,
          type: "initial",
          amount: Decimal.new("19.00"),
          tpay_transaction_id: "test_tr_456"
        })
        |> Repo.insert()

      event = %{
        transaction_id: "test_tr_456",
        error_code: "insufficient_funds",
        error_message: "Insufficient funds"
      }

      assert {:ok, _} = Payments.handle_payment_failed(event)

      updated_transaction = Repo.get(PaymentTransaction, transaction.id)
      assert updated_transaction.status == "failed"
      assert updated_transaction.error_code == "insufficient_funds"
      assert updated_transaction.error_message == "Insufficient funds"
    end

    test "increments retry count for renewal failures" do
      user = create_user()
      subscription = create_subscription(user)
      subscription = activate_subscription(subscription)

      {:ok, _transaction} =
        %PaymentTransaction{}
        |> PaymentTransaction.create_changeset(%{
          subscription_id: subscription.id,
          user_id: user.id,
          type: "renewal",
          amount: Decimal.new("19.00"),
          tpay_transaction_id: "test_tr_renewal"
        })
        |> Repo.insert()

      event = %{
        transaction_id: "test_tr_renewal",
        error_code: "card_declined",
        error_message: "Card declined"
      }

      assert {:ok, _} = Payments.handle_payment_failed(event)

      updated_subscription = Payments.get_subscription(subscription.id)
      assert updated_subscription.retry_count == 1
      assert updated_subscription.last_payment_error == "Card declined"
    end
  end

  describe "list_user_transactions/2" do
    test "returns transactions for user" do
      user = create_user()
      subscription = create_subscription(user)

      {:ok, transaction} =
        %PaymentTransaction{}
        |> PaymentTransaction.create_changeset(%{
          subscription_id: subscription.id,
          user_id: user.id,
          type: "initial",
          amount: Decimal.new("19.00")
        })
        |> Repo.insert()

      transactions = Payments.list_user_transactions(user.id)
      assert length(transactions) == 1
      assert hd(transactions).id == transaction.id
    end

    test "respects limit option" do
      user = create_user()
      subscription = create_subscription(user)

      for _i <- 1..5 do
        %PaymentTransaction{}
        |> PaymentTransaction.create_changeset(%{
          subscription_id: subscription.id,
          user_id: user.id,
          type: "renewal",
          amount: Decimal.new("19.00")
        })
        |> Repo.insert()
      end

      transactions = Payments.list_user_transactions(user.id, limit: 3)
      assert length(transactions) == 3
    end
  end
end
