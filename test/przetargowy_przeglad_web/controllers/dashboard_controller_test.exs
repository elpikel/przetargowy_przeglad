defmodule PrzetargowyPrzegladWeb.DashboardControllerTest do
  use PrzetargowyPrzegladWeb.ConnCase, async: true

  alias PrzetargowyPrzeglad.Accounts

  setup %{conn: conn} do
    # Create and verify a user for authentication
    {:ok, %{user: user}} =
      Accounts.register_user(%{
        email: "test@example.com",
        password: "password123",
        tender_category: "Dostawy",
        region: "mazowieckie"
      })

    # Verify the user's email
    {:ok, verified_user} = Accounts.verify_user_email(user.email_verification_token)

    # Set up authenticated connection
    conn =
      conn
      |> init_test_session(%{})
      |> put_session(:user_id, verified_user.id)

    %{conn: conn, user: verified_user}
  end

  describe "GET /dashboard for free user" do
    test "renders dashboard with free plan section", %{conn: conn} do
      conn = get(conn, ~p"/dashboard")

      assert html_response(conn, 200) =~ "Ustawienia"
      assert html_response(conn, 200) =~ "Plan Darmowy"
      assert html_response(conn, 200) =~ "Rodzaj zamówienia"
      assert html_response(conn, 200) =~ "Region"
    end

    test "shows current alert preferences", %{conn: conn} do
      conn = get(conn, ~p"/dashboard")

      # The user was created with Dostawy and mazowieckie
      response = html_response(conn, 200)
      assert response =~ "Dostawy"
      assert response =~ "mazowieckie"
    end
  end

  describe "GET /dashboard for premium user" do
    setup %{conn: conn} do
      # Create a premium user
      {:ok, %{user: premium_user}} =
        Accounts.register_premium_user(%{
          email: "premium@example.com",
          password: "password123",
          tender_category: "Usługi",
          region: "malopolskie",
          keyword: "oprogramowanie"
        })

      # Verify the user's email
      {:ok, verified_premium} = Accounts.verify_user_email(premium_user.email_verification_token)

      # Set up authenticated connection for premium user
      premium_conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, verified_premium.id)

      %{premium_conn: premium_conn, premium_user: verified_premium}
    end

    test "renders dashboard with premium plan section", %{premium_conn: conn} do
      conn = get(conn, ~p"/dashboard")

      assert html_response(conn, 200) =~ "Ustawienia"
      assert html_response(conn, 200) =~ "Plan Premium"
      assert html_response(conn, 200) =~ "Branże"
      assert html_response(conn, 200) =~ "Regiony"
      assert html_response(conn, 200) =~ "Słowa kluczowe"
    end

    test "shows current premium alert preferences", %{premium_conn: conn} do
      conn = get(conn, ~p"/dashboard")

      response = html_response(conn, 200)
      # The premium user was created with malopolskie region and oprogramowanie keyword
      assert response =~ "malopolskie"
    end
  end

  describe "POST /dashboard/alerts for free user" do
    test "updates alert preferences", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/dashboard/alerts", %{
          "tender_category" => "Usługi",
          "region" => "wielkopolskie"
        })

      assert redirected_to(conn) == ~p"/dashboard"

      # Verify the alert was updated
      alerts = Accounts.list_user_alerts(user)
      alert = List.first(alerts)
      assert alert.rules["tender_category"] == "Usługi" || alert.rules[:tender_category] == "Usługi"
      assert alert.rules["region"] == "wielkopolskie" || alert.rules[:region] == "wielkopolskie"
    end
  end

  describe "POST /dashboard/alerts for premium user" do
    setup %{conn: conn} do
      # Create a premium user
      {:ok, %{user: premium_user}} =
        Accounts.register_premium_user(%{
          email: "premium2@example.com",
          password: "password123",
          tender_category: "Usługi",
          region: "malopolskie",
          keyword: "software"
        })

      # Verify the user's email
      {:ok, verified_premium} = Accounts.verify_user_email(premium_user.email_verification_token)

      # Set up authenticated connection for premium user
      premium_conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, verified_premium.id)

      %{premium_conn: premium_conn, premium_user: verified_premium}
    end

    test "updates premium alert preferences with keywords", %{
      premium_conn: conn,
      premium_user: user
    } do
      conn =
        post(conn, ~p"/dashboard/alerts", %{
          "industries" => ["it", "budownictwo"],
          "regions" => ["mazowieckie", "malopolskie"],
          "keywords" => "software, hardware, cloud"
        })

      assert redirected_to(conn) == ~p"/dashboard"

      # Verify the alert was updated
      alerts = Accounts.list_user_alerts(user)
      alert = List.first(alerts)

      industries = alert.rules["industries"] || alert.rules[:industries]
      regions = alert.rules["regions"] || alert.rules[:regions]
      keywords = alert.rules["keywords"] || alert.rules[:keywords]

      assert "it" in industries
      assert "budownictwo" in industries
      assert "mazowieckie" in regions
      assert "malopolskie" in regions
      assert "software" in keywords
      assert "hardware" in keywords
      assert "cloud" in keywords
    end
  end
end
