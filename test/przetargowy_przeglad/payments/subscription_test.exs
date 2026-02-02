defmodule PrzetargowyPrzeglad.Payments.SubscriptionTest do
  use PrzetargowyPrzeglad.DataCase, async: true

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzeglad.Payments.Subscription

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

  describe "create_changeset/2" do
    test "creates valid subscription with required fields" do
      user = create_user()

      changeset =
        Subscription.create_changeset(%Subscription{}, %{
          user_id: user.id,
          amount: Decimal.new("19.00"),
          currency: "PLN"
        })

      assert changeset.valid?
      # Use get_field since status has a default value in the schema
      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
    end

    test "requires user_id" do
      changeset =
        Subscription.create_changeset(%Subscription{}, %{
          amount: Decimal.new("19.00")
        })

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "activate_changeset/2" do
    test "sets subscription to active with period dates" do
      user = create_user()

      {:ok, subscription} =
        %Subscription{}
        |> Subscription.create_changeset(%{user_id: user.id})
        |> Repo.insert()

      changeset =
        Subscription.activate_changeset(subscription, %{
          tpay_subscription_id: "card_token_123"
        })

      assert changeset.valid?
      assert get_change(changeset, :status) == "active"
      assert get_change(changeset, :tpay_subscription_id) == "card_token_123"
      assert get_change(changeset, :current_period_start)
      assert get_change(changeset, :current_period_end)
      # Use get_field since retry_count has a default of 0 and may not show as a change
      assert Ecto.Changeset.get_field(changeset, :retry_count) == 0
    end
  end

  describe "renew_changeset/1" do
    test "extends subscription period" do
      user = create_user()
      now = DateTime.truncate(DateTime.utc_now(), :second)

      {:ok, subscription} =
        %Subscription{}
        |> Subscription.create_changeset(%{user_id: user.id})
        |> Repo.insert()

      {:ok, subscription} =
        subscription
        |> Ecto.Changeset.change(%{
          status: "active",
          current_period_start: DateTime.add(now, -30, :day),
          current_period_end: now
        })
        |> Repo.update()

      changeset = Subscription.renew_changeset(subscription)

      assert changeset.valid?
      new_end = get_change(changeset, :current_period_end)
      # Should be ~30 days from now
      assert DateTime.diff(new_end, now, :day) >= 29
      # Use get_field since retry_count has a default of 0 and may not show as a change
      assert Ecto.Changeset.get_field(changeset, :retry_count) == 0
    end
  end

  describe "cancel_changeset/2" do
    test "marks for cancellation at period end by default" do
      user = create_user()

      {:ok, subscription} =
        %Subscription{}
        |> Subscription.create_changeset(%{user_id: user.id})
        |> Repo.insert()

      changeset = Subscription.cancel_changeset(subscription, false)

      assert changeset.valid?
      assert get_change(changeset, :cancel_at_period_end) == true
      assert get_change(changeset, :cancelled_at)
      refute get_change(changeset, :status) == "cancelled"
    end

    test "cancels immediately when flag is true" do
      user = create_user()

      {:ok, subscription} =
        %Subscription{}
        |> Subscription.create_changeset(%{user_id: user.id})
        |> Repo.insert()

      changeset = Subscription.cancel_changeset(subscription, true)

      assert changeset.valid?
      assert get_change(changeset, :status) == "cancelled"
      assert get_change(changeset, :cancelled_at)
    end
  end

  describe "expire_changeset/1" do
    test "sets status to expired" do
      user = create_user()

      {:ok, subscription} =
        %Subscription{}
        |> Subscription.create_changeset(%{user_id: user.id})
        |> Repo.insert()

      changeset = Subscription.expire_changeset(subscription)

      assert changeset.valid?
      assert get_change(changeset, :status) == "expired"
    end
  end

  describe "payment_failed_changeset/2" do
    test "increments retry count" do
      user = create_user()

      {:ok, subscription} =
        %Subscription{}
        |> Subscription.create_changeset(%{user_id: user.id})
        |> Repo.insert()

      changeset = Subscription.payment_failed_changeset(subscription, "Card declined")

      assert changeset.valid?
      assert get_change(changeset, :retry_count) == 1
      assert get_change(changeset, :last_payment_error) == "Card declined"
    end

    test "sets status to failed after max retries" do
      user = create_user()

      {:ok, subscription} =
        %Subscription{}
        |> Subscription.create_changeset(%{user_id: user.id})
        |> Repo.insert()

      # Set retry count to max - 1
      {:ok, subscription} =
        subscription
        |> Ecto.Changeset.change(%{retry_count: 2})
        |> Repo.update()

      changeset = Subscription.payment_failed_changeset(subscription, "Card declined")

      assert changeset.valid?
      assert get_change(changeset, :retry_count) == 3
      assert get_change(changeset, :status) == "failed"
    end
  end

  describe "active?/1" do
    test "returns true for active subscription with future end date" do
      subscription = %Subscription{
        status: "active",
        current_period_end: DateTime.add(DateTime.utc_now(), 1, :day)
      }

      assert Subscription.active?(subscription) == true
    end

    test "returns false for active subscription with past end date" do
      subscription = %Subscription{
        status: "active",
        current_period_end: DateTime.add(DateTime.utc_now(), -1, :day)
      }

      assert Subscription.active?(subscription) == false
    end

    test "returns false for pending subscription" do
      subscription = %Subscription{
        status: "pending",
        current_period_end: DateTime.add(DateTime.utc_now(), 1, :day)
      }

      assert Subscription.active?(subscription) == false
    end

    test "returns false for cancelled subscription" do
      subscription = %Subscription{
        status: "cancelled",
        current_period_end: DateTime.add(DateTime.utc_now(), 1, :day)
      }

      assert Subscription.active?(subscription) == false
    end
  end

  describe "due_for_renewal?/1" do
    test "returns true for active subscription expiring within 24 hours" do
      subscription = %Subscription{
        status: "active",
        current_period_end: DateTime.add(DateTime.utc_now(), 12, :hour),
        cancel_at_period_end: false
      }

      assert Subscription.due_for_renewal?(subscription) == true
    end

    test "returns false for subscription not expiring soon" do
      subscription = %Subscription{
        status: "active",
        current_period_end: DateTime.add(DateTime.utc_now(), 30, :day),
        cancel_at_period_end: false
      }

      assert Subscription.due_for_renewal?(subscription) == false
    end

    test "returns false for subscription marked for cancellation" do
      subscription = %Subscription{
        status: "active",
        current_period_end: DateTime.add(DateTime.utc_now(), 12, :hour),
        cancel_at_period_end: true
      }

      assert Subscription.due_for_renewal?(subscription) == false
    end
  end

  describe "can_retry?/1" do
    test "returns true when retry count is below max" do
      subscription = %Subscription{retry_count: 1}
      assert Subscription.can_retry?(subscription) == true
    end

    test "returns false when retry count is at max" do
      subscription = %Subscription{retry_count: 3}
      assert Subscription.can_retry?(subscription) == false
    end
  end
end
