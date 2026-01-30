defmodule PrzetargowyPrzegladWeb.UserControllerTest do
  use PrzetargowyPrzegladWeb.ConnCase, async: true

  import Swoosh.TestAssertions

  alias PrzetargowyPrzeglad.Accounts

  describe "GET /register" do
    test "renders registration form", %{conn: conn} do
      conn = get(conn, ~p"/register")
      assert html_response(conn, 200) =~ "Utwórz konto"
      assert html_response(conn, 200) =~ "Adres e-mail"
      assert html_response(conn, 200) =~ "Hasło"
      assert html_response(conn, 200) =~ "Rodzaj zamówienia"
      assert html_response(conn, 200) =~ "Region"
    end
  end

  describe "GET /register/premium" do
    test "renders premium registration form", %{conn: conn} do
      conn = get(conn, ~p"/register/premium")
      assert html_response(conn, 200) =~ "Utwórz konto Premium"
      assert html_response(conn, 200) =~ "Plan Premium"
      assert html_response(conn, 200) =~ "Adres e-mail"
      assert html_response(conn, 200) =~ "Hasło"
      assert html_response(conn, 200) =~ "Rodzaj zamówienia"
      assert html_response(conn, 200) =~ "Region"
      assert html_response(conn, 200) =~ "Słowo kluczowe"
    end
  end

  describe "POST /register" do
    @valid_attrs %{
      "email" => "test@example.com",
      "password" => "password123",
      "password_confirmation" => "password123",
      "tender_category" => "Dostawy",
      "region" => "mazowieckie",
      "terms" => "true"
    }

    test "creates user and redirects to success page with valid data", %{conn: conn} do
      conn = post(conn, ~p"/register", registration_form: @valid_attrs)
      assert redirected_to(conn) == ~p"/registration-success"

      # Verify user was created
      user = Accounts.get_non_verified_user_by_email("test@example.com")
      assert user
      assert user.email_verified == false
      assert user.email_verification_token
    end

    test "sends verification email", %{conn: conn} do
      post(conn, ~p"/register", registration_form: @valid_attrs)

      assert_email_sent(fn email ->
        email.to == [{"test@example.com", "test@example.com"}] and
          email.subject == "Potwierdź swój adres e-mail - Przetargowy Przegląd"
      end)
    end

    test "renders errors with invalid email", %{conn: conn} do
      invalid_attrs = Map.put(@valid_attrs, "email", "invalid-email")
      conn = post(conn, ~p"/register", registration_form: invalid_attrs)

      assert html_response(conn, 200) =~ "nieprawidłowy format adresu e-mail"
    end

    test "renders errors with short password", %{conn: conn} do
      invalid_attrs = Map.put(@valid_attrs, "password", "short")
      conn = post(conn, ~p"/register", registration_form: invalid_attrs)

      assert html_response(conn, 200) =~ "hasło musi mieć co najmniej 8 znaków"
    end

    test "renders errors with password mismatch", %{conn: conn} do
      invalid_attrs = Map.put(@valid_attrs, "password_confirmation", "different")
      conn = post(conn, ~p"/register", registration_form: invalid_attrs)

      assert html_response(conn, 200) =~ "hasła nie są identyczne"
    end

    test "renders errors with missing required fields", %{conn: conn} do
      conn = post(conn, ~p"/register", registration_form: %{})

      response = html_response(conn, 200)
      assert response =~ "to pole jest wymagane"
    end

    test "renders errors with duplicate email", %{conn: conn} do
      # Create first user
      post(conn, ~p"/register", registration_form: @valid_attrs)

      # Try to create second user with same email
      conn = post(conn, ~p"/register", registration_form: @valid_attrs)

      response = html_response(conn, 200)
      assert response =~ "ten adres e-mail jest już zarejestrowany"
    end

    test "renders errors without accepting terms", %{conn: conn} do
      invalid_attrs = Map.put(@valid_attrs, "terms", "false")
      conn = post(conn, ~p"/register", registration_form: invalid_attrs)

      assert html_response(conn, 200) =~ "musisz zaakceptować regulamin"
    end
  end

  describe "POST /register/premium" do
    @valid_premium_attrs %{
      "email" => "premium@example.com",
      "password" => "password123",
      "password_confirmation" => "password123",
      "tender_category" => "Dostawy",
      "region" => "mazowieckie",
      "keyword" => "oprogramowanie",
      "terms" => "true"
    }

    test "creates premium user and redirects to success page", %{conn: conn} do
      conn = post(conn, ~p"/register/premium", registration_form: @valid_premium_attrs)
      assert redirected_to(conn) == ~p"/registration-success"

      # Verify user was created with premium subscription
      user = Accounts.get_non_verified_user_by_email("premium@example.com")
      assert user
      assert user.subscription_plan == "paid"
      assert user.email_verified == false
    end

    test "creates premium alert with keyword", %{conn: conn} do
      post(conn, ~p"/register/premium", registration_form: @valid_premium_attrs)

      user = Accounts.get_non_verified_user_by_email("premium@example.com")
      alerts = Accounts.list_user_alerts(user)
      assert length(alerts) == 1

      alert = List.first(alerts)
      assert alert.rules["keywords"] == ["oprogramowanie"]
      assert alert.rules["regions"] == ["mazowieckie"]
    end

    test "creates premium user without keyword", %{conn: conn} do
      attrs = Map.delete(@valid_premium_attrs, "keyword")
      conn = post(conn, ~p"/register/premium", registration_form: attrs)
      assert redirected_to(conn) == ~p"/registration-success"

      user = Accounts.get_non_verified_user_by_email("premium@example.com")
      alerts = Accounts.list_user_alerts(user)
      alert = List.first(alerts)
      assert alert.rules["keywords"] == []
    end

    test "renders errors on premium form with invalid data", %{conn: conn} do
      invalid_attrs = Map.put(@valid_premium_attrs, "email", "invalid-email")
      conn = post(conn, ~p"/register/premium", registration_form: invalid_attrs)

      assert html_response(conn, 200) =~ "nieprawidłowy format adresu e-mail"
      assert html_response(conn, 200) =~ "Plan Premium"
    end
  end

  describe "GET /registration-success" do
    test "renders registration success page", %{conn: conn} do
      conn = get(conn, ~p"/registration-success")
      assert html_response(conn, 200) =~ "Rejestracja zakończona!"
      assert html_response(conn, 200) =~ "Sprawdź swoją skrzynkę e-mail"
    end
  end

  describe "GET /verify-email" do
    setup %{conn: conn} do
      # Create a user with verification token
      {:ok, %{user: user}} =
        Accounts.register_user(%{
          email: "test@example.com",
          password: "password123",
          tender_category: "Dostawy",
          region: "mazowieckie"
        })

      %{conn: conn, user: user}
    end

    test "verifies email and redirects to login with valid token", %{conn: conn, user: user} do
      conn = get(conn, ~p"/verify-email?token=#{user.email_verification_token}")
      assert redirected_to(conn) == ~p"/login"

      # Verify user email was updated
      updated_user = Accounts.get_user_by_email("test@example.com")
      assert updated_user.email_verified == true
      assert updated_user.email_verification_token == nil
    end

    test "redirects to home with invalid token", %{conn: conn} do
      conn = get(conn, ~p"/verify-email?token=invalid-token")
      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to home with missing token", %{conn: conn} do
      conn = get(conn, ~p"/verify-email")
      assert redirected_to(conn) == ~p"/"
    end
  end
end
