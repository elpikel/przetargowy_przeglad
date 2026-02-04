defmodule PrzetargowyPrzeglad.Payments.PaymentTransactionTest do
  use PrzetargowyPrzeglad.DataCase, async: true

  alias PrzetargowyPrzeglad.Accounts
  alias PrzetargowyPrzeglad.Payments.PaymentTransaction
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

  defp create_subscription(user) do
    {:ok, subscription} =
      %Subscription{}
      |> Subscription.create_changeset(%{user_id: user.id})
      |> Repo.insert()

    subscription
  end

  describe "create_changeset/2" do
    test "creates valid transaction with required fields" do
      user = create_user()
      subscription = create_subscription(user)

      changeset =
        PaymentTransaction.create_changeset(%PaymentTransaction{}, %{
          subscription_id: subscription.id,
          user_id: user.id,
          type: "initial",
          amount: Decimal.new("19.00")
        })

      assert changeset.valid?
      # Use get_field since status has a default value in the schema
      assert Ecto.Changeset.get_field(changeset, :status) == "pending"
    end

    test "requires user_id, type, and amount" do
      changeset = PaymentTransaction.create_changeset(%PaymentTransaction{}, %{})

      refute changeset.valid?
      errors = errors_on(changeset)
      assert "can't be blank" in errors.user_id
      assert "can't be blank" in errors.type
      assert "can't be blank" in errors.amount
    end

    test "validates type inclusion" do
      user = create_user()

      changeset =
        PaymentTransaction.create_changeset(%PaymentTransaction{}, %{
          user_id: user.id,
          type: "invalid_type",
          amount: Decimal.new("19.00")
        })

      refute changeset.valid?
      assert %{type: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts valid types" do
      user = create_user()

      for type <- ["initial", "renewal", "refund"] do
        changeset =
          PaymentTransaction.create_changeset(%PaymentTransaction{}, %{
            user_id: user.id,
            type: type,
            amount: Decimal.new("19.00")
          })

        assert changeset.valid?, "Type '#{type}' should be valid"
      end
    end
  end

  describe "complete_changeset/2" do
    test "marks transaction as completed with timestamp" do
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

      stripe_response = %{"tr_id" => "123", "tr_status" => "TRUE"}
      changeset = PaymentTransaction.complete_changeset(transaction, stripe_response)

      assert changeset.valid?
      assert get_change(changeset, :status) == "completed"
      assert get_change(changeset, :stripe_response) == stripe_response
      assert get_change(changeset, :paid_at)
    end
  end

  describe "fail_changeset/3" do
    test "marks transaction as failed with error details" do
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

      changeset = PaymentTransaction.fail_changeset(transaction, "card_declined", "Card was declined")

      assert changeset.valid?
      assert get_change(changeset, :status) == "failed"
      assert get_change(changeset, :error_code) == "card_declined"
      assert get_change(changeset, :error_message) == "Card was declined"
    end
  end

  describe "refund_changeset/2" do
    test "marks transaction as refunded" do
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

      stripe_response = %{"refund_id" => "ref_123"}
      changeset = PaymentTransaction.refund_changeset(transaction, stripe_response)

      assert changeset.valid?
      assert get_change(changeset, :status) == "refunded"
      assert get_change(changeset, :stripe_response) == stripe_response
    end
  end
end
