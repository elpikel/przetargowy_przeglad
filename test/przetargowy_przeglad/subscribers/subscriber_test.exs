defmodule PrzetargowyPrzeglad.Subscribers.SubscriberTest do
  use PrzetargowyPrzeglad.DataCase

  alias PrzetargowyPrzeglad.Subscribers.Subscriber

  describe "signup_changeset/2" do
    test "valid email creates valid changeset" do
      changeset = Subscriber.signup_changeset(%Subscriber{}, %{email: "test@example.com"})
      assert changeset.valid?
      assert get_change(changeset, :confirmation_token) != nil
    end

    test "invalid email returns error" do
      changeset = Subscriber.signup_changeset(%Subscriber{}, %{email: "invalid"})
      refute changeset.valid?
      assert "Niepoprawny format." in errors_on(changeset).email
    end

    test "empty email returns error" do
      changeset = Subscriber.signup_changeset(%Subscriber{}, %{})
      refute changeset.valid?
      assert "To pole jest wymagane." in errors_on(changeset).email
    end

    test "valid industry is accepted" do
      changeset =
        Subscriber.signup_changeset(%Subscriber{}, %{
          email: "test@example.com",
          industry: "it"
        })

      assert changeset.valid?
    end

    test "invalid industry returns error" do
      changeset =
        Subscriber.signup_changeset(%Subscriber{}, %{
          email: "test@example.com",
          industry: "nieznana"
        })

      refute changeset.valid?
    end
  end

  describe "confirm_changeset/1" do
    test "sets status to confirmed" do
      subscriber = %Subscriber{status: "pending", confirmation_token: "abc123"}
      changeset = Subscriber.confirm_changeset(subscriber)

      assert get_change(changeset, :status) == "confirmed"
      assert get_change(changeset, :confirmed_at) != nil
      assert get_change(changeset, :confirmation_token) == nil
    end
  end

  describe "unsubscribe_changeset/1" do
    test "sets status to unsubscribed" do
      subscriber = %Subscriber{status: "confirmed"}
      changeset = Subscriber.unsubscribe_changeset(subscriber)

      assert get_change(changeset, :status) == "unsubscribed"
      assert get_change(changeset, :unsubscribed_at) != nil
    end
  end
end
