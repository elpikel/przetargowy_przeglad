defmodule PrzetargowyPrzeglad.SubscribersTest do
  use PrzetargowyPrzeglad.DataCase

  alias PrzetargowyPrzeglad.Subscribers

  describe "subscribe/1" do
    test "creates subscriber with valid data" do
      assert {:ok, subscriber} = Subscribers.subscribe(%{email: "test@example.com"})
      assert subscriber.email == "test@example.com"
      assert subscriber.status == "pending"
      assert subscriber.confirmation_token != nil
    end

    test "returns error for duplicate email" do
      Subscribers.subscribe(%{email: "test@example.com"})
      assert {:error, changeset} = Subscribers.subscribe(%{email: "test@example.com"})
      assert "Ten email jest już zarejestrowany." in errors_on(changeset).email
    end
  end

  describe "confirm_subscription/1" do
    test "confirms pending subscriber" do
      {:ok, subscriber} = Subscribers.subscribe(%{email: "test@example.com"})

      assert {:ok, confirmed} = Subscribers.confirm_subscription(subscriber.confirmation_token)
      assert confirmed.status == "confirmed"
      assert confirmed.confirmed_at != nil
    end

    test "returns error for invalid token" do
      assert {:error, :invalid_token} = Subscribers.confirm_subscription("invalid")
    end

    test "returns error for already confirmed" do
      {:ok, subscriber} = Subscribers.subscribe(%{email: "test@example.com"})
      {:ok, _} = Subscribers.confirm_subscription(subscriber.confirmation_token)

      assert {:error, :already_confirmed} =
               Subscribers.confirm_subscription(subscriber.confirmation_token)
    end
  end

  describe "unsubscribe/1" do
    test "unsubscribes existing subscriber" do
      {:ok, subscriber} = Subscribers.subscribe(%{email: "test@example.com"})

      assert {:ok, unsubscribed} = Subscribers.unsubscribe(subscriber.email)
      assert unsubscribed.status == "unsubscribed"
    end

    test "returns error for non-existent email" do
      assert {:error, :not_found} = Subscribers.unsubscribe("nonexistent@example.com")
    end
  end
end
