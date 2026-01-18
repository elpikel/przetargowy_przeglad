defmodule PrzetargowyPrzegladWeb.LandingLiveTest do
  use PrzetargowyPrzegladWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PrzetargowyPrzeglad.Subscribers

  describe "mount/3" do
    test "renders landing page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Przetargowy Przegląd"
      assert html =~ "Cotygodniowy przegląd najlepszych przetargów publicznych"
    end

    test "shows subscription form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Email *"
      assert html =~ "Zapisz się za darmo"
    end

    test "shows features section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Liczba tygodnia"
      assert html =~ "Top 5 przetargów"
      assert html =~ "Praktyczne tipy"
    end

    test "captures referral code from URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/?ref=ABC123")

      assert view |> element("input[name='subscriber[referred_by]']") |> has_element?()
    end

    test "shows subscriber count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "czytelników"
    end
  end

  describe "validate event" do
    test "validates email format", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("form", %{subscriber: %{email: "invalid-email"}})
        |> render_change()

      assert html =~ "Niepoprawny format"
    end

    test "shows error for empty email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("form", %{subscriber: %{email: ""}})
        |> render_change()

      assert html =~ "To pole jest wymagane"
    end

    test "accepts valid email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("form", %{subscriber: %{email: "test@example.com"}})
        |> render_change()

      refute html =~ "Niepoprawny format"
      refute html =~ "To pole jest wymagane"
    end

    test "preserves name input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("form", %{subscriber: %{email: "test@example.com", name: "Jan Kowalski"}})
        |> render_change()

      assert html =~ "Jan Kowalski"
    end
  end

  describe "toggle_preferences event" do
    test "shows preferences section when toggled", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      refute html =~ "Firma"
      refute html =~ "Branża"

      html =
        view
        |> element("button[phx-click='toggle_preferences']")
        |> render_click()

      assert html =~ "Firma"
      assert html =~ "Branża"
      assert html =~ "Województwa zainteresowania"
    end

    test "hides preferences section when toggled again", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Show preferences
      view
      |> element("button[phx-click='toggle_preferences']")
      |> render_click()

      # Hide preferences
      html =
        view
        |> element("button[phx-click='toggle_preferences']")
        |> render_click()

      refute html =~ "Województwa zainteresowania"
    end

    test "shows industry options when preferences expanded", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> element("button[phx-click='toggle_preferences']")
        |> render_click()

      assert html =~ "IT / Informatyka"
      assert html =~ "Budowlana"
      assert html =~ "Medyczna"
    end

    test "shows region checkboxes when preferences expanded", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> element("button[phx-click='toggle_preferences']")
        |> render_click()

      assert html =~ "Mazowieckie"
      assert html =~ "Małopolskie"
      assert html =~ "Śląskie"
    end
  end

  describe "toggle_region event" do
    test "toggles region checkbox", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Show preferences first
      view
      |> element("button[phx-click='toggle_preferences']")
      |> render_click()

      # Toggle region
      html =
        view
        |> element("input[phx-value-region='mazowieckie']")
        |> render_click()

      # The region should be checked (hidden input should exist)
      assert html =~ "name=\"subscriber[regions][]\" value=\"mazowieckie\""
    end

    test "untoggle region removes from selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Show preferences first
      view
      |> element("button[phx-click='toggle_preferences']")
      |> render_click()

      # Toggle region on
      view
      |> element("input[phx-value-region='mazowieckie']")
      |> render_click()

      # Toggle region off
      html =
        view
        |> element("input[phx-value-region='mazowieckie']")
        |> render_click()

      refute html =~ "name=\"subscriber[regions][]\" value=\"mazowieckie\""
    end

    test "can select multiple regions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Show preferences first
      view
      |> element("button[phx-click='toggle_preferences']")
      |> render_click()

      # Toggle first region
      view
      |> element("input[phx-value-region='mazowieckie']")
      |> render_click()

      # Toggle second region
      html =
        view
        |> element("input[phx-value-region='malopolskie']")
        |> render_click()

      assert html =~ "name=\"subscriber[regions][]\" value=\"mazowieckie\""
      assert html =~ "name=\"subscriber[regions][]\" value=\"malopolskie\""
    end
  end

  describe "subscribe event" do
    test "successful subscription shows confirmation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("form", %{subscriber: %{email: "newuser@example.com"}})
        |> render_submit()

      assert html =~ "Sprawdź swoją skrzynkę!"
      assert html =~ "Wysłaliśmy email z linkiem potwierdzającym"
    end

    test "creates subscriber in database", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{subscriber: %{email: "db-test@example.com", name: "Test User"}})
      |> render_submit()

      subscriber = Subscribers.get_by_email("db-test@example.com")
      assert subscriber != nil
      assert subscriber.name == "Test User"
      assert subscriber.status == "pending"
    end

    test "subscriber has confirmation token", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{subscriber: %{email: "token-test@example.com"}})
      |> render_submit()

      subscriber = Subscribers.get_by_email("token-test@example.com")
      assert subscriber.confirmation_token != nil
    end

    test "subscription with referral code includes hidden input", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/?ref=REFCODE123")

      # Referral code should be in hidden input
      assert html =~ "REFCODE123"
      assert view |> element("input[name='subscriber[referred_by]']") |> has_element?()

      # Subscription should still work
      html =
        view
        |> form("form", %{subscriber: %{email: "referred@example.com"}})
        |> render_submit()

      assert html =~ "Sprawdź swoją skrzynkę!"
    end

    test "subscription with preferences", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Show preferences first
      view
      |> element("button[phx-click='toggle_preferences']")
      |> render_click()

      # Fill form with preferences
      view
      |> form("form", %{
        subscriber: %{
          email: "prefs@example.com",
          name: "Jan",
          company_name: "Firma Sp. z o.o.",
          industry: "it"
        }
      })
      |> render_submit()

      subscriber = Subscribers.get_by_email("prefs@example.com")
      assert subscriber.company_name == "Firma Sp. z o.o."
      assert subscriber.industry == "it"
    end

    test "duplicate email shows error", %{conn: conn} do
      # Create existing subscriber
      {:ok, _} = Subscribers.subscribe(%{email: "existing@example.com"})

      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("form", %{subscriber: %{email: "existing@example.com"}})
        |> render_submit()

      assert html =~ "Ten email jest już zarejestrowany"
    end

    test "invalid email on submit shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("form", %{subscriber: %{email: "not-an-email"}})
        |> render_submit()

      assert html =~ "Niepoprawny format"
    end
  end

  describe "form state persistence" do
    test "industry selection persists after validation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Show preferences
      view
      |> element("button[phx-click='toggle_preferences']")
      |> render_click()

      # Fill form with industry
      html =
        view
        |> form("form", %{
          subscriber: %{
            email: "test@example.com",
            industry: "it"
          }
        })
        |> render_change()

      # Industry should still be selected
      assert html =~ "selected"
    end

    test "company name persists after validation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Show preferences
      view
      |> element("button[phx-click='toggle_preferences']")
      |> render_click()

      html =
        view
        |> form("form", %{
          subscriber: %{
            email: "test@example.com",
            company_name: "Moja Firma"
          }
        })
        |> render_change()

      assert html =~ "Moja Firma"
    end
  end
end
