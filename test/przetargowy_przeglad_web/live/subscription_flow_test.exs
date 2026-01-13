defmodule PrzetargowyPrzegladWeb.SubscriptionFlowTest do
  use PrzetargowyPrzegladWeb.ConnCase
  import Swoosh.TestAssertions
  import Phoenix.LiveViewTest
  alias PrzetargowyPrzeglad.Subscribers

  test "complete signup flow", %{conn: conn} do
    # 1. Visit landing page
    {:ok, view, _html} = live(conn, "/")

    # 2. Fill and submit form
    view
    |> form("form", subscriber: %{email: "test@example.com", name: "Jan"})
    |> render_submit()

    # 3. Check subscriber created
    subscriber = Subscribers.get_by_email("test@example.com")
    assert subscriber != nil
    assert subscriber.status == "pending"

    # 4. Check email sent
    assert_email_sent(subject: "Potwierdź zapis do Przetargowego Przeglądu")

    # 5. Confirm subscription
    {:ok, _view, html} = live(conn, "/confirm/#{subscriber.confirmation_token}")
    assert html =~ "Email potwierdzony"

    # 6. Check status updated
    subscriber = Subscribers.get_by_email("test@example.com")
    assert subscriber.status == "confirmed"
  end
end
