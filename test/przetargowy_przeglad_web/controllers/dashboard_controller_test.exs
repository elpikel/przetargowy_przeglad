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

  describe "POST /dashboard/alerts/new for premium user" do
    setup %{conn: conn} do
      {:ok, %{user: premium_user}} =
        Accounts.register_premium_user(%{
          email: "premium3@example.com",
          password: "password123",
          tender_category: "Usługi",
          region: "malopolskie",
          keyword: "software"
        })

      {:ok, verified_premium} = Accounts.verify_user_email(premium_user.email_verification_token)

      premium_conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, verified_premium.id)

      %{premium_conn: premium_conn, premium_user: verified_premium}
    end

    test "creates a new alert for premium user", %{premium_conn: conn, premium_user: user} do
      # User should have 1 alert initially
      assert length(Accounts.list_user_alerts(user)) == 1

      conn =
        post(conn, ~p"/dashboard/alerts/new", %{
          "industries" => ["it"],
          "regions" => ["wielkopolskie"],
          "keywords" => "cloud"
        })

      assert redirected_to(conn) == ~p"/dashboard"

      # User should now have 2 alerts
      alerts = Accounts.list_user_alerts(user)
      assert length(alerts) == 2
    end
  end

  describe "POST /dashboard/alerts/new for free user" do
    test "rejects creating new alert for free user", %{conn: conn, user: user} do
      # User should have 1 alert initially
      assert length(Accounts.list_user_alerts(user)) == 1

      conn =
        post(conn, ~p"/dashboard/alerts/new", %{
          "tender_category" => "Usługi",
          "region" => "wielkopolskie"
        })

      assert redirected_to(conn) == ~p"/dashboard"

      # User should still have only 1 alert
      assert length(Accounts.list_user_alerts(user)) == 1
    end
  end

  describe "POST /dashboard/alerts/new with redirect_to parameter" do
    setup %{conn: conn} do
      {:ok, %{user: premium_user}} =
        Accounts.register_premium_user(%{
          email: "premium5@example.com",
          password: "password123",
          tender_category: "Usługi",
          region: "malopolskie",
          keyword: "software"
        })

      {:ok, verified_premium} = Accounts.verify_user_email(premium_user.email_verification_token)

      premium_conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, verified_premium.id)

      %{premium_conn: premium_conn, premium_user: verified_premium}
    end

    test "redirects to custom path when redirect_to is provided", %{
      premium_conn: conn,
      premium_user: user
    } do
      initial_count = length(Accounts.list_user_alerts(user))

      conn =
        post(conn, ~p"/dashboard/alerts/new", %{
          "industries" => ["it"],
          "regions" => ["mazowieckie"],
          "keywords" => "cloud",
          "redirect_to" => "/tenders?q=test&regions[]=mazowieckie&page=1"
        })

      assert redirected_to(conn) == "/tenders?q=test&regions[]=mazowieckie&page=1"
      assert length(Accounts.list_user_alerts(user)) == initial_count + 1
    end

    test "redirects to dashboard when redirect_to is not provided", %{
      premium_conn: conn,
      premium_user: user
    } do
      initial_count = length(Accounts.list_user_alerts(user))

      conn =
        post(conn, ~p"/dashboard/alerts/new", %{
          "industries" => ["it"],
          "regions" => ["wielkopolskie"],
          "keywords" => "test"
        })

      assert redirected_to(conn) == ~p"/dashboard"
      assert length(Accounts.list_user_alerts(user)) == initial_count + 1
    end

    test "shows success flash message", %{premium_conn: conn} do
      conn =
        post(conn, ~p"/dashboard/alerts/new", %{
          "industries" => ["it"],
          "regions" => ["mazowieckie"],
          "keywords" => "cloud"
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Alert został dodany pomyślnie"
    end
  end

  describe "edge cases for alert creation" do
    setup %{conn: conn} do
      {:ok, %{user: premium_user}} =
        Accounts.register_premium_user(%{
          email: "premium6@example.com",
          password: "password123",
          tender_category: "Usługi",
          region: "malopolskie",
          keyword: "software"
        })

      {:ok, verified_premium} = Accounts.verify_user_email(premium_user.email_verification_token)

      premium_conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, verified_premium.id)

      %{premium_conn: premium_conn, premium_user: verified_premium}
    end

    test "handles empty keywords string", %{premium_conn: conn, premium_user: user} do
      conn =
        post(conn, ~p"/dashboard/alerts/new", %{
          "industries" => ["it"],
          "regions" => ["mazowieckie"],
          "keywords" => ""
        })

      assert redirected_to(conn) == ~p"/dashboard"

      alerts = Accounts.list_user_alerts(user)
      new_alert = List.last(alerts)
      keywords = new_alert.rules["keywords"] || new_alert.rules[:keywords]

      assert keywords == []
    end

    test "handles keywords with extra whitespace", %{premium_conn: conn, premium_user: user} do
      conn =
        post(conn, ~p"/dashboard/alerts/new", %{
          "industries" => ["it"],
          "regions" => ["mazowieckie"],
          "keywords" => "  software  ,  hardware  ,  cloud  "
        })

      assert redirected_to(conn) == ~p"/dashboard"

      alerts = Accounts.list_user_alerts(user)
      new_alert = List.last(alerts)
      keywords = new_alert.rules["keywords"] || new_alert.rules[:keywords]

      assert "software" in keywords
      assert "hardware" in keywords
      assert "cloud" in keywords
      assert length(keywords) == 3
    end

    test "handles nil industries parameter", %{premium_conn: conn, premium_user: user} do
      conn =
        post(conn, ~p"/dashboard/alerts/new", %{
          "regions" => ["mazowieckie"],
          "keywords" => "test"
        })

      assert redirected_to(conn) == ~p"/dashboard"

      alerts = Accounts.list_user_alerts(user)
      new_alert = List.last(alerts)
      industries = new_alert.rules["industries"] || new_alert.rules[:industries]

      assert industries == []
    end

    test "handles nil regions parameter", %{premium_conn: conn, premium_user: user} do
      conn =
        post(conn, ~p"/dashboard/alerts/new", %{
          "industries" => ["it"],
          "keywords" => "test"
        })

      assert redirected_to(conn) == ~p"/dashboard"

      alerts = Accounts.list_user_alerts(user)
      new_alert = List.last(alerts)
      regions = new_alert.rules["regions"] || new_alert.rules[:regions]

      assert regions == []
    end

    test "filters out empty strings from keywords", %{premium_conn: conn, premium_user: user} do
      conn =
        post(conn, ~p"/dashboard/alerts/new", %{
          "industries" => ["it"],
          "regions" => ["mazowieckie"],
          "keywords" => "software,,cloud,,"
        })

      assert redirected_to(conn) == ~p"/dashboard"

      alerts = Accounts.list_user_alerts(user)
      new_alert = List.last(alerts)
      keywords = new_alert.rules["keywords"] || new_alert.rules[:keywords]

      assert "software" in keywords
      assert "cloud" in keywords
      refute "" in keywords
      assert length(keywords) == 2
    end
  end

  describe "DELETE /dashboard/alerts/:id for premium user" do
    setup %{conn: conn} do
      {:ok, %{user: premium_user}} =
        Accounts.register_premium_user(%{
          email: "premium4@example.com",
          password: "password123",
          tender_category: "Usługi",
          region: "malopolskie",
          keyword: "software"
        })

      {:ok, verified_premium} = Accounts.verify_user_email(premium_user.email_verification_token)

      # Create a second alert so we can delete one
      {:ok, _second_alert} =
        Accounts.create_alert(%{
          user_id: verified_premium.id,
          rules: %{industries: ["it"], regions: ["mazowieckie"], keywords: ["cloud"]}
        })

      premium_conn =
        conn
        |> init_test_session(%{})
        |> put_session(:user_id, verified_premium.id)

      %{premium_conn: premium_conn, premium_user: verified_premium}
    end

    test "deletes an alert for premium user with multiple alerts", %{
      premium_conn: conn,
      premium_user: user
    } do
      alerts = Accounts.list_user_alerts(user)
      assert length(alerts) == 2

      alert_to_delete = List.last(alerts)
      conn = delete(conn, ~p"/dashboard/alerts/#{alert_to_delete.id}")

      assert redirected_to(conn) == ~p"/dashboard"

      # User should now have 1 alert
      assert length(Accounts.list_user_alerts(user)) == 1
    end

    test "cannot delete last alert for premium user", %{premium_conn: conn, premium_user: user} do
      # Delete one alert first
      alerts = Accounts.list_user_alerts(user)
      Accounts.delete_alert(List.last(alerts))

      # Now try to delete the last remaining alert
      [last_alert] = Accounts.list_user_alerts(user)
      conn = delete(conn, ~p"/dashboard/alerts/#{last_alert.id}")

      assert redirected_to(conn) == ~p"/dashboard"

      # User should still have 1 alert
      assert length(Accounts.list_user_alerts(user)) == 1
    end
  end

  describe "DELETE /dashboard/alerts/:id for free user" do
    test "cannot delete alert for free user", %{conn: conn, user: user} do
      [alert] = Accounts.list_user_alerts(user)
      conn = delete(conn, ~p"/dashboard/alerts/#{alert.id}")

      assert redirected_to(conn) == ~p"/dashboard"

      # User should still have 1 alert
      assert length(Accounts.list_user_alerts(user)) == 1
    end
  end
end
