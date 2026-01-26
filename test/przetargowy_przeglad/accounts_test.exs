defmodule PrzetargowyPrzeglad.AccountsTest do
  use PrzetargowyPrzeglad.DataCase, async: true

  import Swoosh.TestAssertions

  alias PrzetargowyPrzeglad.Accounts

  describe "register_user/1" do
    @valid_attrs %{
      email: "test@example.com",
      password: "password123",
      industry: "it",
      region: "mazowieckie"
    }

    test "creates user and alert with valid data" do
      assert {:ok, %{user: user, alert: alert}} = Accounts.register_user(@valid_attrs)

      assert user.email == "test@example.com"
      assert user.email_verified == false
      assert user.email_verification_token
      assert user.subscription_plan == "free"
      # Password should be hashed
      refute user.password == "password123"

      assert alert.user_id == user.id
      assert alert.rules[:industry] == "it" || alert.rules["industry"] == "it"
      assert alert.rules[:region] == "mazowieckie" || alert.rules["region"] == "mazowieckie"
    end

    test "sends verification email" do
      assert {:ok, %{user: user}} = Accounts.register_user(@valid_attrs)

      assert_email_sent(fn email ->
        email.to == [{user.email, user.email}] and
          email.subject == "Potwierdź swój adres e-mail - Przetargowy Przegląd"
      end)
    end

    test "returns error with invalid email" do
      attrs = Map.put(@valid_attrs, :email, "invalid-email")
      assert {:error, :user, changeset, _} = Accounts.register_user(attrs)
      assert %{email: ["nieprawidłowy format adresu e-mail"]} = errors_on(changeset)
    end

    test "returns error with short password" do
      attrs = Map.put(@valid_attrs, :password, "short")
      assert {:error, :user, changeset, _} = Accounts.register_user(attrs)
      assert %{password: errors} = errors_on(changeset)
      assert "hasło musi mieć co najmniej 8 znaków" in errors
    end

    test "returns error with duplicate email" do
      assert {:ok, _} = Accounts.register_user(@valid_attrs)
      assert {:error, :user, changeset, _} = Accounts.register_user(@valid_attrs)
      errors = errors_on(changeset)
      # Check for either Polish or English error message
      assert "ten adres e-mail jest już zarejestrowany" in errors.email || "has already been taken" in errors.email
    end

    test "returns error with missing required fields" do
      assert {:error, :user, changeset, _} = Accounts.register_user(%{})
      errors = errors_on(changeset)
      # Check for either Polish or English error messages
      assert "to pole jest wymagane" in errors.email || "can't be blank" in errors.email
      assert "to pole jest wymagane" in errors.password || "can't be blank" in errors.password
    end
  end

  describe "verify_user_email/1" do
    setup do
      {:ok, %{user: user}} =
        Accounts.register_user(%{
          email: "test@example.com",
          password: "password123",
          industry: "it",
          region: "mazowieckie"
        })

      %{user: user}
    end

    test "verifies email with valid token", %{user: user} do
      assert {:ok, verified_user} = Accounts.verify_user_email(user.email_verification_token)
      assert verified_user.email_verified == true
      assert verified_user.email_verification_token == nil
    end

    test "returns error with invalid token" do
      assert {:error, :invalid_token} = Accounts.verify_user_email("invalid-token")
    end
  end

  describe "get_user_by_email/1" do
    test "returns user when email exists" do
      {:ok, %{user: user}} =
        Accounts.register_user(%{
          email: "test@example.com",
          password: "password123",
          industry: "it",
          region: "mazowieckie"
        })

      found_user = Accounts.get_user_by_email("test@example.com")
      assert found_user.id == user.id
      assert found_user.email == "test@example.com"
    end

    test "returns nil when email does not exist" do
      assert Accounts.get_user_by_email("nonexistent@example.com") == nil
    end
  end

  describe "authenticate_user/2" do
    setup do
      {:ok, %{user: user}} =
        Accounts.register_user(%{
          email: "test@example.com",
          password: "password123",
          industry: "it",
          region: "mazowieckie"
        })

      %{user: user}
    end

    test "authenticates with correct credentials", %{user: user} do
      assert {:ok, authenticated_user} = Accounts.authenticate_user("test@example.com", "password123")
      assert authenticated_user.id == user.id
    end

    test "returns error with incorrect password" do
      assert {:error, :invalid_credentials} = Accounts.authenticate_user("test@example.com", "wrongpassword")
    end

    test "returns error with non-existent email" do
      assert {:error, :invalid_credentials} = Accounts.authenticate_user("nonexistent@example.com", "password123")
    end
  end

  describe "list_user_alerts/1" do
    setup do
      {:ok, %{user: user, alert: alert}} =
        Accounts.register_user(%{
          email: "test@example.com",
          password: "password123",
          industry: "it",
          region: "mazowieckie"
        })

      %{user: user, alert: alert}
    end

    test "returns all alerts for a user", %{user: user, alert: alert} do
      alerts = Accounts.list_user_alerts(user)
      assert length(alerts) == 1
      assert hd(alerts).id == alert.id
    end

    test "returns empty list for user with no alerts" do
      {:ok, %{user: other_user}} =
        Accounts.register_user(%{
          email: "other@example.com",
          password: "password123",
          industry: "it",
          region: "malopolskie"
        })

      # Delete the auto-created alert
      other_user
      |> Accounts.list_user_alerts()
      |> Enum.each(&Accounts.delete_alert/1)

      alerts = Accounts.list_user_alerts(other_user)
      assert alerts == []
    end
  end
end
